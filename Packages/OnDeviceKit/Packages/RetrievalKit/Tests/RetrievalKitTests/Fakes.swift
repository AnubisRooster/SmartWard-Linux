import Foundation
@testable import RetrievalKit

/// A deterministic bag-of-words embedder: hashes each word (stably) into a fixed-size
/// vector bucket and sums, so test strings sharing words score higher on
/// cosine similarity — without needing `NLEmbedding` (unavailable off-device)
/// or any real model.
struct FakeEmbeddingProvider: EmbeddingProviding {
    let dimension: Int = 16

    func embed(_ text: String) async -> [Float]? {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        guard !words.isEmpty else { return nil }
        var vector = [Float](repeating: 0, count: dimension)
        for word in words {
            vector[Self.bucket(for: word, dimension: dimension)] += 1
        }
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return nil }
        return vector.map { $0 / norm }
    }

    /// FNV-1a over the UTF-8 bytes. `hashValue` is seeded randomly per process,
    /// so which words share a bucket (and so which document wins) would change
    /// from run to run.
    static func bucket(for word: Substring, dimension: Int) -> Int {
        let hash = word.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        return Int(hash % UInt64(dimension))
    }
}

/// An embedder that always fails, for exercising the "couldn't embed" paths.
struct NilEmbeddingProvider: EmbeddingProviding {
    let dimension: Int = 16
    func embed(_ text: String) async -> [Float]? { nil }
}
