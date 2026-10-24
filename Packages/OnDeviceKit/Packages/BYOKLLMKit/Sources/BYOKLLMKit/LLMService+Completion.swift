import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension LLMService: LLMCompleting {

    /// One-shot completion with tool calling, structured output and usage.
    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let urlRequest = try makeURLRequest(for: request, stream: false)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LLMCompletionError.http(status: http.statusCode,
                                          body: String(decoding: data.prefix(2000), as: UTF8.self))
        }
        if request.provider == .anthropic {
            return try AnthropicWire.decodeResponse(data,
                                                    structuredToolName: AnthropicWire.structuredToolName(for: request))
        }
        return try OpenAIWire.decodeResponse(data)
    }

    /// Streaming completion for every provider. Yields `.textDelta`s as they
    /// arrive, `.toolCall` once each call's arguments are complete, and always
    /// ends with `.completed` carrying the assembled response and usage.
    ///
    /// Cancelling the consuming `Task` cancels the network request.
    public nonisolated func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runStream(request, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runStream(_ request: LLMRequest,
                           continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation) async throws {
        let urlRequest = try makeURLRequest(for: request, stream: true)
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 2000 { break }
            }
            throw LLMCompletionError.http(status: http.statusCode, body: body)
        }

        if request.provider == .anthropic {
            var accumulator = AnthropicStreamAccumulator(
                structuredToolName: AnthropicWire.structuredToolName(for: request))
            for try await line in bytes.lines {
                try Task.checkCancellation()
                for event in try accumulator.consume(line) { continuation.yield(event) }
                if accumulator.isFinished { break }
            }
            for event in accumulator.finish() { continuation.yield(event) }
        } else {
            var accumulator = OpenAIStreamAccumulator()
            for try await line in bytes.lines {
                try Task.checkCancellation()
                for event in try accumulator.consume(line) { continuation.yield(event) }
                if accumulator.isFinished { break }
            }
            for event in accumulator.finish() { continuation.yield(event) }
        }
        continuation.finish()
    }

    // MARK: - Request building

    func makeURLRequest(for request: LLMRequest, stream: Bool) throws -> URLRequest {
        let apiKey = keychain.get(for: request.provider) ?? ""
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }
        let model = request.model.isEmpty ? defaultModel : request.model
        let body = request.provider == .anthropic
            ? AnthropicWire.requestBody(for: request, model: model, stream: stream)
            : OpenAIWire.requestBody(for: request, model: model, stream: stream)
        return try Self.makeURLRequest(provider: request.provider, apiKey: apiKey, body: body,
                                       stream: stream, openRouterReferer: openRouterReferer)
    }

    static func makeURLRequest(provider: LLMProvider,
                               apiKey: String,
                               body: JSONValue,
                               stream: Bool,
                               openRouterReferer: String?) throws -> URLRequest {
        let path = provider == .anthropic ? "/messages" : "/chat/completions"
        guard let url = URL(string: provider.baseURL + path) else {
            throw LLMError.unsupportedProvider(provider.rawValue)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        }
        if provider == .anthropic {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(AnthropicWire.apiVersion, forHTTPHeaderField: "anthropic-version")
        } else {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if provider == .openrouter, let openRouterReferer {
            request.setValue(openRouterReferer, forHTTPHeaderField: "HTTP-Referer")
        }
        request.httpBody = try body.encodedData()
        return request
    }
}
