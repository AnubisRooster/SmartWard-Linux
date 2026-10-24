import XCTest
@testable import RetrievalKit

final class HybridRetrieverTests: XCTestCase {

    func testKeywordOnlyMatchWhenNothingCanBeEmbedded() async {
        // With an embedder that never produces a vector, only the keyword
        // side can find anything — confirming keyword search doesn't depend
        // on vector search succeeding.
        let hybrid = HybridRetriever(retriever: Retriever(embedder: NilEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "vLLM adds speculative decoding support."))
        await hybrid.index(Document(id: "d2", text: "Sourdough bread rises overnight."))

        let hits = await hybrid.retrieve("vLLM speculative decoding", topK: 5)
        XCTAssertEqual(hits.map(\.chunk.documentID), ["d1"])
        XCTAssertEqual(hits.first?.provenance, .hybrid(keyword: true, vector: false))
    }

    func testHitFoundByBothSidesIsTaggedHybrid() async {
        let hybrid = HybridRetriever(retriever: Retriever(embedder: FakeEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "I feel anxious around my mother."))
        await hybrid.index(Document(id: "d2", text: "The weather was pleasant today."))

        let hits = await hybrid.retrieve("anxious mother", topK: 5)
        XCTAssertEqual(hits.first?.chunk.documentID, "d1")
        guard case .hybrid(let keyword, let vector) = hits.first?.provenance else {
            return XCTFail("expected .hybrid provenance")
        }
        XCTAssertTrue(keyword, "the query's words appear verbatim in the text")
        XCTAssertTrue(vector, "the fake embedder shares vocabulary with the query")
    }

    func testTopKBoundsTheResultCount() async {
        let hybrid = HybridRetriever(retriever: Retriever(embedder: FakeEmbeddingProvider()))
        for index in 0..<10 {
            await hybrid.index(Document(id: "d\(index)", text: "shared searchable term number \(index)"))
        }
        let hits = await hybrid.retrieve("shared searchable term", topK: 3)
        XCTAssertEqual(hits.count, 3)
    }

    func testNoMatchOnEitherSideReturnsEmpty() async {
        // A `NilEmbeddingProvider` guarantees no vector hits; a query sharing
        // no tokens with the indexed text guarantees no keyword hits either.
        let hybrid = HybridRetriever(retriever: Retriever(embedder: NilEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "Sourdough bread rises overnight."))
        let hits = await hybrid.retrieve("quantum computing hardware", topK: 5)
        XCTAssertTrue(hits.isEmpty)
    }

    func testFilterAppliesToKeywordOnlyHitsToo() async {
        let hybrid = HybridRetriever(retriever: Retriever(embedder: NilEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "vLLM release notes", metadata: ["kind": "journal"]))
        await hybrid.index(Document(id: "d2", text: "vLLM release notes", metadata: ["kind": "note"]))

        let hits = await hybrid.retrieve("vLLM release", topK: 5) { $0.metadata["kind"] == "journal" }
        XCTAssertEqual(hits.map(\.chunk.documentID), ["d1"])
    }

    func testRemoveDocumentExcludesItFromFutureResults() async {
        let hybrid = HybridRetriever(retriever: Retriever(embedder: NilEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "vLLM release notes"))
        await hybrid.remove(documentID: "d1")

        let hits = await hybrid.retrieve("vLLM release", topK: 5)
        XCTAssertTrue(hits.isEmpty, "removed from the shared Retriever, so no Chunk resolves even though the stale posting remains")
    }

    func testUnderlyingRetrieverSharesTheSameStorage() async {
        let hybrid = HybridRetriever(retriever: Retriever(embedder: FakeEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "vLLM release notes"))
        let count = await hybrid.underlyingRetriever.underlyingIndex.count
        XCTAssertEqual(count, 1)
    }

    func testRebuildLexicalIndexKeepsOnlyTheGivenChunksSearchable() async {
        let hybrid = HybridRetriever(retriever: Retriever(embedder: NilEmbeddingProvider()))
        await hybrid.index(Document(id: "d1", text: "vLLM release notes"))
        await hybrid.remove(documentID: "d1")
        let survivors = await hybrid.index(Document(id: "d2", text: "Sourdough bread rises overnight."))

        await hybrid.rebuildLexicalIndex(from: survivors)
        let stale = await hybrid.retrieve("vLLM release", topK: 5)
        XCTAssertTrue(stale.isEmpty)
        let hits = await hybrid.retrieve("sourdough bread", topK: 5)
        XCTAssertEqual(hits.map(\.chunk.documentID), ["d2"])
    }
}
