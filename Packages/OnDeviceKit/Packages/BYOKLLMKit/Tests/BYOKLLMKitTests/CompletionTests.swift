import XCTest
@testable import BYOKLLMKit

final class URLRequestBuildingTests: XCTestCase {

    func testAnthropicHeadersAndPath() throws {
        let request = try LLMService.makeURLRequest(provider: .anthropic, apiKey: "sk-ant", body: ["a": 1],
                                                    stream: true, openRouterReferer: nil)
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.httpBody, Data(#"{"a":1}"#.utf8))
    }

    func testOpenAICompatibleHeadersAndReferer() throws {
        let request = try LLMService.makeURLRequest(provider: .openrouter, apiKey: "sk-or", body: [:],
                                                    stream: false, openRouterReferer: "https://example.app")
        XCTAssertEqual(request.url?.absoluteString, "https://openrouter.ai/api/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or")
        XCTAssertEqual(request.value(forHTTPHeaderField: "HTTP-Referer"), "https://example.app")
        XCTAssertNil(request.value(forHTTPHeaderField: "Accept"))
        XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
    }

    func testXAIUsesOpenAICompatibleEndpoint() throws {
        XCTAssertTrue(LLMProvider.xai.isOpenAICompatible)
        let request = try LLMService.makeURLRequest(provider: .xai, apiKey: "xai-key", body: [:],
                                                    stream: false, openRouterReferer: "ignored")
        XCTAssertEqual(request.url?.absoluteString, "https://api.x.ai/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer xai-key")
        XCTAssertNil(request.value(forHTTPHeaderField: "HTTP-Referer"), "Referer is OpenRouter-only")
    }
}

final class ChatMessageTests: XCTestCase {

    func testBridgesLegacyMessages() {
        XCTAssertEqual(LLMChatMessage(LLMMessage(role: "system", content: "s")), .system("s"))
        XCTAssertEqual(LLMChatMessage(LLMMessage(role: "assistant", content: "a")), .assistant("a"))
        XCTAssertEqual(LLMChatMessage(LLMMessage(role: "weird", content: "u")), .user("u"))
    }

    func testAccessors() {
        let call = LLMToolCall(id: "1", name: "t", arguments: [:])
        let message = LLMChatMessage.assistant("hi", toolCalls: [call])
        XCTAssertEqual(message.text, "hi")
        XCTAssertEqual(message.toolCalls, [call])
        XCTAssertEqual(LLMChatMessage.assistant("", toolCalls: [call]).content, [.toolCall(call)])
        XCTAssertEqual(LLMChatMessage.toolResult(callID: "1", content: "r").toolResults,
                       [LLMToolResult(callID: "1", content: "r")])
    }

    func testDecodeToolArguments() throws {
        struct Args: Decodable, Equatable { let query: String }
        let call = LLMToolCall(id: "1", name: "search_corpus", arguments: ["query": "lora"])
        XCTAssertEqual(try call.decodeArguments(as: Args.self), Args(query: "lora"))
    }
}

/// A canned `LLMCompleting` for exercising the protocol extension.
private struct FakeCompleter: LLMCompleting {
    let reply: String

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(message: .assistant(reply), stopReason: .endTurn, usage: nil, model: nil)
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

final class StructuredOutputTests: XCTestCase {
    private struct Entity: Decodable, Equatable { let label: String }

    private let request = LLMRequest(provider: .openrouter, model: "m", messages: [.user("x")],
                                     responseFormat: .jsonSchema(name: "entity", schema: ["type": "object"]))

    func testDecodesFencedJSON() async throws {
        let fake = FakeCompleter(reply: "```json\n{\"label\":\"LoRA\"}\n```")
        let entity = try await fake.generateStructured(request, as: Entity.self)
        XCTAssertEqual(entity, Entity(label: "LoRA"))
    }

    func testRequiresResponseFormat() async {
        var plain = request
        plain.responseFormat = nil
        do {
            _ = try await FakeCompleter(reply: "{}").generateStructured(plain, as: Entity.self)
            XCTFail("expected missingResponseFormat")
        } catch {
            XCTAssertEqual(error as? LLMCompletionError, .missingResponseFormat)
        }
    }

    func testInvalidJSONThrowsInvalidStructuredOutput() async {
        do {
            _ = try await FakeCompleter(reply: "not json").generateStructured(request, as: Entity.self)
            XCTFail("expected invalidStructuredOutput")
        } catch let error as LLMCompletionError {
            guard case .invalidStructuredOutput = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}

final class CompletionServiceTests: XCTestCase {

    func testCompleteWithoutKeyThrowsNoAPIKey() async {
        let service = LLMService(keychain: LLMKeychainStore(service: "kit-tests.complete.\(UUID().uuidString)"))
        do {
            _ = try await service.complete(LLMRequest(provider: .anthropic, model: "m", messages: [.user("hi")]))
            XCTFail("expected noAPIKey")
        } catch let error as LLMError {
            guard case .noAPIKey = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testStreamWithoutKeyThrowsNoAPIKey() async {
        let service = LLMService(keychain: LLMKeychainStore(service: "kit-tests.stream.\(UUID().uuidString)"))
        do {
            for try await _ in service.stream(LLMRequest(provider: .xai, model: "m", messages: [.user("hi")])) {
                XCTFail("should not yield")
            }
            XCTFail("expected noAPIKey")
        } catch let error as LLMError {
            guard case .noAPIKey = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testRetryableClassification() {
        XCTAssertTrue(LLMCompletionError.http(status: 429, body: "").isRetryable)
        XCTAssertTrue(LLMCompletionError.http(status: 503, body: "").isRetryable)
        XCTAssertFalse(LLMCompletionError.http(status: 401, body: "").isRetryable)
        XCTAssertFalse(LLMCompletionError.missingResponseFormat.isRetryable)
    }
}
