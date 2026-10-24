import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import GraphKit

final class GraphExporterTests: XCTestCase {

    // MARK: - Helpers

    /// Builds `sessionCount` copies of the same 3-node/1-edge graph
    /// (Sadness, Anger, Mother; Mother → TRIGGERS → Sadness), each with
    /// session-local IDs, mirroring how per-session storage would look.
    private func makeSessions(count: Int = 1) -> [SessionGraph] {
        (0..<count).map { i in
            let n1 = SessionGraph.Node(id: "s\(i)-n1", type: "emotion", label: "Sadness", strength: 1.0)
            let n2 = SessionGraph.Node(id: "s\(i)-n2", type: "emotion", label: "Anger",   strength: 0.5)
            let n3 = SessionGraph.Node(id: "s\(i)-n3", type: "person",  label: "Mother",  strength: 1.0)
            let e = SessionGraph.Edge(sourceNodeID: n3.id, targetNodeID: n1.id, type: "TRIGGERS", weight: 1.0)
            return SessionGraph(nodes: [n1, n2, n3], edges: [e])
        }
    }

    // MARK: - Aggregation

    func test_aggregate_singleSession_nodeCount() {
        let graph = GraphExporter.aggregate(sessions: makeSessions())
        XCTAssertEqual(graph.nodes.count, 3)
    }

    func test_aggregate_twoSessionsMergesSameLabel() {
        let graph = GraphExporter.aggregate(sessions: makeSessions(count: 2))
        // "Sadness", "Anger", "Mother" each appear in both sessions → still 3 unique nodes
        XCTAssertEqual(graph.nodes.count, 3)
    }

    func test_aggregate_strengthSummedAcrossSessions() {
        let graph = GraphExporter.aggregate(sessions: makeSessions(count: 2))
        let sadness = graph.nodes.first { $0.label == "Sadness" }
        // 1.0 + 1.0 = 2.0
        XCTAssertEqual(sadness?.strength ?? 0, 2.0, accuracy: 0.01)
    }

    func test_aggregate_sessionCountTracked() {
        let graph = GraphExporter.aggregate(sessions: makeSessions(count: 3))
        let mother = graph.nodes.first { $0.label == "Mother" }
        XCTAssertEqual(mother?.sessionCount, 3)
    }

    func test_aggregate_edgesMergedByTypeAndNodes() {
        let graph = GraphExporter.aggregate(sessions: makeSessions(count: 2))
        // Mother → TRIGGERS → Sadness exists in both sessions → 1 merged edge
        XCTAssertEqual(graph.edges.count, 1)
        let edge = graph.edges.first!
        XCTAssertEqual(edge.type, "TRIGGERS")
        XCTAssertEqual(edge.weight, 2.0, accuracy: 0.01)
    }

    func test_aggregate_emptySessionsReturnsEmptyGraph() {
        let graph = GraphExporter.aggregate(sessions: [])
        XCTAssertTrue(graph.nodes.isEmpty)
        XCTAssertTrue(graph.edges.isEmpty)
    }

    // MARK: - Cytoscape JSON

    func test_cytoscapeJSON_validJSON() throws {
        let graph = GraphExporter.aggregate(sessions: makeSessions())
        let json = GraphExporter.cytoscapeJSON(graph: graph)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: json.data(using: .utf8)!))
    }

    func test_cytoscapeJSON_shape() throws {
        let graph = GraphExporter.aggregate(sessions: makeSessions())
        let json = GraphExporter.cytoscapeJSON(graph: graph)

        let parsed = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
        let elements = parsed["elements"] as? [String: Any]
        XCTAssertNotNil(elements)
        let nodes = elements?["nodes"] as? [[String: Any]]
        let edges = elements?["edges"] as? [[String: Any]]
        XCTAssertEqual(nodes?.count, 3)
        XCTAssertEqual(edges?.count, 1)
        // Each node data should have id, label, type, strength.
        let firstNodeData = (nodes?.first)?["data"] as? [String: Any]
        XCTAssertNotNil(firstNodeData?["id"])
        XCTAssertNotNil(firstNodeData?["label"])
        XCTAssertNotNil(firstNodeData?["type"])
        XCTAssertNotNil(firstNodeData?["strength"])
    }

    func test_cytoscapeJSON_emptyGraph_validJSON() {
        let graph = AggregatedGraph(nodes: [], edges: [])
        let json = GraphExporter.cytoscapeJSON(graph: graph)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: json.data(using: .utf8)!))
    }

    // MARK: - GraphML

    func test_graphML_wellFormed() throws {
        let graph = GraphExporter.aggregate(sessions: makeSessions())
        let xml = GraphExporter.graphML(graph: graph)

        let parser = XMLParser(data: xml.data(using: .utf8)!)
        let delegate = XMLParserRecorder()
        parser.delegate = delegate
        XCTAssertTrue(parser.parse(), "GraphML should parse as valid XML")
        XCTAssertNil(delegate.parseError)
    }

    func test_graphML_containsAllNodes() {
        let graph = GraphExporter.aggregate(sessions: makeSessions())
        let xml = GraphExporter.graphML(graph: graph)

        XCTAssertTrue(xml.contains("Sadness"))
        XCTAssertTrue(xml.contains("Anger"))
        XCTAssertTrue(xml.contains("Mother"))
    }

    func test_graphML_containsEdge() {
        let graph = GraphExporter.aggregate(sessions: makeSessions())
        let xml = GraphExporter.graphML(graph: graph)
        XCTAssertTrue(xml.contains("TRIGGERS"))
        XCTAssertTrue(xml.contains("<edge "))
    }

    func test_graphML_emptyGraph_valid() {
        let graph = AggregatedGraph(nodes: [], edges: [])
        let xml = GraphExporter.graphML(graph: graph)
        let parser = XMLParser(data: xml.data(using: .utf8)!)
        XCTAssertTrue(parser.parse(), "Empty GraphML should still be valid XML")
    }

    func test_graphML_specialCharactersEscaped() {
        // Node label with XML-special characters.
        let node = AggregatedNode(id: "emotion:love&fear", type: "emotion",
                                  label: "Love & Fear", strength: 1.0, sessionCount: 1)
        let graph = AggregatedGraph(nodes: [node], edges: [])
        let xml = GraphExporter.graphML(graph: graph)
        XCTAssertTrue(xml.contains("Love &amp; Fear"), "& should be XML-escaped")
        // Must still parse cleanly.
        let parser = XMLParser(data: xml.data(using: .utf8)!)
        XCTAssertTrue(parser.parse())
    }

    // MARK: - File writing helpers

    func test_writeGraphML_createsFile() throws {
        let graph = AggregatedGraph(nodes: [], edges: [])
        let content = GraphExporter.graphML(graph: graph)
        guard let url = GraphExporter.writeGraphML(content) else {
            XCTFail("writeGraphML should return a URL"); return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    func test_writeCytoscapeJSON_createsFile() throws {
        let graph = AggregatedGraph(nodes: [], edges: [])
        let content = GraphExporter.cytoscapeJSON(graph: graph)
        guard let url = GraphExporter.writeCytoscapeJSON(content) else {
            XCTFail("writeCytoscapeJSON should return a URL"); return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - XMLParserRecorder (helper)

private final class XMLParserRecorder: NSObject, XMLParserDelegate {
    var parseError: Error?
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}
