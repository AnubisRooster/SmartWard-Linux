import Foundation
#if canImport(Security)
import Security
#endif

/// The GitHub token lives only in this device's Keychain: never synced to
/// iCloud Keychain, never in backups or SwiftData (PLAN §5.7).
public struct GitHubTokenStore: Sendable {
    public static let shared = GitHubTokenStore()

    private let service: String
    private let account = "github_token"

    public init(service: String = (Bundle.main.bundleIdentifier ?? "SmartWard") + ".github") {
        self.service = service
    }

    #if !canImport(Security)
    /// Linux has no Keychain: the token sits in a 0600 file under
    /// `$XDG_DATA_HOME/smartward/secrets` (a libsecret backend can replace this).
    private var fileURL: URL {
        let base = ProcessInfo.processInfo.environment["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share")
        return base.appendingPathComponent("smartward/secrets/github_token")
    }
    #endif

    public func token() -> String? {
        #if !canImport(Security)
        guard let data = try? Data(contentsOf: fileURL), let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
        #else
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
        #endif
    }

    /// Saves `token`, or deletes the stored one when `nil` or empty.
    @discardableResult
    public func setToken(_ token: String?) -> Bool {
        #if !canImport(Security)
        let fm = FileManager.default
        try? fm.removeItem(at: fileURL)
        guard let token, !token.isEmpty else { return true }
        do {
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
        } catch { return false }
        return fm.createFile(atPath: fileURL.path, contents: Data(token.utf8), attributes: [.posixPermissions: 0o600])
        #else
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let token, !token.isEmpty else { return true }

        var attributes = base
        attributes[kSecValueData] = Data(token.utf8)
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attributes[kSecAttrSynchronizable] = false
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        #endif
    }
}
