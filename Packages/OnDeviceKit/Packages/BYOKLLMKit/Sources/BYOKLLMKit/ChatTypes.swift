import Foundation

// MARK: - Tools

/// A function the model may call. `inputSchema` is a JSON Schema object
/// describing the arguments.
public struct LLMTool: Sendable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue

    public init(name: String, description: String, inputSchema: JSONValue) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// A tool invocation requested by the model.
public struct LLMToolCall: Sendable, Equatable {
    /// Provider-assigned id; echo it back in the matching `LLMToolResult`.
    public let id: String
    public let name: String
    /// Parsed arguments. If a provider returns arguments that aren't valid
    /// JSON, they're preserved verbatim as `.string`.
    public let arguments: JSONValue

    public init(id: String, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    public func decodeArguments<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try arguments.decode(as: type)
    }
}

/// The result of executing an `LLMToolCall`, sent back to the model.
public struct LLMToolResult: Sendable, Equatable {
    public let callID: String
    public let content: String
    public let isError: Bool

    public init(callID: String, content: String, isError: Bool = false) {
        self.callID = callID
        self.content = content
        self.isError = isError
    }
}

public enum LLMToolChoice: Sendable, Equatable {
    /// The model decides whether to call a tool.
    case auto
    /// The model must not call a tool.
    case none
    /// The model must call at least one tool.
    case required
    /// The model must call the named tool.
    case tool(String)
}

// MARK: - Messages

public enum LLMContentBlock: Sendable, Equatable {
    case text(String)
    case toolCall(LLMToolCall)
    case toolResult(LLMToolResult)
}

/// A chat turn that can carry tool calls and tool results — the richer
/// counterpart of `LLMMessage`, used by `LLMCompleting`.
public struct LLMChatMessage: Sendable, Equatable {
    public enum Role: String, Sendable, Equatable {
        case system, user, assistant, tool
    }

    public var role: Role
    public var content: [LLMContentBlock]

    public init(role: Role, content: [LLMContentBlock]) {
        self.role = role
        self.content = content
    }

    /// Bridges a plain-text `LLMMessage`. Unknown role strings map to `.user`.
    public init(_ message: LLMMessage) {
        self.role = Role(rawValue: message.role) ?? .user
        self.content = [.text(message.content)]
    }

    public static func system(_ text: String) -> LLMChatMessage {
        LLMChatMessage(role: .system, content: [.text(text)])
    }

    public static func user(_ text: String) -> LLMChatMessage {
        LLMChatMessage(role: .user, content: [.text(text)])
    }

    public static func assistant(_ text: String, toolCalls: [LLMToolCall] = []) -> LLMChatMessage {
        var blocks: [LLMContentBlock] = text.isEmpty ? [] : [LLMContentBlock.text(text)]
        blocks += toolCalls.map { LLMContentBlock.toolCall($0) }
        return LLMChatMessage(role: .assistant, content: blocks)
    }

    public static func toolResult(callID: String, content: String, isError: Bool = false) -> LLMChatMessage {
        LLMChatMessage(role: .tool,
                       content: [.toolResult(LLMToolResult(callID: callID, content: content, isError: isError))])
    }

    /// All text blocks, concatenated.
    public var text: String {
        content.compactMap { block -> String? in
            if case .text(let text) = block { return text }
            return nil
        }.joined()
    }

    public var toolCalls: [LLMToolCall] {
        content.compactMap { block -> LLMToolCall? in
            if case .toolCall(let call) = block { return call }
            return nil
        }
    }

    public var toolResults: [LLMToolResult] {
        content.compactMap { block -> LLMToolResult? in
            if case .toolResult(let result) = block { return result }
            return nil
        }
    }
}

// MARK: - Request

public enum LLMResponseFormat: Sendable, Equatable {
    /// Any valid JSON object. OpenAI-compatible providers get
    /// `response_format: json_object`; Anthropic gets a JSON-only instruction.
    case jsonObject
    /// JSON matching `schema`. OpenAI-compatible providers get
    /// `response_format: json_schema`; Anthropic gets a forced tool call whose
    /// input is folded back into the reply text. Either way,
    /// `LLMResponse.text` holds the JSON.
    case jsonSchema(name: String, schema: JSONValue, strict: Bool = true)
}

