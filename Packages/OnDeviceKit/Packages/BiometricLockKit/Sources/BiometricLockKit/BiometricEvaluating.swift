import Foundation

/// The seam over `LocalAuthentication`. `BiometricService` talks only to this,
/// so tests inject a fake instead of a real `LAContext` (mirroring how
/// `BYOKLLMKit` hides the network behind `LLMSending`).
public protocol BiometricEvaluating: Sendable {
    /// The biometry the device offers right now (`.none` if unavailable).
    func biometryType() -> BiometryType

    /// Whether a biometric evaluation could be attempted, or why not.
    func canEvaluate() -> Result<Void, BiometricUnavailable>

    /// Presents the system biometric prompt and resolves to the raw outcome.
    /// Implementations must use a *fresh* context per call so a prior
    /// authentication can never be silently reused to satisfy this one.
    func evaluate(reason: String) async -> BiometricEvaluation
}

/// Persists the biometric anti-tamper baseline (an opaque
/// `evaluatedPolicyDomainState` blob). Behind a protocol so the domain-state
/// logic is unit-testable with an in-memory store, keeping the Keychain out of
/// the test path exactly as `PINLockKit` keeps `PINLockout` Keychain-free.
public protocol DomainStateStoring: Sendable {
    func load() -> Data?
    func save(_ data: Data)
    func clear()
}
