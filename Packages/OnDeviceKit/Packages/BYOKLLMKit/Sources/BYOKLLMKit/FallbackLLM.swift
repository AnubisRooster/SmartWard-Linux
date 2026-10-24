import Foundation

/// Retries a request on other models when the provider says the chosen one
/// is rate-limited, overloaded or failing (408/429/5xx, or an in-band
/// "overloaded"/"rate limit" error — see `LLMCompletionError.isRetryable`).
/// Other errors, and a stream that already produced output, are passed
/// through unchanged: a partial reply already shown to the user should never
/// be silently replaced by a retry on another model.
///
/// `FallbackLLM` itself has no opinion on *which* models to try next — that
/// policy (a host's own ordered list, a model catalog's cost/capability
/// ranking, or both) is supplied by the caller as `alternatives`, so this
/// stays a small, dependency-free wrapper around any `LLMCompleting`.
public struct FallbackLLM: LLMCompleting {
    public typealias Alternatives = @Sendable (LLMRequest) -> [String]

    private let base: any LLMCompleting
    private let alternatives: Alternatives
    /// Including the first try.
    public var maxAttempts: Int

    public init(base: any LLMCompleting, maxAttempts: Int = 3, alternatives: @escaping Alternatives) {
        self.base = base
        self.maxAttempts = maxAttempts
        self.alternatives = alternatives
    }

    /// The chosen model, then the alternatives, up to `maxAttempts`, with
    /// duplicates dropped (an alternatives policy might name the same model
    /// twice, or repeat the primary).
    func models(for request: LLMRequest) -> [String] {
        var seen = Set<String>()
        let all = ([request.model] + alternatives(request)).filter { seen.insert($0).inserted }
        return Array(all.prefix(max(1, maxAttempts)))
    }

    static func shouldRotate(after error: Error) -> Bool {
        (error as? LLMCompletionError)?.isRetryable ?? false
    }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        let models = models(for: request)
        for (index, model) in models.enumerated() {
            var attempt = request
            attempt.model = model
            do {
                return try await base.complete(attempt)
            } catch {
                guard Self.shouldRotate(after: error), index < models.count - 1 else { throw error }
            }
        }
        throw LLMCompletionError.malformedResponse("No model to try.")
    }

    public func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        let models = models(for: request)
        let base = self.base
        return AsyncThrowingStream { continuation in
            let task = Task {
                for (index, model) in models.enumerated() {
                    var attempt = request
                    attempt.model = model
                    var started = false
                    do {
                        for try await event in base.stream(attempt) {
                            started = true
                            continuation.yield(event)
                        }
                        continuation.finish()
                        return
                    } catch {
                        // Only rotate before anything reached the caller —
                        // once output has streamed, replacing it with another
                        // model's answer would be worse than surfacing the error.
                        if !started, Self.shouldRotate(after: error), index < models.count - 1, !Task.isCancelled {
                            continue
                        }
                        continuation.finish(throwing: error)
                        return
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
