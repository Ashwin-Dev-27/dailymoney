# DailyMoney Data Retention and Deletion

> **Beta draft - not legally reviewed.** This document describes the retention
> and deletion behaviour of DailyMoney 1.3.1+8 as implemented in this
> repository. It has not been reviewed by a qualified lawyer and is not a claim
> of compliance with any retention or erasure requirement.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)

## 1. The deletion model

DailyMoney has no accounts and no server. There is no remote profile to delete
and no server-side retention period to state. Deleting the data on the device is
the full extent of what the app can do, and the app says so instead of offering
a fake "delete account" flow.

Deletion is available at:

**Settings > Help & support > Legal & privacy > Data controls**

The screen shows the deletion scope, an export action, the number of records in
each category, and a destructive action that requires an explicit confirmation
checkbox. The same screen is linked from **Settings > Security & privacy >
Permissions & data**.

## 2. What is stored and for how long

| Data | Storage | Protection | Retention |
|---|---|---|---|
| Transactions (title, amount, type, category, date, note, split share) | `dm.transactions.v1` | AES-256-GCM, Keystore-backed | Until deleted individually, by a full wipe, or by uninstall |
| Upcoming bills | `dm.upcoming.v1` | Same as above | Same as above |
| Savings goals and contributions | `dm.goals.v1` | Same as above | Same as above |
| Expected income | `dm.expected_income.v1` | Same as above | Same as above |
| Shared expenses and repayments | `dm.shared_expenses.v1` | Same as above | Same as above |
| Detected payments waiting for review | `dm.detections.v1` | AES-256-GCM, Keystore-backed | Until accepted, ignored, cleared, or wiped |
| Native detection queue | Keystore-encrypted `dm_capture_secure` preferences | AES-256-GCM with an Android Keystore key | Until the next app open, or wiped |
| Preferences, onboarding, legal acceptance, consent state | `dm.settings.v1` | AES-256-GCM, Keystore-backed | Until full wipe or uninstall |
| App-lock PIN digest and lock flags | Keystore via `dm.pin.v1`; flags in `dm.security.v1` | Keystore-backed secure storage; PBKDF2 digest | Until PIN disabled, full wipe, or uninstall |
| Random encryption key | Keystore as `dm.vault.key.v1` | Android Keystore | After **Delete all data** until uninstall or Android app-data clear (see Section 4) |
| Optional JSON export | Android clipboard or wherever you paste/save it | Depends on destination | Outside the app's control |
| Notification schedules | Android AlarmManager / notification plugin | Operating system | Removed when the feature is turned off or data is wiped |

There is no server-side retention because there is no server. There is no
separate crash or diagnostic store in this build.

### Detection queue retention

The Android notification listener may write a short payment snippet to an
AES-GCM queue protected by an Android Keystore key so the app can import it on
the next open. Older plaintext queues are migrated and removed. The queue is
always cleared when the app reads it. If payment detection is off at that
moment, the snippet is discarded rather than imported. The retention window is
therefore "until the next app open", subject to Android process behaviour.

## 3. The full deletion flow

1. The user opens **Data controls**.
2. The screen explains that no account exists and that deletion is local.
3. The user may copy a JSON backup first. The screen warns that the export is a
   separate copy and will not be erased by the app.
4. The screen lists the record counts and the additional settings that will be
   erased.
5. A confirmation dialog requires the user to tick a checkbox before
   **Delete everything** becomes enabled.
6. `wipeAllData` calls `StorageService.clearAll()`, resets the security provider,
   resets settings to first-run defaults, and reloads every provider.
7. The welcome screen appears because `welcomeSeen` and the legal acceptance are
   cleared. `seeded` remains `true` so the app does not inject demo records into
   a deliberate reset.
8. A snackbar reports success. If any step throws, the screen reports that the
   deletion could not be completed and does not claim success.

### What is erased

- transactions;
- upcoming bills;
- savings goals;
- expected income entries;
- shared expenses and repayments;
- detected payments;
- the native detection queue;
- currency, budget and planning preferences;
- greeting name;
- tutorial progress and completion state;
- consent choices, consent timestamps and consent version;
- policy acceptance version and time;
- theme choice and notification times;
- app-lock PIN, biometric flag and auto-lock setting.

### What is not erased

- a JSON export that was copied to the clipboard or saved elsewhere;
- a screenshot or screen recording;
- records held by a bank, employer, merchant or payment provider;
- the random encryption key in the Keystore (it contains no financial records);
- Android system logs that the app does not control;
- the installed app itself (uninstall is separate).

