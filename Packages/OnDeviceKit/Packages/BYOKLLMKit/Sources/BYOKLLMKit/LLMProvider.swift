import Foundation

/// A cloud LLM inference backend reachable with a user-supplied API key.
///
/// All providers share the OpenAI-compatible chat-completions format except
/// `anthropic`, which uses its own message schema — `LLMService` branches on
/// that internally.
public enum LLMProvider: String, CaseIterable, Identifiable, Sendable {
    case openrouter
    case openai
    case anthropic
    case deepseek
    case groq
    case together
    case xai

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openrouter: return "OpenRouter"
        case .openai:     return "OpenAI"
        case .anthropic:  return "Anthropic"
        case .deepseek:   return "DeepSeek"
        case .groq:       return "Groq"
        case .together:   return "Together AI"
        case .xai:        return "xAI (Grok)"
        }
    }

    /// REST base URL for the provider.
    public var baseURL: String {
        switch self {
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .openai:     return "https://api.openai.com/v1"
        case .anthropic:  return "https://api.anthropic.com/v1"
        case .deepseek:   return "https://api.deepseek.com/v1"
        case .groq:       return "https://api.groq.com/openai/v1"
        case .together:   return "https://api.together.xyz/v1"
        case .xai:        return "https://api.x.ai/v1"
        }
    }

    /// Whether this provider uses the OpenAI-compatible chat-completions schema.
    public var isOpenAICompatible: Bool { self != .anthropic }

    /// The Keychain account identifier used to store this provider's API key.
    public var keychainKey: String { "llm_key_\(rawValue)" }

    /// An example model identifier, suitable as a BYOK field placeholder.
    public var exampleModelID: String {
        switch self {
        case .openrouter: return "openai/gpt-4o-mini"
        case .openai:     return "gpt-4o-mini"
        case .anthropic:  return "claude-sonnet-5"
        case .deepseek:   return "deepseek-chat"
        case .groq:       return "llama-3.3-70b-versatile"
        case .together:   return "meta-llama/Llama-3.3-70B-Instruct-Turbo"
        case .xai:        return "grok-4"
        }
    }

    /// Where a user can obtain an API key for this provider.
    public var keyHint: String {
        switch self {
        case .openrouter: return "openrouter.ai/keys"
        case .openai:     return "platform.openai.com/api-keys"
        case .anthropic:  return "console.anthropic.com/keys"
        case .deepseek:   return "platform.deepseek.com"
        case .groq:       return "console.groq.com/keys"
        case .together:   return "api.together.ai"
        case .xai:        return "console.x.ai"
        }
    }
}
