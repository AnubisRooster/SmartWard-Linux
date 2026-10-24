import XCTest
@testable import GraphRetrievalKit
import RetrievalKit
import GraphKit

/// `AggregatedGraph`/`AggregatedNode`/`AggregatedEdge` have no public
/// initializers in GraphKit — the only way to construct one from outside that
/// module is `GraphExporter.aggregate(sessions:)` over a `SessionGraph`. Every
/// fixture below goes through that real pipeline rather than hand-building an
/// `AggregatedGraph` directly.
final class GraphExpanderTests: XCTestCase {

    private func chunk(_ id: String, doc: String, text: String) -> Chunk {
        Chunk(id: id, documentID: doc, text: text)
    }

    private func makeIndex(with chunks: [Chunk]) async -> VectorIndex {
        let index = VectorIndex()
        for (i, c) in chunks.enumerated() {
            await index.add(vector: [Float(i), 0], chunk: c)
        }
        return index
    }

    private func aggregatedGraph(nodes: [SessionGraph.Node], edges: [SessionGraph.Edge]) -> AggregatedGraph {
        GraphExporter.aggregate(sessions: [SessionGraph(nodes: nodes, edges: edges)])
    }

    func testExpandsToDirectGraphNeighbor() async {
        let graph = aggregatedGraph(
            nodes: [
                SessionGraph.Node(id: "n1", type: "person", label: "Mother", strength: 1),
                SessionGraph.Node(id: "n2", type: "emotion", label: "Anxious", strength: 1),
            ],
            edges: [SessionGraph.Edge(sourceNodeID: "n1", targetNodeID: "n2", type: "TRIGGERS", weight: 1)]
        )

        var entityIndex = EntityChunkIndex()
        let seedChunk = chunk("seed", doc: "d1", text: "I saw my mother today.")
        let neighborChunk = chunk("neighbor", doc: "d2", text: "I feel anxious constantly.")
        entityIndex.index(seedChunk)
        entityIndex.index(neighborChunk)

        let index = await makeIndex(with: [seedChunk, neighborChunk])
        let seed = ScoredChunk(chunk: seedChunk, score: 1.0, provenance: .vector)

        let results = await GraphExpander(decay: 0.5).expand(seeds: [seed], graph: graph, entityIndex: entityIndex,
                                                              index: index, hops: 1)

        let neighborResult = results.first { $0.chunk.id == "neighbor" }
        XCTAssertNotNil(neighborResult)
        XCTAssertEqual(neighborResult?.provenance, .graphHop(distance: 1, via: "emotion:anxious"))
        XCTAssertEqual(neighborResult?.score ?? -1, 0.5, accuracy: 0.0001)
    }

    func testUnrelatedChunkIsNotPulledIn() async {
        let graph = aggregatedGraph(
            nodes: [
                SessionGraph.Node(id: "n1", type: "person", label: "Mother", strength: 1),
                SessionGraph.Node(id: "n2", type: "emotion", label: "Anxious", strength: 1),
            ],
            edges: [SessionGraph.Edge(sourceNodeID: "n1", targetNodeID: "n2", type: "TRIGGERS", weight: 1)]
        )
        var entityIndex = EntityChunkIndex()
        let seedChunk = chunk("seed", doc: "d1", text: "I saw my mother today.")
        let unrelatedChunk = chunk("unrelated", doc: "d2", text: "The weather was pleasant.")
        entityIndex.index(seedChunk)
        entityIndex.index(unrelatedChunk)

        let index = await makeIndex(with: [seedChunk, unrelatedChunk])
        let seed = ScoredChunk(chunk: seedChunk, score: 1.0, provenance: .vector)

        let results = await GraphExpander().expand(seeds: [seed], graph: graph, entityIndex: entityIndex,
                                                    index: index, hops: 1)
        XCTAssertFalse(results.contains { $0.chunk.id == "unrelated" })
    }

    func testZeroHopsReturnsSeedsUnchanged() async {
        let graph = aggregatedGraph(nodes: [], edges: [])
        let seedChunk = chunk("seed", doc: "d1", text: "text")
        let seed = ScoredChunk(chunk: seedChunk, score: 1.0, provenance: .vector)
        let index = await makeIndex(with: [seedChunk])

        let results = await GraphExpander().expand(seeds: [seed], graph: graph, entityIndex: EntityChunkIndex(),
                                                    index: index, hops: 0)
        XCTAssertEqual(results, [seed])
    }

