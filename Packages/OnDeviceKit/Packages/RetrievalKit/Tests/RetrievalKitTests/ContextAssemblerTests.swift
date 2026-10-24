import XCTest
@testable import RetrievalKit

final class ContextAssemblerTests: XCTestCase {

    private func scored(_ id: String, text: String, score: Float) -> ScoredChunk {
        ScoredChunk(chunk: Chunk(id: id, documentID: "doc", text: text), score: score, provenance: .vector)
    }

    func testEmptyInputReturnsNil() {
        XCTAssertNil(ContextAssembler().assemble([]))
    }

    func testOrdersByScoreDescending() {
        let chunks = [scored("a", text: "low priority text", score: 0.1),
                      scored("b", text: "high priority text", score: 0.9)]
        let result = ContextAssembler(tokenBudget: 1000).assemble(chunks)
        guard let result, let highRange = result.range(of: "high priority"),
              let lowRange = result.range(of: "low priority") else {
            return XCTFail("expected both chunks present")
        }
        XCTAssertLessThan(highRange.lowerBound, lowRange.lowerBound)
    }

    func testDedupesByChunkIDKeepingHighestScore() {
        let chunks = [scored("a", text: "stale version", score: 0.2),
                      scored("a", text: "fresh version", score: 0.8)]
        let result = ContextAssembler(tokenBudget: 1000).assemble(chunks)
        XCTAssertTrue(result?.contains("fresh version") == true)
        XCTAssertFalse(result?.contains("stale version") == true)
    }

    func testRespectsTokenBudget() {
        struct FixedEstimator: TokenEstimating { func estimate(_ text: String) -> Int { 100 } }
        let chunks = (0..<5).map { scored("c\($0)", text: "chunk \($0)", score: Float(5 - $0)) }
        let result = ContextAssembler(tokenBudget: 250, estimator: FixedEstimator()).assemble(chunks) ?? ""
        let includedLines = result.components(separatedBy: "\n").filter { $0.hasPrefix("- ") }
        XCTAssertEqual(includedLines.count, 2, "250 / 100-per-chunk should fit exactly 2 chunks")
    }

    func testSkipsAnOversizedChunkButKeepsSmallerLowerScoredOnes() {
        struct ByLengthEstimator: TokenEstimating { func estimate(_ text: String) -> Int { text.count } }
        let chunks = [scored("big", text: String(repeating: "x", count: 500), score: 0.9),
                      scored("small", text: "fits fine", score: 0.1)]
        let result = ContextAssembler(tokenBudget: 100, estimator: ByLengthEstimator()).assemble(chunks)
        XCTAssertTrue(result?.contains("fits fine") == true)
        XCTAssertFalse(result?.contains(String(repeating: "x", count: 500)) == true)
    }

    func testTooSmallBudgetForAnyChunkReturnsNil() {
        struct HugeEstimator: TokenEstimating { func estimate(_ text: String) -> Int { 10_000 } }
        let chunks = [scored("a", text: "text", score: 1)]
        XCTAssertNil(ContextAssembler(tokenBudget: 10, estimator: HugeEstimator()).assemble(chunks))
    }
}
