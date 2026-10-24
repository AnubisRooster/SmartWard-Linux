import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !canImport(Darwin)
/// swift-corelibs-foundation has no `URLSession.bytes(for:delegate:)`, so on
/// Linux the same guarantees (public-host redirects only, stop at `maxBytes`)
/// come from a data-task delegate.
final class CappedFetch: @unchecked Sendable {
    private let maxBytes: Int
    private let lock = NSLock()
    private var data = Data()
    private var response: HTTPURLResponse?
    private var failure: Error?
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?

    private init(maxBytes: Int) { self.maxBytes = maxBytes }

    static func run(_ request: URLRequest, maxBytes: Int) async throws -> (Data, HTTPURLResponse) {
        let fetch = CappedFetch(maxBytes: maxBytes)
        return try await withCheckedThrowingContinuation { continuation in
            fetch.lock.lock(); fetch.continuation = continuation; fetch.lock.unlock()
            let task = Router.shared.session.dataTask(with: request)
            Router.shared.register(fetch, for: task)
            task.resume()
        }
    }

    /// One long-lived session (creating and tearing down a session per
    /// request trips a swift-corelibs-foundation crash) that hands each task's
    /// callbacks to the fetch that started it.
    final class Router: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        static let shared = Router()
        private let lock = NSLock()
        private var fetches: [Int: CappedFetch] = [:]
        /// Created up front: a lazy property raced when several requests started at once.
        private(set) var session: URLSession!

        private override init() {
            super.init()
            session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        }

        func register(_ fetch: CappedFetch, for task: URLSessionTask) {
            lock.lock(); fetches[task.taskIdentifier] = fetch; lock.unlock()
        }

        private func fetch(for task: URLSessionTask) -> CappedFetch? {
            lock.lock(); defer { lock.unlock() }
            return fetches[task.taskIdentifier]
        }

        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            guard let url = request.url, PublicHost.allowsRedirect(to: url) else { return completionHandler(nil) }
            completionHandler(request)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let fetch = fetch(for: dataTask) else { return completionHandler(.cancel) }
            completionHandler(fetch.received(response) ? .allow : .cancel)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
            if fetch(for: dataTask)?.received(chunk) == false { dataTask.cancel() }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            lock.lock(); let fetch = fetches.removeValue(forKey: task.taskIdentifier); lock.unlock()
            fetch?.completed(error)
        }
    }

    private func finish(_ result: Result<(Data, HTTPURLResponse), Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }

    /// - Returns: whether to keep reading.
    func received(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else {
            finish(.failure(GitHubError.invalidResponse))
            return false
        }
        guard http.expectedContentLength <= Int64(maxBytes) else {
            finish(.failure(IngestError.tooLarge))
            return false
        }
        lock.lock(); self.response = http; lock.unlock()
        return true
    }

    /// - Returns: whether to keep reading.
    func received(_ chunk: Data) -> Bool {
        lock.lock()
        data.append(chunk)
        let tooBig = data.count > maxBytes
        lock.unlock()
        if tooBig { finish(.failure(IngestError.tooLarge)) }
        return !tooBig
    }

    func completed(_ error: Error?) {
        lock.lock()
        let response = self.response, data = self.data
        lock.unlock()
        if let error { finish(.failure(error)) }
        else if let response { finish(.success((data, response))) }
        else { finish(.failure(GitHubError.invalidResponse)) }
    }
}
#endif
