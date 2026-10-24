import XCTest
@testable import RetrievalKit

final class VectorIndexTests: XCTestCase {

    private func chunk(_ id: String, doc: String = "doc", text: String = "text",
                       metadata: [String: String] = [:]) -> Chunk {
        Chunk(id: id, documentID: doc, text: text, metadata: metadata)
    }

    func testSearchReturnsTopKByScoreDescending() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a"))
        await index.add(vector: [0.9, 0.1], chunk: chunk("b"))
        await index.add(vector: [0, 1], chunk: chunk("c"))

        let results = await index.search([1, 0], topK: 2)
        XCTAssertEqual(results.map(\.chunk.id), ["a", "b"])
        XCTAssertEqual(results.first?.provenance, .vector)
    }

    func testTopKLargerThanCorpusReturnsWhatExists() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a"))
        let results = await index.search([1, 0], topK: 50)
        XCTAssertEqual(results.count, 1)
    }

    func testRemoveExcludesChunkFromFutureSearches() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a"))
        await index.remove(chunkID: "a")
        let results = await index.search([1, 0], topK: 5)
        XCTAssertTrue(results.isEmpty)
    }

    func testRemoveAllByDocumentIDOnlyAffectsThatDocument() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a", doc: "docA"))
        await index.add(vector: [1, 0], chunk: chunk("b", doc: "docB"))
        await index.removeAll(documentID: "docA")
        let results = await index.search([1, 0], topK: 5)
        XCTAssertEqual(results.map(\.chunk.id), ["b"])
    }

    func testFilterRestrictsResults() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a", metadata: ["kind": "journal"]))
        await index.add(vector: [1, 0], chunk: chunk("b", metadata: ["kind": "note"]))
        let results = await index.search([1, 0], topK: 5) { $0.metadata["kind"] == "journal" }
        XCTAssertEqual(results.map(\.chunk.id), ["a"])
    }

    func testChunkLookupByIDFindsAddedChunk() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a", text: "hello"))
        let found = await index.chunk(withID: "a")
        XCTAssertEqual(found?.text, "hello")
    }

    func testChunkLookupByIDReturnsNilWhenMissing() async {
        let index = VectorIndex()
        let found = await index.chunk(withID: "missing")
        XCTAssertNil(found)
    }

    func testSnapshotRoundTripsExactly() async {
        let index = VectorIndex()
        await index.add(vector: [0.5, 0.5], chunk: chunk("a", text: "hello"))
        let data = await index.snapshot()

        let restored = VectorIndex()
        await restored.restore(from: data)
        let results = await restored.search([0.5, 0.5], topK: 1)
        XCTAssertEqual(results.first?.chunk.text, "hello")
    }

    func testCountReflectsAddsAndRemoves() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a"))
        await index.add(vector: [1, 0], chunk: chunk("b"))
        var count = await index.count
        XCTAssertEqual(count, 2)
        await index.remove(chunkID: "a")
        count = await index.count
        XCTAssertEqual(count, 1)
    }

    func testAddingSameChunkIDTwiceOverwrites() async {
        let index = VectorIndex()
        await index.add(vector: [1, 0], chunk: chunk("a", text: "first"))
        await index.add(vector: [1, 0], chunk: chunk("a", text: "second"))
        let count = await index.count
        XCTAssertEqual(count, 1)
        let found = await index.chunk(withID: "a")
        XCTAssertEqual(found?.text, "second")
    }
}
