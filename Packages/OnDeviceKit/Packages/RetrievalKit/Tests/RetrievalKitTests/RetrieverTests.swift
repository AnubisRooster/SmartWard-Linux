import XCTest
@testable import RetrievalKit

final class RetrieverTests: XCTestCase {

    func testIndexAndRetrieveFindsRelevantChunk() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider(), chunker: Chunker(targetSize: 500))
        await retriever.index(Document(id: "d1", text: "I feel anxious around my mother."))
        await retriever.index(Document(id: "d2", text: "The weather was pleasant today."))

        let results = await retriever.retrieve("anxious mother", topK: 1)
        XCTAssertEqual(results.first?.chunk.documentID, "d1")
    }

    func testIndexReturnsTheChunksItProduced() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider())
        let chunks = await retriever.index(Document(id: "d1", text: "One sentence here."))
        XCTAssertEqual(chunks.map(\.documentID), ["d1"])
    }

    func testUnembeddableQueryReturnsEmpty() async {
        let retriever = Retriever(embedder: NilEmbeddingProvider())
        await retriever.index(Document(id: "d1", text: "Some text."))
        let results = await retriever.retrieve("query")
        XCTAssertTrue(results.isEmpty)
    }

    func testChunksThatFailToEmbedAreSkippedNotCrashed() async {
        let retriever = Retriever(embedder: NilEmbeddingProvider())
        await retriever.index(Document(id: "d1", text: "Some text."))
        let count = await retriever.underlyingIndex.count
        XCTAssertEqual(count, 0)
    }

    func testRemoveDocumentClearsItsChunks() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider())
        await retriever.index(Document(id: "d1", text: "I feel anxious around my mother."))
        await retriever.remove(documentID: "d1")
        let count = await retriever.underlyingIndex.count
        XCTAssertEqual(count, 0)
    }

    func testFilterIsForwardedToTheUnderlyingIndex() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider())
        await retriever.index(Document(id: "d1", text: "anxious mother", metadata: ["kind": "journal"]))
        await retriever.index(Document(id: "d2", text: "anxious mother", metadata: ["kind": "note"]))

        let results = await retriever.retrieve("anxious mother", topK: 5) { $0.metadata["kind"] == "journal" }
        XCTAssertEqual(results.map(\.chunk.documentID), ["d1"])
    }
}
