import XCTest
@testable import RetrievalKit

final class LexicalIndexTests: XCTestCase {
    func testTokensKeepCompoundTermsAndTheirParts() {
        XCTAssertEqual(LexicalIndex.tokens("SWE-bench, GPT-4o and vLLM!"),
                       ["swe-bench", "swe", "bench", "gpt-4o", "gpt", "4o", "and", "vllm"])
        XCTAssertEqual(LexicalIndex.tokens("Llama 3.1."), ["llama", "3.1", "3", "1"])
        XCTAssertEqual(LexicalIndex.tokens("  "), [])
    }

    func testBM25RanksRareTermsAndShortDocsHigher() {
        var index = LexicalIndex()
        index.add(id: "a", text: "LoRA fine-tuning for small models")
        index.add(id: "b", text: "Fine-tuning large models with full parameter updates and lots of other words here")
        index.add(id: "c", text: "Retrieval augmented generation")
        let hits = index.search("LoRA fine-tuning", limit: 10)
        XCTAssertEqual(hits.first?.id, "a")
        XCTAssertEqual(Set(hits.map(\.id)), ["a", "b"])
    }

    func testNoMatchingTermsReturnsEmpty() {
        var index = LexicalIndex()
        index.add(id: "a", text: "LoRA fine-tuning for small models")
        XCTAssertTrue(index.search("quantum", limit: 10).isEmpty)
    }

    func testEmptyQueryReturnsEmpty() {
        var index = LexicalIndex()
        index.add(id: "a", text: "LoRA fine-tuning for small models")
        XCTAssertTrue(index.search("", limit: 10).isEmpty)
    }

    func testEmptyIndexReturnsEmpty() {
        let index = LexicalIndex()
        XCTAssertTrue(index.search("anything", limit: 10).isEmpty)
    }

    func testLimitBoundsTheResultCount() {
        var index = LexicalIndex()
        for id in ["a", "b", "c", "d"] { index.add(id: id, text: "shared term") }
        XCTAssertEqual(index.search("shared", limit: 2).count, 2)
    }

    func testCountReflectsAddedDocuments() {
        var index = LexicalIndex()
        XCTAssertEqual(index.count, 0)
        index.add(id: "a", text: "text")
        index.add(id: "b", text: "more text")
        XCTAssertEqual(index.count, 2)
    }
}
