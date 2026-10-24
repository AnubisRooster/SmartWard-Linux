import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import BYOKLLMKit
import ModelCatalogKit

/// Fetches the models a provider's own API says it can serve — used to
/// verify a freshly entered key (a successful fetch means the key works)
/// and to show a live model picker in onboarding and Settings instead of a
/// free-text field.
///
/// OpenRouter has its own richer catalog (pricing, context length,
/// capabilities) via `CatalogFetcher`, already used for cost estimates and
/// fallback ranking. Every other provider's `/models` only returns a bare id
/// list, wrapped here as `CatalogEntry` with the fields it doesn't report
/// left empty — `Pricing.zero`, not a real price, so a caller must never
/// feed these into `PriceBook`; only OpenRouter's own catalog prices anything.
public enum ProviderModelFetcher {
    public enum FetchError: LocalizedError, Equatable {
        case invalidKey
        case http(Int)
        case unreadable

        public var errorDescription: String? {
            switch self {
            case .invalidKey: return "That key was rejected."
            case .http(let status): return "The provider returned an error (\(status))."
            case .unreadable: return "Couldn't read the provider's model list."
            }
        }
    }

    /// Fetches `provider`'s available models using `apiKey` directly (not
    /// the Keychain), so a caller can verify a key before saving it.
    public static func fetch(provider: LLMProvider, apiKey: String,
                             session: URLSession = .shared) async throws -> [CatalogEntry] {
        if provider == .openrouter {
            return try await CatalogFetcher().fetch(apiKey: apiKey)
        }
        guard let request = urlRequest(for: provider, apiKey: apiKey) else { throw FetchError.unreadable }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FetchError.unreadable }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.invalidKey }
            throw FetchError.http(http.statusCode)
        }
        return try decode(data, for: provider)
    }

    /// `GET {provider.baseURL}/models` with the provider's own auth scheme —
    /// `x-api-key` + `anthropic-version` for Anthropic, `Bearer` elsewhere,
    /// matching `LLMService`'s own header choices for chat completions.
    static func urlRequest(for provider: LLMProvider, apiKey: String) -> URLRequest? {
        guard let url = URL(string: "\(provider.baseURL)/models") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if provider == .anthropic {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Decodes a `/models` response into `CatalogEntry`, sorted by id.
    /// Anthropic's shape carries a `display_name`; every OpenAI-compatible
    /// provider's is bare ids only (`id`, plus fields this app doesn't need).
    static func decode(_ data: Data, for provider: LLMProvider) throws -> [CatalogEntry] {
        func entry(_ id: String, _ name: String?) -> CatalogEntry {
            CatalogEntry(id: id, name: name, pricing: .zero, contextLength: nil,
                        architecture: nil, supportedParameters: nil)
        }
        do {
            if provider == .anthropic {
                struct Entry: Decodable {
                    let id: String
                    let displayName: String?
                    enum CodingKeys: String, CodingKey { case id; case displayName = "display_name" }
                }
                struct List: Decodable { let data: [Entry] }
                let decoded = try JSONDecoder().decode(List.self, from: data)
                return decoded.data.map { entry($0.id, $0.displayName) }.sorted { $0.id < $1.id }
            }
            struct Entry: Decodable { let id: String }
            struct List: Decodable { let data: [Entry] }
            let decoded = try JSONDecoder().decode(List.self, from: data)
            return decoded.data.map { entry($0.id, nil) }.sorted { $0.id < $1.id }
        } catch {
            throw FetchError.unreadable
        }
    }
}
