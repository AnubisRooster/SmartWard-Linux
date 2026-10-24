import Foundation

/// A TTL-bounded on-disk cache for a fetched model catalog, so the app isn't
/// hitting the catalog endpoint on every launch.
public actor CatalogCache {
    private let fileCache: FileCache
    private let ttl: TimeInterval
    private let cacheKey: String

    private var cachedData: CatalogCacheData?

    /// - Parameters:
    ///   - ttl: how long a cached catalog is considered fresh. Defaults to 12 hours.
    ///   - cacheKey: disk key; override if caching catalogs from multiple providers.
    public init(ttl: TimeInterval = 43_200, cacheKey: String = "model_catalog", fileCache: FileCache = FileCache()) {
        self.ttl = ttl
        self.cacheKey = cacheKey
        self.fileCache = fileCache
    }

    public func load() async -> CatalogCacheData? {
        if let data = cachedData { return data }
        guard let raw = await fileCache.read(key: cacheKey),
              let decoded = try? JSONDecoder().decode(CatalogCacheData.self, from: raw)
        else { return nil }
        cachedData = decoded
        return decoded
    }

    public func save(entries: [CatalogEntry]) async throws {
        let data = CatalogCacheData(entries: entries, lastRefreshed: Date())
        let raw = try JSONEncoder().encode(data)
        try await fileCache.write(data: raw, key: cacheKey)
        cachedData = data
    }

    public func needsRefresh() -> Bool {
        guard let cached = cachedData else { return true }
        return Date().timeIntervalSince(cached.lastRefreshed) > ttl
    }

    public func isStale() -> Bool {
        cachedData == nil || needsRefresh()
    }

    public func clear() {
        cachedData = nil
    }
}
