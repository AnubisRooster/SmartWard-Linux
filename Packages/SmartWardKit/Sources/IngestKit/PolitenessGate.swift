import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// robots.txt rules for one user agent (RFC 9309): the longest matching
/// `Allow`/`Disallow` pattern wins, and `Allow` wins a tie. Patterns support
/// `*` and a trailing `$`.
public struct RobotsRules: Equatable, Sendable {
    struct Rule: Equatable, Sendable {
        let allow: Bool
        let pattern: String
    }

    let rules: [Rule]

    public static let allowAll = RobotsRules(rules: [])
    public static let disallowAll = RobotsRules(rules: [Rule(allow: false, pattern: "/")])

    init(rules: [Rule]) {
        self.rules = rules
    }

    /// Rules from the group naming `userAgent` (a product-token substring
    /// match, case-insensitive), or else the `*` group.
    public init(parsing text: String, userAgent: String) {
        struct Group {
            var agents: [String] = []
            var rules: [Rule] = []
        }
        var groups: [Group] = []
        var current = Group()
        var lastWasAgent = false

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first
                .map { String($0) }?.trimmingCharacters(in: .whitespaces) ?? ""
            guard let colon = line.firstIndex(of: ":") else { continue }
            let field = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)

            switch field {
            case "user-agent":
                if !lastWasAgent, !current.agents.isEmpty {
                    groups.append(current)
                    current = Group()
                }
                current.agents.append(value.lowercased())
                lastWasAgent = true
            case "allow", "disallow":
                lastWasAgent = false
                // An empty Disallow allows everything; it adds no rule.
                guard !value.isEmpty, !current.agents.isEmpty else { continue }
                current.rules.append(Rule(allow: field == "allow", pattern: value))
            default:
                lastWasAgent = false
            }
        }
        if !current.agents.isEmpty { groups.append(current) }

        let token = userAgent.lowercased()
        let named = groups.filter { group in group.agents.contains { $0 != "*" && token.contains($0) } }
        let chosen = named.isEmpty ? groups.filter { $0.agents.contains("*") } : named
        self.rules = chosen.flatMap(\.rules)
    }

    /// `path` includes the query string, e.g. "/search?q=x".
    public func allows(_ path: String) -> Bool {
        var best: Rule?
        for rule in rules where Self.matches(pattern: rule.pattern, path: path) {
            guard let current = best else {
                best = rule
                continue
            }
            if rule.pattern.count > current.pattern.count
                || (rule.pattern.count == current.pattern.count && rule.allow && !current.allow) {
                best = rule
            }
        }
        return best?.allow ?? true
    }

    static func matches(pattern: String, path: String) -> Bool {
        var pattern = Substring(pattern)
        let anchored = pattern.hasSuffix("$")
        if anchored { pattern = pattern.dropLast() }
        let pieces = pattern.split(separator: "*", omittingEmptySubsequences: false)

        var remainder = Substring(path)
        for (index, piece) in pieces.enumerated() {
            if index == 0 {
                guard remainder.hasPrefix(piece) else { return false }
                remainder = remainder.dropFirst(piece.count)
            } else if piece.isEmpty {
                continue
            } else if index == pieces.count - 1 && anchored {
                return remainder.hasSuffix(piece)
            } else {
                guard let range = remainder.range(of: piece) else { return false }
                remainder = remainder[range.upperBound...]
            }
        }
        if anchored {
            // "/a$": nothing may follow. "/a*$": anything may.
            return remainder.isEmpty || pieces.last?.isEmpty == true && pieces.count > 1
        }
        return true
    }
}

public enum IngestError: LocalizedError, Equatable, Sendable {
    case invalidURL(String)
    case disallowedByRobots(String)
    case backingOff(host: String, until: Date)
    case http(status: Int)
    case tooLarge
    case notAFeed
    case invalidResponse
    /// The address redirects somewhere SmartWard won't follow: a host that
    /// isn't a public website (this device, the local network).
    case redirectedAway(host: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Not a valid web address: \(url)"
        case .disallowedByRobots(let url):
            return "The site's robots.txt asks automated readers not to fetch \(url)."
        case .backingOff(let host, let until):
            return "\(host) asked SmartWard to slow down. Retrying after \(until.formatted(date: .omitted, time: .shortened))."
        case .http(let status):
            return "The server returned HTTP \(status)."
        case .tooLarge:
            return "The response was too large to read."
        case .notAFeed:
            return "No RSS or Atom feed was found at that address."
        case .invalidResponse:
            return "The server returned something SmartWard couldn't read."
        case .redirectedAway(let host):
            if let host {
                return "The address redirects to \(host), which SmartWard won't follow because it isn't a public website."
            }
            return "The address redirects somewhere SmartWard won't follow."
        }
    }

    /// What to do about it, in plain words.
    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check the address for a typo."
        case .disallowedByRobots:
            return "The site asks automated readers to stay out. Follow its feed instead, or remove this source."
        case .backingOff:
            return "Nothing to do: SmartWard tries again on its own."
        case .http(let status):
            switch status {
            case 404, 410: return "The feed may have moved or been removed. Check the address, or remove this source."
            case 401, 403: return "The site refuses SmartWard or wants a login. Try the site's public feed, or remove this source."
            case 429: return "The site asked SmartWard to slow down. It tries again on its own."
            case 500...599: return "The site is having trouble. SmartWard tries again on the next refresh."
            default: return "Check the address, or try again later."
            }
        case .tooLarge:
            return "The response is bigger than SmartWard reads. Use a smaller feed for this site."
        case .notAFeed:
            return "That page doesn't offer an RSS or Atom feed. Look for a feed link on the site and use that address instead."
        case .invalidResponse:
            return "Check that the address is a feed, not a web page or a download."
        case .redirectedAway:
            return "Open the address in a browser to see where it goes. If that's the feed you want, add that address instead."
        }
    }
}

