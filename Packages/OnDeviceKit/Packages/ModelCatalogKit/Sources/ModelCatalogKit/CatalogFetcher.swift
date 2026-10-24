import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches a live model catalog from an OpenRouter-shaped API (`GET /models`,
/// optionally `GET /images/models`).
public actor CatalogFetcher {
    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder

    /// - Parameter baseURL: defaults to OpenRouter's API. Point this at any
    ///   other provider that mirrors OpenRouter's `/models` response shape.
    public init(baseURL: String = "https://openrouter.ai/api/v1") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    /// Fetches the chat-model catalog, and merges in the image-model catalog
    /// if that endpoint exists and responds. Each endpoint is fetched
    /// independently so one failing (e.g. a provider with no image models)
    /// doesn't discard models successfully fetched from the other.
    public func fetch(apiKey: String) async throws -> [CatalogEntry] {
        async let chatModels = try? fetchModels(apiKey: apiKey, path: "\(baseURL)/models")
        async let imageModels = try? fetchModels(apiKey: apiKey, path: "\(baseURL)/images/models")
        let merged = (await chatModels ?? []) + (await imageModels ?? [])
        if merged.isEmpty { throw CatalogError.fetchFailed }
        return merged
    }

    private func fetchModels(apiKey: String, path: String) async throws -> [CatalogEntry] {
        var req = URLRequest(url: URL(string: path)!)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }
        let decoded = try decoder.decode(CatalogResponse.self, from: data)
        return decoded.data
    }
}

public enum CatalogError: Error, LocalizedError, Sendable {
    case fetchFailed

    public var errorDescription: String? {
        switch self {
        case .fetchFailed: return "Could not fetch the model catalog from either endpoint."
        }
    }
}
