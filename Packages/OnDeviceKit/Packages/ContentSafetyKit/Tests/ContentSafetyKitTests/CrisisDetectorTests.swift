import XCTest
@testable import ContentSafetyKit

final class CrisisDetectorTests: XCTestCase {
    private let detector = CrisisDetector()

    // MARK: - Positive

    func testCriticalCrisisPhrasesAreFlagged() {
        let phrases = ["I want to die", "I'm going to kill myself",
                       "thinking about suicide", "I keep cutting"]
        for phrase in phrases {
            let result = detector.check(phrase)
            XCTAssertTrue(result.isCrisis, "Expected crisis for: \(phrase)")
            XCTAssertEqual(result.level, "critical", "Expected critical for: \(phrase)")
            XCTAssertNotNil(result.pattern)
        }
    }

    func testWarningLevelCrisisPhrases() {
        let result = detector.check("I feel hopeless and worthless")
        XCTAssertTrue(result.isCrisis)
        XCTAssertEqual(result.level, "warning")
    }

    func testCrisisDetectionIsCaseInsensitive() {
        let result = detector.check("I WANT TO DIE")
        XCTAssertTrue(result.isCrisis)
    }

    // MARK: - Negative

    func testOrdinaryMessageIsNotCrisis() {
        let result = detector.check("I had a really nice walk today and feel calm.")
        XCTAssertFalse(result.isCrisis)
        XCTAssertEqual(result.level, "")
        XCTAssertNil(result.pattern)
    }

    func testEmptyMessageIsNotCrisis() {
        XCTAssertFalse(detector.check("").isCrisis)
    }

    // MARK: - Custom patterns

    func testCustomPatternsOverrideDefaults() {
        let custom = CrisisDetector(patterns: [CrisisPattern(patterns: ["red flag phrase"], level: "custom")])
        XCTAssertTrue(custom.check("this is a red flag phrase").isCrisis)
        XCTAssertFalse(custom.check("I want to die").isCrisis) // not in custom list
    }
}
