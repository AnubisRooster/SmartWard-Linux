# Biometric domain state & the anti-tamper check

`BiometricLockKit`'s anti-tamper feature is built on `LAContext`'s
`evaluatedPolicyDomainState`. This note explains what that value is, its
sharp edges across iOS versions, and exactly how the module behaves around
each one — so the `.biometryChanged` result never surprises you.

## What it is

After a successful policy evaluation, `LAContext.evaluatedPolicyDomainState`
returns an **opaque `Data` blob** that identifies the *current set of enrolled
biometrics* (faces and fingerprints). Enroll a new face, delete a fingerprint,
or reset Face ID, and the blob changes. Apple deliberately does not document
its format — you can only compare two blobs for equality, never parse one.

Why this matters for a lock: a biometric *match* alone isn't enough. If an
attacker with your unlocked device adds *their own* face in Settings, Face ID
will happily match them next time. Comparing the domain state against a stored
baseline catches exactly that.

## How the module uses it

`BiometricService.resolveSuccess(domainState:)`:

| Situation | Baseline in Keychain | Domain state now | Result |
|---|---|---|---|
| First ever successful unlock | *(none)* | non-nil | `.success`, baseline seeded |
| Normal unlock | matches | equal | `.success` |
| Enrolled set changed | present | **differs** | `.biometryChanged` (baseline untouched) |
| OS returned no blob | any | `nil` | `.success` (see fail-open note) |

Recovery from `.biometryChanged`: verify the PIN, then call
`biometrics.acceptCurrentBiometry()`. That clears the baseline so the *next*
successful biometric unlock adopts the new enrolled set. A tampered/unknown
set never silently overwrites the baseline on its own.

## Sharp edges to know

- **Only meaningful after an evaluation.** The blob is `nil` until
  `canEvaluatePolicy` / `evaluatePolicy` has run on that context. The module
  reads it from the *same* context that just authenticated, so this is handled
  — but it's why the value is captured inside `LAContextEvaluator.evaluate`
  rather than fetched separately.

- **Fail-open when `nil`.** If the OS declines to provide a blob on an
  otherwise successful match, the module returns `.success` **without** seeding
  or updating the baseline. Rationale: the domain-state check is a hardening
  layer *on top of* a real biometric match, not the primary gate — biometry
  already vouched for the user. It is not a hard security boundary on its own.

- **An iOS upgrade can rotate the blob.** Across some major iOS updates the
  value has changed without the user re-enrolling anything. If that happens,
  the first post-upgrade unlock returns `.biometryChanged`; the user clears it
  once with their PIN and re-baselines. Treat `.biometryChanged` as "re-verify,"
  not "compromised" — the coordinator in `Examples/AppLockCoordinator.swift`
  does exactly this and the experience is a single extra PIN entry.

- **Passcode changes don't affect it.** Only biometric *enrollment* changes the
  blob; changing the device passcode does not.

- **Keychain persistence vs. reinstall.** The baseline lives in the Keychain
  with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (never synced, never
  leaves the device). Depending on iOS version and backup/restore behavior a
  generic-password item may or may not survive an app reinstall; if it doesn't,
  the next unlock is simply treated as first-run and re-seeds the baseline.
  This is safe — a fresh install has no prior state to protect.

## What it does *not* protect against

- A coerced user unlocking under duress (biometry matches a real enrolled user).
- The device passcode route — the module uses
  `.deviceOwnerAuthenticationWithBiometrics` specifically so the OS passcode is
  **not** an accepted factor; the fallback is your app's own PIN instead.
- Jailbroken devices where the Secure Enclave / Keychain guarantees don't hold.
