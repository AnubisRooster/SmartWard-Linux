import XCTest
@testable import PINLockKit

final class PINLockoutTests: XCTestCase {

    private func ephemeralDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeLockout(maxAttempts: Int = 5) -> PINLockout {
        PINLockout(defaults: ephemeralDefaults(), maxAttempts: maxAttempts)
    }

    // MARK: - Positive: normal failure accounting

    func testFailuresBelowThresholdReportRemainingAttempts() {
        var lockout = makeLockout(maxAttempts: 5)
        XCTAssertEqual(lockout.registerFailure(), .incorrect(attemptsRemaining: 4))
        XCTAssertEqual(lockout.registerFailure(), .incorrect(attemptsRemaining: 3))
        XCTAssertEqual(lockout.registerFailure(), .incorrect(attemptsRemaining: 2))
        XCTAssertEqual(lockout.registerFailure(), .incorrect(attemptsRemaining: 1))
        XCTAssertFalse(lockout.isLockedOut)
    }

    func testReachingThresholdLocksOut() {
        var lockout = makeLockout(maxAttempts: 5)
        for _ in 0..<4 { _ = lockout.registerFailure() }
        let result = lockout.registerFailure()
        XCTAssertEqual(result, .lockedOut(secondsRemaining: 30))
        XCTAssertTrue(lockout.isLockedOut)
    }

    func testLockoutEscalatesOnRepeatedRounds() {
        var lockout = makeLockout(maxAttempts: 2)
        let now: TimeInterval = 1_000

        // Round 1 → 30s lockout.
        _ = lockout.registerFailure(uptime: now)
        XCTAssertEqual(lockout.registerFailure(uptime: now), .lockedOut(secondsRemaining: 30))

        // After it expires, the next round escalates to 60s.
        let afterFirst = now + 31
        _ = lockout.registerFailure(uptime: afterFirst)
        XCTAssertEqual(lockout.registerFailure(uptime: afterFirst), .lockedOut(secondsRemaining: 60))
    }

    // MARK: - Negative / boundary

    func testAttemptsDuringLockoutAreRejectedWithoutCounting() {
        var lockout = makeLockout(maxAttempts: 2)
        let now: TimeInterval = 1_000
        _ = lockout.registerFailure(uptime: now)
        _ = lockout.registerFailure(uptime: now)   // now locked for 30s

        let during = now + 10
        if case .lockedOut(let remaining) = lockout.registerFailure(uptime: during) {
            XCTAssertEqual(remaining, 20)        // 30 - 10
        } else {
            XCTFail("Expected lockedOut while inside the lockout window")
        }
    }

    func testRegisterSuccessClearsAllState() {
        var lockout = makeLockout(maxAttempts: 2)
        _ = lockout.registerFailure()
        _ = lockout.registerFailure()           // locked
        XCTAssertTrue(lockout.isLockedOut)

        lockout.registerSuccess()
        XCTAssertFalse(lockout.isLockedOut)
        XCTAssertEqual(lockout.lockoutRemaining(), 0)
        // And the next failure starts the counter fresh.
        XCTAssertEqual(lockout.registerFailure(), .incorrect(attemptsRemaining: 1))
    }

    func testLockoutRemainingIsZeroAfterExpiry() {
        var lockout = makeLockout(maxAttempts: 1)
        let now: TimeInterval = 1_000
        _ = lockout.registerFailure(uptime: now)   // immediately locked (30s)
        XCTAssertEqual(lockout.lockoutRemaining(uptime: now + 31), 0)
    }

    func testLockoutRemainingIsZeroWhenStaleDeadlineFollowsRebootLikeUptimeReset() {
        // A device reboot resets systemUptime to ~0; a stale stored deadline
        // (from before reboot) would otherwise look astronomically far in
        // the future rather than expired. Simulate that: lock out at a large
        // uptime, then query with a much smaller "post reboot" uptime.
        var lockout = makeLockout(maxAttempts: 1)
        _ = lockout.registerFailure(uptime: 50_000)   // locked until ~50_030
        XCTAssertEqual(lockout.lockoutRemaining(uptime: 5), 0)
    }

    // MARK: - PINService.attempt integration (no Keychain write needed)

    func testServiceAttemptWithWrongPinEventuallyLocksOut() {
        let service = PINService(service: "kit-tests.pin.\(UUID().uuidString)", defaults: ephemeralDefaults())
        // No PIN stored → verify always false → these are all "incorrect".
        var lastResult: PINAttemptResult = .success
        for _ in 0..<5 { lastResult = service.attempt("000000") }
        XCTAssertEqual(lastResult, .lockedOut(secondsRemaining: 30))
        XCTAssertTrue(service.isLockedOut)
    }

    // Note: KeychainLockoutStore and PINService.save()/verify() are
    // deliberately not exercised here with real Keychain reads/writes — a
    // bare SPM XCTest bundle has no host .app and so no keychain-access-group
    // entitlement, which makes SecItemAdd silently no-op on iOS Simulator in
    // this configuration (confirmed by reproduction: every assertion below
    // that depended on a prior write came back as the untouched default).
    // BiometricLockKit's own KeychainDomainStateStore — the same pattern,
    // added earlier — has no direct tests for the same reason; its real
    // Keychain behavior is proven by the host app's own test suite instead,
    // which links a real TEST_HOST with proper entitlements. PINLockout's
    // actual lockout logic (including the monotonic-clock and
    // reboot-staleness fixes) is still fully covered above via the
    // PINLockoutStore protocol, independent of which concrete store backs it.
}
