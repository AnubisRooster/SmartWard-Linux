import Foundation
#if canImport(Accelerate)
import Accelerate
#endif
import SwiftData
import RetrievalKit
import KnowledgeStore

/// One searchable unit: an article's title and summary, or one of its chunks.
public struct SearchDocument: Equatable, Sendable {
    public var id: String
    public var articleID: UUID
    public var text: String
    /// Only vectors from the current embedding model.
    public var vector: [Float]?

    public init(id: String, articleID: UUID, text: String, vector: [Float]? = nil) {
        self.id = id
        self.articleID = articleID
        self.text = text
        self.vector = vector
    }
}

/// BM25 keyword index. Technical queries are full of exact tokens ("LoRA",
/// "vLLM", "SWE-bench", "gpt-4o") where keywords beat embeddings (PLAN §5.2),
/// so compound tokens are indexed whole and by their parts.
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

    /// Lowercased tokens. "SWE-bench" yields "swe-bench", "swe" and "bench".
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

public struct SearchHit: Equatable, Sendable, Identifiable {
    public struct MatchKind: OptionSet, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let keyword = MatchKind(rawValue: 1)
        public static let semantic = MatchKind(rawValue: 2)
    }

    public var articleID: UUID
    public var snippet: String
    public var score: Double
    public var matchedBy: MatchKind

    public var id: UUID { articleID }
}

/// Keyword and semantic retrieval fused with reciprocal rank fusion (FR-14),
/// grouped into one hit per article. Everything runs on-device.
public struct HybridSearchIndex: Sendable {
    static let fusionK = 60.0
    static let candidates = 50
    /// Weaker semantic neighbors are noise, not results.
    static let minimumSimilarity: Float = 0.3

    private var lexical = LexicalIndex()
    private var documents: [String: SearchDocument] = [:]
    /// Unit-length vectors, one row per id in `vectorIDs`, so a query is one
    /// matrix-vector product instead of a cosine per document.
    private var matrix: [Float] = []
    private var vectorIDs: [String] = []
    private var dimension = 0
    /// Ids removed since the last build. Their postings and vectors stay
    /// (they're skipped at query time) until a rebuild clears them.
    public private(set) var retired = Set<String>()

    public init(documents: [SearchDocument]) {
        add(documents)
    }

    /// Adds documents in place: new articles and chunks don't need a rebuild.
    public mutating func add(_ documents: [SearchDocument]) {
        for document in documents {
            lexical.add(id: document.id, text: document.text)
            self.documents[document.id] = document
            guard let vector = document.vector, !vector.isEmpty else { continue }
            if dimension == 0 { dimension = vector.count }
            // Vectors of another size came from another model; they can't be compared.
            guard vector.count == dimension, let unit = Self.normalized(vector) else { continue }
            matrix.append(contentsOf: unit)
            vectorIDs.append(document.id)
        }
    }

    /// Stops returning these documents.
    public mutating func remove(_ ids: some Sequence<String>) {
        for id in ids where documents.removeValue(forKey: id) != nil {
            retired.insert(id)
        }
    }

    public var documentIDs: Set<String> { Set(documents.keys) }

    /// Rebuild once removed documents are a fifth of what's stored: they
    /// still cost time at query time, and a retired id can't be re-added.
    public var needsRebuild: Bool {
        retired.count > max(500, documents.count / 5)
    }

    static func normalized(_ vector: [Float]) -> [Float]? {
        var sumOfSquares: Float = 0
        #if canImport(Accelerate)
        vDSP_svesq(vector, 1, &sumOfSquares, vDSP_Length(vector.count))
        #else
        for x in vector { sumOfSquares += x * x }
        #endif
        guard sumOfSquares > 0, sumOfSquares.isFinite else { return nil }
        var scale = 1 / sumOfSquares.squareRoot()
        var unit = [Float](repeating: 0, count: vector.count)
        #if canImport(Accelerate)
        vDSP_vsmul(vector, 1, &scale, &unit, 1, vDSP_Length(vector.count))
        #else
        for i in 0..<vector.count { unit[i] = vector[i] * scale }
        #endif
        return unit
    }

