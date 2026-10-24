import XCTest
import BYOKLLMKit
@testable import LocalLLMKit

/// Validates that concurrent `loadModel` calls serialize instead of racing,
/// and that a bad path fails gracefully (no crash, no stuck `isLoading`).
@MainActor
final class LocalLLMEngineTests: XCTestCase {

    func testConcurrentLoadOfMissingModelDoesNotDeadlockOrCrash() async {
        let engine = LocalLLMEngine()
        engine.unload()
        let bogus = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("missing-\(UUID().uuidString).gguf")

        // Fire two loads of the same id at once; serialization must let both
        // return, leaving a single consistent (failed) state.
        async let first: Void = engine.loadModel(id: "ghost", url: bogus)
        async let second: Void = engine.loadModel(id: "ghost", url: bogus)
        _ = await (first, second)

        XCTAssertFalse(engine.isLoading, "isLoading must be reset after a failed load")
        XCTAssertNil(engine.loadedModelID, "A missing file must not register as loaded")
        XCTAssertNotNil(engine.loadError, "A missing file should surface a load error")
    }

    func testGenerateWithoutLoadedModelThrowsNotLoaded() async {
        let engine = LocalLLMEngine()
        engine.unload()
        do {
            _ = try await engine.generate(modelID: "ghost",
                                          messages: [LLMMessage(role: "user", content: "hi")])
            XCTFail("Expected notLoaded error")
        } catch let error as LocalLLMError {
            if case .notLoaded = error {} else { XCTFail("Expected .notLoaded, got \(error)") }
        } catch {
            XCTFail("Expected LocalLLMError.notLoaded, got \(error)")
        }
    }

    // MARK: - Stop-sequence selection (pure)

    func testStopSequenceSelectsByModelIDPrefix() {
        XCTAssertEqual(LocalLLMEngine.stopSequence(for: "llama-3.2-1b"), "<|eot_id|>")
        XCTAssertEqual(LocalLLMEngine.stopSequence(for: "phi-3.5-mini"), "<|end|>")
        XCTAssertEqual(LocalLLMEngine.stopSequence(for: "gemma-2-2b"), "<end_of_turn>")
        XCTAssertEqual(LocalLLMEngine.stopSequence(for: "qwen2.5-1.5b"), "<|im_end|>")
    }

    // MARK: - Device-scaled sizing (pure)

    func testContextWindowScalesWithDeviceRAM() {
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 2), 2048)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 3), 2048)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 4), 3072)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 5), 3072)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 6), 4096)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 7), 4096)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 8), 8192)
        XCTAssertEqual(LocalLLMEngine.contextWindow(ramGB: 16), 8192)
    }

    func testHistoryLimitScalesWithDeviceRAM() {
        XCTAssertEqual(LocalLLMEngine.historyLimit(ramGB: 2), 6)
        XCTAssertEqual(LocalLLMEngine.historyLimit(ramGB: 4), 8)
        XCTAssertEqual(LocalLLMEngine.historyLimit(ramGB: 6), 10)
        XCTAssertEqual(LocalLLMEngine.historyLimit(ramGB: 8), 12)
    }
}
