import Foundation

/// The kind of biometry a device offers, mirrored from `LABiometryType` but
/// kept as a plain `Sendable` value so the rest of the module (and callers)
/// never need to import `LocalAuthentication`.
public enum BiometryType: Sendable, Equatable {
    case none
    case faceID
    case touchID
    case opticID

    /// A human-readable name suitable for prompts ("Unlock with Face ID").
    public var displayName: String {
        switch self {
        case .none:    return "Biometrics"
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        }
    }
}
