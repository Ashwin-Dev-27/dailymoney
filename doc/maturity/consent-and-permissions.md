# DailyMoney Consent and Permissions

> **Beta draft - not legally reviewed.** This document describes the consent and
> permission behaviour of DailyMoney 1.3.1+8 as implemented in this repository.
> It is a private-beta draft and has not been reviewed against the consent
> requirements of any jurisdiction. It is not a claim of compliance.

- **Consent version:** 1.1
- **Policy version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)

## 1. Principles used in the app

- Essential processing is limited to storing the records needed for the feature
  you are using.
- Optional processing is off by default and is never preselected.
- Notifications and payment detection are separate choices with separate Android
  permissions.
- A consent choice is recorded with the consent version and a timestamp while
  the choice is enabled.
- Turning an optional choice off stops the related processing.
- The app does not bundle unrelated permissions into one prompt.
- The app does not request permissions at startup.

## 2. Essential local processing

| Processing | Data | Why it is essential | Control |
|---|---|---|---|
| Ledger storage | Transactions, dates, amounts, categories, notes | Without it the app cannot show a balance, budget or history | Delete individual records or erase all data |
| Planning storage | Bills, goals, expected income, shared expenses, repayments | Required for the planning features you open | Delete individual records or erase all data |
| Preference storage | Currency, budget, theme, notification times, tutorial state | Required to keep the app configured as you left it | Change in Settings or erase all data |
| App-lock storage | PBKDF2 PIN digest, lock timing, biometric flag | Required only if you enable the app lock | Disable the PIN or erase all data |

This processing happens on the device. It is not used for advertising,
analytics, profiling or sale.

## 3. Optional choices

### 3.1 Notifications

- **Android permission:** `POST_NOTIFICATIONS` (Android 13 and later).
- **Purpose:** morning greeting, nightly summary, budget alerts and
  detected-payment prompts.
- **Default:** off. New installs start with morning, nightly and budget alerts
  disabled.
- **When requested:** only when you turn on a notification feature in
  **Settings > Notifications**, or when you enable notifications from
  **Settings > Help & support > Consent and permissions**.
- **If denied:** the feature stays off; the rest of the app works. The app shows
  a message explaining that Android settings must allow notifications.
- **Withdrawal:** turn the master switch off in Consent and permissions. This
  also turns off morning, nightly and budget alerts, and stops notification
  prompts for detected payments. Payment detection can stay enabled and still
  queues items for in-app review without notifying you. You can also revoke the
  permission in Android Settings.
- **Recorded:** current on/off state, consent version and the time the choice was
  recorded while enabled.

The app never requests notification permission during startup. The startup
notification code only refreshes already-enabled schedules.

### 3.2 Payment detection

- **Android access:** Notification listener access
  (`BIND_NOTIFICATION_LISTENER_SERVICE`), granted on a special Android Settings
  screen.
- **Purpose:** read payment-style notifications from other apps and queue a
  short snippet for your review.
- **Default:** off.
- **When requested:** only when you turn on **Detect payments in notifications**
  in **Settings > Automatic tracking**, or the equivalent switch in Consent and
  permissions.
- **What is kept:** notification title, app label, package name, amount,
  income/expense guess, timestamp and up to 300 characters of text.
- **What is filtered:** DailyMoney itself, system apps, one-time passwords,
  login codes, notifications without payment wording or without a detectable
  amount.
- **What is not automatic:** no transaction is written to the ledger. Every
  detection waits for accept/ignore.
- **If access is revoked:** the app detects the missing access when it resumes
  and turns the setting back off.
- **Withdrawal:** turn the switch off, or revoke notification access in Android
  Settings. A snippet already queued when you turn the feature off is discarded
  on the next app open instead of being imported.
- **Recorded:** current on/off state, consent version and the time the choice was
  recorded while enabled.

Notification access is broad at the Android level: it can read notifications
from many apps. DailyMoney filters aggressively, but the operating system does
not provide a narrower "payments only" permission.

### 3.3 Biometric unlock

- **Android permission:** `USE_BIOMETRIC` / `USE_FINGERPRINT`.
- **Purpose:** unlock the app with a fingerprint or face instead of the PIN.
- **Default:** off. It requires an existing PIN.
- **When requested:** only when you enable **Unlock with biometrics** in
  **Settings > Security & privacy** and pass an Android biometric prompt.
- **If unavailable or denied:** the PIN remains the unlock method.
- **Withdrawal:** turn the biometric switch off, disable the PIN, or remove the
  device enrolment in Android Settings.
- **Data:** Android performs the match. DailyMoney receives only success or
  failure and stores a flag.

### 3.4 Boot rescheduling

- **Android permission:** `RECEIVE_BOOT_COMPLETED`.
- **Purpose:** restore scheduled briefings after a reboot or app update.
- **Default:** declared in the manifest; it only has an effect if a notification
  feature is enabled.
