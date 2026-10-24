import XCTest
@testable import BYOKLLMKit

final class AnthropicWireRequestTests: XCTestCase {

    func testLiftsSystemAndDefaultsMaxTokens() {
        let body = AnthropicWire.requestBody(
            for: LLMRequest(provider: .anthropic, model: "m", messages: [.system("a"), .system("b"), .user("hi")]),
            model: "claude-sonnet-5", stream: false)

        XCTAssertEqual(body["system"], JSONValue.string("a\n\nb"))
        XCTAssertEqual(body["max_tokens"], JSONValue.int(4096))
        XCTAssertEqual(body["model"], JSONValue.string("claude-sonnet-5"))
        XCTAssertNil(body["stream"])

        let text: JSONValue = ["type": "text", "text": "hi"]
        let expectedMessages: JSONValue = [["role": "user", "content": [text]]]
        XCTAssertEqual(body["messages"], expectedMessages)
    }

    func testToolTurnsBecomeUserToolResultsAndSameRolesMerge() {
        let call = LLMToolCall(id: "toolu_1", name: "search_corpus", arguments: ["query": "lora"])
        let messages = AnthropicWire.encodeMessages([
            .user("find lora"),
            .assistant("Searching.", toolCalls: [call]),
            .toolResult(callID: "toolu_1", content: "3 hits"),
            .toolResult(callID: "toolu_2", content: "boom", isError: true),
            .user("thanks"),
        ])

        XCTAssertEqual(messages.count, 3, "tool results and the following user turn merge into one user turn")

        let text: JSONValue = ["type": "text", "text": "Searching."]
        let toolUse: JSONValue = ["type": "tool_use", "id": "toolu_1", "name": "search_corpus", "input": ["query": "lora"]]
        let expectedAssistant: JSONValue = ["role": "assistant", "content": [text, toolUse]]
        XCTAssertEqual(messages[1], expectedAssistant)

        let ok: JSONValue = ["type": "tool_result", "tool_use_id": "toolu_1", "content": "3 hits"]
        let failed: JSONValue = ["type": "tool_result", "tool_use_id": "toolu_2", "content": "boom", "is_error": true]
        let thanks: JSONValue = ["type": "text", "text": "thanks"]
        let expectedUser: JSONValue = ["role": "user", "content": [ok, failed, thanks]]
        XCTAssertEqual(messages[2], expectedUser)
    }

    func testDropsEmptyTextBlocks() {
        XCTAssertEqual(AnthropicWire.encodeMessages([.user("")]), [])
    }

    func testToolsAndChoiceMapping() {
        let tool = LLMTool(name: "t", description: "d", inputSchema: ["type": "object"])
        let body = AnthropicWire.requestBody(
            for: LLMRequest(provider: .anthropic, model: "m", messages: [.user("x")], tools: [tool], toolChoice: .required),
            model: "m", stream: true)

        let expectedTool: JSONValue = ["name": "t", "description": "d", "input_schema": ["type": "object"]]
        XCTAssertEqual(body["tools"], JSONValue.array([expectedTool]))
        let expectedChoice: JSONValue = ["type": "any"]
        XCTAssertEqual(body["tool_choice"], expectedChoice)
        XCTAssertEqual(body["stream"], JSONValue.bool(true))

        XCTAssertEqual(AnthropicWire.encodeToolChoice(.none), JSONValue.object(["type": "none"]))
        XCTAssertEqual(AnthropicWire.encodeToolChoice(.auto), JSONValue.object(["type": "auto"]))
    }

    func testJSONSchemaBecomesForcedTool() {
        let schema: JSONValue = ["type": "object", "properties": ["label": ["type": "string"]]]
        let request = LLMRequest(provider: .anthropic, model: "m", messages: [.user("x")],
                                 responseFormat: .jsonSchema(name: "entity", schema: schema))
        let body = AnthropicWire.requestBody(for: request, model: "m", stream: false)

        XCTAssertEqual(AnthropicWire.structuredToolName(for: request), "entity")
        XCTAssertEqual(body["tools"]?.arrayValue?.first?["name"], JSONValue.string("entity"))
        XCTAssertEqual(body["tools"]?.arrayValue?.first?["input_schema"], schema)
        let expectedChoice: JSONValue = ["type": "tool", "name": "entity"]
        XCTAssertEqual(body["tool_choice"], expectedChoice)
    }

    func testJSONObjectAddsSystemInstruction() {
        let body = AnthropicWire.requestBody(
            for: LLMRequest(provider: .anthropic, model: "m", messages: [.user("x")], responseFormat: .jsonObject),
            model: "m", stream: false)
        XCTAssertEqual(body["system"]?.stringValue, "Respond with valid JSON only, no markdown.")
    }
}

final class AnthropicWireResponseTests: XCTestCase {

