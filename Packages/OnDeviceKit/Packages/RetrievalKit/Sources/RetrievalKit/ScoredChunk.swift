import Foundation

/// Why a chunk was retrieved. Surfaced (rather than collapsed into a single
/// score) so a host UI can show the user *why* something was pulled in — a
/// semantic match vs. a graph relationship — which matters for trust when
/// retrieval is grounding replies in a personal or therapeutic corpus.
public enum Provenance: Sendable, Equatable {
    /// A direct hit from vector similarity search.
    case vector
    /// Pulled in by `GraphRetrievalKit`'s `GraphExpander` via a graph walk.
    /// `via` is the id of the entity node this chunk was reached through.
    case graphHop(distance: Int, via: String)
    /// From `HybridRetriever`: found by keyword (BM25), by vector similarity,
    /// or by both — a query full of exact technical terms ("LoRA", "vLLM")
    /// often matches on keywords alone, where cosine similarity can miss it.
    case hybrid(keyword: Bool, vector: Bool)
}

public struct ScoredChunk: Sendable, Equatable {
    public let chunk: Chunk
    public let score: Float
    public let provenance: Provenance

    public init(chunk: Chunk, score: Float, provenance: Provenance) {
        self.chunk = chunk
        self.score = score
        self.provenance = provenance
    }
}
