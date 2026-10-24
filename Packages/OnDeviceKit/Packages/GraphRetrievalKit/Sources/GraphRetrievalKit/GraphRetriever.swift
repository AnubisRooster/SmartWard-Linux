import Foundation
import GraphKit
import RetrievalKit

/// Combines `RetrievalKit`'s vector search with `GraphExpander`'s graph-hop
/// expansion into a single retrieval call — the entry point most hosts will
/// use. `GraphRetrievalKit` depends on `RetrievalKit` + `GraphKit`; neither of
/// those depends back on this, so a host that only wants plain vector RAG can
/// use `RetrievalKit.Retriever` alone with no graph involved.
public actor GraphRetriever {
    private let retriever: Retriever
    private var entityIndex = EntityChunkIndex()
    private let expander: GraphExpander

    #if canImport(NaturalLanguage)
    public init(retriever: Retriever = Retriever(), expander: GraphExpander = GraphExpander()) {
        self.retriever = retriever
        self.expander = expander
    }
    #else
    public init(retriever: Retriever, expander: GraphExpander = GraphExpander()) {
        self.retriever = retriever
        self.expander = expander
    }
    #endif

    /// Chunks, embeds, and indexes `document` for both vector search and
    /// graph-entity lookup.
    @discardableResult
    public func index(_ document: Document) async -> [Chunk] {
        let chunks = await retriever.index(document)
        for chunk in chunks { entityIndex.index(chunk) }
        return chunks
    }

    public func remove(documentID: String) async {
        await retriever.remove(documentID: documentID)
        entityIndex.removeDocument(documentID)
    }

    /// Vector search for `query`, then expanded by `hops` graph edges through
    /// the entities the seed chunks mention. Pass the host's current
    /// `AggregatedGraph` — typically `GraphExporter.aggregate(sessions:)` over
    /// the same corpus being indexed here.
    public func retrieve(_ query: String, topK: Int = 8, hops: Int = 1,
                         graph: AggregatedGraph) async -> [ScoredChunk] {
        let seeds = await retriever.retrieve(query, topK: topK)
        return await expander.expand(seeds: seeds, graph: graph, entityIndex: entityIndex,
                                     index: retriever.underlyingIndex, hops: hops)
    }
}
