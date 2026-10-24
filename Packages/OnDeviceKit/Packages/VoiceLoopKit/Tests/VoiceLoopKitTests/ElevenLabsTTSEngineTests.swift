import XCTest
@testable import VoiceLoopKit

final class ElevenLabsTTSEngineTests: XCTestCase {

    func testValidKeyAccepted() {
        XCTAssertTrue(ElevenLabsTTSEngine.isValidKey("sk_1234567890abcdefghijklmno"))
    }

    func testTooShortKeyRejected() {
        XCTAssertFalse(ElevenLabsTTSEngine.isValidKey("short"))
    }

    func testKeyContainingWhitespaceRejected() {
        XCTAssertFalse(ElevenLabsTTSEngine.isValidKey("sk_123456 7890abcdefghijklmno"))
    }

    @MainActor
    func testSpeakingEmptyTextCallsCompletionWithoutNetworkCall() {
        let engine = ElevenLabsTTSEngine()
        let expectation = expectation(description: "completion called")
        engine.speak("   ", voiceId: "", modelId: "", apiKey: "sk_1234567890abcdefghijklmno",
                    onStart: { _, _ in XCTFail("onStart should not be called for empty text") },
                    onProgress: { _ in },
                    completion: { expectation.fulfill() },
                    onError: { _ in XCTFail("onError should not be called for empty text") })
        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testSpeakingWithInvalidKeyCallsOnError() {
        let engine = ElevenLabsTTSEngine()
        let expectation = expectation(description: "error called")
        engine.speak("hello", voiceId: "", modelId: "", apiKey: "short",
                    onStart: { _, _ in XCTFail("onStart should not be called with an invalid key") },
                    onProgress: { _ in },
                    completion: { XCTFail("completion should not be called with an invalid key") },
                    onError: { error in
                        XCTAssertTrue(error is ElevenLabsTTSEngine.TTSError)
                        expectation.fulfill()
                    })
        waitForExpectations(timeout: 1)
    }

    // MARK: - prefetch/play (sentence-level pipelining)

    func testPrefetchingEmptyTextThrowsEmptyAudio() async {
        do {
            _ = try await ElevenLabsTTSEngine.prefetch("   ", voiceId: "", modelId: "", apiKey: "sk_1234567890abcdefghijklmno")
            XCTFail("should have thrown before making a network call")
        } catch let error as ElevenLabsTTSEngine.TTSError {
            if case .emptyAudio = error {} else { XCTFail("expected .emptyAudio, got \(error)") }
        } catch {
            XCTFail("expected TTSError, got \(error)")
        }
    }

    func testPrefetchingWithInvalidKeyThrowsMissingKey() async {
        do {
            _ = try await ElevenLabsTTSEngine.prefetch("hello", voiceId: "", modelId: "", apiKey: "short")
            XCTFail("should have thrown before making a network call")
        } catch let error as ElevenLabsTTSEngine.TTSError {
            if case .missingKey = error {} else { XCTFail("expected .missingKey, got \(error)") }
        } catch {
            XCTFail("expected TTSError, got \(error)")
        }
    }

    @MainActor
    func testPlayingClipWithUnreadableFileCallsOnError() {
        let engine = ElevenLabsTTSEngine()
        let expectation = expectation(description: "error called")
        let bogusURL = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID()).mp3")
        let clip = ElevenLabsTTSEngine.PrefetchedClip(url: bogusURL, text: "hello", energies: [], duration: 0)
        engine.play(clip,
                   onStart: { _, _ in XCTFail("should not start playback for an unreadable file") },
                   onProgress: { _ in },
                   completion: { XCTFail("should not complete for an unreadable file") },
                   onError: { _ in expectation.fulfill() })
        waitForExpectations(timeout: 1)
    }
}
