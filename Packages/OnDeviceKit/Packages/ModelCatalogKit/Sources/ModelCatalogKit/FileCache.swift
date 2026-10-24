import Foundation

/// A minimal key/value disk cache under the app's Caches directory. Used by
/// `CatalogCache`, but generic enough for any small blob a host app wants to
/// persist across launches without going through a full database.
public actor FileCache {
    private let fileManager = FileManager.default
    private let subdirectory: String

    private var cacheDir: URL {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(subdirectory, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public init(subdirectory: String = "kit.filecache") {
        self.subdirectory = subdirectory
    }

    public func write(data: Data, key: String) throws {
        let url = cacheDir.appendingPathComponent(key)
        try data.write(to: url, options: .atomic)
    }

    public func read(key: String) -> Data? {
        let url = cacheDir.appendingPathComponent(key)
        return try? Data(contentsOf: url)
    }

    public func exists(key: String) -> Bool {
        fileManager.fileExists(atPath: cacheDir.appendingPathComponent(key).path)
    }

    public func url(for key: String) -> URL {
        cacheDir.appendingPathComponent(key)
    }

    public func delete(key: String) {
        try? fileManager.removeItem(at: cacheDir.appendingPathComponent(key))
    }
}
