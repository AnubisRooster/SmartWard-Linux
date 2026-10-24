import Foundation

/// What a caller intends to use a model for. Selection filters the catalog
/// by the input/output modalities each role requires.
public enum ModelRole: String, Codable, CaseIterable, Sendable {
    case chat, extract, image
}

/// One entry in a provider's model catalog. Shaped after OpenRouter's
/// `/models` and `/images/models` response, which several OpenAI-compatible
/// providers mirror.
public struct CatalogEntry: Codable, Hashable, Sendable {
    public let id: String
    public let name: String?
    public let pricing: Pricing
    public let contextLength: Int?
    public let architecture: Architecture?
    public let supportedParameters: [String]?

    public init(id: String, name: String?, pricing: Pricing, contextLength: Int?,
               architecture: Architecture?, supportedParameters: [String]?) {
        self.id = id
        self.name = name
        self.pricing = pricing
        self.contextLength = contextLength
        self.architecture = architecture
        self.supportedParameters = supportedParameters
    }

    enum CodingKeys: String, CodingKey {
        case id, name, pricing
        case contextLength = "context_length"
        case architecture
        case supportedParameters = "supported_parameters"
    }
}

public struct Architecture: Codable, Hashable, Sendable {
    public let inputModalities: [String]?
    public let outputModalities: [String]?

    public init(inputModalities: [String]?, outputModalities: [String]?) {
        self.inputModalities = inputModalities
        self.outputModalities = outputModalities
    }

    enum CodingKeys: String, CodingKey {
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}

/// Per-token/per-image pricing. Some providers report these as JSON numbers,
/// others as strings — `init(from:)` accepts either.
public struct Pricing: Codable, Hashable, Sendable {
    public let prompt: Double
    public let completion: Double
    public let image: Double?
    public let perRequest: Double?

    public init(prompt: Double, completion: Double, image: Double? = nil, perRequest: Double? = nil) {
        self.prompt = prompt
        self.completion = completion
        self.image = image
        self.perRequest = perRequest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try Self.decodePrice(container, for: .prompt)
        completion = try Self.decodePrice(container, for: .completion)
        image = try container.decodeIfPresent(String.self, forKey: .image).flatMap { Double($0) }
        perRequest = try container.decodeIfPresent(String.self, forKey: .perRequest).flatMap { Double($0) }
    }

    private static func decodePrice(_ container: KeyedDecodingContainer<CodingKeys>, for key: CodingKeys) throws -> Double {
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: key) {
            return doubleVal
        }
        if let stringVal = try container.decodeIfPresent(String.self, forKey: key), let val = Double(stringVal) {
            return val
        }
        return 0
    }

    enum CodingKeys: String, CodingKey {
        case prompt, completion, image
        case perRequest = "per_request"
    }

    public static let zero = Pricing(prompt: 0, completion: 0, image: nil, perRequest: nil)
}

struct CatalogResponse: Codable {
    let data: [CatalogEntry]
}

/// What's persisted to disk by `CatalogCache`.
public struct CatalogCacheData: Codable, Sendable {
    public let entries: [CatalogEntry]
    public let lastRefreshed: Date

    public init(entries: [CatalogEntry], lastRefreshed: Date) {
        self.entries = entries
        self.lastRefreshed = lastRefreshed
    }

    enum CodingKeys: String, CodingKey {
        case entries
        case lastRefreshed = "last_refreshed"
    }
}
