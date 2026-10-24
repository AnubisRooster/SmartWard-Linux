import Foundation

/// Ranks a model catalog for a given role using a cost-first policy: free
/// models first, then cheapest-paid, with an optional pinned model always
/// sorted to the front. Pure and synchronous — no network access — so it's
/// trivially unit-testable and safe to call from any context.
public struct SelectionPolicy: Sendable {
    public let role: ModelRole
    public let catalog: [CatalogEntry]
    public let pinnedModelId: String?

    public init(role: ModelRole, catalog: [CatalogEntry], pinnedModelId: String? = nil) {
        self.role = role
        self.catalog = catalog
        self.pinnedModelId = pinnedModelId
    }

    /// All catalog entries that satisfy `role`, ranked free-first then
    /// cheapest-first, with `pinnedModelId` (if present and eligible) moved
    /// to the front. Callers that want automatic fallback can walk this list
    /// in order, advancing to the next candidate on a 429/5xx.
    public func rank() -> [CatalogEntry] {
        let filtered = catalog.filter { meetsRequirements($0, for: role) }
        let sorted = filtered.sorted { a, b in
            let aFree = isFree(a)
            let bFree = isFree(b)
            if aFree != bFree { return aFree }
            return totalCost(a) < totalCost(b)
        }
        if let pinned = pinnedModelId, let match = filtered.first(where: { $0.id == pinned }) {
            return [match] + sorted.filter { $0.id != pinned }
        }
        return sorted
    }

    public func best() -> CatalogEntry? { rank().first }

    private func meetsRequirements(_ entry: CatalogEntry, for role: ModelRole) -> Bool {
        switch role {
        case .chat, .extract:
            guard let arch = entry.architecture else { return true }
            return arch.outputModalities?.contains("text") ?? true
        case .image:
            if entry.architecture?.outputModalities?.contains("image") == true { return true }
            return entry.supportedParameters?.contains("input_references") ?? false
        }
    }

    private func isFree(_ entry: CatalogEntry) -> Bool {
        entry.pricing.prompt == 0 && entry.pricing.completion == 0 && (entry.pricing.image ?? 0) == 0
    }

    private func totalCost(_ entry: CatalogEntry) -> Double {
        entry.pricing.prompt + entry.pricing.completion + (entry.pricing.image ?? 0)
    }
}
