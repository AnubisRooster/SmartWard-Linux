import Foundation
#if canImport(Security)
import Security
#endif

/// Stores and verifies a numeric PIN in the device Keychain.
///
/// The PIN never touches `UserDefaults` or iCloud; it lives only in the local
/// Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
public final class PINService {
    public static let shared = PINService()

    private let service: String
    private let account = "user_pin"
    private var lockout: PINLockout

    /// - Parameters:
    ///   - service: Keychain service identifier. Defaults to the host app's
    ///     bundle identifier so PINs are namespaced per app.
    ///   - defaults: persists brute-force lockout counters. Defaults to a
    ///     Keychain-backed store (see `KeychainLockoutStore`) so lockout
    ///     survives app deletion; tests should inject an ephemeral
    ///     `UserDefaults` instance for isolation.
    public init(service: String = (Bundle.main.bundleIdentifier ?? "PINLockKit") + ".pin",
               defaults: PINLockoutStore? = nil) {
        self.service = service
        self.lockout = PINLockout(defaults: defaults ?? KeychainLockoutStore(service: service))
    }

    // MARK: Public API

    /// True when a PIN is stored. A transient Keychain read error is treated
    /// as "PIN exists" (fail closed) rather than "no PIN", so a temporary
    /// glitch can't route a caller into setup-a-new-PIN mode and bypass the
    /// real one.
    public var isPINSetup: Bool {
        #if !canImport(Security)
        return PINFileSecretStore(service: service).exists(account)
        #else
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status != errSecItemNotFound
        #endif
    }

    public var isLockedOut: Bool { lockout.isLockedOut }
    public var lockoutRemaining: Int { lockout.lockoutRemaining() }

    /// Verifies a PIN while enforcing brute-force lockout. Prefer this over
    /// `verify(_:)` at the UI layer.
    public func attempt(_ pin: String, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> PINAttemptResult {
        let remaining = lockout.lockoutRemaining(uptime: uptime)
        if remaining > 0 { return .lockedOut(secondsRemaining: remaining) }
        if verify(pin) {
            lockout.registerSuccess()
            return .success
        }
        return lockout.registerFailure(uptime: uptime)
    }

    /// Stores a new PIN, replacing any existing one. Only clears lockout
    /// state after the Keychain write is confirmed to have succeeded, and
    /// replaces an existing PIN in place (update, not delete-then-add) so a
    /// failed write can never leave the Keychain with no PIN at all.
    @discardableResult
    public func save(_ pin: String) -> Bool {
        guard let data = pin.data(using: .utf8) else { return false }
        #if !canImport(Security)
        guard PINFileSecretStore(service: service).write(data, account: account) else { return false }
        lockout.registerSuccess()
        return true
        #else
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        var addAttrs = query
        addAttrs[kSecValueData] = data
        addAttrs[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        var status = SecItemAdd(addAttrs as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        }
        guard status == errSecSuccess else { return false }
        lockout.registerSuccess()
        return true
        #endif
    }

    public func verify(_ pin: String) -> Bool {
        guard let stored = load() else { return false }
        return Self.constantTimeEqual(stored, pin)
    }

    public func delete() {
        #if !canImport(Security)
        PINFileSecretStore(service: service).delete(account)
        #else
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
        #endif
    }

    // MARK: Private

    private func load() -> String? {
        #if !canImport(Security)
        return PINFileSecretStore(service: service).read(account).flatMap { String(data: $0, encoding: .utf8) }
        #else
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let pin  = String(data: data, encoding: .utf8) else { return nil }
        return pin
        #endif
    }

    /// Constant-time equality check, so comparing the entered PIN against the
    /// stored one doesn't leak a timing signal from an early-exit `==` (the
    /// brute-force lockout above already limits attempt volume; this is
    /// defense-in-depth on top of it).
    private static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
    }
}
