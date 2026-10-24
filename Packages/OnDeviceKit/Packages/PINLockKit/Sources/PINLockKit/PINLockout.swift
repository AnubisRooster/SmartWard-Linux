import Foundation

/// Result of a PIN entry attempt.
public enum PINAttemptResult: Equatable, Sendable {
    case success
    case incorrect(attemptsRemaining: Int)
    case lockedOut(secondsRemaining: Int)
}

/// Minimal key-value store `PINLockout` persists its counters through.
/// `UserDefaults` conforms natively (used by tests, for isolation); host apps
/// that want lockout state to survive app deletion/reinstallation should
/// inject a Keychain-backed store instead — see `KeychainLockoutStore`.
/// Without that, deleting and reinstalling the app silently resets a
/// brute-force lockout back to zero.
public protocol PINLockoutStore {
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func set(_ value: Int, forKey key: String)
    func set(_ value: Double, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: PINLockoutStore {}

/// Brute-force lockout state machine, kept separate from Keychain so it is
/// fully unit-testable with an injected store and clock.
public struct PINLockout {
    let defaults: PINLockoutStore
    let maxAttempts: Int

    private let failKey  = "pin_fail_count"
    private let levelKey = "pin_lock_level"
    // Stores the deadline as a monotonic uptime value, not a wall-clock
    // timestamp — see `lockoutRemaining` for why.
    private let untilUptimeKey = "pin_lock_until_uptime"

    public init(defaults: PINLockoutStore = UserDefaults.standard, maxAttempts: Int = 5) {
        self.defaults = defaults
        self.maxAttempts = maxAttempts
    }

    /// Lockout duration for the Nth lockout (1-based), escalating then capped.
    public func lockoutDuration(level: Int) -> TimeInterval {
        switch level {
        case ..<1:  return 0
        case 1:     return 30
        case 2:     return 60
        case 3:     return 300
        default:    return 900
        }
    }

    /// Seconds remaining in the current lockout, or 0 if not locked out.
    ///
    /// `uptime` is monotonic time since boot (default:
    /// `ProcessInfo.processInfo.systemUptime`), not wall-clock `Date()` —
    /// advancing the device's date/time in Settings can't rewind it, so it
    /// can't be used to bypass a lockout the way a `Date()`-based deadline
    /// could. The tradeoff is that a device reboot resets uptime to ~0; a
    /// stored deadline would then look astronomically far in the future
    /// rather than expired, so any remaining value beyond the longest
    /// possible lockout duration is treated as stale (post-reboot) rather
    /// than "still locked out".
    public func lockoutRemaining(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int {
        let until = defaults.double(forKey: untilUptimeKey)
        guard until > 0 else { return 0 }
        let remaining = until - uptime
        guard remaining > 0, remaining <= lockoutDuration(level: .max) else { return 0 }
        // The deadline loses sub-microsecond precision round-tripping through
        // storage as a Double. Shave a tiny epsilon before rounding up so an
        // exact value like 20.0 doesn't intermittently round to 21 due to
        // that floating-point noise.
        return Int((remaining - 0.0001).rounded(.up))
    }

    public var isLockedOut: Bool { lockoutRemaining() > 0 }

    /// Records a failed attempt and returns the resulting state.
    public mutating func registerFailure(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> PINAttemptResult {
        if lockoutRemaining(uptime: uptime) > 0 {
            return .lockedOut(secondsRemaining: lockoutRemaining(uptime: uptime))
        }
        let fails = defaults.integer(forKey: failKey) + 1
        if fails >= maxAttempts {
            let level = defaults.integer(forKey: levelKey) + 1
            let duration = lockoutDuration(level: level)
            defaults.set(level, forKey: levelKey)
            defaults.set(uptime + duration, forKey: untilUptimeKey)
            defaults.set(0, forKey: failKey)
            return .lockedOut(secondsRemaining: Int(duration.rounded(.up)))
        }
        defaults.set(fails, forKey: failKey)
        return .incorrect(attemptsRemaining: maxAttempts - fails)
    }

    /// Clears all failure/lockout state after a correct PIN.
    public mutating func registerSuccess() {
        defaults.removeObject(forKey: failKey)
        defaults.removeObject(forKey: levelKey)
        defaults.removeObject(forKey: untilUptimeKey)
    }
}
