# DailyMoney Privacy Policy

> **Beta draft - not legally reviewed.** This policy describes DailyMoney
> 1.3.1+8 as implemented in this repository. It is a private-beta draft, has not
> been reviewed by a qualified lawyer, and is not a claim of compliance with
> the GDPR, India's DPDP Act, Google Play policy or any other law or
> certification. Before public release, the operator details, contact routes,
> retention wording and jurisdiction-specific rights must be completed and
> reviewed.

- **Policy version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)
- **Distribution at the time of writing:** private beta / sideload

## 1. Who is responsible

DailyMoney is an Android budgeting app. The repository does not currently
identify a legal entity, registered address, data-protection officer or
monitored privacy contact. **This section must be completed before a public
release.** Until then, the app is a private-beta build and privacy questions can
only be raised through the support route described in Section 12.

## 2. Scope and architecture

DailyMoney is local-first. It has:

- no user accounts;
- no DailyMoney server or cloud sync;
- no advertising;
- no analytics or behavioural tracking SDK;
- no crash-reporting SDK;
- no bank or Account Aggregator connection;
- no payment execution;
- no INTERNET permission in the release Android manifest.

Debug and profile builds add the INTERNET permission for Flutter development
tooling. Those builds are not distributed as the product.

The app stores the information you enter so that budgeting, planning, reporting
and app-lock features can work. That information stays in the app's private
storage on your device.

## 3. Information the app stores

### 3.1 Records you enter

- Transactions: title, amount, income or expense type, category, date, note,
  and your personal share of a split expense.
- Upcoming bills: title, amount, category, due date, repeat setting and paid
  state.
- Savings goals: name, target, saved amount, optional target date and
  contributions.
- Expected income: source, amount, expected date, confidence and received
  state.
- Shared expenses: person label, total, your share, repayments and settlement
  state.
- Detected payments (only if you enable payment detection): notification title,
  app label, package name, amount, income/expense guess, timestamp and up to
  300 characters of notification text.

### 3.2 Preferences and onboarding

- Greeting name (optional), currency, monthly budget, allowance policy,
  money-protection settings, emergency buffer, recovery plan, student mode,
  theme and notification times.
- Policy version accepted, acceptance time, tutorial progress, tutorial
  completion/skip state, consent choices, consent version and the time a
  consent choice was recorded.

### 3.3 Security records

- A PBKDF2-HMAC-SHA256 digest of your app-lock PIN, with a random salt and an
  iteration count. The PIN itself is not stored.
- Lock timing, PIN-enabled and biometric-enabled flags.
- A random encryption key held in the Android Keystore. The key is not a
  financial record.

Biometric matching is performed by Android. DailyMoney does not receive or store
your fingerprint, face template or biometric enrolment data.

### 3.4 Imported statements

When you paste a CSV export, the text is parsed on the device. The original
pasted text is not retained. Only the transactions you choose to import are
stored.

### 3.5 What the app does not collect

DailyMoney does not request or collect contacts, SMS, call logs, location,
camera, microphone, calendar, advertising identifiers or health data. It does
not create a user profile and does not track behaviour across apps.

## 4. Optional payment detection

Payment detection is off by default. It requires two separate actions:

1. Granting Android notification access in Android Settings.
2. Turning on **Detect payments in notifications** in DailyMoney.

When both are active, the Android notification listener reads notifications
from other apps to look for payment-style messages. It keeps a detection only
when the notification contains payment wording and a detectable amount. It
ignores DailyMoney itself, system applications, one-time passwords and login
codes.

The listener may store a short snippet in the app's private SharedPreferences
queue in plaintext so the app can import it on the next open. The app then moves
the snippet into encrypted storage and clears the queue. If you turn payment
detection off before the next open, the queued snippet is discarded instead of
being imported.

Nothing is added to your ledger automatically. Every detection waits for your
review. You can accept or ignore it, or clear the review list.

You can turn payment detection off at any time in **Settings > Automatic
tracking**, in **Settings > Help & support > Consent and permissions**, or by
revoking notification access in Android Settings. A queued snippet is discarded
on the next app open if the feature is off.

## 5. Permissions

| Permission or access | Why | Optional? | When requested |
|---|---|---|---|
| App-private storage | Store your records and preferences | Essential to the feature | On first use |
| `POST_NOTIFICATIONS` | Morning briefings, nightly summaries, budget alerts and detected-payment prompts | Yes | Only when you enable a notification feature |
| Notification listener access (`BIND_NOTIFICATION_LISTENER_SERVICE`) | Read payment-style notifications for review | Yes | Only when you enable payment detection |
| `RECEIVE_BOOT_COMPLETED` | Restore scheduled briefings after a reboot or app update | Tied to notifications | Declared in the manifest; used only for notification rescheduling |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | Optional app unlock through Android biometrics | Yes | Only when you enable biometric unlock after setting a PIN |
| Clipboard | Copy a JSON backup or support report when you tap the action | User-initiated | On your tap |

The release build does not request `INTERNET`. It does not request contacts,
SMS, location, camera, microphone or broad storage access.

## 6. How information is protected

- App data is stored in Android app-private storage.
- Payloads are encrypted with AES-256-GCM using a random 256-bit key held in the
  Android Keystore when the device supports it.
- If a usable Keystore is unavailable, the app falls back to app-private JSON
  storage so it remains usable. The **Permissions & data** screen shows whether
  encryption is currently on.
- The app-lock PIN is verified against a PBKDF2-HMAC-SHA256 digest with 100,000
  iterations. A legacy salted SHA-256 record is upgraded in place after a
  successful unlock.
