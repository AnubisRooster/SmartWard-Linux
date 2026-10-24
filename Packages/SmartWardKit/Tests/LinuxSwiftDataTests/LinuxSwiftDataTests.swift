import Foundation
import SwiftData
import XCTest

@Model
final class Parent {
    var id: UUID = UUID()
    var name: String = ""
    var tags: [String] = []
    var created: Date = Date()
    var note: String?

    @Relationship(deleteRule: .cascade, inverse: \Child.parent)
    var children: [Child]? = []
    @Relationship(inverse: \Tag.parents)
    var pinned: [Tag]? = []

    init(name: String) { self.name = name }
}

@Model
final class Child {
    var id: UUID = UUID()
    var title: String = ""
    var parent: Parent?
    @Attribute(.externalStorage) var blob: Data?

    init(title: String) { self.title = title }
}

@Model
final class Tag {
    var id: UUID = UUID()
    var label: String = ""
    var parents: [Parent]? = []

    init(label: String) { self.label = label }
}

final class LinuxSwiftDataTests: XCTestCase {
    private func makeContainer(inMemory: Bool = true, url: URL? = nil) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none, url: url)
        return try ModelContainer(for: Schema([Parent.self, Child.self, Tag.self]), configurations: [config])
    }

    func testInsertSaveFetchWithPredicateAndSort() throws {
        let context = try makeContainer().mainContext
        for name in ["b", "a", "c"] { context.insert(Parent(name: name)) }
        try context.save()
        let all = try context.fetch(FetchDescriptor<Parent>(sortBy: [SortDescriptor(\.name)]))
        XCTAssertEqual(all.map(\.name), ["a", "b", "c"])
        let target = "b"
        let one = try context.fetch(FetchDescriptor<Parent>(predicate: #Predicate { $0.name == target }))
        XCTAssertEqual(one.count, 1)
        var limited = FetchDescriptor<Parent>(sortBy: [SortDescriptor(\.name, order: .reverse)])
        limited.fetchLimit = 2
        XCTAssertEqual(try context.fetch(limited).map(\.name), ["c", "b"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Parent>()), 3)
    }

    func testInverseRelationshipsStayInSync() throws {
        let parent = Parent(name: "p")
        let child = Child(title: "c")
        parent.children?.append(child)
        XCTAssertTrue(child.parent === parent)

        let other = Parent(name: "q")
        child.parent = other
        XCTAssertEqual(parent.children?.count, 0)
        XCTAssertEqual(other.children?.count, 1)

        let tag = Tag(label: "t")
        parent.pinned?.append(tag)
        XCTAssertEqual(tag.parents?.map(\.name), ["p"])
    }

    func testInsertingParentInsertsRelatedAndPredicateWalksRelationship() throws {
        let context = try makeContainer().mainContext
        let parent = Parent(name: "p")
        parent.children?.append(Child(title: "kid"))
        context.insert(parent)
        let kids = try context.fetch(FetchDescriptor<Child>(predicate: #Predicate { $0.parent?.name == "p" }))
        XCTAssertEqual(kids.map(\.title), ["kid"])
    }

    func testCascadeDeleteAndNullify() throws {
        let context = try makeContainer().mainContext
        let parent = Parent(name: "p")
        let tag = Tag(label: "t")
        parent.children?.append(Child(title: "kid"))
        parent.pinned?.append(tag)
        context.insert(parent)
        try context.save()
        context.delete(parent)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Child>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Tag>()), 1)
        XCTAssertEqual(tag.parents?.count, 0)
    }

    func testPersistsAcrossContainersOnDisk() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shim-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let context = try makeContainer(inMemory: false, url: url).mainContext
            let parent = Parent(name: "persisted")
            parent.tags = ["x", "y"]
            parent.note = "n"
            let child = Child(title: "kid")
            child.blob = Data([1, 2, 3])
            parent.children?.append(child)
            context.insert(parent)
            try context.save()
        }
        let context = try makeContainer(inMemory: false, url: url).mainContext
        let parent = try XCTUnwrap(context.fetch(FetchDescriptor<Parent>()).first)
        XCTAssertEqual(parent.name, "persisted")
        XCTAssertEqual(parent.tags, ["x", "y"])
        XCTAssertEqual(parent.note, "n")
        XCTAssertEqual(parent.children?.map(\.title), ["kid"])
        XCTAssertTrue(parent.children?.first?.parent === parent)
        XCTAssertEqual(parent.children?.first?.blob, Data([1, 2, 3]))
    }

    func testSecondContextSeesSavedChangesAndEdits() throws {
        let container = try makeContainer()
        let a = ModelContext(container)
        let b = ModelContext(container)
        a.insert(Parent(name: "one"))
        try a.save()
        let seen = try b.fetch(FetchDescriptor<Parent>())
        XCTAssertEqual(seen.map(\.name), ["one"])
        seen[0].name = "renamed"
        try b.save()
        XCTAssertEqual(try a.fetch(FetchDescriptor<Parent>()).map(\.name), ["renamed"])
    }

    func testAttributeEditsAreSavedAndRollbackDiscardsInserts() throws {
        let context = try makeContainer().mainContext
        let parent = Parent(name: "p")
        context.insert(parent)
        try context.save()
        parent.name = "changed"
        XCTAssertTrue(context.hasChanges)
        try context.save()
        XCTAssertFalse(context.hasChanges)

        context.insert(Parent(name: "temp"))
        context.rollback()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Parent>()).map(\.name), ["changed"])
    }
}
