import Foundation

#if !canImport(Security)
/// Linux stand-in for the Keychain: one file per (service, account) under
/// `$XDG_DATA_HOME/ondevicekit/secrets`, mode 0600 in a 0700 directory.
/// Not hardware-backed; a libsecret backend can replace it later.
struct BYOKFileSecretStore {
    let service: String

    private var directory: URL {
        let base = ProcessInfo.processInfo.environment["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share")
        return base.appendingPathComponent("ondevicekit/secrets", isDirectory: true)
    }

    private func url(_ account: String) -> URL {
        let safe = (service + "." + account).map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return directory.appendingPathComponent(String(safe))
    }

    func exists(_ account: String) -> Bool {
        FileManager.default.fileExists(atPath: url(account).path)
    }

    func read(_ account: String) -> Data? { try? Data(contentsOf: url(account)) }

    @discardableResult
    func write(_ data: Data, account: String) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
            let target = url(account)
            guard fm.createFile(atPath: target.path, contents: data,
                                attributes: [.posixPermissions: 0o600]) else { return false }
            return true
        } catch { return false }
    }

    @discardableResult
    func delete(_ account: String) -> Bool {
        let target = url(account)
        guard FileManager.default.fileExists(atPath: target.path) else { return true }
        return (try? FileManager.default.removeItem(at: target)) != nil
    }
}
#endif
