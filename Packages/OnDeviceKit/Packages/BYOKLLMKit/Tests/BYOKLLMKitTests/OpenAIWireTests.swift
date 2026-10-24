import XCTest
@testable import BYOKLLMKit

private let searchTool = LLMTool(
    name: "search_corpus",
    description: "Search the research corpus.",
    inputSchema: ["type": "object", "properties": ["query": ["type": "string"]], "required": ["query"]]
)

final class OpenAIWireRequestTests: XCTestCase {

    func testEncodesToolsChoiceAndSchemaFormat() {
        let request = LLMRequest(provider: .openrouter, model: "m",
                                 messages: [.user("hi")],
                                 tools: [searchTool],
                                 toolChoice: .tool("search_corpus"),
                                 responseFormat: .jsonSchema(name: "answer", schema: ["type": "object"]))
        let body = OpenAIWire.requestBody(for: request, model: "m", stream: false)

        let function: JSONValue = [
            "name": "search_corpus",
            "description": "Search the research corpus.",
            "parameters": searchTool.inputSchema,
        ]
        let expectedTool: JSONValue = ["type": "function", "function": function]
        XCTAssertEqual(body["tools"]?.arrayValue?.first, expectedTool)

        let expectedChoice: JSONValue = ["type": "function", "function": ["name": "search_corpus"]]
        XCTAssertEqual(body["tool_choice"], expectedChoice)

        let schemaSpec: JSONValue = ["name": "answer", "schema": ["type": "object"], "strict": true]
        let expectedFormat: JSONValue = ["type": "json_schema", "json_schema": schemaSpec]
        XCTAssertEqual(body["response_format"], expectedFormat)

        let expectedUsage: JSONValue = ["include": true]
        XCTAssertEqual(body["usage"], expectedUsage, "OpenRouter should be asked for usage/cost")
    }

    func testMaxTokensKeyDependsOnProvider() {
        let openAI = OpenAIWire.requestBody(for: LLMRequest(provider: .openai, model: "m", messages: [], maxTokens: 100),
                                            model: "m", stream: false)
        XCTAssertEqual(openAI["max_completion_tokens"], JSONValue.int(100))
        XCTAssertNil(openAI["max_tokens"])

        let groq = OpenAIWire.requestBody(for: LLMRequest(provider: .groq, model: "m", messages: [], maxTokens: 100),
                                          model: "m", stream: false)
        XCTAssertEqual(groq["max_tokens"], JSONValue.int(100))
        XCTAssertNil(groq["max_completion_tokens"])

        let unset = OpenAIWire.requestBody(for: LLMRequest(provider: .groq, model: "m", messages: []),
                                           model: "m", stream: false)
        XCTAssertNil(unset["max_tokens"])
    }

    func testStreamOptionsOnlyForOpenAIStreams() {
        let streaming = OpenAIWire.requestBody(for: LLMRequest(provider: .openai, model: "m", messages: []),
                                               model: "m", stream: true)
        let expectedOptions: JSONValue = ["include_usage": true]
        XCTAssertEqual(streaming["stream_options"], expectedOptions)

        let xai = OpenAIWire.requestBody(for: LLMRequest(provider: .xai, model: "m", messages: []),
                                         model: "m", stream: true)
        XCTAssertNil(xai["stream_options"])
    }

