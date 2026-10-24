import Foundation
import KnowledgeStore

/// One thing said aloud while an article is read to you: its title, its
/// details, one of the summary's answers, a paragraph of the text.
public struct ReadoutSegment: Equatable, Sendable, Identifiable {
    /// Where on the reader screen this is, so the screen can follow along.
    public enum Anchor: Hashable, Sendable {
        case title, details, summary, themes, relevance
        case paragraph(Int)
        case note
    }

    public let id: Int
    public let anchor: Anchor
    /// Ready to speak: cleaned of markdown, links and code.
    public let text: String
    /// Which item of a briefing this belongs to (an article, a digest theme),
    /// so "next article" can jump over the rest of it. A single article's
    /// read-aloud is all group 0.
    public var group = 0
}

public enum ReadoutScope: Equatable, Sendable {
    /// Everything on the reader screen, top to bottom.
    case whole
    /// The title and the five-question summary.
    case summaryOnly
}

/// What "read this article to me" says, in the order the reader screen shows
/// it: title, source and date, the five-question summary, themes, relevance,
/// then the text a paragraph at a time. Pure, so tests cover it; playing it
/// is the app's job.
@MainActor
public enum ArticleReadout {
    /// A paragraph longer than this is said in pieces cut at sentence ends,
    /// so pausing, skipping and going back stay useful in a long block.
    public static let maxSegmentLength = 600
    public static let maxThemes = 8

