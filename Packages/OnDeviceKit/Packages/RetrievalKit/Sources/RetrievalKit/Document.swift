import Foundation

/// A source document to be indexed for retrieval — e.g. a journal entry or
/// session transcript. Host apps map their own storage into this;
/// `RetrievalKit` is persistence-agnostic, matching `GraphKit`'s `SessionGraph`.
public struct Document: Sendable, Identifiable {
    public let id: String
    public let text: String
    /// Arbitrary host-defined tags (e.g. `["sessionID": "...", "date": "..."]`),
    /// carried onto every chunk produced from this document for use as a
    /// `VectorIndex.search(filter:)` predicate.
    public let metadata: [String: String]

    public init(id: String, text: String, metadata: [String: String] = [:]) {
        self.id = id
        self.text = text
        self.metadata = metadata
    }
}
