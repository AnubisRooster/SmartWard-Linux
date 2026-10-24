import XCTest
@testable import VoiceLoopKit

final class VoiceLoopConfigTests: XCTestCase {

    func testDefaultsAreReasonable() {
        let config = VoiceLoopConfig()
        XCTAssertEqual(config.silenceInterval, 5.0)
        XCTAssertEqual(config.ttsRate, 0.5)
        XCTAssertEqual(config.ttsPitch, 1.0)
        XCTAssertEqual(config.voiceID, "")
        XCTAssertFalse(config.requiresOnDeviceRecognition, "server fallback stays allowed unless asked")
    }

    @MainActor
    func testServerFallbackOnlyWhenOnDeviceIsNotRequired() {
        let relaxed = VoiceLoopConfig()
        XCTAssertFalse(VoiceConversationController.dropsOnDeviceRequirement(afterFailures: 1, config: relaxed))
        XCTAssertTrue(VoiceConversationController.dropsOnDeviceRequirement(afterFailures: 2, config: relaxed))

        let strict = VoiceLoopConfig(requiresOnDeviceRecognition: true)
        XCTAssertFalse(VoiceConversationController.dropsOnDeviceRequirement(afterFailures: 2, config: strict))
        XCTAssertFalse(VoiceConversationController.dropsOnDeviceRequirement(afterFailures: 3, config: strict))
    }

    func testSilenceIntervalIsClampedToLowerBound() {
        let config = VoiceLoopConfig(silenceInterval: 0.5)
        XCTAssertEqual(config.silenceInterval, 2.0)
    }

    func testSilenceIntervalIsClampedToUpperBound() {
        let config = VoiceLoopConfig(silenceInterval: 30)
        XCTAssertEqual(config.silenceInterval, 12.0)
    }

    func testSilenceIntervalWithinBoundsIsUnchanged() {
        let config = VoiceLoopConfig(silenceInterval: 7)
        XCTAssertEqual(config.silenceInterval, 7)
    }
}
