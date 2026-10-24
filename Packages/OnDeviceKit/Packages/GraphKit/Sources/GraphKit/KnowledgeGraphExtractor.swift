import Foundation

/// A node implied by a message, not yet persisted anywhere.
public struct NodeSpec: Sendable, Equatable {
    public let type: String
    public let label: String
    public let properties: [String: String]

    public init(type: String, label: String, properties: [String: String] = [:]) {
        self.type = type
        self.label = label
        self.properties = properties
    }
}

/// An edge implied by a message, referencing nodes by label (not yet resolved
/// to persisted IDs).
public struct EdgeSpec: Sendable, Equatable {
    public let sourceLabel: String
    public let targetLabel: String
    public let type: String

    public init(sourceLabel: String, targetLabel: String, type: String) {
        self.sourceLabel = sourceLabel
        self.targetLabel = targetLabel
        self.type = type
    }
}

/// The nodes and edges implied by a single message.
public struct Extraction: Sendable, Equatable {
    public let nodes: [NodeSpec]
    public let edges: [EdgeSpec]
}

/// Heuristic keyword/pattern extraction of emotions, people, and belief
/// statements from free text, with edges wired between co-occurring entities.
/// Pure — performs no persistence, so the same extraction logic can back a
/// live pipeline and a one-time backfill and always agree.
public struct KnowledgeGraphExtractor: Sendable {

    public init() {}

    private let emotionWords = [
        "angry", "anger", "sad", "sadness", "happy", "anxious", "anxiety",
        "fearful", "fear", "guilty", "guilt", "ashamed", "shame", "hopeful",
        "lonely", "loneliness", "frustrated", "frustration", "overwhelmed",
        "hopeless", "jealous", "jealousy", "grief", "hurt", "betrayed",
        "confused", "numb", "empty", "worthless", "helpless",
    ]

    private let personPatterns: [(pattern: String, label: String)] = [
        ("my mother", "Mother"), ("my mom", "Mother"),
        ("my father", "Father"), ("my dad", "Father"),
        ("my sister", "Sister"), ("my brother", "Brother"),
        ("my partner", "Partner"), ("my husband", "Husband"),
        ("my wife", "Wife"), ("my friend", "Friend"),
        ("my boss", "Boss"), ("my therapist", "Previous therapist"),
        ("my child", "Child"), ("my daughter", "Daughter"),
        ("my son", "Son"), ("my colleague", "Colleague"),
        ("my ex", "Ex-partner"),
    ]

    private let beliefPatterns = [
        "i believe", "i think that", "i feel that", "i always", "i never",
        "i should", "i must", "i can't", "i have to", "i am worthless",
        "i am not good enough", "i am a failure", "i don't deserve",
        "nobody cares", "i am broken", "i will never",
    ]

    /// Analyzes a message and returns the entities + edges it implies.
    public func analyze(_ message: String) -> Extraction {
        let lower = message.lowercased()

        var emotions: [NodeSpec] = []
        var persons:  [NodeSpec] = []
        var beliefs:  [NodeSpec] = []

        for word in emotionWords where lower.contains(word) {
            emotions.append(NodeSpec(type: "emotion", label: word.capitalized,
                                     properties: ["source": "message"]))
        }

        for item in personPatterns where lower.contains(item.pattern) {
            persons.append(NodeSpec(type: "person", label: item.label,
                                    properties: ["relation": item.pattern]))
        }

        for pattern in beliefPatterns where lower.contains(pattern) {
            let parts = lower.components(separatedBy: pattern)
            if parts.count > 1 {
                let tail = parts[1].trimmingCharacters(in: .whitespacesAndNewlines
                    .union(.punctuationCharacters)).prefix(50)
                let label = tail.isEmpty ? pattern : "\(pattern) \(tail)"
                beliefs.append(NodeSpec(type: "belief", label: String(label),
                                        properties: ["pattern": pattern]))
            }
        }

        // De-duplicate within a single message (same label twice → once)
        emotions = dedupe(emotions)
        persons  = dedupe(persons)
        beliefs  = dedupe(beliefs)

        var edges: [EdgeSpec] = []

        // person → TRIGGERS → emotion
        for person in persons {
            for emotion in emotions {
                edges.append(EdgeSpec(sourceLabel: person.label,
                                      targetLabel: emotion.label, type: "TRIGGERS"))
            }
        }
        // emotion → CAUSES → belief
        for emotion in emotions {
            for belief in beliefs {
                edges.append(EdgeSpec(sourceLabel: emotion.label,
                                      targetLabel: belief.label, type: "CAUSES"))
            }
        }
        // belief → ASSOCIATED_WITH → emotion
        for belief in beliefs {
            for emotion in emotions {
                edges.append(EdgeSpec(sourceLabel: belief.label,
                                      targetLabel: emotion.label, type: "ASSOCIATED_WITH"))
            }
        }
        // emotion → ASSOCIATED_WITH → emotion (co-occurring)
        if emotions.count > 1 {
            for i in 0..<emotions.count {
                for j in (i + 1)..<emotions.count {
                    edges.append(EdgeSpec(sourceLabel: emotions[i].label,
                                          targetLabel: emotions[j].label,
                                          type: "ASSOCIATED_WITH"))
                }
            }
        }

        return Extraction(nodes: emotions + persons + beliefs, edges: edges)
    }

    private func dedupe(_ specs: [NodeSpec]) -> [NodeSpec] {
        var seen = Set<String>()
        var out: [NodeSpec] = []
        for s in specs where !seen.contains(s.label) {
            seen.insert(s.label)
            out.append(s)
        }
        return out
    }
}

// MARK: - Display helpers

public enum GraphDisplay {
    /// Hex colour for a knowledge-graph node type.
    public static func nodeColorHex(_ type: String) -> String {
        switch type {
        case "person":  return "#4A90D9"
        case "event":   return "#F5A623"
        case "emotion": return "#D0021B"
        case "belief":  return "#7ED321"
        case "theme":   return "#9B59B6"
        default:        return "#999999"
        }
    }

    /// Plain-language phrasing for an edge type, so the relationship reads as
    /// a sentence in the UI (e.g. "Mother brings up Sadness") instead of
    /// exposing raw graph-theory verbs.
    public static func edgeLabel(_ type: String) -> String {
        switch type {
        case "CAUSES":           return "leads to"
        case "TRIGGERS":         return "brings up"
        case "SUPPRESSES":       return "pushes down"
        case "COMPENSATES_FOR":  return "covers for"
        case "ASSOCIATED_WITH":  return "goes with"
        default:                 return type.replacingOccurrences(of: "_", with: " ").lowercased()
        }
    }
}