    func testDecodesTextToolUseAndUsage() throws {
        let json = """
        {"id":"msg_1","type":"message","role":"assistant","model":"claude-sonnet-5",
         "content":[{"type":"text","text":"Let me check."},
                    {"type":"tool_use","id":"toolu_1","name":"search_corpus","input":{"query":"lora"}}],
         "stop_reason":"tool_use","usage":{"input_tokens":20,"output_tokens":9}}
        """
        let response = try AnthropicWire.decodeResponse(Data(json.utf8), structuredToolName: nil)
        XCTAssertEqual(response.text, "Let me check.")
        XCTAssertEqual(response.toolCalls, [LLMToolCall(id: "toolu_1", name: "search_corpus", arguments: ["query": "lora"])])
        XCTAssertEqual(response.stopReason, .toolUse)
        XCTAssertEqual(response.usage, LLMUsage(inputTokens: 20, outputTokens: 9))
        XCTAssertEqual(response.model, "claude-sonnet-5")
    }

    func testFoldsForcedToolIntoJSONText() throws {
        let json = """
        {"content":[{"type":"tool_use","id":"toolu_1","name":"entity","input":{"label":"LoRA"}}],
         "stop_reason":"tool_use","usage":{"input_tokens":1,"output_tokens":1}}
        """
        let response = try AnthropicWire.decodeResponse(Data(json.utf8), structuredToolName: "entity")
        XCTAssertEqual(response.text, #"{"label":"LoRA"}"#)
        XCTAssertEqual(response.toolCalls, [])
        XCTAssertEqual(response.stopReason, .endTurn)
    }

    func testErrorBodyThrowsProviderError() {
        let json = #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
        XCTAssertThrowsError(try AnthropicWire.decodeResponse(Data(json.utf8), structuredToolName: nil)) { error in
            XCTAssertEqual(error as? LLMCompletionError, .provider("Overloaded"))
            XCTAssertTrue((error as? LLMCompletionError)?.isRetryable ?? false)
        }
    }
}

final class AnthropicStreamAccumulatorTests: XCTestCase {

    private func run(_ lines: [String], structuredToolName: String? = nil) throws -> [LLMStreamEvent] {
        var accumulator = AnthropicStreamAccumulator(structuredToolName: structuredToolName)
        var events: [LLMStreamEvent] = []
        for line in lines { events += try accumulator.consume(line) }
        events += accumulator.finish()
        return events
    }

    func testTextStream() throws {
        let events = try run([
            "event: message_start",
            #"data: {"type":"message_start","message":{"model":"claude-sonnet-5","usage":{"input_tokens":10,"output_tokens":1}}}"#,
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"data: {"type":"ping"}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}"#,
            #"data: {"type":"content_block_stop","index":0}"#,
            #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}"#,
            #"data: {"type":"message_stop"}"#,
        ])
        XCTAssertEqual(events, [
            .textDelta("Hel"),
            .textDelta("lo"),
            .completed(LLMResponse(message: .assistant("Hello"), stopReason: .endTurn,
                                   usage: LLMUsage(inputTokens: 10, outputTokens: 5), model: "claude-sonnet-5")),
        ])
    }

    func testToolUseStreamAssemblesInput() throws {
        let events = try run([
            #"data: {"type":"message_start","message":{"model":"m","usage":{"input_tokens":3,"output_tokens":1}}}"#,
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"search_corpus","input":{}}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"que"}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"ry\": \"lora\"}"}}"#,
            #"data: {"type":"content_block_stop","index":0}"#,
            #"data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":7}}"#,
            #"data: {"type":"message_stop"}"#,
        ])
        let call = LLMToolCall(id: "toolu_1", name: "search_corpus", arguments: ["query": "lora"])
        XCTAssertEqual(events, [
            .toolCall(call),
            .completed(LLMResponse(message: .assistant("", toolCalls: [call]), stopReason: .toolUse,
                                   usage: LLMUsage(inputTokens: 3, outputTokens: 7), model: "m")),
        ])
    }

    func testStructuredToolIsFoldedAndNotEmittedAsToolCall() throws {
        let events = try run([
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"toolu_1","name":"entity","input":{}}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta","partial_json":"{\"label\":\"LoRA\"}"}}"#,
            #"data: {"type":"content_block_stop","index":0}"#,
            #"data: {"type":"message_stop"}"#,
        ], structuredToolName: "entity")
        XCTAssertEqual(events.count, 1)
        guard case .completed(let response)? = events.first else { return XCTFail("expected .completed") }
        XCTAssertEqual(response.text, #"{"label":"LoRA"}"#)
        XCTAssertEqual(response.toolCalls, [])
    }

    func testErrorEventThrows() {
        var accumulator = AnthropicStreamAccumulator(structuredToolName: nil)
        let line = #"data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
        XCTAssertThrowsError(try accumulator.consume(line)) { error in
            XCTAssertEqual(error as? LLMCompletionError, .provider("Overloaded"))
        }
    }
}
