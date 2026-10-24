import Foundation

// A Linux-only module named `SwiftData`, so `import SwiftData` in the shared
// sources keeps working off Apple platforms. It implements the subset
// SmartWard uses (@Model, relationships with inverses, ModelContext,
// FetchDescriptor with Foundation's #Predicate), persisting to SQLite.

@attached(member, names: named(__shim), named(init(__shimRestoring:)), named(__shimEntity),
          named(__shimEncode(to:)), named(__shimDecode(from:)))
@attached(memberAttribute)
@attached(extension, conformances: PersistentModel)
public macro Model() = #externalMacro(module: "SwiftDataMacros", type: "ModelMacro")

@attached(peer)
public macro Relationship(deleteRule: Schema.Relationship.DeleteRule = .nullify,
                          inverse: AnyKeyPath? = nil) = #externalMacro(module: "SwiftDataMacros", type: "NoOpMacro")

@attached(peer)
public macro Attribute(_ options: Schema.Attribute.Option...) = #externalMacro(module: "SwiftDataMacros", type: "NoOpMacro")

// Applied to members by @Model; not part of the public SwiftData surface.
@attached(accessor, names: named(didSet))
public macro _ShimAttribute() = #externalMacro(module: "SwiftDataMacros", type: "ShimAttributeMacro")

@attached(accessor, names: named(get), named(set))
public macro _ShimExternal() = #externalMacro(module: "SwiftDataMacros", type: "ShimExternalMacro")

@attached(accessor, names: named(get), named(set))
public macro _ShimToMany() = #externalMacro(module: "SwiftDataMacros", type: "ShimToManyMacro")

@attached(accessor, names: named(get), named(set))
public macro _ShimToOne() = #externalMacro(module: "SwiftDataMacros", type: "ShimToOneMacro")