/// Every ingestion request goes through here (NFR-6):
/// - a truthful User-Agent,
/// - at most one request per host per `minimumInterval`,
/// - exponential backoff (or the server's `Retry-After`) after 429 and 503,
/// - robots.txt for web pages. Feeds and documented APIs (arXiv, Hacker News'
///   Algolia API, Hugging Face) are meant for programmatic reading, so they
///   skip the robots.txt check and still get rate limits and backoff.
public actor PolitenessGate {
    public static let userAgent = "SmartWard/0.1 (personal research reader; +https://github.com/AnubisRooster/SmartWard)"
    static let maxBackoff: TimeInterval = 6 * 60 * 60
    static let robotsLifetime: TimeInterval = 24 * 60 * 60
    static let robotsFailureLifetime: TimeInterval = 60 * 60

    private let transport: any HTTPTransport
    private let minimumInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    private var nextSlot: [String: Date] = [:]
    private var backoff: [String: (until: Date, failures: Int)] = [:]
    private var robots: [String: (rules: RobotsRules, expires: Date)] = [:]

    public init(transport: any HTTPTransport = URLSessionTransport(),
                minimumInterval: TimeInterval = 1,
                now: @escaping @Sendable () -> Date = { Date() },
                sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
                    try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
                }) {
        self.transport = transport
        self.minimumInterval = minimumInterval
        self.now = now
        self.sleep = sleep
    }

    /// Sends `request` politely. Non-2xx responses other than 304 are returned
    /// to the caller, except 429/503, which start a backoff and throw.
    public func send(_ request: URLRequest, checkRobots: Bool) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url, let host = url.host?.lowercased() else {
            throw IngestError.invalidURL(request.url?.absoluteString ?? "")
        }
        if let state = backoff[host], state.until > now() {
            throw IngestError.backingOff(host: host, until: state.until)
        }
        if checkRobots {
            let rules = try await robotsRules(for: url, host: host)
            var path = url.path.isEmpty ? "/" : url.path
            if let query = url.query { path += "?\(query)" }
            guard rules.allows(path) else { throw IngestError.disallowedByRobots(url.absoluteString) }
        }

        var polite = request
        polite.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        polite.cachePolicy = .reloadIgnoringLocalCacheData
        polite.timeoutInterval = 30
        let (data, response) = try await sendRateLimited(polite, host: host)

        if response.statusCode == 429 || response.statusCode == 503 {
            let failures = (backoff[host]?.failures ?? 0) + 1
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            let delay = min(retryAfter ?? 60 * pow(2, Double(failures - 1)), Self.maxBackoff)
            let until = now().addingTimeInterval(delay)
            backoff[host] = (until, failures)
            throw IngestError.backingOff(host: host, until: until)
        }
        backoff[host] = nil
        return (data, response)
    }

    /// Reserves the host's next slot before awaiting, so concurrent callers
    /// queue up instead of all firing when the actor is re-entered.
    private func sendRateLimited(_ request: URLRequest, host: String) async throws -> (Data, HTTPURLResponse) {
        let current = now()
        let slot = max(current, nextSlot[host] ?? current)
        nextSlot[host] = slot.addingTimeInterval(minimumInterval)
        let wait = slot.timeIntervalSince(current)
        if wait > 0 { try await sleep(wait) }
        return try await transport.send(request)
    }

    private func robotsRules(for url: URL, host: String) async throws -> RobotsRules {
        if let cached = robots[host], cached.expires > now() { return cached.rules }

        var components = URLComponents()
        components.scheme = url.scheme ?? "https"
        components.host = url.host
        components.port = url.port
        components.path = "/robots.txt"
        guard let robotsURL = components.url else { return .allowAll }

        var request = URLRequest(url: robotsURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        // RFC 9309: 4xx means no restrictions; 5xx or unreachable means assume
        // everything is disallowed for now.
        let rules: RobotsRules
        let lifetime: TimeInterval
        do {
            let (data, response) = try await sendRateLimited(request, host: host)
            switch response.statusCode {
            case 200...299:
                rules = RobotsRules(parsing: String(decoding: data, as: UTF8.self), userAgent: "SmartWard")
                lifetime = Self.robotsLifetime
            case 400...499:
                rules = .allowAll
                lifetime = Self.robotsLifetime
            default:
                rules = .disallowAll
                lifetime = Self.robotsFailureLifetime
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            rules = .disallowAll
            lifetime = Self.robotsFailureLifetime
        }
        robots[host] = (rules, now().addingTimeInterval(lifetime))
        return rules
    }
}
