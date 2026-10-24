#if canImport(LocalAuthentication)
import Foundation
@testable import BiometricLockKit

/// A programmable `BiometricEvaluating` so tests drive every branch of
/// `BiometricService` without a device, entitlement, or `LAContext`.
final class FakeEvaluator: BiometricEvaluating, @unchecked Sendable {
    var type: BiometryType = .faceID
    var canEvaluateResult: Result<Void, BiometricUnavailable> = .success(())
    /// The queue of results `evaluate` returns, one per call; the last is reused
    /// once the queue drains.
    var evaluations: [BiometricEvaluation]
    private(set) var evaluateCallCount = 0

    init(_ evaluations: [BiometricEvaluation]) {
        self.evaluations = evaluations
    }

    convenience init(_ single: BiometricEvaluation) { self.init([single]) }

    func biometryType() -> BiometryType { type }
    func canEvaluate() -> Result<Void, BiometricUnavailable> { canEvaluateResult }

    func evaluate(reason: String) async -> BiometricEvaluation {
        defer { evaluateCallCount += 1 }
        let index = min(evaluateCallCount, evaluations.count - 1)
        return evaluations[index]
    }
}

/// In-memory `DomainStateStoring`, keeping the Keychain out of the test path.
final class InMemoryStore: DomainStateStoring, @unchecked Sendable {
    private var data: Data?
    init(_ initial: Data? = nil) { self.data = initial }
    func load() -> Data? { data }
    func save(_ data: Data) { self.data = data }
    func clear() { data = nil }
}
#endif
