import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Which hosts SmartWard may reach on the strategist's say-so, or be
/// redirected to: named hosts on the public internet, not IP addresses,
/// local names or unqualified names.
public enum PublicHost {
    static let localSuffixes = [".localhost", ".local", ".internal", ".lan", ".home.arpa"]

    /// A public, named host: dotted, with an alphabetic top-level label (so
    /// no IPv4 in any notation, like `127.1` or `0x7f.0.0.1`), no IPv6, and
    /// no local-network suffix.
    public static func isPublic(_ host: String) -> Bool {
        let host = host.lowercased()
        guard host.contains("."), !host.contains(":"),
              let topLevel = host.split(separator: ".").last,
              topLevel.allSatisfy(\.isLetter) || topLevel.hasPrefix("xn--") else { return false }
        return !localSuffixes.contains { host.hasSuffix($0) }
    }

    /// Whether a redirect to `url` may be followed: http(s) to a public host
    /// on a standard port, with no credentials. A public page can't bounce a
    /// request to this device or its local network.
    public static func allowsRedirect(to url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, isPublic(host),
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 80 || url.port == 443 else { return false }
        return true
    }
}

/// Refuses redirects `PublicHost` doesn't allow; the redirect response
/// itself then comes back to the caller as a non-2xx status.
final class RedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = RedirectPolicy()

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        guard let url = request.url, PublicHost.allowsRedirect(to: url) else { return nil }
        return request
    }
}
