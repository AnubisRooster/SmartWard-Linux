import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Splits a document into overlapping, sentence-aligned chunks sized for
/// embedding + retrieval. Sentence boundaries come from `NLTokenizer` rather
/// than naive punctuation-splitting, so chunks never cut mid-sentence on
/// edge cases like "Dr. Smith" or "3.14".
public struct Chunker: Sendable {
    /// Target chunk size, in characters — a coarse proxy for tokens (see
    /// `HeuristicTokenEstimator`, which uses the same ~4-chars-per-token rule
    /// at the prompt-assembly end).
    public let targetSize: Int
    /// How many trailing sentences from a chunk are repeated at the start of
    /// the next one, so retrieval doesn't lose context right at a chunk
    /// boundary (e.g. a pronoun whose referent is the sentence before it).
    public let overlapSentences: Int

    public init(targetSize: Int = 800, overlapSentences: Int = 1) {
        self.targetSize = targetSize
        self.overlapSentences = overlapSentences
    }

    public func chunk(_ document: Document) -> [Chunk] {
        let sentences = Self.sentences(in: document.text)
        guard !sentences.isEmpty else { return [] }

        var chunks: [Chunk] = []
        var current: [String] = []
        var currentLength = 0
        var index = 0

        func flush() {
            guard !current.isEmpty else { return }
            chunks.append(Chunk(id: "\(document.id)#\(index)",
                                documentID: document.id,
                                text: current.joined(separator: " "),
                                metadata: document.metadata))
            index += 1
        }

        for sentence in sentences {
            if currentLength + sentence.count > targetSize, !current.isEmpty {
                flush()
                current = Array(current.suffix(overlapSentences))
                currentLength = current.reduce(0) { $0 + $1.count }
            }
            current.append(sentence)
            currentLength += sentence.count
        }
        flush()
        return chunks
    }

    static func sentences(in text: String) -> [String] {
        #if !canImport(NaturalLanguage)
        // swift-corelibs-foundation can't enumerate by sentence: split after
        // terminal punctuation followed by whitespace, and at blank lines.
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        func flush() {
            let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            current = ""
        }
        while i < chars.count {
            let c = chars[i]
            current.append(c)
            let next = i + 1 < chars.count ? chars[i + 1] : nil
            if ".!?".contains(c), next == nil || next!.isWhitespace {
                flush()
            } else if c == "\n", next == "\n" {
                flush()
            }
            i += 1
        }
        flush()
        return result
        #else
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            return true
        }
        return result
        #endif
    }
}
