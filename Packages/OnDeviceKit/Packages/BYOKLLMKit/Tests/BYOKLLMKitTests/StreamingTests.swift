import XCTest
@testable import BYOKLLMKit

final class SSEParsingTests: XCTestCase {

    func testParsesDeltaContentFromDataLine() {
        let line = #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#
        XCTAssertEqual(LLMService.parseSSELine(line), .delta("Hello"))
    }

    func testRecognizesDoneSentinel() {
        XCTAssertEqual(LLMService.parseSSELine("data: [DONE]"), .done)
    }

    func testIgnoresNonDataLines() {
        XCTAssertEqual(LLMService.parseSSELine(": comment"), .ignore)
        XCTAssertEqual(LLMService.parseSSELine(""), .ignore)
        XCTAssertEqual(LLMService.parseSSELine("event: ping"), .ignore)
    }

    func testIgnoresDataLineWithNoDeltaContent() {
        // A chunk carrying only a finish_reason and no content delta.
        let line = #"data: {"choices":[{"delta":{}}]}"#
        XCTAssertEqual(LLMService.parseSSELine(line), .ignore)
    }

    func testIgnoresMalformedJSON() {
        XCTAssertEqual(LLMService.parseSSELine("data: not json"), .ignore)
    }

    func testIgnoresEmptyChoicesArray() {
        let line = #"data: {"choices":[]}"#
        XCTAssertEqual(LLMService.parseSSELine(line), .ignore)
    }
}

final class StreamMessageTests: XCTestCase {

    /// Anthropic streaming is now supported, so with no key configured the
    /// legacy API reports the missing key (still as `LLMError`) rather than
    /// `.streamingNotSupported`.
    func testAnthropicStreamingIsSupportedAndReportsMissingKey() async {
        let keychain = LLMKeychainStore(service: "kit-tests.streaming.\(UUID().uuidString)")
        let service = LLMService(keychain: keychain)
        do {
            for try await _ in service.streamMessage(provider: "anthropic", model: "claude-sonnet-5",
                                                      messages: [LLMMessage(role: "user", content: "hi")]) {
                XCTFail("Should not yield any values with no API key configured")
            }
            XCTFail("Expected noAPIKey error")
        } catch let error as LLMError {
            if case .noAPIKey = error {} else { XCTFail("Expected .noAPIKey, got \(error)") }
        } catch {
            XCTFail("Expected LLMError.noAPIKey, got \(error)")
        }
    }

    func testStreamingThrowsForUnknownProvider() async {
        let keychain = LLMKeychainStore(service: "kit-tests.streaming.\(UUID().uuidString)")
        let service = LLMService(keychain: keychain)
        do {
            for try await _ in service.streamMessage(provider: "not-a-real-provider", model: "x",
                                                      messages: [LLMMessage(role: "user", content: "hi")]) {
                XCTFail("Should not yield any values for an unknown provider")
            }
            XCTFail("Expected unsupportedProvider error")
        } catch let error as LLMError {
            if case .unsupportedProvider = error {} else { XCTFail("Expected .unsupportedProvider, got \(error)") }
        } catch {
            XCTFail("Expected LLMError.unsupportedProvider, got \(error)")
        }
    }

    func testStreamingThrowsNoAPIKeyWhenUnconfigured() async {
        let keychain = LLMKeychainStore(service: "kit-tests.streaming.\(UUID().uuidString)")
        let service = LLMService(keychain: keychain)
        do {
            for try await _ in service.streamMessage(provider: "openai", model: "gpt-4o-mini",
                                                      messages: [LLMMessage(role: "user", content: "hi")]) {
                XCTFail("Should not yield any values with no API key configured")
            }
            XCTFail("Expected noAPIKey error")
        } catch let error as LLMError {
            if case .noAPIKey = error {} else { XCTFail("Expected .noAPIKey, got \(error)") }
        } catch {
            XCTFail("Expected LLMError.noAPIKey, got \(error)")
        }
    }
}
