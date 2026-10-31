# Security and Privacy Overview

> **Internal engineering document.** This is not a public policy and not a
> certification. It records the security design of DailyMoney 1.3.1+8, the
> threats considered, and the risks that remain. It must be updated when the
> storage, permission or capture model changes.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)
- **Platform:** Android only

## 1. System context

DailyMoney is a local-first Android app built with Flutter. It has:

- no user account;
- no DailyMoney backend;
- no cloud sync;
- no analytics, advertising or crash-reporting SDK;
- no bank or Account Aggregator integration;
- no payment execution;
- no `INTERNET` permission in the release manifest.

The only data flow off the device is user-initiated: copying a JSON export or a
support report to the Android clipboard and then sending it somewhere. The app
does not transmit it.

```
User input ──► Flutter providers ──► StorageService ──► AES-256-GCM
                                              │              │
                                              │              └── key in Android Keystore
                                              ▼
                                    app-private SharedPreferences

Other apps ──► Android notification listener ──► plaintext queue
                                              │
                                              ▼ (next app open, consent on)
                                    encrypted detection store

Data controls ──► JSON export ──► Android clipboard ──► user's destination
```

## 2. Storage and cryptography

### 2.1 Payload encryption

- Algorithm: AES-256-GCM (`AesGcm.with256bits()`).
- Nonce: 12 random bytes per encryption, prepended to the payload.
- Authentication tag: 16 bytes, appended to the payload.
- Stored format: `enc1:` followed by base64(nonce || ciphertext || MAC).
- Key: 32 random bytes generated on first run, stored in the Android Keystore
  through `flutter_secure_storage` (`AndroidOptions(encryptedSharedPreferences:
  true)`).
- If no persistent Keystore is available, `DataVault.open()` returns null. The
  app then shows a storage-unavailable screen and refuses to write; it does not
  fall back to plain JSON. Existing encrypted payloads are left untouched so a
  transient Keystore failure can be retried.
- The key is never exported and is not part of the JSON backup.

### 2.2 What is encrypted

Encrypted: transactions, bills, goals, expected income, shared expenses,
detections, settings, security flags, the native detection queue and its dedupe
signatures.

Still plaintext: only the capture-enabled and notification-prompt booleans needed
by the Android listener while the app is closed. They contain no payment data.

The PIN digest is stored through `SecureStore`, not in the encrypted settings
payload.

### 2.3 App lock

- PIN length: 4 digits.
- New records use PBKDF2-HMAC-SHA256 with 100,000 iterations, a random 16-byte
  salt and a 256-bit derived key.
- The record is `v2:iterations:salt:hash`; the PIN itself is never stored.
- Legacy salted SHA-256 records (two-part format) are accepted and upgraded to
  PBKDF2 after a successful unlock.
- Hash comparison is constant-time.
- Biometrics use `local_auth`; Android performs the match and the app receives
  only success/failure. Biometrics require an existing PIN.
- Auto-lock can lock immediately on background or after a configured delay.
- A forgotten PIN can only be handled by a full data wipe. There is no recovery
  code or server reset.

### 2.4 Android backup

- `android:allowBackup="false"` and `android:fullBackupContent="false"`.
- `data_extraction_rules.xml` excludes root, file, database, sharedpref and
  external domains from both cloud backup and device transfer.
- Rationale: the Keystore key cannot travel with copied ciphertext. A restored
  copy would be unreadable, and a later write could overwrite it.

## 3. Permissions

| Permission / access | Release manifest | Purpose | Request timing |
|---|---|---|---|
| `POST_NOTIFICATIONS` | Declared | Briefings, budget alerts, detected-payment prompts | Only when a notification feature is enabled |
| `RECEIVE_BOOT_COMPLETED` | Declared | Restore schedules after reboot/update | Only effective when notifications are enabled |
| `USE_BIOMETRIC`, `USE_FINGERPRINT` | Declared | Optional biometric unlock | Only when biometric unlock is enabled |
| Notification listener access | Declared service guarded by `BIND_NOTIFICATION_LISTENER_SERVICE` | Payment detection | Only when payment detection is enabled |
| `INTERNET` | **Not declared** | None | Debug/profile builds only |

No contacts, SMS, call log, location, camera, microphone, calendar, advertising
ID, broad storage, accessibility, usage-access or device-admin permission is
declared.

## 4. Payment detection pipeline

1. The user grants Android notification access on a system settings screen.
2. The user turns on **Detect payments in notifications**. The app verifies that
   access is actually granted before setting the flag.
3. `MoneyNotificationListener` receives notifications. It ignores:
   - DailyMoney itself;
   - `com.android.systemui`, `com.android.settings`, common launchers;
   - messages without a payment hint (debited, credited, spent, paid, etc.);
   - messages with OTP/login hints;
   - messages without a detectable amount.
4. It deduplicates identical package/amount/title combinations for 10 minutes.
5. It stores at most 20 snippets in a Keystore AES-GCM encrypted queue. A snippet
   contains package name, app label, title, up to 300 characters of text, amount,
   type guess, timestamp and a random ID. Dedupe signatures are SHA-256 hashes.
6. It posts a review prompt only if the mirrored notification-consent flag is
   true. Detection still queues without a prompt.
7. On the next app open, the Dart side reads and clears the encrypted queue over
   a MethodChannel. It imports the snippets only when `acceptNative` is true,
   which is tied to the current payment-detection setting. Snippets captured
   before opt-out are discarded.
8. Imported detections are stored encrypted and capped at 40. They never enter
   the ledger until the user accepts them.

Android does not offer a "payments only" notification permission. The listener
can technically read notifications from many apps, which is why it is optional,
off by default, filtered, locally stored and review-only.

