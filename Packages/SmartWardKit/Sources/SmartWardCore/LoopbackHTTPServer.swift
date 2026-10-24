import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// A small HTTP/1.1 server that listens on 127.0.0.1 only and answers one
/// request per connection. Just enough for the Settings page; not a general web server.
public final class LoopbackHTTPServer: @unchecked Sendable {
    public typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse

    public enum ServerError: LocalizedError {
        case cannotBind(port: Int)
        public var errorDescription: String? {
            switch self {
            case .cannotBind(let port): return "Couldn't listen on 127.0.0.1:\(port). Is something else using it?"
            }
        }
    }

    static let maxHeaderBytes = 16 * 1024
    static let maxBodyBytes = 64 * 1024

    private let handler: Handler
    private var listener: Int32 = -1
    public private(set) var port = 0

    public init(handler: @escaping Handler) { self.handler = handler }

    deinit { stop() }

    /// Starts listening on `port` (0 picks a free one) and returns the port in use.
    @discardableResult
    public func start(port requested: Int = 0) throws -> Int {
        #if canImport(Glibc)
        let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { throw ServerError.cannotBind(port: requested) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(requested).bigEndian
        address.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian   // 127.0.0.1
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 16) == 0 else {
            close(fd)
            throw ServerError.cannotBind(port: requested)
        }
        var actual = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        listener = fd
        port = Int(UInt16(bigEndian: actual.sin_port))

        let thread = Thread { [weak self] in self?.acceptLoop(fd) }
        thread.name = "smartward-settings-accept"
        thread.start()
        return port
    }

    public func stop() {
        guard listener >= 0 else { return }
        shutdown(listener, Int32(SHUT_RDWR))
        close(listener)
        listener = -1
    }

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 { return }   // closed by stop()
            let thread = Thread { [handler] in Self.serve(client, handler: handler) }
            thread.start()
        }
    }

    // MARK: One connection

    private static func serve(_ client: Int32, handler: @escaping Handler) {
        defer { close(client) }
        var timeout = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let response: HTTPResponse
        if let request = readRequest(client) {
            let box = ResponseBox()
            let done = DispatchSemaphore(value: 0)
            Task {
                box.value = await handler(request)
                done.signal()
            }
            done.wait()
            response = box.value ?? HTTPResponse(status: 500)
        } else {
            response = HTTPResponse(status: 400, headers: ["Content-Type": "text/plain"], body: Data("Bad request".utf8))
        }
        write(client, serialize(response))
    }

    private final class ResponseBox: @unchecked Sendable { var value: HTTPResponse? }

    private static func readRequest(_ client: Int32) -> HTTPRequest? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 8192)
        let terminator = Data("\r\n\r\n".utf8)
        var headerEnd: Range<Data.Index>?
        while headerEnd == nil {
            let count = recv(client, &chunk, chunk.count, 0)
            if count <= 0 { return nil }
            buffer.append(chunk, count: count)
            headerEnd = buffer.range(of: terminator)
            if buffer.count > maxHeaderBytes && headerEnd == nil { return nil }
        }
        guard let headerEnd, let head = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = Int(headers["content-length"] ?? "0") ?? -1
        guard length >= 0, length <= maxBodyBytes else { return nil }
        var body = Data(buffer[headerEnd.upperBound...])
        while body.count < length {
            let count = recv(client, &chunk, chunk.count, 0)
            if count <= 0 { return nil }
            body.append(chunk, count: count)
        }

        let target = String(requestLine[1])
        let parts = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var query: [String: String] = [:]
        if parts.count == 2 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                query[key] = kv.count == 2 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
            }
        }
        return HTTPRequest(method: String(requestLine[0]), path: String(parts[0]), query: query, headers: headers,
                           body: Data(body.prefix(length)))
    }

    private static func serialize(_ response: HTTPResponse) -> Data {
        let reasons = [200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found", 415: "Unsupported Media Type",
                       500: "Internal Server Error", 502: "Bad Gateway"]
        var head = "HTTP/1.1 \(response.status) \(reasons[response.status] ?? "Status")\r\n"
        var headers = response.headers
        headers["Content-Length"] = String(response.body.count)
        headers["Connection"] = "close"
        headers["X-Content-Type-Options"] = "nosniff"
        for (name, value) in headers.sorted(by: { $0.key < $1.key }) { head += "\(name): \(value)\r\n" }
        return Data((head + "\r\n").utf8) + response.body
    }

    private static func write(_ client: Int32, _ data: Data) {
        data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let sent = send(client, raw.baseAddress! + offset, raw.count - offset, Int32(MSG_NOSIGNAL))
                if sent <= 0 { return }
                offset += sent
            }
        }
    }
}
