import Foundation

/// A set of keyword/phrase patterns that indicate a given severity of
/// distress when found in user-authored text.
public struct CrisisPattern: Sendable {
    public let patterns: [String]
    public let level: String

    public init(patterns: [String], level: String) {
        self.patterns = patterns
        self.level = level
    }
}

/// Keyword-based crisis detection: scans text for phrases that indicate
/// self-harm, suicidal ideation, or acute distress, erring toward caution
/// (a keyword match flags even when negated — false positives are far
/// cheaper than a missed crisis signal).
public struct CrisisDetector: Sendable {
    public let patterns: [CrisisPattern]

    /// A conservative default word list covering suicidal ideation,
    /// self-harm, and acute hopelessness. Host apps can pass their own
    /// `patterns` instead, or append to these via `CrisisDetector.defaultPatterns`.
    public static let defaultPatterns: [CrisisPattern] = [
        CrisisPattern(patterns: ["kill myself", "end my life", "want to die", "better off dead",
                                 "suicide", "self-harm", "hurt myself", "cutting", "suicidal"],
                     level: "critical"),
        CrisisPattern(patterns: ["don't want to be here", "can't go on", "no reason to live",
                                 "worthless", "hopeless"],
                     level: "warning"),
    ]

    public init(patterns: [CrisisPattern] = CrisisDetector.defaultPatterns) {
        self.patterns = patterns
    }

    /// Scans `message` for the first matching pattern, checked in the order
    /// `patterns` was given (so put higher-severity levels first).
    public func check(_ message: String) -> (isCrisis: Bool, level: String, pattern: String?) {
        let lower = message.lowercased()
        for cp in patterns {
            for pattern in cp.patterns {
                if lower.contains(pattern) {
                    return (true, cp.level, pattern)
                }
            }
        }
        return (false, "", nil)
    }
}
