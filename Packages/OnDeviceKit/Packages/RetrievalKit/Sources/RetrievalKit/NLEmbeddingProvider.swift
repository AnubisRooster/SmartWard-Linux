#if canImport(NaturalLanguage)
import Foundation
import NaturalLanguage

/// The default `EmbeddingProviding`: Apple's on-device sentence embeddings via
/// `NaturalLanguage`. No model to bundle or download and no network call —
/// the reason this is the default for a privacy-sensitive personal corpus
/// (the whole indexed corpus never leaves the device).
public struct NLEmbeddingProvider: EmbeddingProviding {
    private let embedding: NLEmbedding?

    public init(language: NLLanguage = .english) {
        self.embedding = NLEmbedding.sentenceEmbedding(for: language)
    }

    /// `0` if this language has no on-device sentence embedding available —
    /// `embed(_:)` then always returns `nil`, so callers should check this
    /// (or `NLEmbedding.sentenceEmbedding(for:)`'s own availability) up front
    /// rather than silently indexing nothing.
    public var dimension: Int { embedding?.dimension ?? 0 }

    public func embed(_ text: String) async -> [Float]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let embedding, let vector = embedding.vector(for: trimmed) else {
            return nil
        }
        return vector.map { Float($0) }
    }
}
#endif