## 4. Why the encryption key remains

`DataVault` keeps a random 256-bit key in the Android Keystore. `clearAll()`
removes the encrypted payloads but deliberately leaves the key so the app can
continue to encrypt new data without recreating a vault on every reset.

The key is not a financial record. It cannot reconstruct deleted ciphertext
without the deleted payloads. It is removed when the app is uninstalled or when
Android app data is cleared. This behaviour is disclosed in the in-app policy
and in the Privacy Policy.

## 5. Individual deletion and correction

- A transaction can be edited or deleted from the Activity screen.
- A bill, goal, expected-income entry or shared expense can be edited or deleted
  from its own screen.
- A detected payment can be accepted, ignored, or cleared from the review list.
- Turning off notifications removes the scheduled notifications.
- Turning off payment detection stops new captures and discards a queued
  snippet on the next app open.
- Disabling the app lock removes the PIN digest and biometric flag.

The app does not keep a soft-delete copy, a trash bin or a version history of
financial records. A deleted record cannot be restored by DailyMoney.

## 6. Export and portability limits

**Settings > Help & support > Legal & privacy > Data controls > Export a
backup** copies a JSON document to the Android clipboard. The export contains:

- transactions;
- upcoming bills;
- savings goals;
- expected income;
- shared expenses;
- settings (including onboarding, legal and consent state).

The export does **not** contain:

- detected payments waiting for review;
- the app-lock PIN digest or biometric flag;
- the encryption key;
- the native detection queue.

The app can restore an exported JSON backup from the clipboard. Restore
replaces financial records and selected preferences; it deliberately keeps the
device's app-lock PIN, biometrics, consent choices, notification settings and
tutorial progress. It is not an automatic or cloud restore, and it does not
import detections, the PIN digest, the encryption key or the native queue.

Deleting app data does not erase a clipboard entry. Clipboard contents may be
visible to other apps or system services depending on the Android version and
device.

## 7. Uninstall and device transfer

- Android cloud backup and device-to-device transfer are disabled with
  `allowBackup="false"`, `fullBackupContent="false"` and
  `data_extraction_rules.xml`.
- Uninstalling the app removes its private storage, including encrypted payloads
  and the Keystore entry associated with the app.
- Because Android backup is disabled, reinstalling does not restore deleted data
  automatically. A user can restore an explicit JSON backup after reinstalling.
- A user who wants to keep records must export before uninstalling.

## 8. Consent records

Only the current consent state is stored. Each enabled optional choice stores
the consent version and the time it was enabled. Turning the choice off clears
the timestamp and version. There is no historical consent ledger.

If a jurisdiction requires a full audit trail of consent changes, the
persistence model must be extended. This is recorded as a legal-review question
in [consent-and-permissions.md](consent-and-permissions.md).

## 9. Evidence and verification

| Check | Result | Evidence |
|---|---|---|
| Full wipe clears financial records and settings | Automated test passes | `test/onboarding_legal_test.dart`: "a full reset clears onboarding and legal state, keeps seeded" |
| Welcome returns after a full wipe | Automated test passes | Same test |
| `seeded` stays true after a wipe | Automated test passes | Same test |
| Detection queue is cleared | Automated test passes | `test/capture_test.dart`: queued-snippet tests |
| Destructive action needs confirmation | Implemented | `lib/screens/data_controls_screen.dart` |
| Deletion on a physical device | **Not run for this build** | The installed APK predates these changes |
| Restore from export | **Not implemented** | No import path exists |

## 10. Legal-review questions

1. Is a local-only app required to offer a remote deletion request channel when
   no account or server exists?
2. What retention statement is required for clipboard exports and notification
   snippets?
3. Must the app retain a consent-change history, and for how long?
4. Does leaving the encryption key in the Keystore require additional notice?
5. Are there jurisdiction-specific rights that cannot be satisfied by on-device
   deletion alone?
6. What response period applies to a deletion or access request sent through
   the support route?
7. Does the app store require an account-deletion declaration even when the app
   has no accounts?

## Document control

| Item | Value |
|---|---|
| In-app source | `lib/services/data_reset.dart`, `lib/services/storage_service.dart`, `lib/screens/data_controls_screen.dart` |
| Review status | Not legally reviewed |
| Device verification | Pending |
| Restore capability | Not implemented |
| Server-side retention | None (no server) |
