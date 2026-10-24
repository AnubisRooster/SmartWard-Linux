import Foundation

/// The `k` best elements without sorting everything: a bounded min-heap,
/// O(n log k). Ranking a large candidate set for the top few shouldn't cost
/// a full sort — `VectorIndex.search` and `LexicalIndex.search` both build on
/// this instead of `Array.sort()` + `prefix(_:)`.
public struct TopK<Element> {
    public let k: Int
    /// `true` when the first argument ranks higher.
    private let ranksHigher: (Element, Element) -> Bool
    /// Min-heap by rank: the weakest kept element is at the root.
    private var heap: [Element] = []

    public init(_ k: Int, ranksHigher: @escaping (Element, Element) -> Bool) {
        self.k = max(0, k)
        self.ranksHigher = ranksHigher
        heap.reserveCapacity(self.k)
    }

    public mutating func insert(_ element: Element) {
        guard k > 0 else { return }
        if heap.count < k {
            heap.append(element)
            siftUp(heap.count - 1)
        } else if ranksHigher(element, heap[0]) {
            heap[0] = element
            siftDown(0)
        }
    }

    /// Best first.
    public func sorted() -> [Element] {
        heap.sorted(by: ranksHigher)
    }

    private mutating func siftUp(_ index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            guard ranksHigher(heap[parent], heap[child]) else { return }
            heap.swapAt(parent, child)
            child = parent
        }
    }

    private mutating func siftDown(_ index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var weakest = parent
            if left < heap.count, ranksHigher(heap[weakest], heap[left]) { weakest = left }
            if right < heap.count, ranksHigher(heap[weakest], heap[right]) { weakest = right }
            guard weakest != parent else { return }
            heap.swapAt(parent, weakest)
            parent = weakest
        }
    }
}