    /// Cosine similarity of every stored vector with `query`, as one
    /// matrix-vector product, keeping the best `limit` above the floor.
    func semanticMatches(_ query: [Float], limit: Int) -> [(id: String, similarity: Float)] {
        guard !vectorIDs.isEmpty, query.count == dimension, let unit = Self.normalized(query) else { return [] }
        var similarities = [Float](repeating: 0, count: vectorIDs.count)
        #if canImport(Accelerate)
        vDSP_mmul(matrix, 1, unit, 1, &similarities, 1,
                  vDSP_Length(vectorIDs.count), 1, vDSP_Length(dimension))
        #else
        matrix.withUnsafeBufferPointer { m in
            unit.withUnsafeBufferPointer { u in
                for row in 0..<vectorIDs.count {
                    var dot: Float = 0
                    let base = row * dimension
                    for column in 0..<dimension { dot += m[base + column] * u[column] }
                    similarities[row] = dot
                }
            }
        }
        #endif
        var best = TopK<(index: Int, similarity: Float)>(limit) { a, b in
            a.similarity != b.similarity ? a.similarity > b.similarity : a.index < b.index
        }
        for (index, similarity) in similarities.enumerated() where similarity >= Self.minimumSimilarity {
            best.insert((index, similarity))
        }
        return best.sorted().map { (id: vectorIDs[$0.index], similarity: $0.similarity) }
    }

    public var documentCount: Int { documents.count }

    /// A document with its fused score and how it matched.
    public struct RankedDocument: Equatable, Sendable {
        public var document: SearchDocument
        public var score: Double
        public var matchedBy: SearchHit.MatchKind
    }

    /// Documents (article headers and chunks) ranked by reciprocal rank fusion.
    public func rankDocuments(_ query: String, queryVector: [Float]?, limit: Int = 50) -> [RankedDocument] {
        let keywordHits = lexical.search(query, limit: Self.candidates).map(\.id)
        var semanticHits: [String] = []
        if let queryVector {
            semanticHits = semanticMatches(queryVector, limit: Self.candidates).map(\.id)
        }

        var fused: [String: (score: Double, kind: SearchHit.MatchKind)] = [:]
        for (rank, id) in keywordHits.enumerated() {
            let current = fused[id] ?? (score: 0, kind: [])
            fused[id] = (score: current.score + 1 / (Self.fusionK + Double(rank + 1)), kind: current.kind.union(.keyword))
        }
        for (rank, id) in semanticHits.enumerated() {
            let current = fused[id] ?? (score: 0, kind: [])
            fused[id] = (score: current.score + 1 / (Self.fusionK + Double(rank + 1)), kind: current.kind.union(.semantic))
        }
        var ranked: [RankedDocument] = []
        for (id, match) in fused {
            guard let document = documents[id] else { continue }
            ranked.append(RankedDocument(document: document, score: match.score, matchedBy: match.kind))
        }
        ranked.sort { $0.score != $1.score ? $0.score > $1.score : $0.document.id < $1.document.id }
        return Array(ranked.prefix(limit))
    }

    public func search(_ query: String, queryVector: [Float]?, limit: Int = 25) -> [SearchHit] {
        // One hit per article: its best document's score and snippet, and
        // every way any of its documents matched.
        var byArticle: [UUID: SearchHit] = [:]
        for ranked in rankDocuments(query, queryVector: queryVector, limit: Int.max) {
            let document = ranked.document
            let match = (score: ranked.score, kind: ranked.matchedBy)
            let snippet = Self.snippet(document.text, query: query)
            if var existing = byArticle[document.articleID] {
                existing.matchedBy = existing.matchedBy.union(match.kind)
                if match.score > existing.score {
                    existing.score = match.score
                    existing.snippet = snippet
                }
                byArticle[document.articleID] = existing
            } else {
                byArticle[document.articleID] = SearchHit(articleID: document.articleID, snippet: snippet,
                                                          score: match.score, matchedBy: match.kind)
            }
        }
        return byArticle.values
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.articleID.uuidString < $1.articleID.uuidString }
            .prefix(limit)
            .map { $0 }
    }

    /// About 240 characters around the first query term found, else the start.
    static func snippet(_ text: String, query: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        let window = 240
        var begin = flat.startIndex
        for term in LexicalIndex.tokens(query) where term.count >= 3 {
            if let range = flat.range(of: term, options: .caseInsensitive) {
                begin = flat.index(range.lowerBound, offsetBy: -80, limitedBy: flat.startIndex) ?? flat.startIndex
                break
            }
        }
        let end = flat.index(begin, offsetBy: window, limitedBy: flat.endIndex) ?? flat.endIndex
        var snippet = String(flat[begin..<end]).trimmingCharacters(in: .whitespaces)
        if begin > flat.startIndex { snippet = "…" + snippet }
        if end < flat.endIndex { snippet += "…" }
        return snippet
    }
}