public struct LLMRequest: Sendable, Equatable {
    public var provider: LLMProvider
    /// Empty means the service's default model.
    public var model: String
    public var messages: [LLMChatMessage]
    public var tools: [LLMTool]
    public var toolChoice: LLMToolChoice?
    public var responseFormat: LLMResponseFormat?
    /// `nil` omits the limit for OpenAI-compatible providers; Anthropic
    /// requires one and falls back to 4096.
    public var maxTokens: Int?
    public var temperature: Double?

    public init(provider: LLMProvider,
                model: String,
                messages: [LLMChatMessage],
                tools: [LLMTool] = [],
                toolChoice: LLMToolChoice? = nil,
                responseFormat: LLMResponseFormat? = nil,
                maxTokens: Int? = nil,
                temperature: Double? = nil) {
        self.provider = provider
        self.model = model
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.responseFormat = responseFormat
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

// MARK: - Response

public struct LLMUsage: Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    /// Billed cost when the provider reports it (OpenRouter does); else `nil`.
    public let costUSD: Double?

    public init(inputTokens: Int, outputTokens: Int, costUSD: Double? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
    }
}

public enum LLMStopReason: Sendable, Equatable {
    case endTurn
    case toolUse
    case maxTokens
    case stopSequence
    case contentFilter
    case other(String)
}

public struct LLMResponse: Sendable, Equatable {
    /// The assistant turn, ready to append to the conversation as-is.
    public let message: LLMChatMessage
    public let stopReason: LLMStopReason
    public let usage: LLMUsage?
    /// The model that actually served the request, when reported.
    public let model: String?

    public init(message: LLMChatMessage, stopReason: LLMStopReason, usage: LLMUsage?, model: String?) {
        self.message = message
        self.stopReason = stopReason
        self.usage = usage
        self.model = model
    }

    public var text: String { message.text }
    public var toolCalls: [LLMToolCall] { message.toolCalls }
}

public enum LLMStreamEvent: Sendable, Equatable {
    /// An incremental piece of assistant text.
    case textDelta(String)
    /// A tool call whose arguments have been fully received.
    case toolCall(LLMToolCall)
    /// The fully assembled response (including usage). Always the last event.
    case completed(LLMResponse)
}

// MARK: - Errors

/// Errors thrown by the `LLMCompleting` API. Kept separate from `LLMError` so
/// hosts that switch exhaustively over `LLMError` keep compiling; missing keys
/// and unknown providers are still reported as `LLMError`.
public enum LLMCompletionError: LocalizedError, Sendable, Equatable {
    /// Non-2xx HTTP status, with (a prefix of) the response body.
    case http(status: Int, body: String)
    /// The provider reported an error in-band (JSON error body or SSE error event).
    case provider(String)
    /// The response couldn't be interpreted.
    case malformedResponse(String)
    /// `generateStructured` was called without a `responseFormat`.
    case missingResponseFormat
    /// The model's structured output didn't decode into the requested type.
    case invalidStructuredOutput(String)

    /// Whether retrying (or rotating to another model) could plausibly
    /// succeed: rate limits, timeouts, and server-side failures.
    public var isRetryable: Bool {
        switch self {
        case .http(let status, _):
            return status == 408 || status == 429 || (500...599).contains(status)
        case .provider(let message):
            let lower = message.lowercased()
            return lower.contains("overloaded") || lower.contains("rate limit")
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .http(let status, let body):
            return "HTTP \(status): \(body)"
        case .provider(let message):
            return "Provider error: \(message)"
        case .malformedResponse(let detail):
            return "Malformed response: \(detail)"
        case .missingResponseFormat:
            return "generateStructured requires a responseFormat on the request."
        case .invalidStructuredOutput(let detail):
            return "Structured output didn't match the requested type: \(detail)"
        }
    }
}

// MARK: - Protocol

/// Tool-calling, structured-output and streaming chat completion. `LLMService`
/// conforms; tests can inject a fake.
public protocol LLMCompleting: Sendable {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}

public extension LLMCompleting {
    /// Runs `request` (which must set `responseFormat`) and decodes the JSON
    /// reply into `T`. Markdown code fences around the JSON are tolerated.
    func generateStructured<T: Decodable>(_ request: LLMRequest, as type: T.Type = T.self) async throws -> T {
        guard request.responseFormat != nil else { throw LLMCompletionError.missingResponseFormat }
        let response = try await complete(request)
        let json = LLMService.stripCodeFences(response.text)
        do {
            return try JSONDecoder().decode(T.self, from: Data(json.utf8))
        } catch {
            throw LLMCompletionError.invalidStructuredOutput("\(error)")
        }
    }
}