## 5. Privacy controls

- Optional processing is off by default for new installs.
- Notification permission is requested only from a user action.
- Payment detection has its own Android access and its own app switch.
- The notification master switch turns off morning, night and budget schedules
  and mirrors `false` to the native prompt flag.
- Turning payment detection off discards queued snippets on next open.
- The app lock is optional and local.
- Full deletion is available without an account.
- The export is user-initiated and clipboard-based; the app cannot revoke a
  copied export.
- There is no analytics, profiling, advertising or sale of data.

## 6. Threat model

| Threat | Mitigation | Residual risk |
|---|---|---|
| Another app reads app-private storage | Android sandbox + AES-GCM | Rooted device, compromised OS or a backup bypass could read files; without the Keystore key the ciphertext is unreadable. Only the capture on/off booleans remain plaintext |
| Lost or stolen unlocked device | Optional PIN + biometrics, auto-lock, screenshot blocking | A weak 4-digit PIN can be guessed if the digest is extracted; the cooldown is app-level |
| Shoulder surfing / screenshots | `FLAG_SECURE` by default | A user can turn blocking off, and a camera can still photograph the screen |
| Clipboard exposure | Export and restore only on tap | Other apps or system UI may read/display clipboard contents; the app does not clear it |
| Malicious notification-access app | Android controls the grant; app filters | Notification access is broad; a user may grant it to a malicious app outside DailyMoney |
| Notification snippet interception | App-private storage, short retention, Keystore AES-GCM queue | A compromised OS with the unlocked Keystore could still read the queue |
| Keystore unavailable | Fallback keeps app usable; encrypted payloads without a key show recovery | Data is then app-private JSON, not encrypted; the UI discloses this |
| Corrupt/undecryptable payload | Recovery screen; export refused; erase is explicit | The unreadable records cannot be repaired; restarting or erasing are the only in-app choices |
| Forgot PIN | Full wipe only | No recovery code; data loss is expected and disclosed |
| PIN brute force | PBKDF2 100k, constant-time compare, persisted cooldown | A 4-digit space is small; the cooldown is enforced by the app, not hardware |
| Fake support message | Support screen never invents an address | A user could still be tricked by an external message; no in-app authenticity check |
| Malicious export file | Strict schema, count limits, explicit confirmation, no code execution | Restore is destructive to current financial records; the user must export first |
| Debug build exposure | Release has no INTERNET permission | Debug/profile builds add INTERNET for tooling and are not distributed |

## 7. Security fixes carried into this build

The previous audit fixed these issues; they remain part of the current code:

1. PIN records use PBKDF2 with migration from legacy SHA-256.
2. Android backup and device transfer are disabled.
3. Settlement type changes no longer leave stale repayment state.
4. Editing/deleting a settlement keeps the shared-expense records in sync.
5. Deleting a split transaction cascades to its repayment records.
6. Future-dated entries are capped.
7. Activity day totals include shared/captured payments.
8. Budget alerts work for captured and shared payments.
9. Payment detection imports respect the current consent setting.
10. Notification review prompts respect the notification consent flag (new in
    this pass).
11. Release manifest has no `INTERNET` permission.
12. Screenshot and recent-apps blocking is on by default and user-configurable.
13. Five wrong PINs start a persisted progressive cooldown.
14. Unreadable ciphertext or JSON shows a recovery screen instead of an empty
    ledger, and export is refused.
15. Backup restore validates the full document, caps its size, requires explicit
    confirmation and replaces financial records only.

## 8. Verification evidence

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze --no-fatal-infos` | Clean | `doc/maturity/analyze-output.txt` |
| Full test suite | Passing (final count recorded in `test-output.txt`) | `doc/maturity/test-output.txt` |
| Release manifest has no INTERNET | Verified by source inspection | `android/app/src/main/AndroidManifest.xml` |
| Debug/profile manifests add INTERNET | Verified by source inspection | `android/app/src/debug/AndroidManifest.xml`, `.../profile/...` |
| Backup disabled | Verified by source inspection | `allowBackup="false"`, `data_extraction_rules.xml` |
| PIN hashing | Unit tests pass | `test/security_test.dart` |
| PIN cooldown | Unit tests pass | `test/security_test.dart` |
| Backup parse and restore | Unit tests pass | `test/backup_restore_test.dart` |
| Read-failure recovery | Unit tests pass | `test/backup_restore_test.dart` |
| Consent opt-out drops queued snippets | Test passes | `test/capture_test.dart` |
| Prompt flag mirrors notification consent | Test passes | `test/onboarding_legal_test.dart` |
| Device penetration test | **Not run** | No device session |
| Keystore behaviour on OEM devices | **Not run** | Needs device matrix |
| Root/jailbreak resistance | **Not claimed** | Out of scope |

## 9. Open security questions

1. Is the default-on screenshot block the right trade-off for usability, and
   should onboarding mention it?
2. Is the 30-second-to-30-minute PIN cooldown long enough for a 4-digit PIN, or
   should a longer delay or alphanumeric passcode be offered?
3. Can the native detection queue be eliminated by moving the listener to write
   directly into encrypted storage, or by shortening its lifetime further?
4. Should the app clear the clipboard after export or restore?
5. Is clipboard-only restore sufficient, or should a file picker be added?
6. Does the target market require a security contact and disclosure policy?
7. Is a formal threat model review required before public release?

## Document control

| Item | Value |
|---|---|
| Public? | Yes - published in this repository |
| Review status | Engineering review only |
| Penetration test | Not performed |
| Device verification | Partial; 1.3.1+8 installed on the Redmi test device, Help Centre/tour passed, security-specific device checks pending |
| Known critical blocker | None identified in code; support/legal/device checks remain |
