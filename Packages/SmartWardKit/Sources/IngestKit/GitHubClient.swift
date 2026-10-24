import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The network seam, so GitHub access is testable without a network.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Every request goes through `RedirectPolicy`, so a public page can't
/// redirect it to this device or its local network, and stops reading at
/// `maxBytes`, so a huge or endless response can't exhaust memory.
public struct URLSessionTransport: HTTPTransport {
    public static let defaultMaxBytes = 16 * 1024 * 1024

    public let maxBytes: Int

    public init(maxBytes: Int = defaultMaxBytes) {
        self.maxBytes = maxBytes
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        #if !canImport(Darwin)
        return try await CappedFetch.run(request, maxBytes: maxBytes)
        #else
        let (bytes, response) = try await URLSession.shared.bytes(for: request, delegate: RedirectPolicy.shared)
        guard let http = response as? HTTPURLResponse else {
            bytes.task.cancel()
            throw GitHubError.invalidResponse
        }
        guard http.expectedContentLength <= Int64(maxBytes) else {
            bytes.task.cancel()
            throw IngestError.tooLarge
        }
        var data = Data()
        if http.expectedContentLength > 0 { data.reserveCapacity(Int(http.expectedContentLength)) }
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxBytes {
                bytes.task.cancel()
                throw IngestError.tooLarge
            }
        }
        return (data, http)
        #endif
    }
}

public enum GitHubError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case unauthorized
    case notFound
    case rateLimited(resetAt: Date?)
    case http(status: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "GitHub returned an unexpected response."
        case .unauthorized:
            return "GitHub rejected the token. Sign in again."
        case .notFound:
            return "Not found on GitHub (or not visible to this account)."
        case .rateLimited(let resetAt):
            if let resetAt {
                return "GitHub rate limit reached; it resets at \(resetAt.formatted(date: .omitted, time: .shortened))."
            }
            return "GitHub rate limit reached. Try again later."
        case .http(let status, let message):
            return "GitHub error \(status): \(message)"
        }
    }
}

public struct GitHubRepo: Decodable, Equatable, Sendable, Identifiable {
    public let fullName: String
    public let isPrivate: Bool
    public let description: String?
    public let topics: [String]?
    public let defaultBranch: String
    public let pushedAt: String?
    public let htmlURL: String

    public var id: String { fullName }

    public init(fullName: String, isPrivate: Bool = false, description: String? = nil, topics: [String]? = nil,
                defaultBranch: String = "main", pushedAt: String? = nil, htmlURL: String? = nil) {
        self.fullName = fullName
        self.isPrivate = isPrivate
        self.description = description
        self.topics = topics
        self.defaultBranch = defaultBranch
        self.pushedAt = pushedAt
        self.htmlURL = htmlURL ?? "https://github.com/\(fullName)"
    }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case isPrivate = "private"
        case description
        case topics
        case defaultBranch = "default_branch"
        case pushedAt = "pushed_at"
        case htmlURL = "html_url"
    }
}

public struct GitHubUser: Decodable, Equatable, Sendable {
    public let login: String
}

/// Read-only GitHub REST client. It only ever issues GET requests (PLAN §5.7):
/// SmartWard never writes to GitHub.
public struct GitHubClient: Sendable {
    public static let apiBase = "https://api.github.com"
    static let apiVersion = "2022-11-28"

    private let token: String?
    private let transport: any HTTPTransport

    public init(token: String? = nil, transport: any HTTPTransport = URLSessionTransport()) {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.token = (trimmed?.isEmpty ?? true) ? nil : trimmed
        self.transport = transport
    }

    public var isAuthenticated: Bool { token != nil }

    // MARK: Endpoints

    public func currentUser() async throws -> GitHubUser {
        guard let (data, _) = try await get("/user") else { throw GitHubError.invalidResponse }
        return try decode(GitHubUser.self, from: data)
    }

    /// At most this many pages of 100 repos are listed.
    static let maxRepoPages = 10

