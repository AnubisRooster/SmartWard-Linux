import Foundation
import GraphKit
import RetrievalKit

/// Maps a stable GraphKit node id (`"type:label"`, matching
/// `AggregatedNode.id`'s convention — see `GraphExporter.aggregate`) to the
/// chunks whose text mentions that entity, and back. Built by running
/// `KnowledgeGraphExtractor` over each chunk at index time, reusing GraphKit's
/// existing extraction logic rather than duplicating it here.
public struct EntityChunkIndex: Sendable {
    private var nodeToChunkIDs: [String: Set<String>] = [:]
    private var chunkToNodeIDs: [String: Set<String>] = [:]
    private var documentToChunkIDs: [String: Set<String>] = [:]
    private let extractor = KnowledgeGraphExtractor()

    public init() {}

    /// Extracts entities from `chunk.text` and records them against this index.
    public mutating func index(_ chunk: Chunk) {
        let extraction = extractor.analyze(chunk.text)
        let nodeIDs = Set(extraction.nodes.map { "\($0.type):\($0.label.lowercased())" })
        chunkToNodeIDs[chunk.id] = nodeIDs
        for nodeID in nodeIDs {
            nodeToChunkIDs[nodeID, default: []].insert(chunk.id)
        }
        documentToChunkIDs[chunk.documentID, default: []].insert(chunk.id)
    }

    /// Removes every chunk that belonged to `documentID`, and prunes any
    /// entity node left with no remaining chunks.
    public mutating func removeDocument(_ documentID: String) {
        guard let chunkIDs = documentToChunkIDs.removeValue(forKey: documentID) else { return }
        for chunkID in chunkIDs {
            guard let nodeIDs = chunkToNodeIDs.removeValue(forKey: chunkID) else { continue }
            for nodeID in nodeIDs {
                nodeToChunkIDs[nodeID]?.remove(chunkID)
                if nodeToChunkIDs[nodeID]?.isEmpty == true {
                    nodeToChunkIDs.removeValue(forKey: nodeID)
                }
            }
        }
    }

    /// The chunks that mention entity `nodeID`.
    public func chunkIDs(forNode nodeID: String) -> Set<String> {
        nodeToChunkIDs[nodeID] ?? []
    }

    /// The entities `chunkID` mentions — the seed set `GraphExpander` walks
    /// outward from.
    public func nodeIDs(forChunk chunkID: String) -> Set<String> {
        chunkToNodeIDs[chunkID] ?? []
    }

    /// Test-only: directly registers a chunk↔node mapping, bypassing
    /// `KnowledgeGraphExtractor`. Lets tests exercise multi-hop traversal over
    /// hand-built graphs without depending on the extractor's actual
    /// vocabulary (e.g. node labels that aren't real emotion/person words).
    mutating func forceIndex(chunkID: String, nodeIDs: Set<String>) {
        chunkToNodeIDs[chunkID] = nodeIDs
        for nodeID in nodeIDs {
            nodeToChunkIDs[nodeID, default: []].insert(chunkID)
        }
    }
}
