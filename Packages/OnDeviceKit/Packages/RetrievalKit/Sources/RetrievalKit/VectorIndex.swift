import Foundation

/// An in-memory, brute-force cosine-similarity index.
///
/// Sized deliberately for a single user's personal corpus — a linear vDSP
/// scan comfortably handles tens of thousands of chunks on-device. Beyond
/// that an ANN index (e.g. HNSW) would be needed; this module doesn't ship
/// one, by design, since that scale doesn't fit a single person's journal or
/// session history. `snapshot()`/`restore(from:)` let a host persist the
/// index however it likes (e.g. via `ModelCatalogKit`'s `FileCache`) —
/// `VectorIndex` itself is not tied to any storage.
public actor VectorIndex {
    private struct Entry: Sendable {
        let vector: [Float]
        let chunk: Chunk
    }

    private var entries: [String: Entry] = [:]

    public init() {}

    public var count: Int { entries.count }

    public func add(vector: [Float], chunk: Chunk) {
        entries[chunk.id] = Entry(vector: vector, chunk: chunk)
    }

    public func remove(chunkID: String) {
        entries.removeValue(forKey: chunkID)
    }

    public func removeAll(documentID: String) {
        entries = entries.filter { $0.value.chunk.documentID != documentID }
    }

    /// Looks up a chunk by id without a similarity search — used by
    /// `GraphRetrievalKit`'s `GraphExpander` to resolve graph-hop neighbors
    /// back to their `Chunk`.
    public func chunk(withID id: String) -> Chunk? {
        entries[id]?.chunk
    }

    /// Returns the top `topK` chunks by cosine similarity to `query`,
    /// optionally restricted by `filter` (e.g. a metadata-based scope).
    public func search(_ query: [Float], topK: Int,
                       filter: (@Sendable (Chunk) -> Bool)? = nil) -> [ScoredChunk] {
        guard topK > 0, !query.isEmpty else { return [] }
        var scored: [ScoredChunk] = []
        scored.reserveCapacity(entries.count)
        for entry in entries.values {
            if let filter, !filter(entry.chunk) { continue }
            scored.append(ScoredChunk(chunk: entry.chunk,
                                      score: CosineSimilarity.score(query, entry.vector),
                                      provenance: .vector))
        }
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(topK))
    }

    // MARK: - Snapshot (host owns actual persistence)

    public func snapshot() -> Data {
        let codable = entries.values.map { CodableEntry(vector: $0.vector, chunk: $0.chunk) }
        return (try? JSONEncoder().encode(codable)) ?? Data()
    }

    public func restore(from data: Data) {
        guard let decoded = try? JSONDecoder().decode([CodableEntry].self, from: data) else { return }
        entries = Dictionary(uniqueKeysWithValues: decoded.map {
            ($0.chunk.id, Entry(vector: $0.vector, chunk: $0.chunk))
        })
    }

    private struct CodableEntry: Codable {
        let vector: [Float]
        let chunk: Chunk
    }
}
