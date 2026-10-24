import Foundation

extension String {
    /// Sentences in order, trimmed. Apple platforms use Foundation's
    /// linguistic splitter; swift-corelibs-foundation doesn't support
    /// `.bySentences`, so Linux splits after `.`, `!` or `?` followed by
    /// whitespace, and at blank lines. Rougher (abbreviations like "e.g."
    /// split), which is fine for chunking and read-aloud pacing.
    var sentenceList: [String] {
        var result: [String] = []
        #if canImport(Darwin)
        enumerateSubstrings(in: startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                result.append(sentence)
            }
        }
        #else
        var current = ""
        let characters = Array(self)
        for (index, character) in characters.enumerated() {
            current.append(character)
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            let endsSentence = ".!?".contains(character) && (next == nil || next!.isWhitespace)
            let blankLine = character == "\n" && next == "\n"
            if endsSentence || blankLine {
                let sentence = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { result.append(sentence) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        #endif
        return result
    }
}
