import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// Linux stand-in for SwiftData's macros. `@Model` inspects the class's stored
// properties and classifies each as a plain attribute, an external-storage
// blob, or a relationship; per-property accessor macros then route reads and
// writes through the runtime in `LinuxSwiftData`.

// MARK: - Property classification

enum PropertyKind {
    case attribute
    case external
    case relationship(RelationshipSyntaxInfo)
}

struct RelationshipSyntaxInfo {
    var target: String
    var toMany: Bool
    var deleteRule: String
    var inverseEntity: String?
    var inverseName: String?
}

struct ModelProperty {
    var name: String
    var kind: PropertyKind
}

private let scalarTypes: Set<String> = [
    "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "CGFloat", "Bool", "Date", "UUID", "Data", "URL", "Decimal", "TimeInterval",
]

private func attributes(of decl: VariableDeclSyntax) -> [AttributeSyntax] {
    decl.attributes.compactMap { $0.as(AttributeSyntax.self) }
}

private func attributeName(_ attr: AttributeSyntax) -> String {
    attr.attributeName.trimmedDescription
}

/// A stored, per-instance `var` declared in the class body (not computed, not static).
private func storedBinding(of decl: VariableDeclSyntax) -> (name: String, type: String?)? {
    guard decl.bindingSpecifier.text == "var",
          !decl.modifiers.contains(where: { $0.name.text == "static" || $0.name.text == "class" }),
          decl.bindings.count == 1, let binding = decl.bindings.first,
          let ident = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }
    if let accessors = binding.accessorBlock {
        switch accessors.accessors {
        case .getter: return nil
        case .accessors(let list):
            // Observers keep a property stored; get/set make it computed.
            let computed = list.contains { ["get", "set", "_read", "_modify"].contains($0.accessorSpecifier.text) }
            if computed { return nil }
        }
    }
    let type = binding.typeAnnotation?.type.trimmedDescription
    return (ident.identifier.text, type)
}

private func relationshipInfo(type: String?, decl: VariableDeclSyntax) -> RelationshipSyntaxInfo? {
    let relAttr = attributes(of: decl).first { attributeName($0) == "Relationship" }
    var rule = "nullify"
    var inverseEntity: String?
    var inverseName: String?
    if let relAttr, case .argumentList(let args)? = relAttr.arguments {
        for arg in args {
            switch arg.label?.text {
            case "deleteRule":
                if let member = arg.expression.as(MemberAccessExprSyntax.self) { rule = member.declName.baseName.text }
            case "inverse":
                if let kp = arg.expression.as(KeyPathExprSyntax.self) {
                    inverseEntity = kp.root?.trimmedDescription
                    if let comp = kp.components.first?.component.as(KeyPathPropertyComponentSyntax.self) {
                        inverseName = comp.declName.baseName.text
                    }
                }
            default: break
            }
        }
    }
    guard var type else { return nil }
    var optional = false
    if type.hasSuffix("?") { optional = true; type.removeLast() }
    else if type.hasPrefix("Optional<"), type.hasSuffix(">") {
        optional = true
        type = String(type.dropFirst("Optional<".count).dropLast())
    }
    var toMany = false
    if type.hasPrefix("["), type.hasSuffix("]"), !type.contains(":") {
        toMany = true
        type = String(type.dropFirst().dropLast())
    }
    type = type.trimmingCharacters(in: .whitespaces)
    guard let first = type.first, first.isUppercase, !type.contains("<"), !type.contains(".") || relAttr != nil else { return nil }
    if relAttr == nil {
        // Without @Relationship, only optional, non-scalar model-looking types count.
        guard optional, !scalarTypes.contains(type) else { return nil }
    }
    return RelationshipSyntaxInfo(target: type, toMany: toMany, deleteRule: rule,
                                  inverseEntity: inverseEntity, inverseName: inverseName)
}

func classify(_ decl: VariableDeclSyntax) -> ModelProperty? {
    guard let (name, type) = storedBinding(of: decl) else { return nil }
    if let info = relationshipInfo(type: type, decl: decl) {
        return ModelProperty(name: name, kind: .relationship(info))
    }
    let external = attributes(of: decl).contains {
        attributeName($0) == "Attribute" && $0.trimmedDescription.contains("externalStorage")
    }
    return ModelProperty(name: name, kind: external ? .external : .attribute)
}

