import Foundation

public struct FetchDescriptor<T: PersistentModel> {
    public var predicate: Predicate<T>?
    public var sortBy: [SortDescriptor<T>]
    public var fetchLimit: Int?
    public var fetchOffset: Int?
    public var includePendingChanges = true
    public var propertiesToFetch: [PartialKeyPath<T>] = []
    public var relationshipKeyPathsForPrefetching: [PartialKeyPath<T>] = []

    public init(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) {
        self.predicate = predicate
        self.sortBy = sortBy
    }
}
