import XCTest
@testable import BYOKLLMKit

private actor CallRecorder {
    private(set) var attemptedModels: [String] = []
    func record(_ model: String) { attemptedModels.append(model) }
}

private enum ScriptedOutcome {
    case success(LLMResponse)
    case failure(Error)
    /// Streams `text` as one delta before failing — for exercising "don't
    /// rotate once output has already reached the caller".
    case partialThenFail(text: String, error: Error)
}

private struct ScriptedCompleter: LLMCompleting {
    let outcomes: [String: ScriptedOutcome]
    let recorder: CallRecorder

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        await recorder.record(request.model)
        switch outcomes[request.model] {
        case .success(let response): return response
        case .failure(let error), .partialThenFail(_, let error): throw error
        case nil: throw LLMCompletionError.malformedResponse("no script for \(request.model)")
        }
    }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await recorder.record(request.model)
                switch outcomes[request.model] {
                case .success(let response):
                    continuation.yield(.completed(response))
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                case .partialThenFail(let text, let error):
                    continuation.yield(.textDelta(text))
                    continuation.finish(throwing: error)
                case nil:
                    continuation.finish(throwing: LLMCompletionError.malformedResponse("no script for \(request.model)"))
                }
            }
        }
    }
}

final class FallbackLLMTests: XCTestCase {
    private let request = LLMRequest(provider: .anthropic, model: "primary", messages: [.user("hi")])
    private let retryable = LLMCompletionError.http(status: 429, body: "")
    private let notRetryable = LLMCompletionError.http(status: 401, body: "")

    private func response(_ text: String) -> LLMResponse {
        LLMResponse(message: .assistant(text), stopReason: .endTurn, usage: nil, model: nil)
    }

    // MARK: - complete

    func testSucceedsOnFirstModelWithoutRotating() async throws {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .success(response("ok"))], recorder: recorder)
        let fallback = FallbackLLM(base: base) { _ in ["secondary"] }

        let result = try await fallback.complete(request)
        XCTAssertEqual(result.message.text, "ok")
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary"])
    }

    func testRotatesToAlternativeOnRetryableError() async throws {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .failure(retryable), "secondary": .success(response("ok"))],
                                     recorder: recorder)
        let fallback = FallbackLLM(base: base) { _ in ["secondary"] }

        let result = try await fallback.complete(request)
        XCTAssertEqual(result.message.text, "ok")
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary", "secondary"])
    }

    func testDoesNotRotateOnNonRetryableError() async {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .failure(notRetryable), "secondary": .success(response("ok"))],
                                     recorder: recorder)
        let fallback = FallbackLLM(base: base) { _ in ["secondary"] }

        do {
            _ = try await fallback.complete(request)
            XCTFail("expected the non-retryable error to propagate")
        } catch {
            XCTAssertEqual(error as? LLMCompletionError, notRetryable)
        }
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary"], "never rotates on a non-retryable error")
    }

    func testStopsAfterMaxAttempts() async {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .failure(retryable), "secondary": .failure(retryable),
                                                "tertiary": .success(response("ok"))],
                                     recorder: recorder)
        let fallback = FallbackLLM(base: base, maxAttempts: 2) { _ in ["secondary", "tertiary"] }

        do {
            _ = try await fallback.complete(request)
            XCTFail("expected failure: only 2 of 3 models are ever tried")
        } catch {
            XCTAssertEqual(error as? LLMCompletionError, retryable)
        }
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary", "secondary"], "tertiary is never reached")
    }

    func testDedupesRepeatedModelNames() async {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .failure(retryable), "secondary": .failure(retryable)],
                                     recorder: recorder)
        // Alternatives names the primary again before the real alternative.
        let fallback = FallbackLLM(base: base, maxAttempts: 5) { _ in ["primary", "secondary"] }

        do {
            _ = try await fallback.complete(request)
            XCTFail("expected failure once both distinct models are exhausted")
        } catch {
            XCTAssertEqual(error as? LLMCompletionError, retryable)
        }
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary", "secondary"], "the repeated \"primary\" is never tried twice")
    }

    // MARK: - stream

    func testStreamSucceedsOnFirstModel() async throws {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .success(response("ok"))], recorder: recorder)
        let fallback = FallbackLLM(base: base) { _ in ["secondary"] }

        var events: [LLMStreamEvent] = []
        for try await event in fallback.stream(request) { events.append(event) }
        XCTAssertEqual(events, [.completed(response("ok"))])
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary"])
    }

    func testStreamRotatesBeforeAnyOutputStarted() async throws {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .failure(retryable), "secondary": .success(response("ok"))],
                                     recorder: recorder)
        let fallback = FallbackLLM(base: base) { _ in ["secondary"] }

        var events: [LLMStreamEvent] = []
        for try await event in fallback.stream(request) { events.append(event) }
        XCTAssertEqual(events, [.completed(response("ok"))])
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary", "secondary"])
    }

    func testStreamDoesNotRotateAfterOutputStarted() async {
        let recorder = CallRecorder()
        let base = ScriptedCompleter(outcomes: ["primary": .partialThenFail(text: "partial", error: retryable)],
                                     recorder: recorder)
        let fallback = FallbackLLM(base: base) { _ in ["secondary"] }

        var events: [LLMStreamEvent] = []
        do {
            for try await event in fallback.stream(request) { events.append(event) }
            XCTFail("expected the stream to finish with the original error")
        } catch {
            XCTAssertEqual(error as? LLMCompletionError, retryable)
        }
        XCTAssertEqual(events, [.textDelta("partial")], "the partial output already yielded is never discarded")
        let attempted = await recorder.attemptedModels
        XCTAssertEqual(attempted, ["primary"], "never rotates once output has started")
    }
}
