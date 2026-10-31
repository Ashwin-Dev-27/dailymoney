# Known Limitations and External Dependencies

> **Internal engineering document.** This is the honest boundary of what
> DailyMoney 1.3.1+8 does, what it cannot do without external work, and what has
> not been verified. It must be reviewed before any public claim is made.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)

## 1. Product limitations

### 1.1 Money and planning

1. **No live bank connection.** The app cannot read a bank account. Bank
   statement import is a manual CSV paste-and-parse feature. A real connection
   requires a regulated bank or Account Aggregator partner and a backend.
2. **No payment execution.** The app does not move money, hold money, issue a
   card, lend, or act as a wallet. Marking a bill paid only changes local
   records.
3. **Estimates are estimates.** Daily allowance, money map, recovery plan,
   what-if, purchase check and projections depend on what the user entered.
   Missing, duplicated, late or miscategorised records change every downstream
   number.
4. **No multi-currency conversion.** The app formats amounts in the selected
   currency but does not fetch exchange rates or convert between currencies.
5. **Reports allowance uses the current budget.** Historical reports do not
   reconstruct the budget or protection settings that were active in a past
   month. The allowance shown for a past month can differ from what the user
   actually saw at the time.
6. **Future-date cap.** Entries beyond the app's future-date limit are rejected
   to prevent accidental long-range records. This is intentional but may
   surprise a user who wants to pre-record a distant bill.
7. **CSV import depends on the export format.** The parser supports common
   comma/semicolon/tab files with Debit/Credit or Amount columns. Unusual bank
   layouts, password-protected files, PDFs and scanned statements are not
   supported.
8. **No bank reconciliation.** The app does not compare the ledger against a
   bank balance. The user must reconcile manually.
9. **No attachments.** Receipts, photos and documents cannot be attached.
10. **No multi-user or shared account.** Shared expenses are a local record of
    who owes whom; there is no sync or invitation.

### 1.2 Data and continuity

11. **Backup restore is clipboard-only.** Export copies JSON to the clipboard
    and restore reads it back from the clipboard. It replaces financial records
    and selected preferences, but it does not import the PIN, biometrics,
    consent, notification choices or tutorial state. A file picker is not used,
    to avoid broad storage permission.
12. **No cloud sync or multi-device support.** Moving to a new device now
    requires exporting the JSON, installing the app on the new device, and
    restoring it there. There is no automatic transfer.
13. **Android backup and device transfer are disabled.** This is deliberate
    because the encryption key cannot travel, but it also means the operating
    system will not restore the app.
14. **Decrypt failure needs a manual decision.** If the Keystore key is lost or
    a payload is corrupt, the app shows a recovery screen instead of an empty
    ledger and refuses to export. The unreadable records cannot be repaired;
    the only choices are to restart the app once or erase everything.
15. **No trash or version history.** Deleting a record is permanent.
16. **Detection export is incomplete.** The JSON export excludes the
    detected-payment review list, the PIN digest and the native queue. This is
    documented on the Data controls screen.

### 1.3 Notifications and capture

17. **Notifications are inexact.** The app uses
    `AndroidScheduleMode.inexactAllowWhileIdle`. Android may delay or suppress a
    briefing or alert because of battery optimisation, reboot timing or OEM
    policy. A notification is not a guarantee.
18. **Notification permission can be denied or revoked.** The feature stays off
    or stops; the rest of the app works.
19. **Payment detection is heuristic.** It relies on notification wording and
    amount patterns. It can miss a payment phrased unusually and can flag a
    non-payment that contains a payment word and a number. Every detection
    requires review.
20. **Notification access is broad.** Android does not offer a payments-only
    notification permission. The listener can technically read notifications
    from many apps; DailyMoney filters and stores only payment-like snippets,
    but the operating-system grant is broad.
21. **Pending snippets are briefly plaintext.** The native listener writes to a
    plaintext app-private queue before the Dart side imports it into encrypted
    storage. The queue is cleared on the next app open and discarded if payment
    detection is off.
22. **Capture availability varies by app.** Some apps use custom notification
    layouts, media styles or end-to-end content that the listener cannot parse.
23. **No iOS build.** The repository is Android-only.

### 1.4 Accessibility and localisation

24. **No verified screen-reader pass.** TalkBack has not been run on a device
    for this build.
25. **No large-text verification.** 200% font and maximum display size have not
    been tested.
26. **No contrast audit.** Theme colours have not been measured against WCAG.
27. **Charts lack a text alternative.** A screen-reader user may not get the
    same insight from a chart.
28. **Tutorial Back/Next/Skip buttons are 40 dp high**, below the 48 dp
    guideline.
29. **English only.** No localisation and no RTL support.
30. **No tablet/foldable/landscape optimisation.** The app is designed for a
    phone; large-screen layouts are not verified.

## 2. Security limitations

1. **4-digit PIN with an app-level cooldown.** PBKDF2 raises the cost of a
   copied digest, and five wrong entries start a persisted 30-second to
   30-minute cooldown. The keyspace remains small, and the cooldown is enforced
   by this app, not by hardware or a server; offline guessing against a copied
   digest is still possible.
2. **Screenshot blocking is available but user-controlled.** `FLAG_SECURE` is
   on by default and covers screenshots, screen recording and the recents
   preview. A user can turn it off, and it cannot stop a camera photographing
   the screen.
3. **Clipboard exposure.** Exported JSON and support reports are copied to the
   Android clipboard. Other apps or system UI may read or display it. The app
   does not clear the clipboard automatically. A restore also reads plaintext
   JSON from the clipboard.
4. **Encryption fallback.** If the Keystore is unavailable, data is stored as
   app-private JSON, not encrypted. The UI discloses this, but the fallback is
   weaker.