    /// The paragraphs the reader shows: the saved text (or, without it, the
    /// teaser) split at blank lines. The reader and the readout share this so
    /// a segment's paragraph number is the paragraph on screen.
    public static func paragraphs(of article: Article) -> [String] {
        let text = article.cleanedText.isEmpty ? article.summary : article.cleanedText
        return text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    /// The themes found in the article, in the order they first appear.
    public static func themeLabels(of article: Article) -> [String] {
        var seen = Set<UUID>()
        var labels: [String] = []
        for chunk in (article.chunks ?? []).sorted(by: { $0.ordinal < $1.ordinal }) {
            for mention in chunk.mentions ?? [] {
                guard let node = mention.node, seen.insert(node.id).inserted else { continue }
                labels.append(node.canonicalLabel)
            }
        }
        return labels
    }

    /// - Parameters:
    ///   - sourceName: how the reader labels the source; the source's own
    ///     title when `nil`.
    ///   - clean: what the speech engine does to text before speaking it
    ///     (VoiceLoopKit's `SpeechService.speakableText`).
    public static func segments(for article: Article, scope: ReadoutScope = .whole,
                                sourceName: String? = nil,
                                clean: @escaping (String) -> String = { $0 },
                                locale: Locale = .current, timeZone: TimeZone = .current) -> [ReadoutSegment] {
        var builder = Builder(clean: clean)
        builder.add(.title, article.title)

        if scope == .whole {
            builder.add(.details, details(of: article, sourceName: sourceName, locale: locale, timeZone: timeZone))
        }

        let summaryBits = summary(of: article)
        if summaryBits.isEmpty {
            if scope == .summaryOnly { builder.add(.note, "There isn't a summary for this article yet.") }
        } else {
            for (index, bit) in summaryBits.enumerated() {
                builder.add(.summary, index == 0 ? "Summary. \(bit)" : bit)
            }
        }
        guard scope == .whole else { return builder.segments }

        let themes = themeLabels(of: article).prefix(maxThemes)
        if !themes.isEmpty { builder.add(.themes, "Themes: " + themes.joined(separator: ", ") + ".") }

        if let percent = Triage.displayPercent(for: article) {
            var text = "Relevance \(percent) percent."
            let reason = article.relevanceReason.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reason.isEmpty { text += " " + (reason.last.map { ".!?".contains($0) } == true ? reason : reason + ".") }
            builder.add(.relevance, text)
        }

        let body = paragraphs(of: article)
        if body.isEmpty && article.stage != .fetched {
            builder.add(.note, "Only the headline was saved for this item.")
        }
        for (index, paragraph) in body.enumerated() {
            for piece in pieces(of: paragraph) { builder.add(.paragraph(index), piece) }
        }
        return builder.segments
    }

    // MARK: Parts

    private static func details(of article: Article, sourceName: String?, locale: Locale, timeZone: TimeZone) -> String {
        var parts: [String] = []
        let source = (sourceName ?? article.source?.title)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !source.isEmpty { parts.append("From \(source).") }
        if let byline = article.byline?.trimmingCharacters(in: .whitespacesAndNewlines), !byline.isEmpty {
            parts.append("By \(byline).")
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        parts.append("Published \(formatter.string(from: article.publishedAt ?? article.ingestedAt)).")
        return parts.joined(separator: " ")
    }

    /// One piece per question that has an answer, each the question and its
    /// bullets as sentences.
    private static func summary(of article: Article) -> [String] {
        guard let summary = ArticleSummarizer.cached(for: article) else { return [] }
        return ArticleSummary.Question.allCases.compactMap { question in
            let bullets = summary.bullets(for: question).map(sentence)
            return bullets.isEmpty ? nil : ([question.title] + bullets).joined(separator: " ")
        }
    }

    /// `text` ending in sentence punctuation, so the voice pauses between bullets.
    private static func sentence(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".!?".contains(last) ? text : text + "."
    }

    /// `paragraph` in pieces of at most `maxSegmentLength`, cut between
    /// sentences (a single longer sentence stays whole).
    static func pieces(of paragraph: String) -> [String] {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxSegmentLength else { return trimmed.isEmpty ? [] : [trimmed] }
        let sentences = trimmed.sentenceList
        var result: [String] = []
        var current = ""
        for sentence in sentences {
            let next = current.isEmpty ? sentence : current + " " + sentence
            if next.count > maxSegmentLength, !current.isEmpty {
                result.append(current)
                current = sentence
            } else {
                current = next
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Cleans each piece and numbers the ones that survive.
    private struct Builder {
        let clean: (String) -> String
        var segments: [ReadoutSegment] = []

        init(clean: @escaping (String) -> String) { self.clean = clean }

        mutating func add(_ anchor: ReadoutSegment.Anchor, _ text: String) {
            let spoken = clean(text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !spoken.isEmpty else { return }
            segments.append(ReadoutSegment(id: segments.count, anchor: anchor, text: spoken))
        }
    }
}

/// Where a read-aloud is: which segment is being said, and whether it's
/// playing, paused or over. The audio follows this; nothing here touches it.
///
/// Skipping while paused starts playing again: pressing next or previous
/// means you want to hear it.
public struct ReadoutPlayback: Equatable, Sendable {
    public enum Status: Equatable, Sendable { case idle, playing, paused, finished }

    public private(set) var segments: [ReadoutSegment] = []
    public private(set) var index = 0
    public private(set) var status = Status.idle

    public init() {}

    public var current: ReadoutSegment? {
        status == .playing || status == .paused ? segments[safe: index] : nil
    }

    /// Playing or paused: there's a read-aloud to control.
    public var isActive: Bool { status == .playing || status == .paused }

    /// "3 of 12", for a status line.
    public var position: (number: Int, count: Int) { (min(index + 1, segments.count), segments.count) }

    public mutating func start(_ segments: [ReadoutSegment]) {
        self.segments = segments
        index = 0
        status = segments.isEmpty ? .finished : .playing
    }

    public mutating func pause() {
        if status == .playing { status = .paused }
    }

    public mutating func resume() {
        if status == .paused { status = .playing }
    }

    public mutating func stop() {
        segments = []
        index = 0
        status = .idle
    }

    /// The current segment has been said in full.
    public mutating func segmentFinished() {
        guard status == .playing else { return }
        advance()
    }

    public mutating func next() {
        guard isActive else { return }
        advance()
    }

    /// Back to the start of the previous segment; from the first, its own start.
    public mutating func previous() {
        guard isActive else { return }
        index = max(0, index - 1)
        status = .playing
    }

    private mutating func advance() {
        if index + 1 < segments.count {
            index += 1
            status = .playing
        } else {
            status = .finished
        }
    }
}

// MARK: Groups

extension ReadoutPlayback {
    /// The briefing item being read.
    public var currentGroup: Int? { current?.group }

    /// "Article 3 of 12", by group.
    public var groupPosition: (number: Int, count: Int)? {
        guard let group = currentGroup else { return nil }
        let groups = segments.map(\.group).reduce(into: [Int]()) { if $1 != $0.last { $0.append($1) } }
        guard let place = groups.firstIndex(of: group) else { return nil }
        return (place + 1, groups.count)
    }

    /// Jumps to the start of the next item; from the last one it ends.
    public mutating func nextGroup() {
        guard isActive, let group = currentGroup else { return }
        if let start = segments[(index + 1)...].firstIndex(where: { $0.group != group }) {
            index = start
            status = .playing
        } else {
            status = .finished
        }
    }

    /// Jumps to the start of the previous item; from the first, to its own start.
    public mutating func previousGroup() {
        guard isActive, let group = currentGroup else { return }
        let start = firstIndex(ofGroup: group)
        index = start > 0 ? firstIndex(ofGroup: segments[start - 1].group) : start
        status = .playing
    }

    /// Back to the start of the item being read.
    public mutating func restartGroup() {
        guard isActive, let group = currentGroup else { return }
        index = firstIndex(ofGroup: group)
        status = .playing
    }

    /// Swaps what's said for the current item (the gist, say) for something
    /// else (the whole article), and starts it from the top.
    public mutating func replaceCurrentGroup(with replacement: [ReadoutSegment]) {
        guard isActive, let group = currentGroup, !replacement.isEmpty else { return }
        let members = segments.indices.filter { segments[$0].group == group }
        guard let first = members.first, let last = members.last else { return }
        var updated = Array(segments[..<first])
        updated += replacement.map { ReadoutSegment(id: 0, anchor: $0.anchor, text: $0.text, group: group) }
        updated += Array(segments[(last + 1)...])
        segments = updated.enumerated().map { ReadoutSegment(id: $0.offset, anchor: $0.element.anchor, text: $0.element.text, group: $0.element.group) }
        index = first
        status = .playing
    }

    private func firstIndex(ofGroup group: Int) -> Int {
        segments.firstIndex { $0.group == group } ?? 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
