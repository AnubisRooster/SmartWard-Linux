import Foundation

/// A pluggable token-count estimate, used by `ContextAssembler` to respect a
/// prompt budget without depending on any specific model's tokenizer.
public protocol TokenEstimating: Sendable {
    func estimate(_ text: String) -> Int
}

/// A fast, model-agnostic heuristic — roughly 4 characters per token, a
/// reasonable average across English text and most BPE-style tokenizers.
/// Deliberately approximate: exact tokenization would require depending on
/// one specific model's tokenizer, which this module has no reason to pull in.
public struct HeuristicTokenEstimator: TokenEstimating {
    public init() {}
    public func estimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }
}
