import Foundation

/// Ties an `EmbeddingProviding` to a `VectorIndex` via a `Chunker` — the
/// layer a host app actually calls: chunk + embed documents in, embed +
/// search queries out.
public actor Retriever {
    private let embedder: EmbeddingProviding
    private let index: VectorIndex
    private let chunker: Chunker

    #if canImport(NaturalLanguage)
    public init(embedder: EmbeddingProviding = NLEmbeddingProvider(),
                index: VectorIndex = VectorIndex(),
                chunker: Chunker = Chunker()) {
        self.embedder = embedder
        self.index = index
        self.chunker = chunker
    }
    #else
    /// No default embedder off Apple platforms: pass one (e.g. a local-model provider).
    public init(embedder: EmbeddingProviding,
                index: VectorIndex = VectorIndex(),
                chunker: Chunker = Chunker()) {
        self.embedder = embedder
        self.index = index
        self.chunker = chunker
    }
    #endif

    /// The `VectorIndex` backing this retriever — exposed so composing types
    /// (e.g. `GraphRetrievalKit`'s `GraphRetriever`) can share it rather than
    /// duplicating storage.
    public var underlyingIndex: VectorIndex { index }

    /// Chunks and embeds `document`, adding every chunk to the index. Chunks
    /// that fail to embed (e.g. empty after trimming) are silently skipped.
    /// Returns the chunks produced, so callers that also need per-chunk
    /// entity indexing don't have to re-chunk the document themselves.
    @discardableResult
    public func index(_ document: Document) async -> [Chunk] {
        let chunks = chunker.chunk(document)
        for chunk in chunks {
            guard let vector = await embedder.embed(chunk.text) else { continue }
            await index.add(vector: vector, chunk: chunk)
        }
        return chunks
    }

    public func remove(documentID: String) async {
        await index.removeAll(documentID: documentID)
    }

    /// Embeds `query` and returns its top-k most similar chunks. Returns an
    /// empty array (rather than throwing) if the query itself can't be
    /// embedded — an empty result set is a safe, silent no-match.
    public func retrieve(_ query: String, topK: Int = 8,
                         filter: (@Sendable (Chunk) -> Bool)? = nil) async -> [ScoredChunk] {
        guard let vector = await embedder.embed(query) else { return [] }
        return await index.search(vector, topK: topK, filter: filter)
    }
}