    /// Repos the signed-in user owns or collaborates on, most recently pushed
    /// first: every page, not just the first 100.
    public func repositories() async throws -> [GitHubRepo] {
        var all: [GitHubRepo] = []
        for page in 1...Self.maxRepoPages {
            let query = [URLQueryItem(name: "per_page", value: "100"),
                         URLQueryItem(name: "page", value: String(page)),
                         URLQueryItem(name: "sort", value: "pushed"),
                         URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")]
            guard let (data, _) = try await get("/user/repos", query: query) else { throw GitHubError.invalidResponse }
            let repos = try decode([GitHubRepo].self, from: data)
            all += repos
            if repos.count < 100 { break }
        }
        return all
    }

    /// `nil` when unchanged since `etag` (a 304, which doesn't count against the rate limit).
    public func repository(_ fullName: String, etag: String? = nil) async throws -> (repo: GitHubRepo, etag: String?)? {
        guard let (data, newEtag) = try await get("/repos/\(fullName)", etag: etag) else { return nil }
        return (try decode(GitHubRepo.self, from: data), newEtag)
    }

    /// Blob paths on `branch`, or `nil` if GitHub truncated the listing.
    public func filePaths(_ fullName: String, branch: String) async throws -> Set<String>? {
        let query = [URLQueryItem(name: "recursive", value: "1")]
        guard let (data, _) = try await get("/repos/\(fullName)/git/trees/\(branch)", query: query) else {
            throw GitHubError.invalidResponse
        }
        struct Tree: Decodable {
            struct Entry: Decodable { let path: String; let type: String }
            let tree: [Entry]
            let truncated: Bool?
        }
        let tree = try decode(Tree.self, from: data)
        if tree.truncated == true { return nil }
        return Set(tree.tree.filter { $0.type == "blob" }.map(\.path))
    }

    /// Raw text of a file, or `nil` if it doesn't exist.
    public func fileText(_ fullName: String, path: String) async throws -> String? {
        do {
            guard let (data, _) = try await get("/repos/\(fullName)/contents/\(path)",
                                                accept: "application/vnd.github.raw") else { return nil }
            return String(decoding: data, as: UTF8.self)
        } catch GitHubError.notFound {
            return nil
        }
    }

    /// The repo's README as raw text, or `nil` if it has none.
    public func readme(_ fullName: String) async throws -> String? {
        do {
            guard let (data, _) = try await get("/repos/\(fullName)/readme",
                                                accept: "application/vnd.github.raw") else { return nil }
            return String(decoding: data, as: UTF8.self)
        } catch GitHubError.notFound {
            return nil
        }
    }

    // MARK: Transport

    func makeRequest(path: String, query: [URLQueryItem] = [],
                     accept: String = "application/vnd.github+json", etag: String? = nil) -> URLRequest {
        var components = URLComponents(string: Self.apiBase)!
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("SmartWard", forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        return request
    }

    /// `nil` on 304 Not Modified.
    private func get(_ path: String, query: [URLQueryItem] = [],
                     accept: String = "application/vnd.github+json",
                     etag: String? = nil) async throws -> (Data, String?)? {
        let request = makeRequest(path: path, query: query, accept: accept, etag: etag)
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200...299:
            return (data, response.value(forHTTPHeaderField: "ETag"))
        case 304:
            return nil
        default:
            throw Self.error(status: response.statusCode, data: data, response: response)
        }
    }

    static func error(status: Int, data: Data, response: HTTPURLResponse) -> GitHubError {
        let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
        if status == 429 || (status == 403 && remaining == "0") {
            let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap { TimeInterval($0) }
                .map { Date(timeIntervalSince1970: $0) }
            return .rateLimited(resetAt: reset)
        }
        switch status {
        case 401: return .unauthorized
        case 404: return .notFound
        default:
            struct Message: Decodable { let message: String }
            let message = (try? JSONDecoder().decode(Message.self, from: data))?.message
                ?? String(decoding: data.prefix(300), as: UTF8.self)
            return .http(status: status, message: message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw GitHubError.invalidResponse
        }
    }
}
