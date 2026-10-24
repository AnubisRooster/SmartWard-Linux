#if canImport(LocalAuthentication)
import XCTest
@testable import BiometricLockKit

final class BiometricServiceTests: XCTestCase {

    private func service(_ eval: FakeEvaluator, _ store: InMemoryStore = InMemoryStore()) -> BiometricService {
        BiometricService(evaluator: eval, store: store)
    }

    // MARK: - Result mapping (raw evaluation → BiometricResult)

    func testSuccessWithNoDomainStateUnlocks() async {
        let result = await service(FakeEvaluator(.success(domainState: nil))).unlock(reason: "unlock")
        XCTAssertEqual(result, .success)
    }

    func testFallbackIsSurfaced() async {
        let result = await service(FakeEvaluator(.fallback)).unlock(reason: "unlock")
        XCTAssertEqual(result, .fallback)
    }

    func testLockoutIsSurfaced() async {
        let result = await service(FakeEvaluator(.lockout)).unlock(reason: "unlock")
        XCTAssertEqual(result, .lockout)
    }

    func testCanceledIsSurfaced() async {
        let result = await service(FakeEvaluator(.canceled)).unlock(reason: "unlock")
        XCTAssertEqual(result, .canceled)
    }

    func testUnavailablePropagatesReason() async {
        let result = await service(FakeEvaluator(.unavailable(.notEnrolled))).unlock(reason: "unlock")
        XCTAssertEqual(result, .unavailable(.notEnrolled))
    }

    func testUnexpectedErrorMapsToFailedNotSuccess() async {
        // An unexpected LAError must never read as an unlock.
        let result = await service(FakeEvaluator(.error("boom"))).unlock(reason: "unlock")
        XCTAssertEqual(result, .failed)
    }

    // MARK: - Introspection passthrough

    func testBiometryTypePassthrough() {
        let eval = FakeEvaluator(.success(domainState: nil)); eval.type = .touchID
        XCTAssertEqual(service(eval).biometryType(), .touchID)
    }

    func testAvailabilityPassthrough() {
        let eval = FakeEvaluator(.success(domainState: nil))
        eval.canEvaluateResult = .failure(.passcodeNotSet)
        if case .failure(let reason) = service(eval).availability() {
            XCTAssertEqual(reason, .passcodeNotSet)
        } else {
            XCTFail("expected unavailability to propagate")
        }
    }
}
#endif