    func testEncodesAssistantToolCallsAndToolResults() {
        let call = LLMToolCall(id: "call_1", name: "search_corpus", arguments: ["query": "lora"])
        let messages = OpenAIWire.requestBody(
            for: LLMRequest(provider: .openai, model: "m", messages: [
                .system("sys"),
                .user("find lora"),
                .assistant("", toolCalls: [call]),
                .toolResult(callID: "call_1", content: "3 hits"),
                .toolResult(callID: "call_2", content: "boom", isError: true),
            ]),
            model: "m", stream: false)["messages"]?.arrayValue

        XCTAssertEqual(messages?.count, 5)

        let expectedSystem: JSONValue = ["role": "system", "content": "sys"]
        XCTAssertEqual(messages?[0], expectedSystem)

        let function: JSONValue = ["name": "search_corpus", "arguments": .string(#"{"query":"lora"}"#)]
        let toolCall: JSONValue = ["id": "call_1", "type": "function", "function": function]
        let expectedAssistant: JSONValue = ["role": "assistant", "content": .null, "tool_calls": [toolCall]]
        XCTAssertEqual(messages?[2], expectedAssistant)

        let expectedResult: JSONValue = ["role": "tool", "tool_call_id": "call_1", "content": "3 hits"]
        XCTAssertEqual(messages?[3], expectedResult)
        let expectedError: JSONValue = ["role": "tool", "tool_call_id": "call_2", "content": "ERROR: boom"]
        XCTAssertEqual(messages?[4], expectedError)
    }
}

final class OpenAIWireResponseTests: XCTestCase {

    func testDecodesTextToolCallsAndUsageWithCost() throws {
        let json = """
        {"id":"x","model":"openai/gpt-4o-mini",
         "choices":[{"message":{"role":"assistant","content":null,
           "tool_calls":[{"id":"call_1","type":"function",
             "function":{"name":"search_corpus","arguments":"{\\"query\\":\\"lora\\"}"}}]},
           "finish_reason":"tool_calls"}],
         "usage":{"prompt_tokens":12,"completion_tokens":5,"cost":0.00042}}
        """
        let response = try OpenAIWire.decodeResponse(Data(json.utf8))
        XCTAssertEqual(response.text, "")
        XCTAssertEqual(response.toolCalls, [LLMToolCall(id: "call_1", name: "search_corpus", arguments: ["query": "lora"])])
        XCTAssertEqual(response.stopReason, .toolUse)
        XCTAssertEqual(response.usage, LLMUsage(inputTokens: 12, outputTokens: 5, costUSD: 0.00042))
        XCTAssertEqual(response.model, "openai/gpt-4o-mini")
    }

    func testPlainTextReply() throws {
        let json = #"{"choices":[{"message":{"role":"assistant","content":"Hello"},"finish_reason":"stop"}]}"#
        let response = try OpenAIWire.decodeResponse(Data(json.utf8))
        XCTAssertEqual(response.text, "Hello")
        XCTAssertEqual(response.stopReason, .endTurn)
        XCTAssertNil(response.usage)
    }

    func testErrorBodyThrowsProviderError() {
        let json = #"{"error":{"message":"No endpoints found","code":404}}"#
        XCTAssertThrowsError(try OpenAIWire.decodeResponse(Data(json.utf8))) { error in
            XCTAssertEqual(error as? LLMCompletionError, .provider("No endpoints found"))
        }
    }

    func testMalformedArgumentsArePreservedVerbatim() {
        XCTAssertEqual(OpenAIWire.parseArguments("{not json"), .string("{not json"))
        XCTAssertEqual(OpenAIWire.parseArguments(""), .object([:]))
    }
}

final class OpenAIStreamAccumulatorTests: XCTestCase {

    private func run(_ lines: [String]) throws -> [LLMStreamEvent] {
        var accumulator = OpenAIStreamAccumulator()
        var events: [LLMStreamEvent] = []
        for line in lines { events += try accumulator.consume(line) }
        events += accumulator.finish()
        return events
    }

    func testTextDeltasThenCompleted() throws {
        let events = try run([
            ": OPENROUTER PROCESSING",
            #"data: {"model":"m","choices":[{"delta":{"content":"Hel"}}]}"#,
            #"data: {"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}]}"#,
            #"data: {"choices":[],"usage":{"prompt_tokens":3,"completion_tokens":2}}"#,
            "data: [DONE]",
        ])
        XCTAssertEqual(events, [
            .textDelta("Hel"),
            .textDelta("lo"),
            .completed(LLMResponse(message: .assistant("Hello"), stopReason: .endTurn,
                                   usage: LLMUsage(inputTokens: 3, outputTokens: 2), model: "m")),
        ])
    }

    func testAssemblesToolCallArgumentsAcrossChunks() throws {
        let events = try run([
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"search_corpus","arguments":""}}]}}]}"#,
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"que"}}]}}]}"#,
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ry\":\"lora\"}"}}]}}]}"#,
            #"data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#,
            "data: [DONE]",
        ])
        let call = LLMToolCall(id: "call_1", name: "search_corpus", arguments: ["query": "lora"])
        XCTAssertEqual(events, [
            .toolCall(call),
            .completed(LLMResponse(message: .assistant("", toolCalls: [call]), stopReason: .toolUse,
                                   usage: nil, model: nil)),
        ])
    }

    func testFinishIsIdempotentAfterDone() throws {
        var accumulator = OpenAIStreamAccumulator()
        _ = try accumulator.consume("data: [DONE]")
        XCTAssertTrue(accumulator.isFinished)
        XCTAssertEqual(accumulator.finish(), [])
    }

    func testInBandErrorThrows() {
        var accumulator = OpenAIStreamAccumulator()
        XCTAssertThrowsError(try accumulator.consume(#"data: {"error":{"message":"Rate limit exceeded"}}"#)) { error in
            XCTAssertEqual(error as? LLMCompletionError, .provider("Rate limit exceeded"))
            XCTAssertTrue((error as? LLMCompletionError)?.isRetryable ?? false)
        }
    }
}