private func properties(of group: some DeclGroupSyntax) -> [ModelProperty] {
    group.memberBlock.members.compactMap { member in
        member.decl.as(VariableDeclSyntax.self).flatMap(classify)
    }
}

// MARK: - @Model

public struct ModelMacro: MemberMacro, MemberAttributeMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
                                 conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let cls = declaration.as(ClassDeclSyntax.self) else { return [] }
        let className = cls.name.text
        let props = properties(of: declaration)

        var relationshipLiterals: [String] = []
        var externalNames: [String] = []
        var encodeLines: [String] = []
        var decodeLines: [String] = []
        for prop in props {
            switch prop.kind {
            case .attribute:
                encodeLines.append("try c.encode(self.\(prop.name), forKey: ShimKey(\"\(prop.name)\"))")
                decodeLines.append("try c.shimAssign(&self.\(prop.name), \"\(prop.name)\")")
            case .external:
                externalNames.append("\"\(prop.name)\"")
            case .relationship(let info):
                let inverseEntity = info.inverseEntity.map { "\"\($0)\"" } ?? "nil"
                let inverseName = info.inverseName.map { "\"\($0)\"" } ?? "nil"
                relationshipLiterals.append("""
                ShimRelationship(name: "\(prop.name)", target: "\(info.target)", toMany: \(info.toMany), \
                deleteRule: .\(info.deleteRule), inverseEntity: \(inverseEntity), inverseName: \(inverseName))
                """)
            }
        }

        return [
            "public let __shim = ShimObjectState()",
            "public required init(__shimRestoring: ShimRestoring) {}",
            """
            public static var __shimEntity: ShimEntity {
                ShimEntity(name: "\(raw: className)",
                           relationships: [\(raw: relationshipLiterals.joined(separator: ", "))],
                           externals: [\(raw: externalNames.joined(separator: ", "))])
            }
            """,
            """
            public func __shimEncode(to c: inout KeyedEncodingContainer<ShimKey>) throws {
                \(raw: encodeLines.joined(separator: "\n    "))
            }
            """,
            """
            public func __shimDecode(from c: KeyedDecodingContainer<ShimKey>) throws {
                \(raw: decodeLines.joined(separator: "\n    "))
            }
            """,
        ]
    }

    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingAttributesFor member: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AttributeSyntax] {
        guard let decl = member.as(VariableDeclSyntax.self), let prop = classify(decl) else { return [] }
        switch prop.kind {
        case .attribute: return ["@_ShimAttribute"]
        case .external: return ["@_ShimExternal"]
        case .relationship(let info): return [info.toMany ? "@_ShimToMany" : "@_ShimToOne"]
        }
    }

    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type.trimmed): PersistentModel {}")]
    }
}

// MARK: - Per-property accessors

private func propertyName(_ decl: some DeclSyntaxProtocol) -> String? {
    decl.as(VariableDeclSyntax.self)?.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
}

public struct ShimAttributeMacro: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        ["didSet { __shim.attributeDidChange() }"]
    }
}

public struct ShimExternalMacro: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let name = propertyName(declaration) else { return [] }
        return [
            "get { __shim.external(self, \"\(raw: name)\") }",
            "set { __shim.setExternal(self, \"\(raw: name)\", newValue) }",
        ]
    }
}

public struct ShimToManyMacro: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let name = propertyName(declaration) else { return [] }
        return [
            "get { __shim.toMany(self, \"\(raw: name)\") }",
            "set { __shim.setToMany(self, \"\(raw: name)\", newValue) }",
        ]
    }
}

public struct ShimToOneMacro: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        guard let name = propertyName(declaration) else { return [] }
        return [
            "get { __shim.toOne(self, \"\(raw: name)\") }",
            "set { __shim.setToOne(self, \"\(raw: name)\", newValue) }",
        ]
    }
}

/// `@Relationship` / `@Attribute` carry information the `@Model` macro reads
/// syntactically; on their own they expand to nothing.
public struct NoOpMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

@main
struct SwiftDataMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ModelMacro.self, ShimAttributeMacro.self, ShimExternalMacro.self,
        ShimToManyMacro.self, ShimToOneMacro.self, NoOpMacro.self,
    ]
}
