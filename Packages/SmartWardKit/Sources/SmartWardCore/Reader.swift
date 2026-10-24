import Foundation
import KnowledgeStore
import Pipeline
import SwiftData

/// Plays one WAV recording to the end.
public protocol AudioPlaying: Sendable {
    func play(_ wav: Data) async throws
}

/// Plays through whichever command-line player is installed (PipeWire,
/// PulseAudio, ALSA, ffplay or mpv). Cancelling the task stops the sound.
public struct CommandAudioPlayer: AudioPlaying {
    public let executable: URL
    public let arguments: [String]

    public init(executable: URL, arguments: [String] = []) {
        self.executable = executable
        self.arguments = arguments
    }

    static let candidates: [(name: String, arguments: [String])] = [
        ("pw-play", []), ("paplay", []), ("aplay", ["-q"]),
        ("ffplay", ["-nodisp", "-autoexit", "-loglevel", "quiet"]), ("mpv", ["--no-video", "--really-quiet"]),
    ]

    public static func detect(searchPath: String? = nil) -> CommandAudioPlayer? {
        let path = searchPath ?? ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        for (name, arguments) in candidates {
            for directory in path.split(separator: ":") {
                let url = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: url.path) {
                    return CommandAudioPlayer(executable: url, arguments: arguments)
                }
            }
        }
        return nil
    }

    public var name: String { executable.lastPathComponent }

    public func play(_ wav: Data) async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("smartward-\(UUID().uuidString).wav")
        try wav.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments + [file.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in continuation.resume() }
                do { try process.run() } catch { continuation.resume(throwing: error) }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}

extension SmartWardEngine {
    public struct ReadResult: Sendable {
        public var title: String
        public var segments: Int
        /// The whole reading as one WAV, when it was asked for.
        public var audio: Data?
    }

    public enum ReadError: LocalizedError {
        case noArticle(String)
        case nothingToRead

        public var errorDescription: String? {
            switch self {
            case .noArticle(let query):
                return query.isEmpty ? "The library has no articles yet." : "Nothing in the library matches \"\(query)\"."
            case .nothingToRead:
                return "That article has no text to read."
            }
        }
    }

    /// Reads an article aloud with a local voice. `query` picks the best
    /// search match; empty means the newest article. The next piece is
    /// synthesized while the current one plays, so there's no gap between them.
    public func read(_ query: String, scope: ReadoutScope = .whole, speech: SpeechClient,
                     player: (any AudioPlaying)?, keepAudio: Bool = false,
                     progress: ((_ number: Int, _ count: Int, _ text: String) -> Void)? = nil) async throws -> ReadResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let article: Article
        if trimmed.isEmpty {
            var latest = FetchDescriptor<Article>(sortBy: [SortDescriptor(\.ingestedAt, order: .reverse)])
            latest.fetchLimit = 1
            guard let newest = try context.fetch(latest).first else { throw ReadError.noArticle("") }
            article = newest
        } else {
            guard let hit = try await search(trimmed, limit: 1).first else { throw ReadError.noArticle(trimmed) }
            let id = hit.articleID
            guard let found = try context.fetch(FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })).first else {
                throw ReadError.noArticle(trimmed)
            }
            article = found
        }

        let texts = ArticleReadout.segments(for: article, scope: scope).map(\.text).filter { !$0.isEmpty }
        guard !texts.isEmpty else { throw ReadError.nothingToRead }

        var pending: Task<Data, Error>? = Task { try await speech.synthesize(texts[0]) }
        defer { pending?.cancel() }
        var pieces: [Data] = []
        for index in texts.indices {
            let audio = try await pending!.value
            pending = index + 1 < texts.count ? Task { [text = texts[index + 1]] in try await speech.synthesize(text) } : nil
            if keepAudio { pieces.append(audio) }
            progress?(index + 1, texts.count, texts[index])
            try await player?.play(audio)
        }
        return ReadResult(title: article.title, segments: texts.count,
                          audio: keepAudio ? WAV.concatenate(pieces) : nil)
    }
}
