import XCTest
@testable import RetrievalKit

final class ChunkerTests: XCTestCase {

    func testSingleShortDocumentProducesOneChunk() {
        let doc = Document(id: "d1", text: "I feel anxious around my mother. She calls every day.")
        let chunks = Chunker(targetSize: 800).chunk(doc)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].documentID, "d1")
        XCTAssertEqual(chunks[0].id, "d1#0")
    }

    func testLongDocumentSplitsAcrossMultipleChunks() {
        let sentence = "This is a sentence about my mother and my feelings. "
        let doc = Document(id: "d2", text: String(repeating: sentence, count: 40))
        let chunks = Chunker(targetSize: 200, overlapSentences: 0).chunk(doc)
        XCTAssertGreaterThan(chunks.count, 1)
    }

    func testOverlapRepeatsTrailingSentenceInNextChunk() {
        let doc = Document(id: "d3", text:
            "Sentence one is here. Sentence two follows. Sentence three continues. Sentence four wraps up.")
        let chunks = Chunker(targetSize: 40, overlapSentences: 1).chunk(doc)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks[1].text.hasPrefix("Sentence one is here."),
                      "expected the previous chunk's last sentence to open the next chunk, got: \(chunks[1].text)")
    }

    func testZeroOverlapDoesNotRepeatSentences() {
        let doc = Document(id: "d4", text:
            "Sentence one is here. Sentence two follows. Sentence three continues. Sentence four wraps up.")
        let chunks = Chunker(targetSize: 40, overlapSentences: 0).chunk(doc)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertFalse(chunks[1].text.hasPrefix("Sentence one is here."))
    }

    func testEmptyDocumentProducesNoChunks() {
        XCTAssertTrue(Chunker().chunk(Document(id: "d5", text: "")).isEmpty)
    }

    func testWhitespaceOnlyDocumentProducesNoChunks() {
        XCTAssertTrue(Chunker().chunk(Document(id: "d6", text: "   \n\n  ")).isEmpty)
    }

    func testMetadataIsCarriedIntoEveryChunk() {
        let doc = Document(id: "d7", text: "One sentence here.", metadata: ["sessionID": "s1"])
        let chunks = Chunker().chunk(doc)
        XCTAssertEqual(chunks.first?.metadata["sessionID"], "s1")
    }
}
