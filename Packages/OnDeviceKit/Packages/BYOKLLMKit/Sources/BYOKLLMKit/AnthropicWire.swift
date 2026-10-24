import Foundation

/// Request/response mapping for Anthropic's Messages API. Pure and static so
/// the wire format is unit-testable without a network.
enum AnthropicWire {
    static let apiVersion = "2023-06-01"
    static let defaultMaxTokens = 4096

    /// For `.jsonSchema` requests, Anthropic is forced to call a tool with this
    /// name; its input is folded back into the reply as JSON text.
    static func structuredToolName(for request: LLMRequest) -> String? {
        guard case .jsonSchema(let name, _, _)? = request.responseFormat else { return nil }
        return name
    }

    // MARK: Request

    static func requestBody(for request: LLMRequest, model: String, stream: Bool) -> JSONValue {
        var body: [String: JSONValue] = [:]
        body["model"] = .string(model)
        body["max_tokens"] = .int(request.maxTokens ?? defaultMaxTokens)
        if stream { body["stream"] = .bool(true) }
        if let temperature = request.temperature {
            body["temperature"] = .double(temperature)
        }

        var systemParts = request.messages.filter { $0.role == .system }.map(\.text).filter { !$0.isEmpty }
        if case .jsonObject? = request.responseFormat {
            systemParts.append("Respond with valid JSON only, no markdown.")
        }
        if !systemParts.isEmpty {
            body["system"] = .string(systemParts.joined(separator: "\n\n"))
        }
        body["messages"] = .array(encodeMessages(request.messages))

        var tools = request.tools.map(encodeTool)
        var toolChoice = request.toolChoice.map(encodeToolChoice)
        if case .jsonSchema(let name, let schema, _)? = request.responseFormat {
            tools.append(encodeTool(LLMTool(name: name,
                                            description: "Return the final answer as structured data matching this schema.",
                                            inputSchema: schema)))
            toolChoice = encodeToolChoice(.tool(name))
        }
        if !tools.isEmpty {
            body["tools"] = .array(tools)
        }
        if let toolChoice {
            body["tool_choice"] = toolChoice
        }
        return .object(body)
    }

    /// System turns are lifted out (see `requestBody`); `tool` turns become
    /// `user` turns carrying `tool_result` blocks; consecutive turns with the
    /// same role are merged, as the API requires alternating roles.
    static func encodeMessages(_ messages: [LLMChatMessage]) -> [JSONValue] {
        var out: [JSONValue] = []
        var currentRole: String?
        var currentBlocks: [JSONValue] = []

        func flush() {
            if let role = currentRole, !currentBlocks.isEmpty {
                out.append(.object(["role": .string(role), "content": .array(currentBlocks)]))
            }
            currentRole = nil
            currentBlocks = []
        }

        for message in messages where message.role != .system {
            let role = message.role == .assistant ? "assistant" : "user"
            let blocks = message.content.compactMap(encodeBlock)
            guard !blocks.isEmpty else { continue }
            if role != currentRole {
                flush()
                currentRole = role
            }
            currentBlocks += blocks
        }
        flush()
        return out
    }

    static func encodeBlock(_ block: LLMContentBlock) -> JSONValue? {
        switch block {
        case .text(let text):
            // The API rejects empty text blocks.
            guard !text.isEmpty else { return nil }
            return .object(["type": "text", "text": .string(text)])
        case .toolCall(let call):
            var object: [String: JSONValue] = ["type": "tool_use"]
            object["id"] = .string(call.id)
            object["name"] = .string(call.name)
            // `input` must be an object.
            if case .object = call.arguments {
                object["input"] = call.arguments
            } else {
                object["input"] = .object([:])
            }
            return .object(object)
        case .toolResult(let result):
            var object: [String: JSONValue] = ["type": "tool_result"]
            object["tool_use_id"] = .string(result.callID)
            object["content"] = .string(result.content)
            if result.isError { object["is_error"] = .bool(true) }
            return .object(object)
        }
    }

