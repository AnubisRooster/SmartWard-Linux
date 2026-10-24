import XCTest
@testable import ContentSafetyKit

final class BoundaryDetectorTests: XCTestCase {
    private let detector = BoundaryDetector()

    // MARK: - Positive (standard context)

    func testDiagnosingLanguageIsBoundaryViolation() {
        let result = detector.check("Based on this, your diagnosis is bipolar disorder.")
        XCTAssertTrue(result.isViolation)
        XCTAssertNotNil(result.pattern)
    }

    func testPrescribingLanguageIsBoundaryViolation() {
        XCTAssertTrue(detector.check("I prescribe a daily dose of sertraline.").isViolation)
        XCTAssertTrue(detector.check("You need medication for this.").isViolation)
    }

    // MARK: - Negative (standard context)

    func testEmpatheticLanguageIsNotBoundaryViolation() {
        // Ordinary reflective language must not trip the diagnosis/prescription filter.
        let result = detector.check("It sounds like you have been feeling overwhelmed lately.")
        XCTAssertFalse(result.isViolation)
        XCTAssertNil(result.pattern)
    }

    // MARK: - spiritualGuidance context

    func testSpiritualGuidanceContextAllowsPracticeLanguage() {
        // Guidance about prayer/practice must NOT be blocked in this context,
        // even though it would look borderline in a clinical context.
        let result = detector.check("Consider setting aside time for prayer each morning.",
                                    context: .spiritualGuidance)
        XCTAssertFalse(result.isViolation)
    }

    func testSpiritualGuidanceContextStillBlocksProselytising() {
        XCTAssertTrue(detector.check("You must convert to be saved.", context: .spiritualGuidance).isViolation)
        XCTAssertTrue(detector.check("Your beliefs are false.", context: .spiritualGuidance).isViolation)
    }

    func testStandardContextBlocksReligiousCoercionToo() {
        XCTAssertTrue(detector.check("You will go to hell for this.", context: .standard).isViolation)
    }

    func testUniversalPatternsAreBlockedInBothContexts() {
        XCTAssertTrue(detector.check("I diagnose you with anxiety.", context: .standard).isViolation)
        XCTAssertTrue(detector.check("I diagnose you with anxiety.", context: .spiritualGuidance).isViolation)
    }
}
