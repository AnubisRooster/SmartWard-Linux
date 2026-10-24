import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif
import RetrievalKit

/// An embedder plus the identifier recorded on every chunk it embeds
/// (FR-5), so vectors from a different model are never compared and can be
/// re-embedded when the model changes.
public struct EmbeddingModel: Sendable {
    public let id: String
    public let provider: any EmbeddingProviding

    public init(id: String, provider: any EmbeddingProviding) {
        self.id = id
        self.provider = provider
    }

    /// Apple's on-device English sentence embedding, or `nil` when the
    /// device has none. Nothing leaves the device.
    #if canImport(NaturalLanguage)
    public static func appleSentence() -> EmbeddingModel? {
        let provider = NLEmbeddingProvider(language: .english)
        guard provider.dimension > 0 else { return nil }
        let revision = NLEmbedding.currentSentenceEmbeddingRevision(for: .english)
        return EmbeddingModel(id: "apple-nl-sentence-en-r\(revision)", provider: provider)
    }
    #endif
}

/// Chunk vectors are stored as raw little-endian Float32 bytes (PLAN §5.2),
/// not JSON.
public enum VectorCoding {
    public static func data(from vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// Empty when `data` isn't a whole number of floats.
    public static func vector(from data: Data) -> [Float] {
        let stride = MemoryLayout<Float>.stride
        guard !data.isEmpty, data.count % stride == 0 else { return [] }
        var vector = [Float](repeating: 0, count: data.count / stride)
        _ = vector.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return vector
    }

    /// The element-wise mean, or `nil` for no vectors or mismatched lengths.
    public static func mean(_ vectors: [[Float]]) -> [Float]? {
        guard let first = vectors.first, !first.isEmpty,
              vectors.allSatisfy({ $0.count == first.count }) else { return nil }
        var sum = [Float](repeating: 0, count: first.count)
        for vector in vectors {
            for index in vector.indices { sum[index] += vector[index] }
        }
        let count = Float(vectors.count)
        return sum.map { $0 / count }
    }
}