    func testDoesNotRevisitOrOverwriteTheSeedChunk() async {
        // A 2-hop walk loops straight back to the seed's own node; the seed
        // chunk must not be re-added with a decayed score/provenance.
        let graph = aggregatedGraph(
            nodes: [
                SessionGraph.Node(id: "n1", type: "person", label: "Mother", strength: 1),
                SessionGraph.Node(id: "n2", type: "emotion", label: "Anxious", strength: 1),
            ],
            edges: [
                SessionGraph.Edge(sourceNodeID: "n1", targetNodeID: "n2", type: "TRIGGERS", weight: 1),
                SessionGraph.Edge(sourceNodeID: "n2", targetNodeID: "n1", type: "ASSOCIATED_WITH", weight: 1),
            ]
        )
        var entityIndex = EntityChunkIndex()
        let seedChunk = chunk("seed", doc: "d1", text: "I saw my mother and felt anxious.")
        entityIndex.index(seedChunk)
        let index = await makeIndex(with: [seedChunk])
        let seed = ScoredChunk(chunk: seedChunk, score: 1.0, provenance: .vector)

        let results = await GraphExpander().expand(seeds: [seed], graph: graph, entityIndex: entityIndex,
                                                    index: index, hops: 2)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.provenance, .vector)
        XCTAssertEqual(results.first?.score, 1.0)
    }

    func testMultiHopScoreDecaysWithDistance() async {
        let graph = aggregatedGraph(
            nodes: [
                SessionGraph.Node(id: "n1", type: "theme", label: "A", strength: 1),
                SessionGraph.Node(id: "n2", type: "theme", label: "B", strength: 1),
                SessionGraph.Node(id: "n3", type: "theme", label: "C", strength: 1),
            ],
            edges: [
                SessionGraph.Edge(sourceNodeID: "n1", targetNodeID: "n2", type: "ASSOCIATED_WITH", weight: 1),
                SessionGraph.Edge(sourceNodeID: "n2", targetNodeID: "n3", type: "ASSOCIATED_WITH", weight: 1),
            ]
        )
        var entityIndex = EntityChunkIndex()
        let seedChunk = chunk("seed", doc: "d1", text: "seed")
        let hop1Chunk = chunk("hop1", doc: "d2", text: "hop1")
        let hop2Chunk = chunk("hop2", doc: "d3", text: "hop2")
        // "A"/"B"/"C" aren't real extractor vocabulary, so wire the mapping
        // directly to isolate the hop/decay math from extraction behavior.
        entityIndex.forceIndex(chunkID: "seed", nodeIDs: ["theme:a"])
        entityIndex.forceIndex(chunkID: "hop1", nodeIDs: ["theme:b"])
        entityIndex.forceIndex(chunkID: "hop2", nodeIDs: ["theme:c"])

        let index = await makeIndex(with: [seedChunk, hop1Chunk, hop2Chunk])
        let seed = ScoredChunk(chunk: seedChunk, score: 1.0, provenance: .vector)

        let results = await GraphExpander(decay: 0.5).expand(seeds: [seed], graph: graph, entityIndex: entityIndex,
                                                              index: index, hops: 2)
        let hop1 = results.first { $0.chunk.id == "hop1" }
        let hop2 = results.first { $0.chunk.id == "hop2" }
        XCTAssertEqual(hop1?.score ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(hop2?.score ?? -1, 0.25, accuracy: 0.0001)
    }

    func testHopsBeyondGraphDiameterTerminateWithoutHanging() async {
        // Only 1 real hop exists; asking for 5 must stop early via the
        // empty-frontier break, not iterate needlessly or crash on an empty range.
        let graph = aggregatedGraph(
            nodes: [
                SessionGraph.Node(id: "n1", type: "person", label: "Mother", strength: 1),
                SessionGraph.Node(id: "n2", type: "emotion", label: "Anxious", strength: 1),
            ],
            edges: [SessionGraph.Edge(sourceNodeID: "n1", targetNodeID: "n2", type: "TRIGGERS", weight: 1)]
        )
        var entityIndex = EntityChunkIndex()
        let seedChunk = chunk("seed", doc: "d1", text: "I saw my mother today.")
        entityIndex.index(seedChunk)
        let index = await makeIndex(with: [seedChunk])
        let seed = ScoredChunk(chunk: seedChunk, score: 1.0, provenance: .vector)

        let results = await GraphExpander().expand(seeds: [seed], graph: graph, entityIndex: entityIndex,
                                                    index: index, hops: 5)
        XCTAssertEqual(results.count, 1)
    }
}
