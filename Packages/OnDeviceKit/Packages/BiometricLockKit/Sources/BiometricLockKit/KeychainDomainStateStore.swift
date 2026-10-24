#if canImport(LocalAuthentication)
import Foundation
import Security

/// Stores the biometric anti-tamper baseline (the
/// `evaluatedPolicyDomainState` blob) in the Keychain, namespaced per app,
/// with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` so it never syncs to
/// iCloud or leaves the device — matching `PINService`'s posture.
public final class KeychainDomainStateStore: DomainStateStoring, @unchecked Sendable {
    private let service: String
    private let account = "biometric_domain_state"

    /// - Parameter service: Keychain service identifier. Defaults to the host
    ///   app's bundle identifier so baselines are namespaced per app.
    public init(service: String = (Bundle.main.bundleIdentifier ?? "BiometricLockKit") + ".biometric") {
        self.service = service
    }

    public func load() -> Data? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, !data.isEmpty
        else { return nil }
        return data
    }

    public func save(_ data: Data) {
        let base: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(base as CFDictionary)

        var attrs = base
        attrs[kSecValueData]      = data
        attrs[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    public func clear() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
#endif
