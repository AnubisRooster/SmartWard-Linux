import Foundation

/// A way of reading articles aloud on iPhone: which system voice, how fast,
/// and how much (the whole article or just its summary). Pure and stored as
/// JSON in `UserDefaults`, so the Settings screens and the read-aloud
/// controller agree and tests cover the rules.
public struct ReadAloudProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// An `AVSpeechSynthesisVoice` identifier; empty means the best English
    /// voice installed.
    public var voiceID: String
    /// `AVSpeechUtterance.rate`, 0.3 to 0.7 here.
    public var rate: Double
    /// Read only the title and the five-question summary.
    public var summaryOnly: Bool

    public init(id: UUID = UUID(), name: String, voiceID: String = "", rate: Double = 0.5, summaryOnly: Bool = false) {
        self.id = id
        self.name = name
        self.voiceID = voiceID
        self.rate = rate
        self.summaryOnly = summaryOnly
    }
}

public struct ReadAloudProfiles: Codable, Equatable, Sendable {
    public static let rateRange: ClosedRange<Double> = 0.3...0.7
    public static let maxProfiles = 12
    public static let maxNameLength = 40

    public private(set) var profiles: [ReadAloudProfile]
    /// The profile used when reading an article; `nil` uses the voice and
    /// rate under Settings → Voice conversation.
    public var activeID: UUID?

    public init(profiles: [ReadAloudProfile] = [], activeID: UUID? = nil) {
        self.profiles = profiles.prefix(Self.maxProfiles).map(Self.cleaned)
        self.activeID = activeID.flatMap { id in profiles.contains { $0.id == id } ? id : nil }
    }

    public var active: ReadAloudProfile? { profiles.first { $0.id == activeID } }

    /// Adds `profile`, or replaces the one with the same id.
    /// - Returns: `false` when it's new and there are already `maxProfiles`.
    @discardableResult
    public mutating func upsert(_ profile: ReadAloudProfile) -> Bool {
        let cleaned = Self.cleaned(profile)
        if let index = profiles.firstIndex(where: { $0.id == cleaned.id }) {
            profiles[index] = cleaned
            return true
        }
        guard profiles.count < Self.maxProfiles else { return false }
        profiles.append(cleaned)
        return true
    }

    public mutating func remove(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeID == id { activeID = nil }
    }

    /// A name that isn't already used, for a new profile.
    public func newName(base: String = "Profile") -> String {
        let used = Set(profiles.map(\.name))
        var number = profiles.count + 1
        while used.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    private static func cleaned(_ profile: ReadAloudProfile) -> ReadAloudProfile {
        var result = profile
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.name = String((trimmed.isEmpty ? "Profile" : trimmed).prefix(maxNameLength))
        result.rate = min(max(profile.rate.isFinite ? profile.rate : 0.5, rateRange.lowerBound), rateRange.upperBound)
        return result
    }

    // MARK: Storage

    public func encoded() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    /// The saved profiles, or none when `json` is empty or unreadable.
    public static func decode(_ json: String) -> ReadAloudProfiles {
        guard let data = json.data(using: .utf8), !data.isEmpty,
              let decoded = try? JSONDecoder().decode(ReadAloudProfiles.self, from: data) else { return ReadAloudProfiles() }
        return ReadAloudProfiles(profiles: decoded.profiles, activeID: decoded.activeID)
    }
}
