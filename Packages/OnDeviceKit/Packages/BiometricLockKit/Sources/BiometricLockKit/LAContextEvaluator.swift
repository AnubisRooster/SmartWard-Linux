#if canImport(LocalAuthentication)
import Foundation
import LocalAuthentication

/// The production `BiometricEvaluating`, backed by `LocalAuthentication`.
///
/// All face matching happens inside the Secure Enclave; this type only ever
/// receives an opaque success/failure — it never sees face data or a match
/// score. It uses `.deviceOwnerAuthenticationWithBiometrics` (biometrics only,
/// *not* the device passcode) so that a failure routes to the host app's own
/// PIN rather than iOS's system passcode, keeping a single lock authority.
///
/// > Important: The host app's `Info.plist` must contain an
/// > `NSFaceIDUsageDescription` string, or Face ID evaluation crashes at runtime.
public struct LAContextEvaluator: BiometricEvaluating {
    private let policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
    private let fallbackTitle: String?

    /// - Parameter fallbackTitle: label for the prompt's fallback button (e.g.
    ///   "Use PIN"). Tapping it yields `.fallback`. Pass `nil` to hide it.
    public init(fallbackTitle: String? = "Use PIN") {
        self.fallbackTitle = fallbackTitle
    }

    public func biometryType() -> BiometryType {
        let context = LAContext()
        // `biometryType` is only meaningful after a canEvaluatePolicy probe.
        _ = context.canEvaluatePolicy(policy, error: nil)
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default:       return .none
        }
    }

    public func canEvaluate() -> Result<Void, BiometricUnavailable> {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(policy, error: &error) {
            return .success(())
        }
        return .failure(Self.unavailableReason(from: error))
    }

    public func evaluate(reason: String) async -> BiometricEvaluation {
        // A fresh context per call: never set an allowable-reuse duration, so a
        // recent unlock can't silently satisfy this one.
        let context = LAContext()
        if let fallbackTitle { context.localizedFallbackTitle = fallbackTitle }

        var probeError: NSError?
        guard context.canEvaluatePolicy(policy, error: &probeError) else {
            return .unavailable(Self.unavailableReason(from: probeError))
        }

        do {
            // The completion-handler API bridges to `async throws -> Bool`: it
            // throws on failure, so a `false` return without a throw shouldn't
            // occur — but guard it rather than assume a match.
            let matched = try await context.evaluatePolicy(policy, localizedReason: reason)
            guard matched else { return .failed }
            return .success(domainState: context.evaluatedPolicyDomainState)
        } catch {
            return Self.mapEvaluateError(error)
        }
    }

    // MARK: - LAError translation

    private static func unavailableReason(from error: NSError?) -> BiometricUnavailable {
        switch LAError.Code(rawValue: error?.code ?? -1) {
        case .biometryNotEnrolled:  return .notEnrolled
        case .passcodeNotSet:       return .passcodeNotSet
        default:                    return .notAvailable
        }
    }

    private static func mapEvaluateError(_ error: Error) -> BiometricEvaluation {
        guard let la = error as? LAError else {
            return .error(String(describing: error))
        }
        switch la.code {
        case .authenticationFailed:          return .failed
        case .userCancel, .systemCancel, .appCancel:
                                             return .canceled
        case .userFallback:                  return .fallback
        case .biometryLockout:               return .lockout
        case .biometryNotEnrolled:           return .unavailable(.notEnrolled)
        case .biometryNotAvailable:          return .unavailable(.notAvailable)
        case .passcodeNotSet:                return .unavailable(.passcodeNotSet)
        default:                             return .error(String(describing: la))
        }
    }
}
#endif
