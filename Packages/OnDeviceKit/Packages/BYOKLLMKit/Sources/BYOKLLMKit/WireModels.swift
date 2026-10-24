import Foundation

// MARK: - Chat message

/// A single chat turn in provider-agnostic form.
public struct LLMMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - OpenAI-compatible wire format (OpenRouter, OpenAI, DeepSeek, Groq, Together)

struct OpenRouterRequest: Codable {
    let model: String
    let messages: [LLMMessage]
    let stream: Bool
}

struct OpenRouterResponse: Codable {
    let id: String
    let choices: [OpenRouterChoice]
    let usage: OpenRouterUsage?
}

struct OpenRouterChoice: Codable {
    let message: OpenRouterMessage
}

struct OpenRouterMessage: Codable {
    let role: String
    let content: String
}

struct OpenRouterUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

// MARK: - OpenAI-compatible SSE streaming chunk

struct OpenRouterStreamChunk: Codable {
    let choices: [OpenRouterStreamChoice]
}

struct OpenRouterStreamChoice: Codable {
    let delta: OpenRouterDelta
}

struct OpenRouterDelta: Codable {
    let content: String?
}

// MARK: - Anthropic wire format

struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContentBlock]
}

struct AnthropicContentBlock: Codable {
    let type: String
    let text: String
}

struct AnthropicResponse: Codable {
    let id: String
    let content: [AnthropicContentBlock]
    let model: String
    let usage: AnthropicUsage?
}

struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens  = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
