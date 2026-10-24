import XCTest
@testable import GraphKit

final class KnowledgeGraphExtractorTests: XCTestCase {
    private let extractor = KnowledgeGraphExtractor()

    // MARK: - Pure analysis (positive)

    func testAnalyzeExtractsEmotionPersonAndEdge() {
        let extraction = extractor.analyze("I am so angry at my mother")
        let labels = Set(extraction.nodes.map(\.label))
        XCTAssertTrue(labels.contains("Angry"))
        XCTAssertTrue(labels.contains("Mother"))

        // A person co-occurring with an emotion should imply a TRIGGERS edge.
        XCTAssertTrue(extraction.edges.contains {
            $0.sourceLabel == "Mother" && $0.targetLabel == "Angry" && $0.type == "TRIGGERS"
        })
    }

    func testAnalyzeDeduplicatesRepeatedEmotion() {
        let extraction = extractor.analyze("angry angry angry, so angry")
        let angryCount = extraction.nodes.filter { $0.label == "Angry" }.count
        XCTAssertEqual(angryCount, 1)
    }

    func testCoOccurringEmotionsProduceAssociation() {
        let extraction = extractor.analyze("I feel anxious and also lonely")
        XCTAssertTrue(extraction.edges.contains { $0.type == "ASSOCIATED_WITH" })
    }

    // MARK: - Pure analysis (negative)

    func testNeutralMessageProducesNoNodes() {
        let extraction = extractor.analyze("The weather is mild and the train was on time.")
        XCTAssertTrue(extraction.nodes.isEmpty)
        XCTAssertTrue(extraction.edges.isEmpty)
    }

    // MARK: - Plain-language edge labels

    func testEdgeTypeLabelsArePlainLanguage() {
        XCTAssertEqual(GraphDisplay.edgeLabel("TRIGGERS"), "brings up")
        XCTAssertEqual(GraphDisplay.edgeLabel("CAUSES"), "leads to")
        XCTAssertEqual(GraphDisplay.edgeLabel("SUPPRESSES"), "pushes down")
        XCTAssertEqual(GraphDisplay.edgeLabel("COMPENSATES_FOR"), "covers for")
        XCTAssertEqual(GraphDisplay.edgeLabel("ASSOCIATED_WITH"), "goes with")
    }

    func testEdgeTypeLabelUnknownTypeIsHumanized() {
        // Unknown types should be de-underscored and lowercased, not crash.
        XCTAssertEqual(GraphDisplay.edgeLabel("SOME_NEW_TYPE"), "some new type")
    }

    func testEdgeTypeLabelNeverReturnsRawConstant() {
        for type in ["TRIGGERS", "CAUSES", "SUPPRESSES", "COMPENSATES_FOR", "ASSOCIATED_WITH"] {
            let label = GraphDisplay.edgeLabel(type)
            XCTAssertFalse(label.contains("_"), "Label should not contain underscores")
            XCTAssertEqual(label, label.lowercased(), "Label should be lowercased phrasing")
        }
    }
}
