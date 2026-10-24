import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import BYOKLLMKit
import IngestKit

public enum LocalAIError: LocalizedError, Equatable, Sendable {
    /// The base URL isn't this machine, so "local" content would leave it.
    case notLoopback(String)
    case unreachable(String)
    case modelMissing(String)
    case http(status: Int, body: String)
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .notLoopback(let host):
            return "The local model server must run on this machine, not \(host)."
        case .unreachable(let why):
            return "The local model server isn't reachable (\(why)). Is Ollama running?"
        case .modelMissing(let model):
            return "The local model \"\(model)\" isn't installed. Pull it with: ollama pull \(model)"
        case .http(let status, let body):
            return "The local model server answered \(status): \(body.prefix(200))"
        case .badResponse:
            return "The local model server sent an unexpected answer."
        }
    }
}

enum LocalAddress {
    /// Whether `url` points at this machine, so "local" content can't be sent elsewhere.
    static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host) || host.hasSuffix(".localhost")
    }
}

/// A client for a local Ollama server. It only ever talks to loopback
/// addresses (D5): content that must stay on the device is sent to a model
/// on this machine and nowhere else.
public struct OllamaClient: Sendable {
    public static let defaultBaseURL = URL(string: "http://127.0.0.1:11434")!

    public let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL = OllamaClient.defaultBaseURL,
                transport: any HTTPTransport = URLSessionTransport()) throws {
        guard LocalAddress.isLoopback(baseURL) else {
            throw LocalAIError.notLoopback(baseURL.host ?? baseURL.absoluteString)
        }
        self.baseURL = baseURL
        self.transport = transport
    }

    public struct ChatReply: Sendable, Equatable {
        public var text: String
        public var model: String?
        public var inputTokens: Int?
        public var outputTokens: Int?
    }

    /// One non-streaming chat turn. `format` is a JSON Schema (or `.string("json")`)
    /// that constrains the answer.
    public func chat(model: String, system: String, user: String, format: JSONValue? = nil,
                     maxTokens: Int? = nil, temperature: Double? = nil,
                     contextTokens: Int = 8_192) async throws -> ChatReply {
        var options: [String: JSONValue] = ["num_ctx": .int(contextTokens)]
        if let maxTokens { options["num_predict"] = .int(maxTokens) }
        if let temperature { options["temperature"] = .double(temperature) }
        var body: [String: JSONValue] = [
            "model": .string(model),
            "stream": .bool(false),
            "messages": .array([
                .object(["role": .string("system"), "content": .string(system)]),
                .object(["role": .string("user"), "content": .string(user)]),
            ]),
            "options": .object(options),
        ]
        if let format { body["format"] = format }
        let json = try await post("/api/chat", .object(body), model: model)
        guard case .object(let object) = json, case .object(let message)? = object["message"],
              case .string(let text)? = message["content"] else { throw LocalAIError.badResponse }
        func int(_ key: String) -> Int? { if case .int(let n)? = object[key] { return n } else { return nil } }
        var served: String?
        if case .string(let name)? = object["model"] { served = name }
        return ChatReply(text: text, model: served, inputTokens: int("prompt_eval_count"),
                         outputTokens: int("eval_count"))
    }

    /// Embeddings for each input, in order.
    public func embed(model: String, inputs: [String]) async throws -> [[Float]] {
        let body: JSONValue = .object(["model": .string(model), "input": .array(inputs.map { .string($0) })])
        let json = try await post("/api/embed", body, model: model)
        guard case .object(let object) = json, case .array(let rows)? = object["embeddings"] else {
            throw LocalAIError.badResponse
        }
        return try rows.map { row in
            guard case .array(let values) = row else { throw LocalAIError.badResponse }
            return values.compactMap { value -> Float? in
                switch value {
                case .double(let d): return Float(d)
                case .int(let n): return Float(n)
                default: return nil
                }
            }
        }
    }

    /// Names of the installed models, or throws if the server can't be reached.
    public func installedModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 5
        let (data, response) = try await send(request)
        guard response.statusCode == 200,
              let json = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .object(let object) = json, case .array(let models)? = object["models"] else {
            throw LocalAIError.badResponse
        }
        return models.compactMap { model in
            if case .object(let fields) = model, case .string(let name)? = fields["name"] { return name }
            return nil
        }
    }

    // MARK: Plumbing

    private func post(_ path: String, _ body: JSONValue, model: String) async throws -> JSONValue {
        var request = URLRequest(url: baseURL.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(request)
        guard response.statusCode == 200 else {
            let text = String(decoding: data, as: UTF8.self)
            if response.statusCode == 404, text.lowercased().contains("not found") { throw LocalAIError.modelMissing(model) }
            throw LocalAIError.http(status: response.statusCode, body: text)
        }
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: data) else { throw LocalAIError.badResponse }
        return json
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch let error as LocalAIError {
            throw error
        } catch {
            throw LocalAIError.unreachable(error.localizedDescription)
        }
    }
}
