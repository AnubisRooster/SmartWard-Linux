import Foundation

public final class ModelContainer: @unchecked Sendable {
    public let schema: Schema

    private let db: SQLiteDatabase
    private let lock = NSRecursiveLock()
    private var types: [String: any PersistentModel.Type] = [:]
    private var _version = 0
    private var _nextSeq = 0
    private var _mainContext: ModelContext?

    public init(for schema: Schema, configurations: [ModelConfiguration] = []) throws {
        self.schema = schema
        let configuration = configurations.first
        let path: String
        if configuration?.isStoredInMemoryOnly == true {
            path = ":memory:"
        } else {
            let url = configuration?.url ?? ModelConfiguration.defaultStoreURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            path = url.path
        }
        db = try SQLiteDatabase(path: path)
        for type in schema.types { types[ShimRegistry.entity(of: type).name] = type }
        try db.execute("""
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;
            CREATE TABLE IF NOT EXISTS objects (
                entity TEXT NOT NULL, pk TEXT NOT NULL, json BLOB NOT NULL,
                PRIMARY KEY (entity, pk));
            CREATE TABLE IF NOT EXISTS blobs (
                entity TEXT NOT NULL, pk TEXT NOT NULL, property TEXT NOT NULL, data BLOB NOT NULL,
                PRIMARY KEY (entity, pk, property));
            """)
        try db.run("SELECT COALESCE(MAX(rowid), 0) FROM objects") { self._nextSeq = $0.int(0) }
    }

    public convenience init(for types: any PersistentModel.Type..., configurations: ModelConfiguration...) throws {
        try self.init(for: Schema(types), configurations: configurations)
    }

    /// The context bound to this container (SwiftData's is main-actor-only;
    /// here it is created on first use).
    public var mainContext: ModelContext {
        lock.lock(); defer { lock.unlock() }
        if let ctx = _mainContext { return ctx }
        let ctx = ModelContext(self)
        _mainContext = ctx
        return ctx
    }

    // MARK: Used by ModelContext

    var version: Int { lock.lock(); defer { lock.unlock() }; return _version }

    func nextSeq() -> Int { lock.lock(); defer { lock.unlock() }; _nextSeq += 1; return _nextSeq }

    func type(named name: String) -> (any PersistentModel.Type)? { types[name] }

    func readRows(entity: String) -> [(pk: UUID, seq: Int, json: Data)] {
        lock.lock(); defer { lock.unlock() }
        var rows: [(UUID, Int, Data)] = []
        try? db.run("SELECT pk, rowid, json FROM objects WHERE entity = ? ORDER BY rowid", [.text(entity)]) { r in
            if let pk = UUID(uuidString: r.text(0)) { rows.append((pk, r.int(1), r.data(2))) }
        }
        return rows.map { (pk: $0.0, seq: $0.1, json: $0.2) }
    }

    func readRow(entity: String, pk: UUID) -> (seq: Int, json: Data)? {
        lock.lock(); defer { lock.unlock() }
        var found: (Int, Data)?
        try? db.run("SELECT rowid, json FROM objects WHERE entity = ? AND pk = ?",
                    [.text(entity), .text(pk.uuidString)]) { found = ($0.int(0), $0.data(1)) }
        return found.map { (seq: $0.0, json: $0.1) }
    }

    func readBlob(entity: String, pk: UUID, property: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        var data: Data?
        try? db.run("SELECT data FROM blobs WHERE entity = ? AND pk = ? AND property = ?",
                    [.text(entity), .text(pk.uuidString), .text(property)]) { data = $0.data(0) }
        return data
    }

    /// Runs `body` in a transaction and bumps the version on success.
    /// `foreignWrites` reports whether another context saved since `knownVersion`.
    func write(knownVersion: Int, _ body: (SQLiteDatabase) throws -> Void) throws -> (foreign: Bool, version: Int) {
        lock.lock(); defer { lock.unlock() }
        try db.execute("BEGIN IMMEDIATE")
        do {
            try body(db)
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            throw error
        }
        let foreign = _version != knownVersion
        _version += 1
        return (foreign, _version)
    }
}
