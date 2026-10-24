// AppLockCoordinator.swift
//
// A copy-paste reference showing how to compose the two standalone lock
// modules — BiometricLockKit (fast path) and PINLockKit (always-present
// fallback) — into a single app-unlock flow.
//
// This file is intentionally NOT part of any SwiftPM target: it's the one
// place the two modules meet, and keeping it out of the build is what lets
// BiometricLockKit stay dependency-free. Drop it into your app target (which
// depends on both products) and adapt `presentPIN` to your own UI.

import Foundation
import BiometricLockKit
import PINLockKit

/// Drives "unlock the app": try biometrics, fall back to the PIN for every
/// non-success outcome, and re-baseline biometrics once a PIN recovery clears
/// a `.biometryChanged`.
@MainActor
public final class AppLockCoordinator {
    public enum Outcome: Equatable {
        case unlocked
        /// The user couldn't be authenticated (cancelled, or exhausted the PIN
        /// and is now in a PIN lockout window).
        case denied
    }

    private let biometrics: BiometricService
    private let pin: PINService

    /// - Parameter presentPIN: your PIN UI. Return the entered PIN, or `nil`
    ///   if the user backed out. The coordinator handles verification and
    ///   brute-force lockout via `PINService.attempt`.
    private let presentPIN: () async -> String?

    public init(biometrics: BiometricService = BiometricService(),
                pin: PINService = .shared,
                presentPIN: @escaping () async -> String?) {
        self.biometrics = biometrics
        self.pin = pin
        self.presentPIN = presentPIN
    }

    /// Runs the full unlock flow and returns whether the app should open.
    public func unlock(reason: String) async -> Outcome {
        // Skip straight to the PIN if biometrics aren't usable on this device.
        guard case .success = biometrics.availability() else {
            return await runPINFallback(rebaselineOnSuccess: false)
        }

        switch await biometrics.unlock(reason: reason) {
        case .success:
            return .unlocked

        case .biometryChanged:
            // Enrolled biometrics changed since we last trusted this device.
            // Require the PIN, then adopt the new set as the baseline.
            return await runPINFallback(rebaselineOnSuccess: true)

        case .fallback, .lockout, .failed, .unavailable, .canceled:
            return await runPINFallback(rebaselineOnSuccess: false)
        }
    }

    // MARK: - PIN fallback

    private func runPINFallback(rebaselineOnSuccess: Bool) async -> Outcome {
        // Respect an in-progress brute-force lockout before prompting.
        if pin.isLockedOut { return .denied }

        guard let entered = await presentPIN() else { return .denied }

        switch pin.attempt(entered) {
        case .success:
            if rebaselineOnSuccess {
                // Next successful Face ID / Touch ID adopts the new enrolled set.
                biometrics.acceptCurrentBiometry()
            }
            return .unlocked
        case .incorrect, .lockedOut:
            return .denied
        }
    }
}
