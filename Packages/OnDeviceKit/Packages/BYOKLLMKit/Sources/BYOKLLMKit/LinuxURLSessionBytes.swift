import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking

/// swift-corelibs-foundation has no `URLSession.bytes(for:)`. This shim covers
/// the one thing BYOKLLMKit uses it for: reading a streamed response line by
/// line (SSE). Same shape as Apple's `(AsyncBytes, URLResponse)` result, with
/// only `.lines` available.
struct LinuxStreamedBytes {
    let lines: AsyncThrowingStream<String, Error>
}

private final class StreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var responseContinuation: CheckedContinuation<URLResponse, Error>?
    private var lineContinuation: AsyncThrowingStream<String, Error>.Continuation?
    private var finished = false

    func attach(_ continuation: AsyncThrowingStream<String, Error>.Continuation) {
        lock.lock(); lineContinuation = continuation; lock.unlock()
    }

    func awaitResponse(_ start: () -> Void) async throws -> URLResponse {
        try await withCheckedThrowingContinuation { cont in
            lock.lock(); responseContinuation = cont; lock.unlock()
            start()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock(); let cont = responseContinuation; responseContinuation = nil; lock.unlock()
        cont?.resume(returning: response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            var line = buffer[buffer.startIndex..<nl]
            if line.last == 0x0D { line = line.dropLast() }
            lines.append(String(decoding: line, as: UTF8.self))
            buffer.removeSubrange(buffer.startIndex...nl)
        }
        let cont = lineContinuation
        lock.unlock()
        for line in lines { cont?.yield(line) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let respCont = responseContinuation; responseContinuation = nil
        let cont = lineContinuation
        let tail = buffer; buffer = Data()
        lock.unlock()
        if let error { respCont?.resume(throwing: error) }
        if !tail.isEmpty { cont?.yield(String(decoding: tail, as: UTF8.self)) }
        if let error { cont?.finish(throwing: error) } else { cont?.finish() }
    }
}

extension URLSession {
    func bytes(for request: URLRequest) async throws -> (LinuxStreamedBytes, URLResponse) {
        let delegate = StreamDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        var continuation: AsyncThrowingStream<String, Error>.Continuation!
        let lines = AsyncThrowingStream<String, Error> { continuation = $0 }
        delegate.attach(continuation)
        continuation.onTermination = { _ in task.cancel(); session.finishTasksAndInvalidate() }
        let response = try await delegate.awaitResponse { task.resume() }
        return (LinuxStreamedBytes(lines: lines), response)
    }
}
#endif
