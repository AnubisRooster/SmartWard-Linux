import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
import BYOKLLMKit
import IngestKit
@testable import Pipeline

/// Answers Ollama requests from a handler and records them.
private final class FakeOllama: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var requests: [URLRequest] = []
    private let handler: @Sendable (URLRequest) throws -> (Int, String)

    init(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, String)) { self.handler = handler }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock(); requests.append(request); lock.unlock()
        let (status, body) = try handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }

    func jsonBody(_ index: Int = 0) throws -> [String: Any] {
        let data = try XCTUnwrap(requests[index].httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private func chatReply(_ content: String) -> String {
    let escaped = String(data: try! JSONEncoder().encode(content), encoding: .utf8)!
    return #"{"model":"llama3.2:3b","message":{"role":"assistant","content":\#(escaped)},"prompt_eval_count":12,"eval_count":7}"#
}

final class LocalBackendsTests: XCTestCase {
    func testClientRefusesAddressesOffThisMachine() {
        XCTAssertThrowsError(try OllamaClient(baseURL: URL(string: "http://192.168.1.20:11434")!)) {
            XCTAssertEqual($0 as? LocalAIError, .notLoopback("192.168.1.20"))
        }
        XCTAssertThrowsError(try OllamaClient(baseURL: URL(string: "https://example.com")!))
        XCTAssertNoThrow(try OllamaClient(baseURL: URL(string: "http://localhost:11434")!))
        XCTAssertNoThrow(try OllamaClient())
    }

    func testChatSendsModelSchemaAndOptionsAndReadsReply() async throws {
        let fake = FakeOllama { _ in (200, chatReply("hello")) }
        let client = try OllamaClient(transport: fake)
        let reply = try await client.chat(model: "m", system: "sys", user: "hi",
                                          format: ["type": "object"], maxTokens: 50, temperature: 0.1)
        XCTAssertEqual(reply.text, "hello")
        XCTAssertEqual(reply.inputTokens, 12)
        XCTAssertEqual(reply.outputTokens, 7)
        XCTAssertEqual(fake.requests[0].url?.path, "/api/chat")
        let body = try fake.jsonBody()
        XCTAssertEqual(body["model"] as? String, "m")
        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertNotNil(body["format"])
        let options = try XCTUnwrap(body["options"] as? [String: Any])
        XCTAssertEqual(options["num_predict"] as? Int, 50)
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user"])
    }

    func testMissingModelAndUnreachableServerAreDistinguished() async throws {
        let missing = try OllamaClient(transport: FakeOllama { _ in (404, #"{"error":"model 'x' not found"}"#) })
        do {
            _ = try await missing.chat(model: "x", system: "", user: "")
            XCTFail("expected an error")
        } catch { XCTAssertEqual(error as? LocalAIError, .modelMissing("x")) }

        struct Down: Error {}
        let down = try OllamaClient(transport: FakeOllama { _ in throw Down() })
        do {
            _ = try await down.embed(model: "x", inputs: ["a"])
            XCTFail("expected an error")
        } catch { guard case .unreachable? = error as? LocalAIError else { return XCTFail("\(error)") } }
    }

    func testEmbeddingProviderBatchesAndChecksDimension() async throws {
        let fake = FakeOllama { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let inputs = body["input"] as! [String]
            let rows = inputs.map { _ in "[0.5, 0.25, 0.125]" }.joined(separator: ",")
            return (200, #"{"embeddings":[\#(rows)]}"#)
        }
        let client = try OllamaClient(transport: fake)
        let found = await EmbeddingModel.ollama(config: LocalModelConfig(embeddingModel: "nomic-embed-text"), client: client)
        let model = try XCTUnwrap(found)
        XCTAssertEqual(model.id, "ollama-nomic-embed-text")
        XCTAssertEqual(model.provider.dimension, 3)
        let vectors = await model.provider.embed(batch: ["one", "  ", "two"])
        XCTAssertEqual(vectors.count, 3)
        XCTAssertEqual(vectors[0], [0.5, 0.25, 0.125])
        XCTAssertNil(vectors[1], "blank text isn't embedded")
        XCTAssertEqual(vectors[2], [0.5, 0.25, 0.125])
    }

    func testSummarizerReadsJSONAndFallsBackToHeadings() async throws {
        let json = #"{"about":["A paper."],"says":["It is fast."],"evidence":["Benchmarks."],"matters":["Cost."],"remember":["2x."]}"#
        let ok = LocalArticleSummarizer(client: try OllamaClient(transport: FakeOllama { _ in (200, chatReply(json)) }), model: "m")
        let output = try await ok.summarize(title: "T", text: "Body text")
        XCTAssertEqual(ok.tier, .onDevice)
        XCTAssertNil(output.usage, "local work isn't billed")
        XCTAssertEqual(output.draft.says, ["It is fast."])

        let headings = "ABOUT:\n- A paper.\nSAYS:\n- It is fast.\nEVIDENCE:\n- Benchmarks.\nMATTERS:\n- Cost.\nREMEMBER:\n- 2x."
        let plain = LocalArticleSummarizer(client: try OllamaClient(transport: FakeOllama { _ in (200, chatReply(headings)) }), model: "m")
        let fallback = try await plain.summarize(title: "T", text: "Body text")
        XCTAssertEqual(fallback.draft.matters, ["- Cost."], "bullet markers are cleaned later, as for Apple replies")

        let refusal = LocalArticleSummarizer(client: try OllamaClient(transport: FakeOllama { _ in (200, chatReply("I can't help with that.")) }), model: "m")
        do {
            _ = try await refusal.summarize(title: "T", text: "Body")
            XCTFail("a refusal isn't a summary")
        } catch { XCTAssertEqual(error as? ArticleSummaryError, .declined) }
    }

    func testExtractorReadsJSONAndReportsABusyServerAsRetryable() async throws {
        let json = #"{"entities":[{"name":"vLLM","type":"tool"}],"relations":[]}"#
        let extractor = LocalEntityExtractor(client: try OllamaClient(transport: FakeOllama { _ in (200, chatReply(json)) }), model: "m")
        let output = try await extractor.extract("vLLM serves models.")
        XCTAssertEqual(output.graph.entities, [.init(name: "vLLM", type: "tool")])
        XCTAssertNil(output.provider)

        struct Down: Error {}
        let down = LocalEntityExtractor(client: try OllamaClient(transport: FakeOllama { _ in throw Down() }), model: "m")
        do {
            _ = try await down.extract("text")
            XCTFail("expected an error")
        } catch { XCTAssertTrue(error is ExtractionBusy, "an unreachable server isn't the article's fault") }
    }

    func testJudgeAndDigestSummarizer() async throws {
        let judge = LocalRelevanceJudge(client: try OllamaClient(transport: FakeOllama { _ in (200, chatReply(#"{"relevant": true}"#)) }), model: "m")
        let verdict = await judge.isRelevant(title: "T", summary: "S", interests: "agents")
        XCTAssertEqual(verdict, true)
        let noInterests = await judge.isRelevant(title: "T", summary: "S", interests: "")
        XCTAssertNil(noInterests)

        let digest = LocalDigestSummarizer(client: try OllamaClient(transport: FakeOllama { _ in (200, chatReply("  New work on agents.  ")) }), model: "m")
        let summary = try await digest.summarize(.init(themes: ["agents"], projects: [], excerpts: [.init(title: "A", text: "text")]))
        XCTAssertEqual(summary.text, "New work on agents.")
        XCTAssertEqual(digest.tier, .onDevice)
    }
}