5. **Plaintext capture queue.** See Section 1.3, item 21.
6. **No root/tamper resistance.** A rooted device, compromised OS, debugger or
   malicious app with sufficient access can bypass the protections.
7. **No certificate pinning or transport security.** There is no network
   traffic in release, so there is nothing to pin. This changes if sync or a
   bank connection is added.
8. **No remote wipe.** Because there is no account or server, a lost device
   cannot be wiped remotely. Android's own device-management tools may help, but
   the app does not provide them.
9. **No security contact configured.** A vulnerability reporter has no published
   private channel in this build.
10. **No formal threat-model or penetration-test sign-off.** The internal
    overview in
    [security-and-privacy-overview.md](security-and-privacy-overview.md) is an
    engineering document, not an independent audit.

## 3. Legal, compliance and operational dependencies

These cannot be solved by changing Dart code.

| Dependency | Why it is needed | Current state |
|---|---|---|
| Operator/legal entity | Policies must identify who is responsible | Missing |
| Qualified legal review | Privacy, terms, consent, liability and financial-disclaimer wording | Not done |
| Target jurisdictions | Determine rights, retention, consumer and financial rules | Not selected |
| Monitored support mailbox | Genuine route for bugs and complaints | Not configured |
| Monitored privacy mailbox | Access/deletion/consent requests | Not configured |
| Monitored security mailbox | Vulnerability disclosure | Not configured |
| Complaint-handling process | Intake, acknowledgement, triage, escalation, retention | Not defined |
| Store data-safety declaration | Must match manifest and data flows | Not prepared |
| Store account-deletion declaration | App has no accounts; local deletion must be explained | Not prepared |
| Privacy policy URL | Store listing requirement | Not published |
| Support URL | Store listing requirement | Not published |
| Content rating / age position | Determines child-user handling | Not decided |
| Financial-features declaration | Store may require it for budgeting apps | Not reviewed |
| Release signing key | Public builds must not use debug keys | Configured locally; keystore and `key.properties` are outside the repository |
| Store developer account | Distribution | Not confirmed in the repository |

## 4. Technical dependencies for future capabilities

| Capability | External dependency | Why the client cannot do it alone |
|---|---|---|
| Live bank sync | Regulated bank or Account Aggregator, consent artefacts, backend | The app has no server, no network permission and no regulated licence |
| Cloud backup/sync | Backend, identity, encryption-key escrow design | The current key is device-bound; sync needs a key-management design |
| Multi-device shared expenses | Backend and identity | Local records cannot be shared across devices |
| Push notifications | Backend or push service | Only local notifications exist |
| Payment execution | Licensed payment provider, compliance, settlement | Regulated activity; explicitly out of scope |
| Credit/lending/investment advice | Licence, suitability assessment, regulated disclosures | Regulated activity; explicitly out of scope |
| Crash reporting | Crash SDK or backend, consent, data-minimisation review | No crash store exists today |
| Remote wipe | Identity and device-management backend | No account or server exists |

## 5. Verification gaps

The following are not verified for this build:

1. A post-change APK was built (`1.3.1+8`, versionCode 8). A release-signed
   copy exists for fresh installs; the developer device still runs the
   debug-signed build so its existing data survives the signature change.
2. The newly built APK is installed on `the Redmi test device`. The Help Centre and tour
   have passed device checks; first launch, consent, wipe, notifications,
   capture, backup restore and biometrics have not yet been run on this build.
3. No TalkBack, Switch Access, 200% text, contrast or reduced-motion device run.
4. No OEM Keystore matrix.
5. No notification-delivery timing test across reboots and battery savers.
6. No capture test against real payment apps and notification styles.
7. No upgrade test on a device with a large existing ledger.
8. No performance test with a large ledger or long history.
9. No independent security review or penetration test.
10. No store review.
12. No legal review.

## 6. Accepted product trade-offs

These are deliberate choices, not defects, but they must be disclosed:

- Local-only storage instead of cloud convenience.
- No account, so no remote recovery or remote wipe.
- Device-bound encryption, so backup/transfer is disabled.
- Clipboard export instead of a file picker, to avoid broad storage permission.
- Optional app lock instead of mandatory authentication.
- Review-only payment detection instead of automatic ledger writes.
- Inexact notifications instead of requesting exact-alarm permission.
- No analytics, so product decisions rely on tester feedback rather than
  telemetry.

## 7. Release position

**Private beta:** possible only for known testers, with a clear warning that the
build is a beta, that support may be unavailable, and that records should be
exported before destructive tests. Testers moving from the old debug-signed
install to a release-signed build must follow the export/uninstall/restore path
in [release-signing.md](release-signing.md).

**Public release:** blocked until the eight blockers in
[release-readiness-checklist.md](release-readiness-checklist.md) are closed.
The largest external dependencies are the monitored support/privacy/security
contacts, qualified legal review, operator identity and jurisdiction, a release
keystore, a post-change device pass and store declarations.

## 8. Review questions

1. Which limitations must appear in the store listing versus only in the app?
2. Is clipboard-only restore sufficient, or is a file picker needed before a
   public release?
3. Should screenshot blocking remain on by default, and should the setting be
   disclosed in onboarding?
4. Is the 30-second-to-30-minute PIN cooldown long enough for a 4-digit PIN?
5. Is the plaintext native queue acceptable, or must it be eliminated?
6. Which jurisdiction's consumer and privacy rules govern the beta?
7. Who is the operator, and who monitors each contact route?
8. What evidence will be accepted as proof that the device matrix passed?

## Document control

| Item | Value |
|---|---|
| Public? | Yes - published in this repository |
| Review status | Engineering review only |
| External dependencies | 15+ |
| Public-release blockers | 8 |
| Accepted trade-offs | 8 |
