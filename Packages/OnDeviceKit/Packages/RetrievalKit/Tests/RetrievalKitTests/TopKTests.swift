import XCTest
@testable import RetrievalKit

final class TopKTests: XCTestCase {
    private func higher(_ a: Int, _ b: Int) -> Bool { a > b }

    func testKeepsOnlyTheKLargestSortedDescending() {
        var topK = TopK<Int>(3, ranksHigher: higher)
        for value in [5, 1, 9, 3, 7, 2, 8] { topK.insert(value) }
        XCTAssertEqual(topK.sorted(), [9, 8, 7])
    }

    func testFewerElementsThanKReturnsWhatWasInserted() {
        var topK = TopK<Int>(10, ranksHigher: higher)
        topK.insert(4)
        topK.insert(1)
        XCTAssertEqual(topK.sorted(), [4, 1])
    }

    func testKOfZeroKeepsNothing() {
        var topK = TopK<Int>(0, ranksHigher: higher)
        topK.insert(1)
        topK.insert(2)
        XCTAssertTrue(topK.sorted().isEmpty)
    }

    func testNegativeKIsClampedToZero() {
        var topK = TopK<Int>(-5, ranksHigher: higher)
        topK.insert(1)
        XCTAssertTrue(topK.sorted().isEmpty)
    }

    func testCustomComparatorOrdersByItsOwnRule() {
        // Ranks lower numbers higher (a min-of-k), to confirm the comparator
        // controls direction rather than TopK assuming "larger is better".
        var topK = TopK<Int>(2) { $0 < $1 }
        for value in [5, 1, 9, 3] { topK.insert(value) }
        XCTAssertEqual(topK.sorted(), [1, 3])
    }
}