public enum SearchCorpus {
    /// What changed in the library since `index` was built.
    public struct Update: Equatable, Sendable {
        public var add: [SearchDocument] = []
        public var remove: Set<String> = []
        /// Too much changed, or an id came back: build a new index instead.
        public var rebuild = false

        public var isEmpty: Bool { add.isEmpty && remove.isEmpty && !rebuild }
    }

    /// Diffs the library's article and chunk ids against `index`, loading
    /// only new documents.
    @MainActor
    public static func update(for index: HybridSearchIndex?, context: ModelContext,
                              embeddingModelID: String?) throws -> Update {
        guard let index else { return Update(rebuild: true) }
        var articleIDs = FetchDescriptor<Article>()
        articleIDs.propertiesToFetch = [\.id]
        var chunkIDs = FetchDescriptor<KnowledgeStore.Chunk>(predicate: #Predicate { $0.article != nil })
        chunkIDs.propertiesToFetch = [\.id]
        var current = Set<String>()
        var articles: [UUID: String] = [:]
        var chunks: [UUID: String] = [:]
        for article in try context.fetch(articleIDs) {
            let id = "article:\(article.id.uuidString)"
            current.insert(id)
            articles[article.id] = id
        }
        for chunk in try context.fetch(chunkIDs) {
            let id = "chunk:\(chunk.id.uuidString)"
            current.insert(id)
            chunks[chunk.id] = id
        }

        let indexed = index.documentIDs
        var update = Update()
        update.remove = indexed.subtracting(current)
        let added = current.subtracting(indexed)
        if !added.isDisjoint(with: index.retired) || index.retired.count + update.remove.count > max(500, current.count / 5) {
            return Update(rebuild: true)
        }
        let newArticles = articles.filter { added.contains($0.value) }.map(\.key)
        let newChunks = chunks.filter { added.contains($0.value) }.map(\.key)
        update.add = try documents(context: context, embeddingModelID: embeddingModelID,
                                   articleIDs: newArticles, chunkIDs: newChunks)
        return update
    }

    /// Just these articles' headers and these chunks.
    @MainActor
    public static func documents(context: ModelContext, embeddingModelID: String?,
                                 articleIDs: [UUID], chunkIDs: [UUID]) throws -> [SearchDocument] {
        var documents: [SearchDocument] = []
        if !articleIDs.isEmpty {
            for article in try context.fetch(FetchDescriptor<Article>(predicate: #Predicate { articleIDs.contains($0.id) })) {
                documents.append(header(article))
            }
        }
        if !chunkIDs.isEmpty {
            var descriptor = FetchDescriptor<KnowledgeStore.Chunk>(predicate: #Predicate { chunkIDs.contains($0.id) })
            descriptor.relationshipKeyPathsForPrefetching = [\.article]
            for chunk in try context.fetch(descriptor) {
                if let document = self.document(chunk, embeddingModelID: embeddingModelID) { documents.append(document) }
            }
        }
        return documents
    }

    static func header(_ article: Article) -> SearchDocument {
        let text = [article.title, article.summary].filter { !$0.isEmpty }.joined(separator: "\n")
        return SearchDocument(id: "article:\(article.id.uuidString)", articleID: article.id, text: text)
    }

    static func document(_ chunk: KnowledgeStore.Chunk, embeddingModelID: String?) -> SearchDocument? {
        guard let article = chunk.article else { return nil }
        var vector: [Float]?
        if let data = chunk.vector, let embeddingModelID, chunk.embeddingModel == embeddingModelID {
            vector = VectorCoding.vector(from: data)
        }
        return SearchDocument(id: "chunk:\(chunk.id.uuidString)", articleID: article.id, text: chunk.text, vector: vector)
    }

    /// Every article (title and summary, including off-topic ones, which
    /// stay searchable) plus every chunk. Vectors are included only when
    /// they came from `embeddingModelID`.
    @MainActor
    public static func documents(context: ModelContext, embeddingModelID: String?) throws -> [SearchDocument] {
        var documents: [SearchDocument] = []
        for article in try context.fetch(FetchDescriptor<Article>()) {
            documents.append(header(article))
        }
        var chunks = FetchDescriptor<KnowledgeStore.Chunk>()
        // One query for the articles instead of a fault per chunk.
        chunks.relationshipKeyPathsForPrefetching = [\.article]
        for chunk in try context.fetch(chunks) {
            if let document = document(chunk, embeddingModelID: embeddingModelID) { documents.append(document) }
        }
        return documents
    }
}
