import XCTest
@testable import GraphRetrievalKit
import RetrievalKit
import GraphKit

final class GraphRetrieverTests: XCTestCase {

    func testEndToEndRetrievalIncludesGraphExpandedNeighbor() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider(), chunker: Chunker(targetSize: 500))
        let graphRetriever = GraphRetriever(retriever: retriever, expander: GraphExpander(decay: 0.5))

        await graphRetriever.index(Document(id: "d1", text: "I saw my mother today."))
        await graphRetriever.index(Document(id: "d2", text: "I feel anxious constantly."))
        await graphRetriever.index(Document(id: "d3", text: "The weather was pleasant."))

        let sessionGraph = SessionGraph(
            nodes: [
                SessionGraph.Node(id: "n1", type: "person", label: "Mother", strength: 1),
                SessionGraph.Node(id: "n2", type: "emotion", label: "Anxious", strength: 1),
            ],
            edges: [SessionGraph.Edge(sourceNodeID: "n1", targetNodeID: "n2", type: "TRIGGERS", weight: 1)]
        )
        let aggregated = GraphExporter.aggregate(sessions: [sessionGraph])

        // topK: 1 on vector search alone would surface only the "mother" hit —
        // the anxious-themed document should still appear via the graph hop.
        let results = await graphRetriever.retrieve("mother", topK: 1, hops: 1, graph: aggregated)

        XCTAssertTrue(results.contains { $0.chunk.documentID == "d1" })
        XCTAssertTrue(results.contains { $0.chunk.documentID == "d2" })
        XCTAssertFalse(results.contains { $0.chunk.documentID == "d3" })
    }

    func testRemoveDocumentDropsItFromBothVectorAndGraphIndexes() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider())
        let graphRetriever = GraphRetriever(retriever: retriever)
        await graphRetriever.index(Document(id: "d1", text: "I feel anxious around my mother."))
        await graphRetriever.remove(documentID: "d1")

        let emptyGraph = GraphExporter.aggregate(sessions: [])
        let results = await graphRetriever.retrieve("anxious mother", topK: 5, hops: 1, graph: emptyGraph)
        XCTAssertTrue(results.isEmpty)
    }

    func testZeroHopsBehavesLikePlainVectorRetrieval() async {
        let retriever = Retriever(embedder: FakeEmbeddingProvider())
        let graphRetriever = GraphRetriever(retriever: retriever)
        await graphRetriever.index(Document(id: "d1", text: "I feel anxious around my mother."))
        await graphRetriever.index(Document(id: "d2", text: "The weather was pleasant."))

        let emptyGraph = GraphExporter.aggregate(sessions: [])
        let results = await graphRetriever.retrieve("anxious mother", topK: 5, hops: 0, graph: emptyGraph)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.provenance == .vector })
    }
}
