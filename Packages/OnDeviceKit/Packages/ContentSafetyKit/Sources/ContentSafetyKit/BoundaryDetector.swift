import Foundation

/// Which boundary rule set applies to a reply. `standard` is appropriate for
/// any assistant that must avoid diagnostic/prescriptive language.
/// `spiritualGuidance` relaxes the rules that would otherwise block
/// legitimate faith/practice discussion (prayer, meaning-making) while still
/// blocking proselytising and condemnation.
public enum BoundaryContext: Sendable {
    case standard
    case spiritualGuidance
}

/// Checks whether an assistant's reply crosses a boundary it shouldn't —
/// diagnosing, prescribing, or (in `spiritualGuidance` contexts) proselytising
/// or condemning.
public struct BoundaryDetector: Sendable {

    public init() {}

    // These patterns are always disallowed, regardless of context.
    private let universalBlocked = [
        "i diagnose you",
        "you are diagnosed",
        "your diagnosis is",
        "i prescribe",
        "you need medication",
        "i recommend you take",
        "start taking",
        "stop taking your",
    ]

    // Blocked only outside spiritualGuidance contexts.
    private let clinicalExtras = [
        "god is telling you",
        "you must convert",
        "your religion is wrong",
        "only my faith",
        "you will go to hell",
        "you are a sinner",
    ]

    // Blocked specifically within spiritualGuidance contexts: proselytising
    // and condemnation, while guidance about practice/prayer/meaning stays allowed.
    private let spiritualBlocked = [
        "you must convert",
        "your religion is wrong",
        "only my faith",
        "you will go to hell",
        "you are a sinner",
        "your beliefs are false",
    ]

    public func check(_ text: String, context: BoundaryContext = .standard) -> (isViolation: Bool, pattern: String?) {
        let lower = text.lowercased()

        for pattern in universalBlocked {
            if lower.contains(pattern) {
                return (true, pattern)
            }
        }

        if context != .spiritualGuidance {
            for pattern in clinicalExtras {
                if lower.contains(pattern) {
                    return (true, pattern)
                }
            }
        }

        if context == .spiritualGuidance {
            for pattern in spiritualBlocked {
                if lower.contains(pattern) {
                    return (true, pattern)
                }
            }
        }

        return (false, nil)
    }
}
