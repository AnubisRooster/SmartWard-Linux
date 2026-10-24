import Foundation
import Pipeline

/// How an article is read: who reads it, how fast, and how much of it.
public struct ReadingProfile: Codable, Equatable, Sendable {
    public enum Scope: String, Codable, CaseIterable, Sendable {
        /// Title, details, summary and the full text.
        case whole
        /// Title and the five-question summary only.
        case summary

        public var readoutScope: ReadoutScope { self == .whole ? .whole : .summaryOnly }
    }

    public var voice: String
    public var speed: Double
    public var scope: Scope

    public init(voice: String = SpeechClient.defaultVoice, speed: Double = 1.0, scope: Scope = .whole) {
        self.voice = voice
        self.speed = speed
        self.scope = scope
    }
}

/// Everything the Settings page and the command line share, stored in
/// `$XDG_CONFIG_HOME/smartward/config.json`.
public struct AppSettings: Codable, Equatable, Sendable {
    public var speechURL: String
    public var ollamaURL: String
    public var chatModel: String
    public var embeddingModel: String
    /// The reading voice used when no profile is chosen.
    public var voice: String
    public var speed: Double
    public var profiles: [String: ReadingProfile]
    /// A profile in `profiles` used by `smartward read` unless told otherwise.
    public var activeProfile: String?

    public static let speedRange: ClosedRange<Double> = 0.5...2.0
    public static let maxProfiles = 24

    public init(speechURL: String = SpeechClient.defaultBaseURL.absoluteString,
                ollamaURL: String = OllamaClient.defaultBaseURL.absoluteString,
                chatModel: String = LocalModelConfig.recommendedChatModel,
                embeddingModel: String = LocalModelConfig.recommendedEmbeddingModel,
                voice: String = SpeechClient.defaultVoice, speed: Double = 1.0,
                profiles: [String: ReadingProfile] = [:], activeProfile: String? = nil) {
        self.speechURL = speechURL
        self.ollamaURL = ollamaURL
        self.chatModel = chatModel
        self.embeddingModel = embeddingModel
        self.voice = voice
        self.speed = speed
        self.profiles = profiles
        self.activeProfile = activeProfile
    }

    // A missing key (a file written by an older version) keeps its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        speechURL = try c.decodeIfPresent(String.self, forKey: .speechURL) ?? d.speechURL
        ollamaURL = try c.decodeIfPresent(String.self, forKey: .ollamaURL) ?? d.ollamaURL
        chatModel = try c.decodeIfPresent(String.self, forKey: .chatModel) ?? d.chatModel
        embeddingModel = try c.decodeIfPresent(String.self, forKey: .embeddingModel) ?? d.embeddingModel
        voice = try c.decodeIfPresent(String.self, forKey: .voice) ?? d.voice
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? d.speed
        profiles = try c.decodeIfPresent([String: ReadingProfile].self, forKey: .profiles) ?? [:]
        activeProfile = try c.decodeIfPresent(String.self, forKey: .activeProfile)
    }

    /// Who reads, for `profile` (the active one when `nil`, else the saved default voice).
    public func reading(profile name: String? = nil) throws -> ReadingProfile {
        if let name = name ?? activeProfile {
            guard let profile = profiles[name] else { throw SettingsError.unknownProfile(name) }
            return profile
        }
        return ReadingProfile(voice: voice, speed: speed, scope: .whole)
    }

    public var models: LocalModelConfig {
        LocalModelConfig(baseURL: URL(string: ollamaURL) ?? OllamaClient.defaultBaseURL,
                         chatModel: chatModel, embeddingModel: embeddingModel)
    }

    /// Throws `SettingsError.invalid` for anything that shouldn't be saved.
    public func validated() throws -> AppSettings {
        var problems: [String] = []
        func check(_ voice: String, _ label: String) {
            if !Self.isVoiceName(voice) { problems.append("\(label): \"\(voice)\" isn't a voice name like af_heart.") }
        }
        func checkSpeed(_ speed: Double, _ label: String) {
            if !Self.speedRange.contains(speed) {
                problems.append("\(label): speed must be between \(Self.speedRange.lowerBound) and \(Self.speedRange.upperBound).")
            }
        }
        check(voice, "Voice")
        checkSpeed(speed, "Voice")
        if let url = URL(string: speechURL), (try? SpeechClient(baseURL: url)) != nil {} else {
            problems.append("Speech server: use an address on this machine, like http://127.0.0.1:8880.")
        }
        if let url = URL(string: ollamaURL), (try? OllamaClient(baseURL: url)) != nil {} else {
            problems.append("Ollama: use an address on this machine, like http://127.0.0.1:11434.")
        }
        for (label, value) in [("Chat model", chatModel), ("Embedding model", embeddingModel)]
        where value.trimmingCharacters(in: .whitespaces).isEmpty || value.count > 120 {
            problems.append("\(label) can't be empty.")
        }
        if profiles.count > Self.maxProfiles { problems.append("At most \(Self.maxProfiles) profiles.") }
        for (name, profile) in profiles {
            if name.trimmingCharacters(in: .whitespaces).isEmpty || name.count > 40
                || name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                problems.append("Profile names are 1–40 characters.")
            }
            check(profile.voice, "Profile \"\(name)\"")
            checkSpeed(profile.speed, "Profile \"\(name)\"")
        }
        if let active = activeProfile, profiles[active] == nil {
            problems.append("The default profile \"\(active)\" doesn't exist.")
        }
        guard problems.isEmpty else { throw SettingsError.invalid(problems) }
        return self
    }

    /// `af_heart`, `bm_george`: two letters for accent and gender, an underscore, a name.
    public static func isVoiceName(_ name: String) -> Bool {
        let parts = name.split(separator: "_", maxSplits: 1)
        guard parts.count == 2, parts[0].count == 2, name.count <= 40 else { return false }
        return name.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }
    }
}

public enum SettingsError: LocalizedError, Equatable {
    case invalid([String])
    case unknownProfile(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let problems): return problems.joined(separator: "\n")
        case .unknownProfile(let name): return "There's no profile called \"\(name)\"."
        }
    }
}

public struct SettingsStore: Sendable {
    public let url: URL

    public init(url: URL = SettingsStore.defaultURL) { self.url = url }

    public static var defaultURL: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        return base.appendingPathComponent("smartward/config.json")
    }

    /// The saved settings, or the defaults when there is no file yet.
    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppSettings() }
        return try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
    }

    public func save(_ settings: AppSettings) throws {
        let valid = try settings.validated()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(valid).write(to: url, options: .atomic)
    }
}
