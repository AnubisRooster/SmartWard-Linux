import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Sending protocol

/// Abstraction over the inference backend so callers can be unit-tested with
/// a mock instead of hitting the network.
public protocol LLMSending: Sendable {
    func sendMessage(provider: String, model: String, messages: [LLMMessage]) async throws -> String
}

// MARK: - LLMService

/// Single chokepoint for BYOK cloud LLM inference. Routes to the appropriate
/// provider's REST API based on the `provider` string (matches
/// `LLMProvider.rawValue`), using a per-provider API key from `LLMKeychainStore`.
public actor LLMService: LLMSending {
    public static let shared = LLMService()

    var defaultModel: String
    let keychain: LLMKeychainStore
    /// Sent as `HTTP-Referer` on OpenRouter requests for their attribution
    /// dashboard. Optional; OpenRouter works fine without it.
    let openRouterReferer: String?

    public init(keychain: LLMKeychainStore = .shared,
               defaultModel: String = "openai/gpt-4o-mini",
               openRouterReferer: String? = nil) {
        self.keychain = keychain
        self.defaultModel = defaultModel
        self.openRouterReferer = openRouterReferer
    }

    public func setDefaultModel(_ model: String) {
        self.defaultModel = model
    }

    public func sendMessage(provider: String = "openrouter",
                            model: String,
                            messages: [LLMMessage]) async throws -> String {
        guard let providerEnum = LLMProvider(rawValue: provider) else {
            throw LLMError.unsupportedProvider(provider)
        }

        let resolvedModel = model.isEmpty ? defaultModel : model

        if providerEnum == .anthropic {
            return try await callAnthropic(model: resolvedModel, messages: messages)
        }

        return try await callOpenAICompatible(provider: providerEnum,
                                              model: resolvedModel,
                                              messages: messages)
    }

    /// Streams a reply token-by-token via SSE, for every provider.
    ///
    /// Errors are always `LLMError`, as before. For tool calls, structured
    /// output, or usage, use `stream(_:)` instead.
    ///
    /// Cancelling the returned stream's consuming `Task` cancels the
    /// underlying network request.
    public nonisolated func streamMessage(provider: String = "openrouter",
                                          model: String,
                                          messages: [LLMMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let providerEnum = LLMProvider(rawValue: provider) else {
                        throw LLMError.unsupportedProvider(provider)
                    }
                    guard providerEnum.isOpenAICompatible else {
                        try await streamViaCompletionAPI(provider: providerEnum, model: model,
                                                         messages: messages, continuation: continuation)
                        return
                    }
                    try await streamOpenAICompatible(provider: providerEnum, model: model,
                                                     messages: messages, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Text-only bridge from the legacy `streamMessage` API onto `stream(_:)`
    /// (used for Anthropic). Maps the new API's errors back to `LLMError` so
    /// legacy callers see the same error type as before.
    private nonisolated func streamViaCompletionAPI(provider: LLMProvider,
                                                    model: String,
                                                    messages: [LLMMessage],
                                                    continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let request = LLMRequest(provider: provider, model: model,
                                 messages: messages.map { LLMChatMessage($0) })
        do {
            for try await event in stream(request) {
                if case .textDelta(let text) = event {
                    continuation.yield(text)
                }
            }
            continuation.finish()
        } catch let error as LLMCompletionError {
            switch error {
            case .http(_, let body):
                throw LLMError.apiError(body.isEmpty ? "Unknown error" : body)
            default:
                throw LLMError.apiError(error.errorDescription ?? "Unknown error")
            }
        }
    }

    private func streamOpenAICompatible(provider: LLMProvider,
                                        model: String,
                                        messages: [LLMMessage],
                                        continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let apiKey = keychain.get(for: provider) ?? ""
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let resolvedModel = model.isEmpty ? defaultModel : model
        let url = URL(string: "\(provider.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if provider == .openrouter, let referer = openRouterReferer {
            request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        }
        request.httpBody = try JSONEncoder().encode(OpenRouterRequest(model: resolvedModel, messages: messages, stream: true))

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 1000 { break }
            }
            throw LLMError.apiError(body.isEmpty ? "Unknown error" : body)
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            switch Self.parseSSELine(line) {
            case .delta(let text): continuation.yield(text)
            case .done: continuation.finish(); return
            case .ignore: continue
            }
        }
        continuation.finish()
    }

    /// The result of interpreting one line of an OpenAI-compatible SSE
    /// stream. Pure and static so the parsing logic is unit-testable without
    /// a live network connection.
    enum SSEEvent: Equatable {
        case delta(String)
        case done
        case ignore
    }

    static func parseSSELine(_ line: String) -> SSEEvent {
        guard line.hasPrefix("data: ") else { return .ignore }
        let json = String(line.dropFirst(6))
        if json == "[DONE]" { return .done }
        guard let data = json.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(OpenRouterStreamChunk.self, from: data),
              let delta = chunk.choices.first?.delta.content
        else { return .ignore }
        return .delta(delta)
    }

    /// Convenience for structured-output prompts: appends a "respond with
    /// JSON only" instruction and strips any markdown code fences from the
    /// reply before returning it.
    public func sendJSONQuery(provider: String = "openrouter",
                              model: String,
                              systemPrompt: String,
                              userMessage: String) async throws -> String {
        let messages = [
            LLMMessage(role: "system", content: "\(systemPrompt)\n\nRespond with valid JSON only, no markdown."),
            LLMMessage(role: "user", content: userMessage),
        ]
        let raw = try await sendMessage(provider: provider, model: model, messages: messages)
        return Self.stripCodeFences(raw)
    }

    // MARK: - OpenAI-compatible (OpenRouter, OpenAI, DeepSeek, Groq, Together)

    private func callOpenAICompatible(provider: LLMProvider,
                                      model: String,
                                      messages: [LLMMessage]) async throws -> String {
        let apiKey = keychain.get(for: provider) ?? ""
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "\(provider.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if provider == .openrouter, let referer = openRouterReferer {
            request.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
        }

        let body = OpenRouterRequest(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }

        let result = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }

    // MARK: - Anthropic

    private func callAnthropic(model: String, messages: [LLMMessage]) async throws -> String {
        let apiKey = keychain.get(for: .anthropic) ?? ""
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "\(LLMProvider.anthropic.baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")

        request.httpBody = try Self.buildAnthropicRequest(model: model, messages: messages)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.apiError(String(data: data, encoding: .utf8) ?? "Unknown error")
        }

        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return result.content.first?.text ?? ""
    }

    private static func buildAnthropicRequest(model: String, messages: [LLMMessage]) throws -> Data {
        // Anthropic keeps `system` at the top level, separate from `messages`.
        let systemMessages = messages.filter { $0.role == "system" }.map(\.content).joined(separator: "\n\n")
        let conversationMessages = messages.filter { $0.role != "system" }
            .map { AnthropicMessage(role: $0.role, content: [AnthropicContentBlock(type: "text", text: $0.content)]) }

        let body = AnthropicRequest(model: model,
                                    maxTokens: 4096,
                                    system: systemMessages.isEmpty ? nil : systemMessages,
                                    messages: conversationMessages)
        return try JSONEncoder().encode(body)
    }

    // MARK: - Helpers

    static func stripCodeFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if let range = t.range(of: "```", options: .backwards) {
                t = String(t[..<range.lowerBound])
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

public enum LLMError: LocalizedError, Sendable {
    case noAPIKey
    case apiError(String)
    case unsupportedProvider(String)
    case streamingNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured for this provider."
        case .apiError(let msg):
            return "API error: \(msg)"
        case .unsupportedProvider(let p):
            return "Unsupported provider: \(p)."
        case .streamingNotSupported(let p):
            return "\(p) doesn't support streaming yet; use sendMessage instead."
        }
    }
}
