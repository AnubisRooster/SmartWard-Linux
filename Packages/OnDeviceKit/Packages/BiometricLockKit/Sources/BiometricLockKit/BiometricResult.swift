import Foundation

/// The outcome the host UI acts on. Anything other than `.success` is the
/// host's cue to present its own fallback (e.g. the `PINLockKit` screen) —
/// this module deliberately owns *no* fallback UI so it stays standalone.
public enum BiometricResult: Equatable, Sendable {
    /// Biometry matched the enrolled user and the anti-tamper baseline held.
    case success
    /// Biometry ran but matched no one. The host may retry or fall back.
    case failed
    /// The user tapped the fallback button (e.g. "Use PIN"). Show the PIN screen.
    case fallback
    /// The OS locked biometry after too many failed attempts. A passcode/PIN
    /// is now the *only* way in until the device is unlocked — fall back.
    case lockout
    /// Biometry succeeded, but the enrolled face/finger set changed since this
    /// app last established its baseline. Treated as a hard fail: fall back to
    /// PIN, then call `acceptCurrentBiometry()` once the PIN is verified.
    case biometryChanged
    /// The user or system dismissed the prompt without a decision.
    case canceled
    /// Biometry can't be used at all right now — see the reason.
    case unavailable(BiometricUnavailable)
}

/// Why biometric evaluation isn't currently possible.
public enum BiometricUnavailable: Error, Equatable, Sendable {
    /// No face/finger is enrolled in Settings.
    case notEnrolled
    /// The hardware isn't present or is disabled for this app.
    case notAvailable
    /// The device has no passcode set, so biometry is inoperative.
    case passcodeNotSet
}

/// The raw result of a single policy evaluation, *before* `BiometricService`
/// layers on the domain-state anti-tamper check. Modeled as our own `Sendable`
/// type (rather than leaking `LAError`) so the `LAError` translation — the one
/// part that genuinely needs a physical device — stays isolated inside
/// `LAContextEvaluator`, and every compositional decision in `BiometricService`
/// is exercised in unit tests with a fake evaluator.
public enum BiometricEvaluation: Equatable, Sendable {
    /// Authentication succeeded. `domainState` is
    /// `LAContext.evaluatedPolicyDomainState` captured from the *same* context
    /// that authenticated — an opaque blob that changes when the enrolled
    /// biometric set changes. `nil` when the OS declined to provide it.
    case success(domainState: Data?)
    case failed
    case fallback
    case lockout
    case canceled
    case unavailable(BiometricUnavailable)
    /// An unexpected `LAError` we don't map to a specific case; the string is
    /// for logging only, never for display.
    case error(String)
}
