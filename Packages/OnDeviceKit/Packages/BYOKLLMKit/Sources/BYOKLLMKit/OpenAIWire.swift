import Foundation

/// Request/response mapping for the OpenAI-compatible chat-completions schema
/// (OpenRouter, OpenAI, xAI, DeepSeek, Groq, Together). Pure and static so the
/// wire format is unit-testable without a network.
enum OpenAIWire {

    // MARK: Request

    static func requestBody(for request: LLMRequest, model: String, stream: Bool) -> JSONValue {
        var body: [String: JSONValue] = [:]
        body["model"] = .string(model)
        body["messages"] = .array(request.messages.flatMap(encodeMessage))
        body["stream"] = .bool(stream)

        if let maxTokens = request.maxTokens {
            // OpenAI's reasoning models reject `max_tokens`; everyone else
            // (including OpenRouter, which translates) accepts it.
            let key = request.provider == .openai ? "max_completion_tokens" : "max_tokens"
            body[key] = .int(maxTokens)
        }
        if let temperature = request.temperature {
            body["temperature"] = .double(temperature)
        }
        if !request.tools.isEmpty {
            body["tools"] = .array(request.tools.map(encodeTool))
        }
        if let choice = request.toolChoice {
            body["tool_choice"] = encodeToolChoice(choice)
        }
        switch request.responseFormat {
        case .jsonObject:
            body["response_format"] = .object(["type": "json_object"])
        case .jsonSchema(let name, let schema, let strict):
            var spec: [String: JSONValue] = [:]
            spec["name"] = .string(name)
            spec["schema"] = schema
            spec["strict"] = .bool(strict)
            body["response_format"] = .object(["type": "json_schema", "json_schema": .object(spec)])
        case nil:
            break
        }
        if stream && request.provider == .openai {
            body["stream_options"] = .object(["include_usage": true])
        }
        if request.provider == .openrouter {
            // Asks OpenRouter to report token counts and billed cost.
            body["usage"] = .object(["include": true])
        }
        return .object(body)
    }

    static func encodeMessage(_ message: LLMChatMessage) -> [JSONValue] {
        switch message.role {
        case .system, .user:
            // Tool results can't live inside a user message in this schema;
            // emit them as separate `tool` messages first.
            var out = message.toolResults.map(encodeToolResult)
            let text = message.text
            if !text.isEmpty || out.isEmpty {
                out.append(.object(["role": .string(message.role.rawValue), "content": .string(text)]))
            }
            return out

        case .assistant:
            var object: [String: JSONValue] = ["role": "assistant"]
            let text = message.text
            let calls = message.toolCalls
            object["content"] = text.isEmpty && !calls.isEmpty ? JSONValue.null : JSONValue.string(text)
            if !calls.isEmpty {
                object["tool_calls"] = .array(calls.map { call -> JSONValue in
                    var function: [String: JSONValue] = [:]
                    function["name"] = .string(call.name)
                    function["arguments"] = .string(call.arguments.jsonString)
                    return .object(["id": .string(call.id), "type": "function", "function": .object(function)])
                })
            }
            return [.object(object)]

        case .tool:
            return message.toolResults.map(encodeToolResult)
        }
    }

    static func encodeToolResult(_ result: LLMToolResult) -> JSONValue {
        // The schema has no error flag, so errors are marked in the content.
        let content = result.isError ? "ERROR: \(result.content)" : result.content
        return .object(["role": "tool", "tool_call_id": .string(result.callID), "content": .string(content)])
    }

    static func encodeTool(_ tool: LLMTool) -> JSONValue {
        var function: [String: JSONValue] = [:]
        function["name"] = .string(tool.name)
        function["description"] = .string(tool.description)
        function["parameters"] = tool.inputSchema
        return .object(["type": "function", "function": .object(function)])
    }

    static func encodeToolChoice(_ choice: LLMToolChoice) -> JSONValue {
        switch choice {
        case .auto:     return "auto"
        case .none:     return "none"
        case .required: return "required"
        case .tool(let name):
            return .object(["type": "function", "function": .object(["name": .string(name)])])
        }
    }

    // MARK: Response

    static func decodeResponse(_ data: Data) throws -> LLMResponse {
        let json: JSONValue
        do {
            json = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw LLMCompletionError.malformedResponse(String(decoding: data.prefix(500), as: UTF8.self))
        }
        if let error = json["error"], error != .null {
            throw LLMCompletionError.provider(errorMessage(error))
        }
        guard let choice = json["choices"]?.arrayValue?.first, let message = choice["message"] else {
            throw LLMCompletionError.malformedResponse("no choices in response")
        }

        var blocks: [LLMContentBlock] = []
        if let text = message["content"]?.stringValue, !text.isEmpty {
            blocks.append(.text(text))
        }
        let calls = (message["tool_calls"]?.arrayValue ?? []).map { call in
            LLMToolCall(id: call["id"]?.stringValue ?? "",
                        name: call["function"]?["name"]?.stringValue ?? "",
                        arguments: parseArguments(call["function"]?["arguments"]?.stringValue ?? ""))
        }
        blocks += calls.map { LLMContentBlock.toolCall($0) }

        return LLMResponse(message: LLMChatMessage(role: .assistant, content: blocks),
                           stopReason: stopReason(choice["finish_reason"]?.stringValue, hasToolCalls: !calls.isEmpty),
                           usage: json["usage"].flatMap(usage(from:)),
                           model: json["model"]?.stringValue)
    }

