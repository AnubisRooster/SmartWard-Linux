import XCTest
@testable import BYOKLLMKit

final class LLMProviderTests: XCTestCase {

    func testAnthropicIsNotOpenAICompatible() {
        XCTAssertFalse(LLMProvider.anthropic.isOpenAICompatible)
    }

    func testAllOtherProvidersAreOpenAICompatible() {
        for provider in LLMProvider.allCases where provider != .anthropic {
            XCTAssertTrue(provider.isOpenAICompatible, "\(provider) should be OpenAI-compatible")
        }
    }

    func testKeychainKeysAreUniquePerProvider() {
        let keys = Set(LLMProvider.allCases.map(\.keychainKey))
        XCTAssertEqual(keys.count, LLMProvider.allCases.count)
    }

    func testBaseURLsAreWellFormed() {
        for provider in LLMProvider.allCases {
            XCTAssertNotNil(URL(string: provider.baseURL), "\(provider) has an invalid base URL")
        }
    }
}

final class LLMServiceJSONTests: XCTestCase {

    func testStripCodeFencesRemovesMarkdownFence() {
        let fenced = "```json\n{\"a\":1}\n```"
        XCTAssertEqual(LLMService.stripCodeFences(fenced), "{\"a\":1}")
    }

    func testStripCodeFencesLeavesPlainTextUnchanged() {
        XCTAssertEqual(LLMService.stripCodeFences("{\"a\":1}"), "{\"a\":1}")
    }
}
