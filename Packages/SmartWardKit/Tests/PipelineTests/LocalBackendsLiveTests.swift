import Foundation
import XCTest
import RetrievalKit
@testable import Pipeline

/// Runs the local backends against a real Ollama on this machine. Skipped
/// unless `SMARTWARD_OLLAMA=1` (needs `llama3.2:3b` and `nomic-embed-text`).
final class LocalBackendsLiveTests: XCTestCase {
    private func backends() async throws -> LocalBackends {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SMARTWARD_OLLAMA"] == "1", "set SMARTWARD_OLLAMA=1")
        let detected = await LocalBackends.detect()
        return try XCTUnwrap(detected, "Ollama isn't running or llama3.2:3b isn't installed")
    }

    private let article = """
    vLLM 0.6 adds speculative decoding with a draft model, and reports up to 2.3x higher throughput on Llama 3 70B \
    at low batch sizes. The release also introduces chunked prefill, which overlaps long prompt processing with \
    decoding, and ships a new OpenAI-compatible server. The vLLM project, maintained by UC Berkeley's Sky Lab, \
    recommends enabling prefix caching for chat workloads.
    """

    func testEmbeddingsRankRelatedTextCloser() async throws {
        let backends = try await backends()
        let embedding = try XCTUnwrap(backends.embedding)
        XCTAssertEqual(embedding.id, "ollama-nomic-embed-text")
        let vectors = await embedding.provider.embed(batch: [
            "Speculative decoding speeds up LLM inference",
            "Faster token generation with a draft model",
            "A recipe for sourdough bread with rye flour",
        ])
        let v = try XCTUnwrap(vectors[0]), related = try XCTUnwrap(vectors[1]), unrelated = try XCTUnwrap(vectors[2])
        XCTAssertEqual(v.count, embedding.provider.dimension)
        let near = CosineSimilarity.score(v, related), far = CosineSimilarity.score(v, unrelated)
        print("LIVE embedding dim=\(v.count) related=\(near) unrelated=\(far)")
        XCTAssertGreaterThan(near, far)
    }

    func testSummaryExtractionJudgeAndDigest() async throws {
        let backends = try await backends()

        let summary = try await backends.summarizer.summarize(title: "vLLM 0.6", text: article)
        print("LIVE summary: \(summary.draft)")
        XCTAssertFalse(summary.draft.about.isEmpty)
        XCTAssertFalse(summary.draft.says.isEmpty)

        let output = try await backends.extractor.extract(article)
        print("LIVE entities: \(output.graph.entities.map { "\($0.name) (\($0.type))" })")
        XCTAssertTrue(output.graph.entities.contains { $0.name.lowercased().contains("vllm") })

        let relevant = await backends.judge.isRelevant(title: "vLLM 0.6 released", summary: article,
                                                       interests: "Serving and optimizing large language models")
        let irrelevant = await backends.judge.isRelevant(title: "Sourdough tips", summary: "How to bake rye bread.",
                                                         interests: "Serving and optimizing large language models")
        print("LIVE judge: relevant=\(String(describing: relevant)) irrelevant=\(String(describing: irrelevant))")
        XCTAssertEqual(relevant, true)
        XCTAssertEqual(irrelevant, false)

        let digest = try await backends.digest.summarize(.init(
            themes: ["speculative decoding"], projects: ["Inference stack"],
            excerpts: [.init(title: "vLLM 0.6", text: article)]))
        print("LIVE digest: \(digest.text)")
        XCTAssertFalse(digest.text.isEmpty)
    }
}
