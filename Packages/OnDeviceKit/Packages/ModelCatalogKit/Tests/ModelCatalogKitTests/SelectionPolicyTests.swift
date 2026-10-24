import XCTest
@testable import ModelCatalogKit

final class SelectionPolicyTests: XCTestCase {
    let freeModel = CatalogEntry(
        id: "free/chat", name: "Free Chat", pricing: .zero, contextLength: 4096,
        architecture: Architecture(inputModalities: ["text"], outputModalities: ["text"]),
        supportedParameters: ["streaming"]
    )

    let cheapModel = CatalogEntry(
        id: "cheap/chat", name: "Cheap Chat",
        pricing: Pricing(prompt: 0.0001, completion: 0.0002, image: nil, perRequest: nil),
        contextLength: 8192,
        architecture: Architecture(inputModalities: ["text"], outputModalities: ["text"]),
        supportedParameters: ["streaming"]
    )

    let expensiveModel = CatalogEntry(
        id: "expensive/chat", name: "Expensive Chat",
        pricing: Pricing(prompt: 0.002, completion: 0.006, image: nil, perRequest: nil),
        contextLength: 16384,
        architecture: Architecture(inputModalities: ["text", "image"], outputModalities: ["text"]),
        supportedParameters: []
    )

    let imageModel = CatalogEntry(
        id: "image/model", name: "Image Generator",
        pricing: Pricing(prompt: 0.01, completion: 0.01, image: 0.05, perRequest: nil),
        contextLength: nil,
        architecture: Architecture(inputModalities: ["text", "image"], outputModalities: ["image"]),
        supportedParameters: ["input_references"]
    )

    func testFreeModelRanksFirstForChat() {
        let policy = SelectionPolicy(role: .chat, catalog: [cheapModel, freeModel, expensiveModel])
        XCTAssertEqual(policy.rank().first?.id, "free/chat")
    }

    func testCheapestPaidModelAfterFree() {
        let policy = SelectionPolicy(role: .chat, catalog: [expensiveModel, cheapModel, freeModel])
        let ranked = policy.rank()
        XCTAssertEqual(ranked[0].id, "free/chat")
        XCTAssertEqual(ranked[1].id, "cheap/chat")
        XCTAssertEqual(ranked[2].id, "expensive/chat")
    }

    func testPinnedModelAlwaysFirst() {
        let policy = SelectionPolicy(role: .chat, catalog: [freeModel, expensiveModel, cheapModel],
                                     pinnedModelId: "expensive/chat")
        XCTAssertEqual(policy.rank().first?.id, "expensive/chat")
    }

    func testBestReturnsTopFreeModel() {
        let policy = SelectionPolicy(role: .chat, catalog: [expensiveModel, cheapModel, freeModel])
        XCTAssertEqual(policy.best()?.id, "free/chat")
    }

    func testImageModelFilteredByRole() {
        let policy = SelectionPolicy(role: .image, catalog: [freeModel, imageModel, cheapModel])
        let ranked = policy.rank()
        XCTAssertTrue(ranked.allSatisfy { $0.architecture?.outputModalities?.contains("image") ?? false })
        XCTAssertTrue(ranked.contains { $0.id == "image/model" })
    }

    func testEmptyCatalogReturnsNilBest() {
        let policy = SelectionPolicy(role: .chat, catalog: [])
        XCTAssertNil(policy.best())
    }

    func testTextModelMeetsChatRoleWithoutModalities() {
        let basicModel = CatalogEntry(id: "basic/chat", name: "Basic Chat", pricing: .zero,
                                      contextLength: 2048, architecture: nil, supportedParameters: nil)
        let policy = SelectionPolicy(role: .chat, catalog: [basicModel])
        XCTAssertEqual(policy.best()?.id, "basic/chat")
    }

    func testPinnedModelIneligibleForRoleIsIgnored() {
        // A pinned id that doesn't meet the role's requirements should not
        // be forced to the front — it simply isn't in `filtered`.
        let policy = SelectionPolicy(role: .image, catalog: [freeModel, imageModel],
                                     pinnedModelId: "free/chat")
        XCTAssertEqual(policy.best()?.id, "image/model")
    }
}