    static func encodeTool(_ tool: LLMTool) -> JSONValue {
        var object: [String: JSONValue] = [:]
        object["name"] = .string(tool.name)
        object["description"] = .string(tool.description)
        object["input_schema"] = tool.inputSchema
        return .object(object)
    }

    static func encodeToolChoice(_ choice: LLMToolChoice) -> JSONValue {
        switch choice {
        case .auto:           return .object(["type": "auto"])
        case .none:           return .object(["type": "none"])
        case .required:       return .object(["type": "any"])
        case .tool(let name): return .object(["type": "tool", "name": .string(name)])
        }
    }

    // MARK: Response

    static func decodeResponse(_ data: Data, structuredToolName: String?) throws -> LLMResponse {
        let json: JSONValue
        do {
            json = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch {
            throw LLMCompletionError.malformedResponse(String(decoding: data.prefix(500), as: UTF8.self))
        }
        if json["type"]?.stringValue == "error" {
            throw LLMCompletionError.provider(errorMessage(json["error"] ?? json))
        }
        guard let content = json["content"]?.arrayValue else {
            throw LLMCompletionError.malformedResponse("no content in response")
        }

        let blocks = content.compactMap { block -> LLMContentBlock? in
            switch block["type"]?.stringValue {
            case "text":
                return LLMContentBlock.text(block["text"]?.stringValue ?? "")
            case "tool_use":
                return LLMContentBlock.toolCall(LLMToolCall(id: block["id"]?.stringValue ?? "",
                                                            name: block["name"]?.stringValue ?? "",
                                                            arguments: block["input"] ?? .object([:])))
            default:
                return nil  // e.g. thinking blocks
            }
        }

        let response = LLMResponse(message: LLMChatMessage(role: .assistant, content: blocks),
                                   stopReason: stopReason(json["stop_reason"]?.stringValue),
                                   usage: usage(input: json["usage"]?["input_tokens"]?.intValue,
                                                output: json["usage"]?["output_tokens"]?.intValue),
                                   model: json["model"]?.stringValue)
        return foldStructuredOutput(response, toolName: structuredToolName)
    }

    /// Replaces the forced structured-output tool call with its input as JSON
    /// text, so callers read structured output from `text` for every provider.
    static func foldStructuredOutput(_ response: LLMResponse, toolName: String?) -> LLMResponse {
        guard let toolName,
              let call = response.toolCalls.first(where: { $0.name == toolName }) else { return response }
        return LLMResponse(message: LLMChatMessage(role: .assistant,
                                                   content: [LLMContentBlock.text(call.arguments.jsonString)]),
                           stopReason: .endTurn,
                           usage: response.usage,
                           model: response.model)
    }

    static func stopReason(_ reason: String?) -> LLMStopReason {
        switch reason {
        case "end_turn", nil: return .endTurn
        case "tool_use":      return .toolUse
        case "max_tokens":    return .maxTokens
        case "stop_sequence": return .stopSequence
        case "refusal":       return .contentFilter
        case let other?:      return .other(other)
        }
    }

    static func usage(input: Int?, output: Int?) -> LLMUsage? {
        guard input != nil || output != nil else { return nil }
        return LLMUsage(inputTokens: input ?? 0, outputTokens: output ?? 0)
    }

    static func errorMessage(_ error: JSONValue) -> String {
        error["message"]?.stringValue ?? error.stringValue ?? error.jsonString
    }
}

// MARK: - Streaming

/// Assembles Anthropic's SSE event stream (`message_start`,
/// `content_block_start/delta/stop`, `message_delta`, `message_stop`) into
/// `LLMStreamEvent`s. Only `data:` lines are needed: each payload carries its
/// own `type`.
struct AnthropicStreamAccumulator {
    private enum Block {
        case text(String)
        case toolUse(id: String, name: String, json: String)
    }

