#if canImport(LocalAuthentication)
import Foundation

/// A "unlock with Face ID / Touch ID" primitive built on `LocalAuthentication`,
/// with a domain-state anti-tamper check layered on top.
///
/// This module is **standalone** — it owns no fallback UI and has no dependency
/// on `PINLockKit`. Any non-`.success` result is the host's signal to present
/// its own fallback (typically the `PINLockKit` screen); see the README for the
/// wiring.
///
/// ### Anti-tamper
/// A successful biometric match isn't sufficient on its own: someone who
/// enrolls *their own* face in Settings would then pass Face ID. To catch that,
/// the first successful unlock records `evaluatedPolicyDomainState` as a
/// baseline; every later unlock compares against it and returns
/// `.biometryChanged` if the enrolled set changed — forcing a PIN fallback.
/// After the PIN is verified, call `acceptCurrentBiometry()` to re-baseline.
public final class BiometricService: @unchecked Sendable {
    private let evaluator: BiometricEvaluating
    private let store: DomainStateStoring

    public init(evaluator: BiometricEvaluating = LAContextEvaluator(),
                store: DomainStateStoring = KeychainDomainStateStore()) {
        self.evaluator = evaluator
        self.store = store
    }

    // MARK: Introspection

    /// The biometry the device offers (`.none` if unavailable/unenrolled).
    public func biometryType() -> BiometryType { evaluator.biometryType() }

    /// Whether an unlock could be attempted right now, or why not.
    public func availability() -> Result<Void, BiometricUnavailable> {
        evaluator.canEvaluate()
    }

    /// Whether an anti-tamper baseline has been established for this app.
    public var hasBaseline: Bool { store.load() != nil }

    // MARK: Unlock

    /// Presents the system biometric prompt and returns the resolved result.
    /// `reason` is shown in the prompt (Touch ID) / the accessibility label
    /// (Face ID).
    public func unlock(reason: String) async -> BiometricResult {
        switch await evaluator.evaluate(reason: reason) {
        case .success(let domainState):
            return resolveSuccess(domainState: domainState)
        case .failed:               return .failed
        case .fallback:             return .fallback
        case .lockout:              return .lockout
        case .canceled:             return .canceled
        case .unavailable(let u):   return .unavailable(u)
        case .error:
            // Unexpected LAError: treat as a failure so the host falls back
            // rather than silently unlocking.
            return .failed
        }
    }

    // MARK: Baseline management

    /// Clears the stored baseline so the *next* successful biometric unlock
    /// re-records it. Call this after the user resolves a `.biometryChanged`
    /// via PIN, or whenever biometric unlock is (re)enabled.
    public func acceptCurrentBiometry() { store.clear() }

    /// Forgets the baseline entirely (e.g. on sign-out or when the user turns
    /// biometric unlock off).
    public func reset() { store.clear() }

    // MARK: Private

    private func resolveSuccess(domainState: Data?) -> BiometricResult {
        // The OS didn't hand us a domain state. Biometry already matched, so
        // allow it — the anti-tamper check is a hardening layer on top of a
        // successful match, not the primary gate — but leave the baseline as-is.
        guard let domainState else { return .success }

        guard let baseline = store.load() else {
            // First successful unlock: establish the baseline.
            store.save(domainState)
            return .success
        }

        return baseline == domainState ? .success : .biometryChanged
    }
}
#endif
