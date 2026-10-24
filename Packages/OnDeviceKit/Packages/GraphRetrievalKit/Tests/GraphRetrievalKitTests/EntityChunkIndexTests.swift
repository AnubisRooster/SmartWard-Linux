import XCTest
@testable import GraphRetrievalKit
import RetrievalKit

final class EntityChunkIndexTests: XCTestCase {

    func testIndexingRecordsNodeToChunkMapping() {
        var index = EntityChunkIndex()
        let chunk = Chunk(id: "c1", documentID: "d1", text: "I feel anxious around my mother.")
        index.index(chunk)

        XCTAssertTrue(index.chunkIDs(forNode: "emotion:anxious").contains("c1"))
        XCTAssertTrue(index.chunkIDs(forNode: "person:mother").contains("c1"))
    }

    func testNodeIDsForChunkRoundTrips() {
        var index = EntityChunkIndex()
        let chunk = Chunk(id: "c1", documentID: "d1", text: "I feel anxious around my mother.")
        index.index(chunk)
        XCTAssertEqual(index.nodeIDs(forChunk: "c1"), Set(["emotion:anxious", "person:mother"]))
    }

    func testChunkWithNoRecognizedEntitiesIndexesToEmptySet() {
        var index = EntityChunkIndex()
        index.index(Chunk(id: "c1", documentID: "d1", text: "The weather was pleasant today."))
        XCTAssertTrue(index.nodeIDs(forChunk: "c1").isEmpty)
    }

    func testRemoveDocumentClearsItsChunksButLeavesOtherDocumentsIntact() {
        var index = EntityChunkIndex()
        index.index(Chunk(id: "c1", documentID: "d1", text: "I feel anxious."))
        index.index(Chunk(id: "c2", documentID: "d2", text: "I feel anxious too."))

        index.removeDocument("d1")

        XCTAssertTrue(index.nodeIDs(forChunk: "c1").isEmpty)
        XCTAssertTrue(index.chunkIDs(forNode: "emotion:anxious").contains("c2"))
        XCTAssertFalse(index.chunkIDs(forNode: "emotion:anxious").contains("c1"))
    }

    func testRemovingLastChunkForANodePrunesTheNodeEntirely() {
        var index = EntityChunkIndex()
        index.index(Chunk(id: "c1", documentID: "d1", text: "I feel anxious."))
        index.removeDocument("d1")
        XCTAssertTrue(index.chunkIDs(forNode: "emotion:anxious").isEmpty)
    }

    func testUnrecognizedNodeReturnsEmptySet() {
        let index = EntityChunkIndex()
        XCTAssertTrue(index.chunkIDs(forNode: "person:nobody").isEmpty)
    }

    func testRemovingUnknownDocumentIsANoOp() {
        var index = EntityChunkIndex()
        index.index(Chunk(id: "c1", documentID: "d1", text: "I feel anxious."))
        index.removeDocument("does-not-exist")
        XCTAssertTrue(index.chunkIDs(forNode: "emotion:anxious").contains("c1"))
    }
}
