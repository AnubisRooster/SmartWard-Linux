import Foundation

/// A BM25 keyword index over `(id, text)` pairs. Technical or proper-noun
/// queries ("LoRA", "vLLM", "SWE-bench") are full of exact tokens that
/// embeddings alone can miss — keyword search is what `HybridRetriever` fuses
/// with `Retriever`'s vector search to cover both.
///
/// Persistence-agnostic like the rest of `RetrievalKit`: a value type keyed
/// by whatever id the host already uses (typically a `Chunk.id`).
public struct LexicalIndex: Sendable {
    static let k1 = 1.2
    static let b = 0.75

    private var postings: [String: [Int: Int]] = [:]
    private var lengths: [Int] = []
    private var totalLength = 0
    private(set) var ids: [String] = []

    public init() {}

    public var count: Int { ids.count }

    public mutating func add(id: String, text: String) {
        let index = ids.count
        ids.append(id)
        let tokens = Self.tokens(text)
        lengths.append(tokens.count)
        totalLength += tokens.count
        for token in tokens {
            postings[token, default: [:]][index, default: 0] += 1
        }
    }

    /// The `limit` best matches by BM25 score, best first. Ids removed from
    /// the host's own storage but never added here again are simply never
    /// returned; this index has no notion of removal itself — a host that
    /// deletes documents should rebuild from its remaining ids once enough
    /// have gone stale, the same way `VectorIndex` tracks removal directly
    /// but a value-type keyword posting list does not.
    public func search(_ query: String, limit: Int) -> [(id: String, score: Double)] {
        let terms = Set(Self.tokens(query))
        guard !terms.isEmpty, !ids.isEmpty else { return [] }
        let averageLength = max(1, Double(totalLength) / Double(lengths.count))
        let total = Double(ids.count)

        var scores: [Int: Double] = [:]
        for term in terms {
            guard let docs = postings[term] else { continue }
            let idf = log(1 + (total - Double(docs.count) + 0.5) / (Double(docs.count) + 0.5))
            for (doc, frequency) in docs {
                let tf = Double(frequency)
                let norm = tf * (Self.k1 + 1)
                    / (tf + Self.k1 * (1 - Self.b + Self.b * Double(lengths[doc]) / averageLength))
                scores[doc, default: 0] += idf * norm
            }
        }
        var best = TopK<(doc: Int, score: Double)>(limit) { a, b in
            a.score != b.score ? a.score > b.score : a.doc < b.doc
        }
        for (doc, score) in scores { best.insert((doc, score)) }
        return best.sorted().map { (id: ids[$0.doc], score: $0.score) }
    }

    /// Lowercased tokens, with compound tokens ("SWE-bench") indexed both
    /// whole and by their parts ("swe-bench", "swe", "bench"), so a query for
    /// either form matches.
    public static func tokens(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        func flush() {
            let trimmed = current.trimmingCharacters(in: CharacterSet(charactersIn: "-.+_"))
            if !trimmed.isEmpty {
                result.append(trimmed)
                let parts = trimmed.split(whereSeparator: { "-.+_".contains($0) }).map(String.init)
                if parts.count > 1 { result += parts }
            }
            current = ""
        }
        for character in text.lowercased() {
            if character.isLetter || character.isNumber || "-.+_".contains(character) {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return result
    }
}