- **Control:** turning notifications off removes the scheduled notifications.

### 3.5 Clipboard export and restore

- **Android permission:** none.
- **Purpose:** copy a JSON backup or a support report when you tap the action,
  and read a DailyMoney JSON backup back when you choose **Restore from
  clipboard**.
- **Control:** both actions are user-initiated. The app does not read the
  clipboard in the background or clear it automatically. Android may show a
  clipboard preview to other apps.
- **Withdrawal:** do not use the export action; erase the clipboard or the saved
  file yourself.
- **Restore scope:** restore replaces transactions, bills, goals, expected income,
  shared records and selected preferences. It deliberately does not import the
  PIN, biometrics, consent choices, notification settings or tutorial state.

### 3.6 Screenshot blocking

- **Android permission:** none.
- **Purpose:** hide balances and transaction history from screenshots, screen
  recording and the recent-apps preview.
- **Default:** on. It is a privacy control, not a runtime permission.
- **Control:** **Settings > Security & privacy > Block screenshots**. Turning it
  off allows screenshots and recents previews again. A camera pointed at the
  screen cannot be blocked by the app.

## 4. What the app does not request

The release build does not request:

- `INTERNET`;
- contacts, SMS, call logs or phone state;
- location;
- camera or microphone;
- calendar;
- advertising ID;
- broad external storage;
- accessibility service;
- usage-access or device-admin access.

Debug and profile builds add `INTERNET` for Flutter development tooling. Those
builds are not distributed.

There is no analytics consent because there is no analytics. There is no
marketing consent because the app sends no marketing. There is no cloud-sync
consent because there is no cloud service.

## 5. Records and withdrawal

The app records:

- the policy version accepted and the acceptance time;
- tutorial progress and completion/skip state;
- the current notification and payment-detection choices;
- the consent version and the time each enabled choice was recorded.

The consent timestamps are cleared when the corresponding choice is turned off.
The app does not keep a historical consent ledger. If a jurisdiction requires a
full audit trail of consent changes, the persistence model must be extended.

When the privacy or terms version changes, the Legal & privacy screen marks the
current version as not accepted and offers it for review. Existing records stay
accessible while review is pending; the app does not silently treat the old
acceptance as acceptance of the new version.

Withdrawal of essential processing is performed by deleting all data in
**Settings > Help & support > Legal & privacy > Data controls**. That action
returns the app to the welcome screen.

## 6. Design requirements checked in the implementation

| Requirement | Status | Evidence |
|---|---|---|
| Optional choices start off | Implemented | `SettingsProvider` defaults; onboarding tests |
| Nothing preselected on first run | Implemented | Welcome gate test checks both checkboxes are false |
| Purpose-specific notification consent | Implemented | Separate `notificationsConsent` and `autoCaptureConsent` |
| Separate Android permissions | Implemented | `POST_NOTIFICATIONS` vs notification-listener access |
| Permission requested only on feature use | Implemented | `_ensureNotifications` and `CaptureSetup`; startup does not request |
| Consent version and timestamp | Implemented | `kConsentVersion`; persistence test |
| Withdrawal turns processing off | Implemented | Master switch; revoked access reconciled on resume |
| Queued snippets dropped after opt-out | Implemented | `CaptureProvider.load(acceptNative: false)` and capture test |
| No permission dumping at startup | Implemented | Startup only schedules enabled features |
| Screenshot blocking on by default | Implemented | `blockScreenshots` default; `FLAG_SECURE` channel |
| Restore cannot change security or consent | Implemented | `restoreBackup` replaces financial records only; backup tests |
| Records deleted with full wipe | Implemented | `resetToDefaults` and data-controls flow |
| Legal-basis mapping per jurisdiction | **Not done** | Requires legal review |
| Consent history/audit log | **Not done** | Only current state is stored |

## 7. Legal-review questions

1. What lawful basis applies to each processing activity in each distribution
   country?
2. Is notification-listener access treated as sensitive data access, and what
   enhanced consent wording is required?
3. Must the app provide a consent history or an export of consent records?
4. What is the minimum age for valid consent, and how should the app handle a
   child user when it cannot identify the user?
5. Are separate consent and terms acceptance required, or can they remain a
   single acceptance step for the essential terms?
6. What withdrawal mechanism and response period are required?
7. Does the app need a "reject all optional" path with equal prominence? The
   current welcome screen has no optional processing enabled, so nothing is
   bundled; confirm this is sufficient.
8. Does the store require a prominent disclosure for notification access?

## Document control

| Item | Value |
|---|---|
| In-app source | `lib/services/legal_content.dart` |
| In-app consent version | 1.1 |
| Review status | Not legally reviewed |
| Consent audit history | Not implemented |
| Monitored privacy contact | Missing |
