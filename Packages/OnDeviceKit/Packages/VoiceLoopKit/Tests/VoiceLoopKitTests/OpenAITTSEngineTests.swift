import XCTest
@testable import VoiceLoopKit

final class OpenAITTSEngineTests: XCTestCase {

    func testValidKeyAccepted() {
        XCTAssertTrue(OpenAITTSEngine.isValidKey("sk-1234567890abcdefghijklmno"))
    }

    func testTooShortKeyRejected() {
        XCTAssertFalse(OpenAITTSEngine.isValidKey("short"))
    }

    func testKeyContainingWhitespaceRejected() {
        XCTAssertFalse(OpenAITTSEngine.isValidKey("sk-123456 7890abcdefghijklmno"))
    }

    func testAvailableVoicesIsNonEmpty() {
        XCTAssertFalse(OpenAITTSEngine.availableVoices.isEmpty)
        XCTAssertTrue(OpenAITTSEngine.availableVoices.contains(OpenAITTSEngine.defaultVoice))
    }

    func testAvailableModelsIsNonEmpty() {
        XCTAssertFalse(OpenAITTSEngine.availableModels.isEmpty)
        XCTAssertTrue(OpenAITTSEngine.availableModels.contains(OpenAITTSEngine.defaultModel))
    }

    @MainActor
    func testSpeakingEmptyTextCallsCompletionWithoutNetworkCall() {
        let engine = OpenAITTSEngine()
        let expectation = expectation(description: "completion called")
        engine.speak("   ", voice: "", model: "", apiKey: "sk-1234567890abcdefghijklmno",
                    onStart: { _, _ in XCTFail("should not start playback for empty text") },
                    onProgress: { _ in },
                    completion: { expectation.fulfill() },
                    onError: { _ in XCTFail("should not error for empty text") })
        waitForExpectations(timeout: 1)
    }

    @MainActor
    func testSpeakingWithInvalidKeyCallsOnError() {
        let engine = OpenAITTSEngine()
        let expectation = expectation(description: "error called")
        engine.speak("hello", voice: "", model: "", apiKey: "short",
                    onStart: { _, _ in XCTFail("should not start playback with invalid key") },
                    onProgress: { _ in },
                    completion: { XCTFail("should not complete with invalid key") },
                    onError: { error in
                        XCTAssertTrue(error is OpenAITTSEngine.TTSError)
                        expectation.fulfill()
                    })
        waitForExpectations(timeout: 1)
    }

    // MARK: - prefetch/play (sentence-level pipelining)

    func testPrefetchingEmptyTextThrowsEmptyAudio() async {
        do {
            _ = try await OpenAITTSEngine.prefetch("   ", voice: "", model: "", apiKey: "sk-1234567890abcdefghijklmno")
            XCTFail("should have thrown before making a network call")
        } catch let error as OpenAITTSEngine.TTSError {
            if case .emptyAudio = error {} else { XCTFail("expected .emptyAudio, got \(error)") }
        } catch {
            XCTFail("expected TTSError, got \(error)")
        }
    }

    func testPrefetchingWithInvalidKeyThrowsMissingKey() async {
        do {
            _ = try await OpenAITTSEngine.prefetch("hello", voice: "", model: "", apiKey: "short")
            XCTFail("should have thrown before making a network call")
        } catch let error as OpenAITTSEngine.TTSError {
            if case .missingKey = error {} else { XCTFail("expected .missingKey, got \(error)") }
        } catch {
            XCTFail("expected TTSError, got \(error)")
        }
    }

    @MainActor
    func testPlayingClipWithUnreadableFileCallsOnError() {
        let engine = OpenAITTSEngine()
        let expectation = expectation(description: "error called")
        // A clip pointing at a file that was never written — exercises the
        // playback path without needing a real synthesized MP3 on disk.
        let bogusURL = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID()).mp3")
        let clip = OpenAITTSEngine.PrefetchedClip(url: bogusURL, text: "hello", energies: [], duration: 0)
        engine.play(clip,
                   onStart: { _, _ in XCTFail("should not start playback for an unreadable file") },
                   onProgress: { _ in },
                   completion: { XCTFail("should not complete for an unreadable file") },
                   onError: { _ in expectation.fulfill() })
        waitForExpectations(timeout: 1)
    }
}