- Android cloud backup and device-to-device transfer are disabled for
  DailyMoney. The backup rules exclude app files and preferences.
- The optional JSON export is copied to the Android clipboard at your request.
  Clipboard contents can be visible to other apps or system services depending
  on the Android version and device. Export only when you are ready to store the
  file somewhere safe.
- Screenshot and recent-apps blocking is on by default (`FLAG_SECURE`). You can
  turn it off in **Settings > Security & privacy > Block screenshots**. Even when
  it is on, a camera pointed at the screen is outside the app's control.
- A restore reads a DailyMoney JSON backup from the clipboard at your request.
  It replaces financial records and selected preferences, but it does not import
  the app-lock PIN, biometrics, consent choices, notification settings or
  tutorial progress.

No method of storage is perfectly secure. A rooted device, a compromised
operating system, a malicious app with notification access, or physical access
to an unlocked device can reduce the protection described here.

## 7. Sharing and third parties

DailyMoney does not sell, rent, share or upload your records. The app contains
no analytics, advertising, crash-reporting, cloud-sync or bank-connection SDK.
It does not connect to a bank or Account Aggregator.

The app uses Android system services for local notifications, biometric
authentication, the clipboard and app-private storage. Those services are
provided by your device and operating system.

If you install DailyMoney from an app store, the store may process installation,
update, crash and review information under its own privacy policy. That
processing is outside the app's control and is not performed by DailyMoney.

Open-source packages used by the app run locally. They are listed in
**Settings > Help & support > Legal & privacy > Open-source licences**. They are
not data recipients in the sense of a server transfer.

## 8. Retention

- Ledger, planning, preference, onboarding and consent records are kept until
  you delete them in the app or uninstall DailyMoney.
- The native payment-detection queue is cleared when the app next opens and
  imports or discards it. Detections you ignore or delete are removed.
- Exported JSON exists only where you paste or save it. DailyMoney does not keep
  a copy. You can restore it yourself from **Data controls**; restore is not
  automatic.
- This build does not maintain a separate crash or diagnostic store.
- The random encryption key remains in the Android Keystore after **Delete all
  data** so the app can keep working. It contains no financial records and is
  removed when the app is uninstalled or Android app data is cleared.
- There is no server-side retention because the app has no server.

## 9. Deletion and your controls

DailyMoney has no accounts, so deleting the data on this device is the
equivalent of account deletion. Open **Settings > Help & support > Legal &
privacy > Data controls** to review the deletion scope, export a backup, and
erase:

- transactions;
- upcoming bills;
- savings goals;
- expected income;
- shared expense records and repayments;
- detected payments;
- preferences, greeting name, budget and planning settings;
- tutorial progress, consent records and policy acceptance;
- notification schedules, app-lock PIN and biometric flag.

The app returns to the welcome screen with an empty ledger. A confirmation
checkbox is required before the destructive action is enabled.

Other controls:

- **Access and portability:** export a JSON copy from Data controls.
- **Restore:** paste a DailyMoney JSON backup in Data controls. This replaces
  financial records, not the device security or consent state.
- **Correction:** edit or delete individual records in the app.
- **Deletion:** erase all data from Data controls.
- **Withdraw optional consent:** turn notifications or payment detection off in
  Consent and permissions.
- **Limit local access:** enable the app lock and biometric unlock.
- **Uninstall:** removes the app and its private storage. Android backup is
  disabled, so a reinstall does not restore deleted data.

Deletion does not erase a clipboard copy, a JSON file you saved elsewhere, a
screenshot, or records held by a bank or payment provider.

## 10. Children

DailyMoney is a general-purpose budgeting tool. It does not create accounts,
does not knowingly collect information from children, and cannot identify who
is using a device. Parents and guardians should decide whether the app is
appropriate for a child and should use the device's app-lock controls.

## 11. International transfers

The app does not transfer records to DailyMoney or to a third-country server.
If an app store processes installation or crash information, that processing is
governed by the store's own terms and may involve international transfers.

## 12. Changes to this policy

The policy has a version and an updated date. When the version changes, the
Legal & privacy screen shows that the current version has not been accepted and
offers the new version for review. The app does not block access to your
existing records while a new version is pending. Material changes will be
described in the app.

## 13. Contact

Privacy questions and complaints can be started from **Settings > Help &
legal > Support & complaints**. **This beta build does not publish a monitored
support or privacy email.** The Support screen says so explicitly rather than
inventing an address. A verified privacy contact must be configured with the
`--dart-define` keys documented in
[support-and-complaints.md](support-and-complaints.md) before public release.

## 14. Questions that require legal review

1. Who is the data controller/operator, and in which jurisdiction is it
   established?
2. Which privacy statute applies to the intended distribution countries, and
   what minimum rights, notices and response periods does it require?
3. Is the app "processing" payment notification content on behalf of the user,
   and what consent wording is required for that access?
4. What is the lawful basis for the essential local processing?
5. Are children's provisions sufficient for the intended audience?
6. What retention period, if any, must be stated for detection snippets and app
   logs?
7. What privacy contact and complaint escalation route must be published?
8. Does the app store need a Data safety declaration that differs from this
   draft?

## Document control

| Item | Value |
|---|---|
| In-app source | `lib/services/legal_content.dart` |
| In-app version | 1.1 |
| In-app updated date | 29 October 2026 |
| Review status | Not legally reviewed |
| Operator details | Missing |
| Monitored privacy contact | Missing |
