import Foundation

/// Something sent to SmartWard from the share sheet (PLAN FR-3).
public struct SharedItem: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var url: String?
    /// Selected text, or text shared on its own.
    public var text: String?
    public var title: String?
    /// The project it was shared to, if one was picked.
    public var projectID: UUID?
    public var createdAt: Date

    public init(id: UUID = UUID(), url: String? = nil, text: String? = nil, title: String? = nil,
                projectID: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.url = url
        self.text = text
        self.title = title
        self.projectID = projectID
        self.createdAt = createdAt
    }
}

/// A project as the share extension sees it: just enough to pick one.
public struct SharedProject: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// A folder of JSON files in the App Group container that the share
/// extension writes and the app drains. The extension never opens the
/// SwiftData store, so the two processes can't contend for it.
///
/// Dependency-free on purpose: this is the only SmartWardKit module the
/// extension links.
public struct SharedInbox: Sendable {
    public static let appGroupID = "group.com.intelligentdesignsllc.smartward"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// The shared container's inbox, or `nil` when the App Group isn't
    /// configured (e.g. an unsigned build).
    public static func appGroup() -> SharedInbox? {
        #if os(Linux)
        // No App Groups: the inbox lives in the XDG data dir.
        let base = ProcessInfo.processInfo.environment["XDG_DATA_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share")
        return SharedInbox(directory: base.appendingPathComponent("smartward/Inbox", isDirectory: true))
        #else
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        return SharedInbox(directory: container.appendingPathComponent("Inbox", isDirectory: true))
        #endif
    }

    private var itemsDirectory: URL { directory.appendingPathComponent("Items", isDirectory: true) }
    private var projectsFile: URL { directory.appendingPathComponent("projects.json") }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: Items

    public func write(_ item: SharedItem) throws {
        try FileManager.default.createDirectory(at: itemsDirectory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(item)
        try data.write(to: itemsDirectory.appendingPathComponent("\(item.id.uuidString).json"),
                       options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    /// Waiting items, oldest first. Unreadable files are skipped.
    public func pending() -> [SharedItem] {
        let files = (try? FileManager.default.contentsOfDirectory(at: itemsDirectory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? Self.decoder.decode(SharedItem.self, from: $0) } }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func remove(_ id: UUID) {
        try? FileManager.default.removeItem(at: itemsDirectory.appendingPathComponent("\(id.uuidString).json"))
    }

    // MARK: Projects

    public func writeProjects(_ projects: [SharedProject]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.encoder.encode(projects).write(to: projectsFile, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    public func projects() -> [SharedProject] {
        guard let data = try? Data(contentsOf: projectsFile) else { return [] }
        return (try? Self.decoder.decode([SharedProject].self, from: data)) ?? []
    }
}
