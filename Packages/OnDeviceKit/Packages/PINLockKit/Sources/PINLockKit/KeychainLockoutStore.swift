import Foundation
#if canImport(Security)
import Security
#endif

/// Persists `PINLockout`'s counters to the Keychain instead of
/// `UserDefaults`. `UserDefaults` is wiped when the app is deleted, but a
/// Keychain item with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// survives app deletion/reinstallation — so without this, an attacker
/// locked out after `maxAttempts` wrong guesses could just delete and
/// reinstall the host app to get unlimited fresh attempt rounds against the
/// (still-present, Keychain-stored) PIN.
public final class KeychainLockoutStore: PINLockoutStore {
    private let service: String
    private let account: String

    public init(service: String, account: String = "pin_lockout_state") {
        self.service = service
        self.account = account
    }

    private struct State: Codable {
        var ints: [String: Int] = [:]
        var doubles: [String: Double] = [:]
    }

    private func load() -> State {
        #if !canImport(Security)
        guard let data = PINFileSecretStore(service: service).read(account),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return State() }
        return state
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
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
        #endif
    }

    private func persist(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        #if !canImport(Security)
        PINFileSecretStore(service: service).write(data, account: account)
        #else
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let update: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var attrs = query
            attrs[kSecValueData] = data
            attrs[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(attrs as CFDictionary, nil)
        }
        #endif
    }

    public func integer(forKey key: String) -> Int { load().ints[key] ?? 0 }
    public func double(forKey key: String) -> Double { load().doubles[key] ?? 0 }

    public func set(_ value: Int, forKey key: String) {
        var state = load()
        state.ints[key] = value
        persist(state)
    }

    public func set(_ value: Double, forKey key: String) {
        var state = load()
        state.doubles[key] = value
        persist(state)
    }

    public func removeObject(forKey key: String) {
        var state = load()
        state.ints.removeValue(forKey: key)
        state.doubles.removeValue(forKey: key)
        persist(state)
    }
}
