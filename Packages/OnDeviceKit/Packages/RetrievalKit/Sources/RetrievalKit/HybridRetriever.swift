import Foundation

/// Fuses `Retriever`'s vector search with `LexicalIndex`'s BM25 keyword
/// search via reciprocal rank fusion — the entry point most hosts should use
/// instead of `Retriever` alone once queries start including exact technical
/// terms ("LoRA", "vLLM", "SWE-bench") that keyword matching finds and
/// embeddings can miss.
///
/// `HybridRetriever` depends only on `Retriever` + `LexicalIndex`; neither of
/// those depends back on it, so a host that only wants plain vector RAG can
/// keep using `Retriever` directly — the same layering `GraphRetrievalKit`
/// uses on top of `Retriever` for graph-hop expansion.
public actor HybridRetriever {
    /// Reciprocal rank fusion's rank-damping constant — standard IR default.
    static let fusionK = 60.0

    private let retriever: Retriever
    private var lexical = LexicalIndex()
    /// Keeps every chunk `Retriever.index` produced, not just the ones that
    /// embedded successfully — a chunk `Retriever`'s own `VectorIndex` never
    /// stored (an unembeddable one, or any embedder failure) must still be
    /// resolvable here, since keyword search's whole point is not depending
    /// on embedding having worked.
    private var chunksByID: [String: Chunk] = [:]
    /// How many candidates each side contributes before fusion. Wider than
    /// the eventual `topK` so fusion has enough of both rankings to combine.
    public let candidateLimit: Int

    #if canImport(NaturalLanguage)
    public init(retriever: Retriever = Retriever(), candidateLimit: Int = 50) {
        self.retriever = retriever
        self.candidateLimit = candidateLimit
    }
    #else
    public init(retriever: Retriever, candidateLimit: Int = 50) {
        self.retriever = retriever
        self.candidateLimit = candidateLimit
    }
    #endif

    /// The `Retriever` backing this hybrid index — exposed so a host that
    /// also wants graph-hop expansion (`GraphRetrievalKit`) can share its
    /// storage rather than indexing the same documents twice.
    public var underlyingRetriever: Retriever { retriever }

    /// Chunks, embeds, and indexes `document` for both vector search and
    /// keyword search.
    @discardableResult
    public func index(_ document: Document) async -> [Chunk] {
        let chunks = await retriever.index(document)
        for chunk in chunks {
            lexical.add(id: chunk.id, text: chunk.text)
            chunksByID[chunk.id] = chunk
        }
        return chunks
    }

    public func remove(documentID: String) async {
        await retriever.remove(documentID: documentID)
        chunksByID = chunksByID.filter { $0.value.documentID != documentID }
        // `LexicalIndex` itself has no in-place removal (see its own doc
        // comment): its postings for this document go stale, but they can no
        // longer resolve to a `Chunk` above, so they're harmless until
        // `rebuildLexicalIndex(from:)` clears them out for good.
    }

    /// Discards the keyword index and rebuilds it from `chunks` — call this
    /// periodically once enough documents have been removed that stale
    /// postings would otherwise keep costing time at query.
    public func rebuildLexicalIndex(from chunks: [Chunk]) {
        var fresh = LexicalIndex()
        for chunk in chunks { fresh.add(id: chunk.id, text: chunk.text) }
        lexical = fresh
    }

    /// Vector and keyword hits for `query`, fused by reciprocal rank fusion
    /// and returned as `[ScoredChunk]` tagged `.hybrid(keyword:vector:)`.
    /// Bounded by `TopK` rather than a full sort, matching `VectorIndex`'s
    /// own approach to ranking a candidate set.
    public func retrieve(_ query: String, topK: Int = 8,
                         filter: (@Sendable (Chunk) -> Bool)? = nil) async -> [ScoredChunk] {
        let vectorHits = await retriever.retrieve(query, topK: candidateLimit, filter: filter)
        let keywordHits = lexical.search(query, limit: candidateLimit)
        guard !vectorHits.isEmpty || !keywordHits.isEmpty else { return [] }

        var fused: [String: (score: Double, keyword: Bool, vector: Bool)] = [:]
        for (rank, hit) in keywordHits.enumerated() {
            // Same filter vector hits already went through, applied here too
            // so a keyword-only match can't bypass it.
            guard let chunk = chunksByID[hit.id], filter?(chunk) ?? true else { continue }
            var entry = fused[hit.id] ?? (score: 0, keyword: false, vector: false)
            entry.score += 1 / (Self.fusionK + Double(rank + 1))
            entry.keyword = true
            fused[hit.id] = entry
        }
        for (rank, hit) in vectorHits.enumerated() {
            var entry = fused[hit.chunk.id] ?? (score: 0, keyword: false, vector: false)
            entry.score += 1 / (Self.fusionK + Double(rank + 1))
            entry.vector = true
            fused[hit.chunk.id] = entry
        }

        var best = TopK<ScoredChunk>(topK) { a, b in
            a.score != b.score ? a.score > b.score : a.chunk.id < b.chunk.id
        }
        for (id, entry) in fused {
            guard let chunk = chunksByID[id] else { continue }
            best.insert(ScoredChunk(chunk: chunk, score: Float(entry.score),
                                    provenance: .hybrid(keyword: entry.keyword, vector: entry.vector)))
        }
        return best.sorted()
    }
}
