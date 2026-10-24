import XCTest
@testable import ModelCatalogKit

final class CatalogCacheTests: XCTestCase {

    private func makeCache(ttl: TimeInterval = 43_200) -> CatalogCache {
        CatalogCache(ttl: ttl, cacheKey: "catalog-\(UUID().uuidString)",
                    fileCache: FileCache(subdirectory: "kit-tests.catalogcache.\(UUID().uuidString)"))
    }

    private let entry = CatalogEntry(id: "free/chat", name: "Free Chat", pricing: .zero,
                                     contextLength: 4096, architecture: nil, supportedParameters: nil)

    func testIsStaleBeforeAnySave() async {
        let cache = makeCache()
        let stale = await cache.isStale()
        XCTAssertTrue(stale)
    }

    func testNotStaleImmediatelyAfterSave() async throws {
        let cache = makeCache()
        try await cache.save(entries: [entry])
        let stale = await cache.isStale()
        XCTAssertFalse(stale)
    }

    func testStaleOnceTTLElapses() async throws {
        let cache = makeCache(ttl: 0.01)
        try await cache.save(entries: [entry])
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms > 10ms TTL
        let stale = await cache.isStale()
        XCTAssertTrue(stale)
    }

    func testLoadReturnsSavedEntries() async throws {
        let cache = makeCache()
        try await cache.save(entries: [entry])
        let loaded = await cache.load()
        XCTAssertEqual(loaded?.entries.map(\.id), ["free/chat"])
    }

    func testLoadPersistsAcrossFreshCacheInstanceSameKey() async throws {
        let fileCache = FileCache(subdirectory: "kit-tests.catalogcache.\(UUID().uuidString)")
        let key = "shared-key"
        let first = CatalogCache(cacheKey: key, fileCache: fileCache)
        try await first.save(entries: [entry])

        // A second CatalogCache instance (simulating a fresh app launch) should
        // read the same on-disk data rather than starting empty.
        let second = CatalogCache(cacheKey: key, fileCache: fileCache)
        let loaded = await second.load()
        XCTAssertEqual(loaded?.entries.map(\.id), ["free/chat"])
    }

    func testClearForgetsInMemoryCacheButNotDisk() async throws {
        let cache = makeCache()
        try await cache.save(entries: [entry])
        await cache.clear()
        // load() falls back to disk when the in-memory copy is cleared.
        let loaded = await cache.load()
        XCTAssertEqual(loaded?.entries.map(\.id), ["free/chat"])
    }
}
