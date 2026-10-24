import Foundation

/// A retrievable slice of a `Document`, produced by `Chunker`. `Codable` so
/// `VectorIndex.snapshot()`/`restore(from:)` can round-trip it verbatim.
public struct Chunk: Sendable, Identifiable, Equatable, Codable {
    public let id: String
    public let documentID: String
    public let text: String
    public let metadata: [String: String]

    public init(id: String, documentID: String, text: String, metadata: [String: String] = [:]) {
        self.id = id
        self.documentID = documentID
        self.text = text
        self.metadata = metadata
    }
}
