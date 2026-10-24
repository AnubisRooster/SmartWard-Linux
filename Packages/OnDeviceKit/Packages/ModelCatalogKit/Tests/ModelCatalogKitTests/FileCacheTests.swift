import XCTest
@testable import ModelCatalogKit

final class FileCacheTests: XCTestCase {

    private func makeCache() -> FileCache {
        FileCache(subdirectory: "kit-tests.filecache.\(UUID().uuidString)")
    }

    func testWriteThenReadRoundTrips() async throws {
        let cache = makeCache()
        let payload = Data("hello".utf8)
        try await cache.write(data: payload, key: "greeting")
        let read = await cache.read(key: "greeting")
        XCTAssertEqual(read, payload)
    }

    func testReadMissingKeyReturnsNil() async {
        let cache = makeCache()
        let read = await cache.read(key: "never-written")
        XCTAssertNil(read)
    }

    func testExistsReflectsWriteState() async throws {
        let cache = makeCache()
        let exists1 = await cache.exists(key: "k")
        XCTAssertFalse(exists1)
        try await cache.write(data: Data("x".utf8), key: "k")
        let exists2 = await cache.exists(key: "k")
        XCTAssertTrue(exists2)
    }

    func testDeleteRemovesKey() async throws {
        let cache = makeCache()
        try await cache.write(data: Data("x".utf8), key: "k")
        await cache.delete(key: "k")
        let read = await cache.read(key: "k")
        XCTAssertNil(read)
    }

    func testWriteOverwritesExistingValue() async throws {
        let cache = makeCache()
        try await cache.write(data: Data("first".utf8), key: "k")
        try await cache.write(data: Data("second".utf8), key: "k")
        let read = await cache.read(key: "k")
        XCTAssertEqual(read, Data("second".utf8))
    }
}
