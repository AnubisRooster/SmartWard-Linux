import Foundation

public struct Schema {
    public enum Relationship {
        public enum DeleteRule: Sendable { case noAction, nullify, cascade, deny }
    }

    public enum Attribute {
        public struct Option: Sendable, Equatable {
            let name: String
            public static let unique = Option(name: "unique")
            public static let externalStorage = Option(name: "externalStorage")
            public static let allowsCloudEncryption = Option(name: "allowsCloudEncryption")
            public static let spotlight = Option(name: "spotlight")
            public static let preserveValueOnDeletion = Option(name: "preserveValueOnDeletion")
            public static let ephemeral = Option(name: "ephemeral")
        }
    }

    public struct Entity {
        public let name: String
    }

    public let types: [any PersistentModel.Type]

    public var entities: [Entity] { types.map { Entity(name: ShimRegistry.entity(of: $0).name) } }

    public init(_ types: [any PersistentModel.Type]) {
        self.types = types
    }
}

public typealias DeleteRule = Schema.Relationship.DeleteRule

public struct ModelConfiguration: Sendable {
    public enum CloudKitDatabase: Sendable {
        case automatic
        case none
        case `private`(String)
    }

    public let name: String?
    public let isStoredInMemoryOnly: Bool
    public let url: URL?

    public init(_ name: String? = nil, schema: Schema? = nil, isStoredInMemoryOnly: Bool = false,
                allowsSave: Bool = true, cloudKitDatabase: CloudKitDatabase = .automatic, url: URL? = nil) {
        self.name = name
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
        self.url = url
    }

    public init(schema: Schema, url: URL, allowsSave: Bool = true, cloudKitDatabase: CloudKitDatabase = .automatic) {
        self.init(nil, schema: schema, isStoredInMemoryOnly: false, allowsSave: allowsSave,
                  cloudKitDatabase: cloudKitDatabase, url: url)
    }

    /// `$XDG_DATA_HOME/smartward/default.store` (or `~/.local/share/...`).
    public static var defaultStoreURL: URL {
        let base = ProcessInfo.processInfo.environment["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share")
        return base.appendingPathComponent("smartward/default.store")
    }
}

// MARK: - Metadata the @Model macro generates

public struct ShimRestoring {}

public struct ShimRelationship: Sendable {
    public let name: String
    public let target: String
    public let toMany: Bool
    public let deleteRule: DeleteRule
    public let inverseEntity: String?
    public let inverseName: String?

    public init(name: String, target: String, toMany: Bool, deleteRule: DeleteRule,
                inverseEntity: String?, inverseName: String?) {
        self.name = name
        self.target = target
        self.toMany = toMany
        self.deleteRule = deleteRule
        self.inverseEntity = inverseEntity
        self.inverseName = inverseName
    }
}

public struct ShimEntity: Sendable {
    public let name: String
    public let relationships: [ShimRelationship]
    public let externals: [String]

    public init(name: String, relationships: [ShimRelationship], externals: [String]) {
        self.name = name
        self.relationships = relationships
        self.externals = externals
    }

    func relationship(named name: String) -> ShimRelationship? {
        relationships.first { $0.name == name }
    }
}

public struct ShimKey: CodingKey {
    public var stringValue: String
    public var intValue: Int? { nil }
    public init(_ string: String) { stringValue = string }
    public init?(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where K == ShimKey {
    /// Assigns the stored value to `target` when the key is present; a missing
    /// key (a column added after the row was written) keeps the default.
    public func shimAssign<T: Decodable>(_ target: inout T, _ key: String) throws {
        let k = ShimKey(key)
        if contains(k) { target = try decode(T.self, forKey: k) }
    }
}

enum ShimRegistry {
    private static let lock = NSLock()
    private static var cache: [ObjectIdentifier: ShimEntity] = [:]

    static func entity(of type: any PersistentModel.Type) -> ShimEntity {
        lock.lock(); defer { lock.unlock() }
        let id = ObjectIdentifier(type)
        if let cached = cache[id] { return cached }
        let entity = type.__shimEntity
        cache[id] = entity
        return entity
    }
}
