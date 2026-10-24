import Foundation

public protocol PersistentModel: AnyObject, Hashable {
    static var __shimEntity: ShimEntity { get }
    var __shim: ShimObjectState { get }
    init(__shimRestoring: ShimRestoring)
    func __shimEncode(to c: inout KeyedEncodingContainer<ShimKey>) throws
    func __shimDecode(from c: KeyedDecodingContainer<ShimKey>) throws
}

extension PersistentModel {
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

extension PersistentModel {
    var shimEntity: ShimEntity { ShimRegistry.entity(of: type(of: self)) }
}
