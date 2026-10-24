import Foundation
import GraphKit
import RetrievalKit

/// Expands vector-search seeds by walking `AggregatedGraph` edges from the
/// entities each seed chunk mentions, pulling in sibling chunks that discuss
/// related entities — the layer that makes this GraphRAG rather than plain
/// RAG.
///
/// Multi-hop reasoning ("what Mother triggers, and what that leads to") falls
/// out of walking `AggregatedEdge`s; plain cosine similarity over chunk text
/// can't reliably find that connection unless the two chunks happen to share
/// vocabulary.
public struct GraphExpander: Sendable {
    /// How much a hop's score is discounted per hop of distance from a seed.
    /// A hop-1 neighbor scores `bestSeedScore * decay`; hop-2 scores
    /// `bestSeedScore * decay^2`, and so on — so directly vector-retrieved
    /// chunks always outrank graph-expanded ones, and closer graph neighbors
    /// outrank farther ones.
    public let decay: Float

    public init(decay: Float = 0.6) {
        self.decay = decay
    }

    /// - Parameters:
    ///   - seeds: the vector-search results to expand from.
    ///   - graph: the host's current aggregated knowledge graph — typically
    ///     `GraphExporter.aggregate(sessions:)` over the same corpus being
    ///     indexed. This module doesn't build or own that graph.
    ///   - entityIndex: maps graph node ids to the chunks that mention them
    ///     (built alongside indexing via `EntityChunkIndex.index(_:)`).
    ///   - index: resolves a graph-hop neighbor's chunk id back to its `Chunk`.
    ///   - hops: how many edges to walk outward from each seed's entities.
    ///     `0` returns `seeds` unchanged. Edges are walked as undirected —
    ///     retrieval cares about relatedness, not the extractor's edge direction.
    public func expand(seeds: [ScoredChunk],
                       graph: AggregatedGraph,
                       entityIndex: EntityChunkIndex,
                       index: VectorIndex,
                       hops: Int = 1) async -> [ScoredChunk] {
        guard hops > 0, !seeds.isEmpty else { return seeds }

        let adjacency = Self.buildAdjacency(graph)

        var results: [String: ScoredChunk] = [:]
        for seed in seeds { results[seed.chunk.id] = seed }

        var frontier: Set<String> = []
        for seed in seeds {
            frontier.formUnion(entityIndex.nodeIDs(forChunk: seed.chunk.id))
        }
        var visitedNodes = frontier
        var currentScore = seeds.map(\.score).max() ?? 1

        for hop in 1...hops {
            currentScore *= decay
            var nextFrontier: Set<String> = []

            for nodeID in frontier {
                for neighborID in adjacency[nodeID] ?? [] where !visitedNodes.contains(neighborID) {
                    nextFrontier.insert(neighborID)

                    for chunkID in entityIndex.chunkIDs(forNode: neighborID) where results[chunkID] == nil {
                        guard let chunk = await index.chunk(withID: chunkID) else { continue }
                        results[chunkID] = ScoredChunk(chunk: chunk, score: currentScore,
                                                       provenance: .graphHop(distance: hop, via: neighborID))
                    }
                }
            }

            visitedNodes.formUnion(nextFrontier)
            frontier = nextFrontier
            if frontier.isEmpty { break }
        }

        return results.values.sorted { $0.score > $1.score }
    }

    private static func buildAdjacency(_ graph: AggregatedGraph) -> [String: Set<String>] {
        var adjacency: [String: Set<String>] = [:]
        for edge in graph.edges {
            adjacency[edge.sourceID, default: []].insert(edge.targetID)
            adjacency[edge.targetID, default: []].insert(edge.sourceID)
        }
        return adjacency
    }
}
