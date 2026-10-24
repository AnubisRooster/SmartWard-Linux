import XCTest
@testable import RetrievalKit

final class CosineSimilarityTests: XCTestCase {

    func testIdenticalVectorsScoreOne() {
        let v: [Float] = [1, 2, 3]
        XCTAssertEqual(CosineSimilarity.score(v, v), 1, accuracy: 0.0001)
    }

    func testOrthogonalVectorsScoreZero() {
        XCTAssertEqual(CosineSimilarity.score([1, 0], [0, 1]), 0, accuracy: 0.0001)
    }

    func testOppositeVectorsScoreNegativeOne() {
        XCTAssertEqual(CosineSimilarity.score([1, 0], [-1, 0]), -1, accuracy: 0.0001)
    }

    func testMismatchedLengthsScoreZero() {
        XCTAssertEqual(CosineSimilarity.score([1, 2], [1, 2, 3]), 0)
    }

    func testZeroVectorScoresZeroNotNaN() {
        let score = CosineSimilarity.score([0, 0], [1, 1])
        XCTAssertEqual(score, 0)
        XCTAssertFalse(score.isNaN)
    }

    func testEmptyVectorsScoreZero() {
        XCTAssertEqual(CosineSimilarity.score([], []), 0)
    }
}
