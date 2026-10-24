import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import IngestKit
import Pipeline

public struct HTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var query: [String: String]
    /// Header names are lowercased.
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, query: [String: String] = [:], headers: [String: String] = [:],
                body: Data = Data()) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    static func json(_ value: some Encodable, status: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return HTTPResponse(status: status, headers: ["Content-Type": "application/json"],
                            body: (try? encoder.encode(value)) ?? Data("{}".utf8))
    }

    static func error(_ message: String, status: Int) -> HTTPResponse {
        json(["error": message], status: status)
    }
}

/// The Settings page and its API. Pure request → response, so tests call it
/// directly; `LoopbackHTTPServer` carries it over a socket on 127.0.0.1.
///
/// Because a web page on any site can send requests to 127.0.0.1, every
/// request needs this run's secret token and a loopback `Host` header.
public final class SettingsService: @unchecked Sendable {
    public static let sampleSentence = "This is how I will read your articles. Speculative decoding lets a small model draft ahead."

    private let store: SettingsStore
    private let token: String
    private let allowedHosts: Set<String>
    private let speechTransport: any HTTPTransport
    private let ollamaTransport: any HTTPTransport

    public init(store: SettingsStore, token: String, port: Int,
                speechTransport: any HTTPTransport = URLSessionTransport(),
                ollamaTransport: any HTTPTransport = URLSessionTransport()) {
        self.store = store
        self.token = token
        self.allowedHosts = ["127.0.0.1:\(port)", "localhost:\(port)"]
        self.speechTransport = speechTransport
        self.ollamaTransport = ollamaTransport
    }

    public func handle(_ request: HTTPRequest) async -> HTTPResponse {
        guard let host = request.headers["host"]?.lowercased(), allowedHosts.contains(host) else {
            return .error("Unexpected Host header.", status: 403)
        }
        if request.method == "GET", request.path == "/" {
            guard Self.matches(request.query["t"], token) else { return .error("Open the address smartward settings printed.", status: 403) }
            return HTTPResponse(status: 200, headers: [
                "Content-Type": "text/html; charset=utf-8",
                "Cache-Control": "no-store",
                "X-Frame-Options": "DENY",
                "Content-Security-Policy": "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
                    + "connect-src 'self'; media-src blob:; base-uri 'none'; form-action 'none'",
            ], body: Data(SettingsPage.html.utf8))
        }
        guard request.path.hasPrefix("/api/") else { return .error("Not found.", status: 404) }
        guard Self.matches(request.headers["x-smartward-token"], token) else { return .error("Missing or wrong token.", status: 403) }

        do {
            switch (request.method, request.path) {
            case ("GET", "/api/settings"):
                return .json(try store.load())
            case ("PUT", "/api/settings"):
                guard request.headers["content-type"]?.hasPrefix("application/json") == true else {
                    return .error("Send JSON.", status: 415)
                }
                let incoming = try JSONDecoder().decode(AppSettings.self, from: request.body)
                try store.save(incoming)
                return .json(try store.load())
            case ("GET", "/api/voices"):
                return try await voices()
            case ("GET", "/api/status"):
                return await status()
            case ("POST", "/api/sample"):
                return try await sample(request)
            default:
                return .error("Not found.", status: 404)
            }
        } catch let error as SettingsError {
            return .error(error.localizedDescription, status: 400)
        } catch let error as DecodingError {
            return .error("That wasn't valid settings: \(error)", status: 400)
        } catch {
            return .error(error.localizedDescription, status: 502)
        }
    }

    // MARK: Routes

    private func speechClient(voice: String? = nil, speed: Double? = nil) throws -> SpeechClient {
        let settings = try store.load()
        guard let url = URL(string: settings.speechURL) else { throw SettingsError.invalid(["Speech server address is invalid."]) }
        return try SpeechClient(baseURL: url, voice: voice ?? settings.voice, speed: speed ?? settings.speed,
                                transport: speechTransport)
    }

    private func voices() async throws -> HTTPResponse {
        struct Reply: Encodable { var voices: [String] }
        return .json(Reply(voices: try await speechClient().voices()))
    }

    private func sample(_ request: HTTPRequest) async throws -> HTTPResponse {
        struct Body: Decodable { var voice: String; var speed: Double }
        let body = try JSONDecoder().decode(Body.self, from: request.body)
        guard AppSettings.isVoiceName(body.voice), AppSettings.speedRange.contains(body.speed) else {
            return .error("Pick a voice and a speed between 0.5 and 2.", status: 400)
        }
        let audio = try await speechClient(voice: body.voice, speed: body.speed).synthesize(Self.sampleSentence)
        return HTTPResponse(status: 200, headers: ["Content-Type": "audio/wav", "Cache-Control": "no-store"], body: audio)
    }

    private func status() async -> HTTPResponse {
        struct Reply: Encodable {
            var speechReachable = false
            var ollamaReachable = false
            var installedModels: [String] = []
        }
        var reply = Reply()
        if let settings = try? store.load() {
            if let url = URL(string: settings.speechURL),
               let client = try? SpeechClient(baseURL: url, transport: speechTransport) {
                reply.speechReachable = await client.isReachable()
            }
            if let url = URL(string: settings.ollamaURL),
               let client = try? OllamaClient(baseURL: url, transport: ollamaTransport),
               let models = try? await client.installedModels() {
                reply.ollamaReachable = true
                reply.installedModels = models
            }
        }
        return .json(reply)
    }

    /// Compares without stopping at the first difference.
    static func matches(_ given: String?, _ expected: String) -> Bool {
        guard let given, given.utf8.count == expected.utf8.count else { return false }
        return zip(given.utf8, expected.utf8).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
