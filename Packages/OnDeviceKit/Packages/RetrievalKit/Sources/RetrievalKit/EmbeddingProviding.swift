import Foundation

/// The seam over text→vector embedding. Everything downstream (`VectorIndex`,
/// `Retriever`) depends only on this protocol, so the default on-device
/// `NLEmbeddingProvider` can be swapped for a GGUF embedding model (via
/// `LocalLLMKit`) or a BYOK embeddings API without touching retrieval logic.
///
/// > Important: a cloud-backed conformance sends the *entire indexed corpus*
/// > to that provider, not just one chat turn — a materially bigger exposure
/// > than a single message. Prefer the on-device default for personal data.
public protocol EmbeddingProviding: Sendable {
    /// Fixed dimensionality of vectors this provider returns.
    var dimension: Int { get }
    /// Embeds `text`, or `nil` if it can't be (empty text, or — for a
    /// lookup-based embedder — no vocabulary overlap at all).
    func embed(_ text: String) async -> [Float]?
    /// Batch form. The default implementation just calls `embed(_:)`
    /// sequentially; providers with a real batch API should override this.
    func embed(batch texts: [String]) async -> [[Float]?]
}

public extension EmbeddingProviding {
    func embed(batch texts: [String]) async -> [[Float]?] {
        var results: [[Float]?] = []
        results.reserveCapacity(texts.count)
        for text in texts {
            results.append(await embed(text))
        }
        return results
    }
}
