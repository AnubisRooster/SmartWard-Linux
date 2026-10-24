import Foundation

private let boxKey = CodingUserInfoKey(rawValue: "shim.decodeBox")!

private final class DecodeBox {
    let object: AnyModel
    var links: [String: [UUID]] = [:]
    init(_ object: AnyModel) { self.object = object }
}

private struct RowDecoder: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ShimKey.self)
        guard let box = decoder.userInfo[boxKey] as? DecodeBox else { return }
        try box.object.__shimDecode(from: c)
        if c.contains(ShimKey("__links")) {
            box.links = try c.decode([String: [UUID]].self, forKey: ShimKey("__links"))
        }
    }
}

private struct RowEncoder: Encodable {
    let object: AnyModel
    let links: [String: [UUID]]

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ShimKey.self)
        try object.__shimEncode(to: &c)
        if !links.isEmpty { try c.encode(links, forKey: ShimKey("__links")) }
    }
}

public final class ModelContext {
    public let container: ModelContainer
    public var autosaveEnabled = false

    private var objects: [String: [UUID: AnyModel]] = [:]
    private var dirty: [UUID: AnyModel] = [:]
    private var pendingDeletes: [(entity: String, pk: UUID)] = []
    private var knownVersion: Int
    private var entitySynced: [String: Int] = [:]

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public init(_ container: ModelContainer) {
        self.container = container
        knownVersion = container.version
    }

    public var hasChanges: Bool { !dirty.isEmpty || !pendingDeletes.isEmpty }

    func noteDirty(_ model: AnyModel) { dirty[model.__shim.pk] = model }

    // MARK: Insert / delete

    public func insert<T: PersistentModel>(_ model: T) {
        insertAny(model)
    }

    func insertAny(_ model: AnyModel) {
        let state = model.__shim
        guard state.context == nil else { return }
        let entity = model.shimEntity
        state.context = self
        state.owner = model
        state.entityName = entity.name
        state.isPendingInsert = true
        state.seq = container.nextSeq()
        objects[entity.name, default: [:]][state.pk] = model
        state.isDirty = true
        dirty[state.pk] = model
        for rel in entity.relationships {
            for target in state.resolvedLinks(rel.name) where target.__shim.context == nil {
                insertAny(target)
            }
        }
    }

    public func delete<T: PersistentModel>(_ model: T) {
        deleteAny(model)
    }

    public func delete<T: PersistentModel>(model: T.Type, where predicate: Predicate<T>? = nil,
                                           includeSubclasses: Bool = true) throws {
        for object in try fetch(FetchDescriptor<T>(predicate: predicate)) { deleteAny(object) }
    }

    private func deleteAny(_ model: AnyModel) {
        let state = model.__shim
        guard state.context === self, !state.isDeleted else { return }
        let entity = model.shimEntity
        state.isDeleted = true
        for rel in entity.relationships {
            let targets = state.resolvedLinks(rel.name)
            switch rel.deleteRule {
            case .cascade:
                for target in targets { deleteAny(target) }
            case .noAction:
                break
            case .nullify, .deny:
                for target in targets { target.__shim.dropInverse(of: rel, owner: model, from: target) }
            }
        }
        objects[entity.name]?[state.pk] = nil
        dirty[state.pk] = nil
        if state.isPersisted { pendingDeletes.append((entity.name, state.pk)) }
    }

    // MARK: Fetch