    private let structuredToolName: String?
    private var blocks: [Int: Block] = [:]
    private var stopReason: String?
    private var inputTokens: Int?
    private var outputTokens: Int?
    private var model: String?
    private(set) var isFinished = false

    init(structuredToolName: String?) {
        self.structuredToolName = structuredToolName
    }

    mutating func consume(_ line: String) throws -> [LLMStreamEvent] {
        guard !isFinished,
              let payload = SSE.dataPayload(line),
              let json = try? JSONValue.parse(payload) else { return [] }

        switch json["type"]?.stringValue {
        case "message_start":
            model = json["message"]?["model"]?.stringValue
            inputTokens = json["message"]?["usage"]?["input_tokens"]?.intValue
            outputTokens = json["message"]?["usage"]?["output_tokens"]?.intValue
            return []

        case "content_block_start":
            guard let index = json["index"]?.intValue, let block = json["content_block"] else { return [] }
            switch block["type"]?.stringValue {
            case "text":
                blocks[index] = .text(block["text"]?.stringValue ?? "")
            case "tool_use":
                blocks[index] = .toolUse(id: block["id"]?.stringValue ?? "",
                                         name: block["name"]?.stringValue ?? "",
                                         json: "")
            default:
                break
            }
            return []

        case "content_block_delta":
            guard let index = json["index"]?.intValue, let delta = json["delta"] else { return [] }
            let deltaType = delta["type"]?.stringValue ?? ""
            switch (blocks[index], deltaType) {
            case (.text(let soFar)?, "text_delta"):
                let piece = delta["text"]?.stringValue ?? ""
                blocks[index] = .text(soFar + piece)
                return piece.isEmpty ? [] : [LLMStreamEvent.textDelta(piece)]
            case (.toolUse(let id, let name, let soFar)?, "input_json_delta"):
                blocks[index] = .toolUse(id: id, name: name,
                                         json: soFar + (delta["partial_json"]?.stringValue ?? ""))
                return []
            default:
                return []
            }

        case "content_block_stop":
            guard let index = json["index"]?.intValue,
                  case .toolUse(let id, let name, let raw)? = blocks[index],
                  name != structuredToolName else { return [] }
            return [LLMStreamEvent.toolCall(LLMToolCall(id: id, name: name,
                                                        arguments: OpenAIWire.parseArguments(raw)))]

        case "message_delta":
            if let reason = json["delta"]?["stop_reason"]?.stringValue { stopReason = reason }
            if let output = json["usage"]?["output_tokens"]?.intValue { outputTokens = output }
            if let input = json["usage"]?["input_tokens"]?.intValue { inputTokens = input }
            return []

        case "message_stop":
            return finish()

        case "error":
            throw LLMCompletionError.provider(AnthropicWire.errorMessage(json["error"] ?? json))

        default:
            return []  // ping, unknown future events
        }
    }

    /// Emits the final `.completed` event. Idempotent.
    mutating func finish() -> [LLMStreamEvent] {
        guard !isFinished else { return [] }
        isFinished = true

        let content = blocks.keys.sorted().compactMap { index -> LLMContentBlock? in
            switch blocks[index] {
            case .text(let text)?:
                return text.isEmpty ? nil : LLMContentBlock.text(text)
            case .toolUse(let id, let name, let raw)?:
                return LLMContentBlock.toolCall(LLMToolCall(id: id, name: name,
                                                            arguments: OpenAIWire.parseArguments(raw)))
            case nil:
                return nil
            }
        }
        let response = LLMResponse(message: LLMChatMessage(role: .assistant, content: content),
                                   stopReason: AnthropicWire.stopReason(stopReason),
                                   usage: AnthropicWire.usage(input: inputTokens, output: outputTokens),
                                   model: model)
        return [LLMStreamEvent.completed(AnthropicWire.foldStructuredOutput(response, toolName: structuredToolName))]
    }
}
