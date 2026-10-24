import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct GitHubDeviceCode: Decodable, Equatable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURI: String
    public let expiresIn: Int
    public let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

public enum GitHubTokenPoll: Equatable, Sendable {
    case pending
    case slowDown
    case token(String)
}

public enum GitHubDeviceFlowError: LocalizedError, Equatable, Sendable {
    case notConfigured
    case expired
    case denied
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "GitHub sign-in isn't configured in this build. Use a personal access token instead."
        case .expired:       return "The sign-in code expired. Start again."
        case .denied:        return "Sign-in was cancelled on GitHub."
        case .failed(let m): return "GitHub sign-in failed: \(m)"
        }
    }
}

/// OAuth device flow (PLAN §5.8, D4): the app shows a code, the user approves
/// at github.com/login/device, and the app polls for the token. Needs only a
/// client ID — no client secret and no backend. These two auth endpoints are
/// the only non-GET requests SmartWard sends to GitHub.
public struct GitHubDeviceFlow: Sendable {
    public let clientID: String
    public let scope: String
    private let transport: any HTTPTransport
    private let sleep: @Sendable (UInt64) async throws -> Void

    /// `includePrivateRepos` asks for the `repo` scope. OAuth apps have no
    /// read-only private scope; SmartWard enforces read-only use itself.
    public init(clientID: String, includePrivateRepos: Bool,
                transport: any HTTPTransport = URLSessionTransport(),
                sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) {
        self.clientID = clientID
        self.scope = includePrivateRepos ? "repo read:user" : "read:user"
        self.transport = transport
        self.sleep = sleep
    }

    public func start() async throws -> GitHubDeviceCode {
        guard !clientID.isEmpty else { throw GitHubDeviceFlowError.notConfigured }
        let request = Self.formRequest("https://github.com/login/device/code",
                                       fields: ["client_id": clientID, "scope": scope])
        let (data, response) = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            throw GitHubDeviceFlowError.failed(String(decoding: data.prefix(300), as: UTF8.self))
        }
        do {
            return try JSONDecoder().decode(GitHubDeviceCode.self, from: data)
        } catch {
            throw GitHubDeviceFlowError.failed("unexpected response")
        }
    }

    public func pollOnce(deviceCode: String) async throws -> GitHubTokenPoll {
        let request = Self.formRequest("https://github.com/login/oauth/access_token",
                                       fields: ["client_id": clientID,
                                                "device_code": deviceCode,
                                                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"])
        let (data, _) = try await transport.send(request)
        return try Self.parsePoll(data)
    }

    /// Polls at GitHub's interval (backing off on `slow_down`) until the user
    /// approves, denies, or the code expires.
    public func waitForToken(_ code: GitHubDeviceCode, now: @Sendable () -> Date = { Date() }) async throws -> String {
        let deadline = now().addingTimeInterval(TimeInterval(code.expiresIn))
        var interval = max(code.interval, 1)
        while now() < deadline {
            try await sleep(UInt64(interval) * 1_000_000_000)
            let poll = try await pollOnce(deviceCode: code.deviceCode)
            switch poll {
            case .pending:
                continue
            case .slowDown:
                interval += 5
            case .token(let token):
                return token
            }
        }
        throw GitHubDeviceFlowError.expired
    }

    static func parsePoll(_ data: Data) throws -> GitHubTokenPoll {
        struct Reply: Decodable {
            let accessToken: String?
            let error: String?
            let errorDescription: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case error
                case errorDescription = "error_description"
            }
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
            throw GitHubDeviceFlowError.failed("unexpected response")
        }
        if let token = reply.accessToken, !token.isEmpty { return .token(token) }
        switch reply.error {
        case "authorization_pending": return .pending
        case "slow_down":             return .slowDown
        case "expired_token":         throw GitHubDeviceFlowError.expired
        case "access_denied":         throw GitHubDeviceFlowError.denied
        default:
            throw GitHubDeviceFlowError.failed(reply.errorDescription ?? reply.error ?? "unknown error")
        }
    }

    static func formRequest(_ url: String, fields: [String: String]) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = fields.keys.sorted().map { URLQueryItem(name: $0, value: fields[$0]) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        return request
    }
}