    public func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        let name = ShimRegistry.entity(of: T.self).name
        try syncEntity(name)
        var result = (objects[name] ?? [:]).values.compactMap { $0 as? T }
            .filter { !$0.__shim.isDeleted }
            .sorted { $0.__shim.seq < $1.__shim.seq }
        if let predicate = descriptor.predicate {
            result = try result.filter { try predicate.evaluate($0) }
        }
        if !descriptor.sortBy.isEmpty { result = result.sorted(using: descriptor.sortBy) }
        if let offset = descriptor.fetchOffset, offset > 0 { result = Array(result.dropFirst(offset)) }
        if let limit = descriptor.fetchLimit { result = Array(result.prefix(limit)) }
        return result
    }

    public func fetchCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        var counting = descriptor
        counting.fetchLimit = nil
        counting.fetchOffset = nil
        return try fetch(counting).count
    }

    // MARK: Save / rollback

    public func save() throws {
        let writes = dirty.values.sorted { $0.__shim.seq < $1.__shim.seq }
        let deletes = pendingDeletes
        guard !writes.isEmpty || !deletes.isEmpty else { return }

        struct Payload {
            let model: AnyModel
            let entity: String
            let pk: UUID
            let json: Data
            let blobs: [(name: String, data: Data?)]
        }
        var payloads: [Payload] = []
        for model in writes {
            let state = model.__shim
            let json = try encoder.encode(RowEncoder(object: model, links: state.linkIDs()))
            let blobs = state.blobs.filter { $0.value.dirty }.map { (name: $0.key, data: $0.value.data) }
            payloads.append(Payload(model: model, entity: state.entityName, pk: state.pk, json: json, blobs: blobs))
        }

        let result = try container.write(knownVersion: knownVersion) { db in
            for p in payloads {
                try db.run("""
                    INSERT INTO objects (entity, pk, json) VALUES (?, ?, ?)
                    ON CONFLICT (entity, pk) DO UPDATE SET json = excluded.json
                    """, [.text(p.entity), .text(p.pk.uuidString), .blob(p.json)])
                for blob in p.blobs {
                    if let data = blob.data {
                        try db.run("""
                            INSERT INTO blobs (entity, pk, property, data) VALUES (?, ?, ?, ?)
                            ON CONFLICT (entity, pk, property) DO UPDATE SET data = excluded.data
                            """, [.text(p.entity), .text(p.pk.uuidString), .text(blob.name), .blob(data)])
                    } else {
                        try db.run("DELETE FROM blobs WHERE entity = ? AND pk = ? AND property = ?",
                                   [.text(p.entity), .text(p.pk.uuidString), .text(blob.name)])
                    }
                }
            }
            for d in deletes {
                try db.run("DELETE FROM objects WHERE entity = ? AND pk = ?", [.text(d.entity), .text(d.pk.uuidString)])
                try db.run("DELETE FROM blobs WHERE entity = ? AND pk = ?", [.text(d.entity), .text(d.pk.uuidString)])
            }
        }

        for p in payloads {
            let state = p.model.__shim
            state.isPersisted = true
            state.isPendingInsert = false
            state.isDirty = false
            state.persistedFingerprint = p.json.hashValue
            for name in state.blobs.keys { state.blobs[name]?.dirty = false }
        }
        dirty.removeAll()
        pendingDeletes.removeAll()
        if !result.foreign {
            for (name, version) in entitySynced where version == knownVersion { entitySynced[name] = result.version }
        }
        knownVersion = result.version
    }

    /// Discards unsaved changes. Objects are re-read from the store on the
    /// next fetch; instances held from before the rollback are stale.
    public func rollback() {
        for model in dirty.values {
            let state = model.__shim
            if state.isPendingInsert { state.isDeleted = true }
            objects[state.entityName]?[state.pk] = nil
        }
        for d in pendingDeletes { objects[d.entity]?[d.pk] = nil }
        dirty.removeAll()
        pendingDeletes.removeAll()
        entitySynced.removeAll()
    }

    public func transaction(block: () throws -> Void) throws {
        try block()
        try save()
    }

    // MARK: Loading

    /// Loads (or refreshes) every stored row of `name` into the identity map.
    private func syncEntity(_ name: String) throws {
        guard let type = container.type(named: name) else { return }
        let version = container.version
        if entitySynced[name] == version { return }
        let deleted = Set(pendingDeletes.filter { $0.entity == name }.map(\.pk))
        var live = Set<UUID>()
        for row in container.readRows(entity: name) {
            live.insert(row.pk)
            if deleted.contains(row.pk) { continue }
            if let existing = objects[name]?[row.pk] {
                let state = existing.__shim
                if !state.isDirty, state.persistedFingerprint != row.json.hashValue {
                    try restore(existing, json: row.json)
                }
            } else {
                _ = try materialize(type: type, entity: name, pk: row.pk, seq: row.seq, json: row.json)
            }
        }
        for (pk, object) in objects[name] ?? [:] {
            let state = object.__shim
            if state.isPersisted, !state.isDirty, !live.contains(pk) {
                state.isDeleted = true
                objects[name]?[pk] = nil
            }
        }
        entitySynced[name] = version
    }

    /// The object for a stored primary key, loading its row if needed.
    func object(entity: String, pk: UUID) -> AnyModel? {
        if let object = objects[entity]?[pk] { return object.__shim.isDeleted ? nil : object }
        if pendingDeletes.contains(where: { $0.entity == entity && $0.pk == pk }) { return nil }
        guard let type = container.type(named: entity), let row = container.readRow(entity: entity, pk: pk) else {
            return nil
        }
        return try? materialize(type: type, entity: entity, pk: pk, seq: row.seq, json: row.json)
    }

    private func materialize(type: any PersistentModel.Type, entity: String, pk: UUID,
                             seq: Int, json: Data) throws -> AnyModel {
        let object = type.init(__shimRestoring: ShimRestoring())
        let state = object.__shim
        state.pk = pk
        state.seq = seq
        state.context = self
        state.owner = object
        state.entityName = entity
        state.isPersisted = true
        try restore(object, json: json)
        objects[entity, default: [:]][pk] = object
        return object
    }

    private func restore(_ object: AnyModel, json: Data) throws {
        let state = object.__shim
        let box = DecodeBox(object)
        let decoder = JSONDecoder()
        decoder.userInfo[boxKey] = box
        state.isLoading = true
        defer { state.isLoading = false }
        _ = try decoder.decode(RowDecoder.self, from: json)
        state.links = box.links.mapValues { .pending($0) }
        for name in state.blobs.keys where state.blobs[name]?.dirty == false { state.blobs[name] = nil }
        state.persistedFingerprint = json.hashValue
        state.isDirty = false
    }
}
