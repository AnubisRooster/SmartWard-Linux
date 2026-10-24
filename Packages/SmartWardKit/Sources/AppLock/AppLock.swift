import Foundation
import PINLockKit
import BiometricLockKit

// MARK: - Seams

/// What the coordinator needs from a PIN store. `PINService` conforms.
public protocol PINVerifying: AnyObject {
    var isPINSetup: Bool { get }
    var isLockedOut: Bool { get }
    var lockoutRemaining: Int { get }
    func attemptPIN(_ pin: String) -> PINAttemptResult
}

extension PINService: PINVerifying {
    public func attemptPIN(_ pin: String) -> PINAttemptResult { attempt(pin) }
}

/// What the coordinator needs from biometrics. `BiometricService` conforms.
public protocol BiometricUnlocking: AnyObject {
    func biometryType() -> BiometryType
    func availability() -> Result<Void, BiometricUnavailable>
    func unlock(reason: String) async -> BiometricResult
    func acceptCurrentBiometry()
}

#if canImport(LocalAuthentication)
extension BiometricService: BiometricUnlocking {}
#endif

// MARK: - Policy

/// When the app should lock (PLAN §5.7): always on a cold launch, and after
/// being in the background for at least `gracePeriod`.
public struct AppLockPolicy: Equatable, Sendable {
    public var isEnabled: Bool
    public var gracePeriod: TimeInterval

    public init(isEnabled: Bool, gracePeriod: TimeInterval = 0) {
        self.isEnabled = isEnabled
        self.gracePeriod = max(0, gracePeriod)
    }

    /// - Parameter backgroundedAt: when the app last left the foreground, or
    ///   `nil` on a cold launch.
    public func shouldLock(backgroundedAt: Date?, now: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        guard let backgroundedAt else { return true }
        return now.timeIntervalSince(backgroundedAt) >= gracePeriod
    }
}

// MARK: - Coordinator

/// Biometrics as the fast path, the PIN as the always-present fallback
/// (OnDeviceKit's `AppLockCoordinator` pattern, split into steps a SwiftUI
/// lock screen can drive).
@MainActor
public final class AppLockCoordinator {
    public enum BiometricStep: Equatable {
        case unlocked
        /// Show the PIN pad. `rebaseline` is true when the enrolled
        /// biometrics changed: after the PIN is verified, the new set is trusted.
        case needsPIN(rebaseline: Bool)
    }

    public enum PINOutcome: Equatable {
        case unlocked
        case incorrect(attemptsRemaining: Int)
        case lockedOut(secondsRemaining: Int)
        /// No PIN has been set, so the PIN path can't unlock.
        case noPIN
    }

    private let pin: any PINVerifying
    private let biometrics: any BiometricUnlocking

    public init(pin: any PINVerifying, biometrics: any BiometricUnlocking) {
        self.pin = pin
        self.biometrics = biometrics
    }

    /// "Face ID", "Touch ID", …; `nil` when biometrics can't be used.
    public var biometryName: String? {
        guard case .success = biometrics.availability() else { return nil }
        let type = biometrics.biometryType()
        return type == .none ? nil : type.displayName
    }

    public var isPINLockedOut: Bool { pin.isLockedOut }
    public var pinLockoutRemaining: Int { pin.lockoutRemaining }

    public func unlockWithBiometrics(reason: String) async -> BiometricStep {
        guard case .success = biometrics.availability() else { return .needsPIN(rebaseline: false) }
        let result = await biometrics.unlock(reason: reason)
        switch result {
        case .success:
            return .unlocked
        case .biometryChanged:
            return .needsPIN(rebaseline: true)
        case .failed, .fallback, .lockout, .canceled, .unavailable:
            return .needsPIN(rebaseline: false)
        }
    }

    public func submitPIN(_ entered: String, rebaseline: Bool) -> PINOutcome {
        guard pin.isPINSetup else { return .noPIN }
        switch pin.attemptPIN(entered) {
        case .success:
            if rebaseline { biometrics.acceptCurrentBiometry() }
            return .unlocked
        case .incorrect(let remaining):
            return .incorrect(attemptsRemaining: remaining)
        case .lockedOut(let seconds):
            return .lockedOut(secondsRemaining: seconds)
        }
    }
}

// MARK: - PIN rules

public enum PINRules {
    public static let length = 6

    /// Six digits, not all the same, and not a straight run like 123456.
    public static func isAcceptable(_ pin: String) -> Bool {
        let digits = pin.compactMap(\.wholeNumberValue)
        guard pin.count == length, digits.count == length else { return false }
        if Set(digits).count == 1 { return false }
        let steps = zip(digits, digits.dropFirst()).map { $1 - $0 }
        if steps.allSatisfy({ $0 == 1 }) || steps.allSatisfy({ $0 == -1 }) { return false }
        return true
    }
}