    static func parseArguments(_ raw: String) -> JSONValue {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .object([:]) }
        return (try? JSONValue.parse(trimmed)) ?? .string(raw)
    }

    static func stopReason(_ reason: String?, hasToolCalls: Bool) -> LLMStopReason {
        switch reason {
        case "stop":                         return hasToolCalls ? .toolUse : .endTurn
        case "tool_calls", "function_call":  return .toolUse
        case "length":                       return .maxTokens
        case "content_filter":               return .contentFilter
        case nil:                            return hasToolCalls ? .toolUse : .endTurn
        case let other?:                     return .other(other)
        }
    }

    static func usage(from json: JSONValue) -> LLMUsage? {
        guard let input = json["prompt_tokens"]?.intValue,
              let output = json["completion_tokens"]?.intValue else { return nil }
        return LLMUsage(inputTokens: input, outputTokens: output, costUSD: json["cost"]?.doubleValue)
    }

    static func errorMessage(_ error: JSONValue) -> String {
        error["message"]?.stringValue ?? error.stringValue ?? error.jsonString
    }
}

// MARK: - SSE

enum SSE {
    /// The payload of an SSE `data:` line, or `nil` for any other line
    /// (comments, `event:` lines, blank keep-alives).
    static func dataPayload(_ line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        var payload = line.dropFirst(5)
        if payload.first == " " { payload = payload.dropFirst() }
        return String(payload)
    }
}

// MARK: - Streaming

/// Assembles an OpenAI-compatible SSE stream into `LLMStreamEvent`s. Feed it
/// every line; call `finish()` if the stream ends without `[DONE]`.
struct OpenAIStreamAccumulator {
    private struct PartialToolCall {
        var id = ""
        var name = ""
        var arguments = ""
    }

    private var text = ""
    private var partialCalls: [Int: PartialToolCall] = [:]
    private var finishReason: String?
    private var usage: LLMUsage?
    private var model: String?
    private(set) var isFinished = false

    mutating func consume(_ line: String) throws -> [LLMStreamEvent] {
        guard !isFinished, let payload = SSE.dataPayload(line) else { return [] }
        if payload == "[DONE]" { return finish() }
        guard let json = try? JSONValue.parse(payload) else { return [] }

        if let error = json["error"], error != .null {
            throw LLMCompletionError.provider(OpenAIWire.errorMessage(error))
        }
        if let name = json["model"]?.stringValue { model = name }
        if let usageJSON = json["usage"], let parsed = OpenAIWire.usage(from: usageJSON) {
            usage = parsed
        }

        guard let choice = json["choices"]?.arrayValue?.first else { return [] }
        var events: [LLMStreamEvent] = []
        if let piece = choice["delta"]?["content"]?.stringValue, !piece.isEmpty {
            text += piece
            events.append(.textDelta(piece))
        }
        for call in choice["delta"]?["tool_calls"]?.arrayValue ?? [] {
            let index = call["index"]?.intValue ?? 0
            var partial = partialCalls[index] ?? PartialToolCall()
            if let id = call["id"]?.stringValue, !id.isEmpty { partial.id = id }
            if let name = call["function"]?["name"]?.stringValue, !name.isEmpty, partial.name.isEmpty {
                partial.name = name
            }
            if let fragment = call["function"]?["arguments"]?.stringValue {
                partial.arguments += fragment
            }
            partialCalls[index] = partial
        }
        if let reason = choice["finish_reason"]?.stringValue {
            finishReason = reason
        }
        return events
    }

    /// Emits the completed tool calls and the final `.completed` event. Idempotent.
    mutating func finish() -> [LLMStreamEvent] {
        guard !isFinished else { return [] }
        isFinished = true

        let calls = partialCalls.keys.sorted().compactMap { partialCalls[$0] }.map { partial in
            LLMToolCall(id: partial.id, name: partial.name,
                        arguments: OpenAIWire.parseArguments(partial.arguments))
        }
        var blocks: [LLMContentBlock] = text.isEmpty ? [] : [LLMContentBlock.text(text)]
        blocks += calls.map { LLMContentBlock.toolCall($0) }

        let response = LLMResponse(message: LLMChatMessage(role: .assistant, content: blocks),
                                   stopReason: OpenAIWire.stopReason(finishReason, hasToolCalls: !calls.isEmpty),
                                   usage: usage,
                                   model: model)
        var events: [LLMStreamEvent] = calls.map { LLMStreamEvent.toolCall($0) }
        events.append(.completed(response))
        return events
    }
}
