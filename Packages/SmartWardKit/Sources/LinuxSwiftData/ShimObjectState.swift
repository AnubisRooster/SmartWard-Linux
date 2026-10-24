import Foundation

typealias AnyModel = any PersistentModel

/// Per-object bookkeeping: relationship links, external-storage blobs, and
/// the ties to the owning `ModelContext`. Relationships behave as in
/// SwiftData: setting one side updates the inverse side.
public final class ShimObjectState: @unchecked Sendable {
    enum LinkSlot {
        /// Primary keys read from the store, resolved to objects on first use.
        case pending([UUID])
        case resolved([AnyModel])
    }

    struct BlobSlot {
        var data: Data?
        var loaded: Bool
        var dirty: Bool
    }

    var pk: UUID
    var seq = 0
    weak var context: ModelContext?
    unowned(unsafe) var owner: AnyObject?
    var entityName = ""
    /// Not yet written to the store.
    var isPendingInsert = false
    var isDirty = false
    var isDeleted = false
    var isPersisted = false
    /// Suppresses dirty-marking while values are being restored from the store.
    var isLoading = false
    var persistedFingerprint = 0
    var links: [String: LinkSlot] = [:]
    var blobs: [String: BlobSlot] = [:]

    public init() { pk = UUID() }

    init(pk: UUID) { self.pk = pk }

    // MARK: Dirty tracking

    public func attributeDidChange() {
        guard !isLoading else { return }
        markDirty()
    }

    func markDirty() {
        guard !isDeleted else { return }
        isDirty = true
        if let context, let owner = owner as? AnyModel { context.noteDirty(owner) }
    }

    // MARK: Blobs

    public func external<M: PersistentModel>(_ owner: M, _ name: String) -> Data? {
        if let slot = blobs[name], slot.loaded { return slot.data }
        var slot = blobs[name] ?? BlobSlot(data: nil, loaded: false, dirty: false)
        if isPersisted, let context {
            slot.data = context.container.readBlob(entity: entityName, pk: pk, property: name)
        }
        slot.loaded = true
        blobs[name] = slot
        return slot.data
    }

    public func setExternal<M: PersistentModel>(_ owner: M, _ name: String, _ value: Data?) {
        blobs[name] = BlobSlot(data: value, loaded: true, dirty: true)
        markDirty()
    }

    // MARK: Typed relationship access (called by macro-generated accessors)

    public func toMany<T: PersistentModel, M: PersistentModel>(_ owner: M, _ name: String) -> [T]? {
        resolvedLinks(name).compactMap { $0 as? T }
    }

    public func setToMany<T: PersistentModel, M: PersistentModel>(_ owner: M, _ name: String, _ value: [T]?) {
        setLinks(owner: owner, name: name, to: (value ?? []).map { $0 as AnyModel })
    }

    public func toOne<T: PersistentModel, M: PersistentModel>(_ owner: M, _ name: String) -> T? {
        resolvedLinks(name).first as? T
    }

    public func setToOne<T: PersistentModel, M: PersistentModel>(_ owner: M, _ name: String, _ value: T?) {
        setLinks(owner: owner, name: name, to: value.map { [$0 as AnyModel] } ?? [])
    }

    // MARK: Link storage

    func resolvedLinks(_ name: String) -> [AnyModel] {
        switch links[name] {
        case nil: return []
        case .resolved(let objects)?: return objects
        case .pending(let ids)?:
            guard let context, let rel = (owner as? AnyModel)?.shimEntity.relationship(named: name) else { return [] }
            let objects = ids.compactMap { context.object(entity: rel.target, pk: $0) }
            links[name] = .resolved(objects)
            return objects
        }
    }

    private func store(_ name: String, _ objects: [AnyModel]) {
        links[name] = .resolved(objects)
        markDirty()
    }

    /// Sets a relationship and keeps the inverse side in sync.
    func setLinks(owner: AnyModel, name: String, to newValue: [AnyModel]) {
        guard let rel = owner.shimEntity.relationship(named: name) else { return }
        var unique: [AnyModel] = []
        for object in newValue where !unique.contains(where: { $0 === object }) { unique.append(object) }
        if !rel.toMany { unique = Array(unique.prefix(1)) }

        let old = resolvedLinks(name)
        let removed = old.filter { o in !unique.contains { $0 === o } }
        let added = unique.filter { n in !old.contains { $0 === n } }
        store(name, unique)

        for target in removed { target.__shim.dropInverse(of: rel, owner: owner, from: target) }
        for target in added {
            target.__shim.attachInverse(of: rel, owner: owner, to: target)
            adoptContext(owner, target)
        }
    }

    /// Raw edits for the inverse side: no further propagation.
    func removeRaw(_ name: String, _ object: AnyModel) {
        let current = resolvedLinks(name)
        guard current.contains(where: { $0 === object }) else { return }
        store(name, current.filter { $0 !== object })
    }

    func addRaw(_ name: String, _ object: AnyModel, toMany: Bool) {
        var current = resolvedLinks(name)
        if toMany {
            guard !current.contains(where: { $0 === object }) else { return }
            current.append(object)
        } else {
            current = [object]
        }
        store(name, current)
    }

    // MARK: Inverse maintenance

    private func inverseName(of rel: ShimRelationship, ownerEntity: String, target: AnyModel) -> ShimRelationship? {
        let targetEntity = target.shimEntity
        if let name = rel.inverseName { return targetEntity.relationship(named: name) }
        return targetEntity.relationships.first { $0.inverseEntity == ownerEntity && $0.inverseName == rel.name }
    }

    /// `self` is the target's state; `owner` just linked to it through `rel`.
    func attachInverse(of rel: ShimRelationship, owner: AnyModel, to target: AnyModel) {
        guard let inverse = inverseName(of: rel, ownerEntity: owner.shimEntity.name, target: target) else { return }
        if !inverse.toMany, let previous = resolvedLinks(inverse.name).first, previous !== owner {
            // A to-one inverse can point at only one owner: the old one lets go.
            previous.__shim.removeRaw(rel.name, target)
        }
        addRaw(inverse.name, owner, toMany: inverse.toMany)
    }

    func dropInverse(of rel: ShimRelationship, owner: AnyModel, from target: AnyModel) {
        guard let inverse = inverseName(of: rel, ownerEntity: owner.shimEntity.name, target: target) else { return }
        removeRaw(inverse.name, owner)
    }

    private func adoptContext(_ a: AnyModel, _ b: AnyModel) {
        if let context = a.__shim.context, b.__shim.context == nil {
            context.insert(b)
        } else if let context = b.__shim.context, a.__shim.context == nil {
            context.insert(a)
        }
    }

    // MARK: Persistence helpers

    func linkIDs() -> [String: [UUID]] {
        var result: [String: [UUID]] = [:]
        for (name, slot) in links {
            let ids: [UUID]
            switch slot {
            case .pending(let pending): ids = pending
            case .resolved(let objects): ids = objects.filter { !$0.__shim.isDeleted }.map { $0.__shim.pk }
            }
            if !ids.isEmpty { result[name] = ids }
        }
        return result
    }
}
