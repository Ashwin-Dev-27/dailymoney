# Release Readiness Checklist

> **Internal engineering document.** This checklist records what is actually
> done, what is verified, and what still blocks a public release. A checked box
> means the item was completed for the current source tree; it does not mean a
> store has approved the app or that a lawyer has reviewed it.

- **Version under review:** 1.3.1+8 (`com.dailymoney.app`)
- **Last updated:** 30 October 2026
- **Toolchain:** Flutter 3.47.8 stable, Dart 3.13.7
- **Platform:** Android only
- **Repository:** local Git repository initialized on `main`; no remote configured yet
- **Installed APK:** 1.3.1+8, debug-signed, installed on the developer device on 30 October 2026
- **Distributable APK:** 1.3.1+8, release-signed, built on 30 October 2026 and uploaded to Firebase App Distribution

## 1. Release blockers

These items **must** be resolved before a public release.

| # | Blocker | Why it blocks | Owner / action |
|---|---|---|---|
| 1 | Support contact is not configured | The Support screen says "not configured"; users have no genuine route for bugs, privacy or security reports | Configure and monitor `DAILYMONEY_SUPPORT_EMAIL`, `DAILYMONEY_PRIVACY_EMAIL`, `DAILYMONEY_SECURITY_EMAIL`; verify delivery |
| 2 | Legal review is not complete | Privacy Policy, Terms, Disclaimer, consent wording and liability clauses are drafts | Qualified lawyer review for the target jurisdictions |
| 3 | Operator identity and jurisdiction are missing | Policies cannot identify the data controller or governing law | Complete the operator/legal entity details |
| 4 | Release keystore has only one local backup | The key exists and is backed up outside the repository, but the password has not been rotated and there is no second offline copy; losing the key means a new application id or uninstall/data loss for existing users | Store a second offline copy and rotate the password |
| 5 | Release build is only partially device-verified | A release-signed 1.3.1+8 APK exists, but the installed developer build is debug-signed and the full beta test plan has not run | Complete the device matrix against the release-signed APK |
| 6 | Physical-device verification is incomplete | Automated tests cannot validate notifications, biometrics, capture, Keystore or TalkBack, and only one device has run the build | Run the beta test plan on the device matrix |
| 7 | Store declarations are not prepared | Data safety, account deletion, content rating, privacy policy URL and support URL are required by the store | Complete the store listing and declarations |
| 8 | Complaint-handling process is not defined | The beta has no intake, acknowledgement, escalation or retention process | Agree the process and staff the mailbox before release |

## 2. Code quality and build

| Check | Status | Evidence |
|---|---|---|
| `dart format lib test` | ✅ Run | 111 files checked; 0 reformatted on the final pass |
| `flutter analyze --no-fatal-infos` | ✅ Clean | `doc/maturity/analyze-output.txt` |
| Full `flutter test` | ✅ Passing | `doc/maturity/test-output.txt` |
| Test count | ✅ 174 tests across 22 files | Final compact run |
| New onboarding/legal tests | ✅ 8 tests | `test/onboarding_legal_test.dart` |
| New backup/restore tests | ✅ 7 tests | `test/backup_restore_test.dart` |
| New PIN cooldown tests | ✅ 3 tests | `test/security_test.dart` |
| Capture consent edge-case test | ✅ Passes | `test/capture_test.dart` |
| Release APK built after changes | ✅ Built | `build/app/outputs/flutter-apk/app-release.apk`, 57.8 MB, versionCode 8/versionName 1.3.1, signed with the local AIX release key |
| Release signing code supports a private key | ✅ | `android/app/build.gradle.kts`, `android/key.properties.example` |
| Release keystore created and used | ✅ Created locally | `android/dailymoney-release.jks` and `android/key.properties` exist on the build machine; both are gitignored and must be backed up securely |
| App size / startup profile | ❌ Not measured | 57.8 MB universal APK; no startup baseline |
| Crash-free smoke run | ✅ Passed on device | 1.3.1+8 installed over the existing build on the Redmi test device; app launches; existing data intact; Help Centre search/FAQ/chapter/tour replay and tour steps 1-10 passed; FLAG_SECURE still blocks screenshots |
| Dependency audit | ❌ Not performed | `pubspec.lock` has newer versions available; no vulnerability scan recorded |

## 3. Product surface

### 3.1 Preserved core features

- [x] Transaction ledger, categories, notes and splits
- [x] Daily budget and allowance policies
- [x] Money map and money protection
- [x] Recovery mode
- [x] Expected income
- [x] Shared expenses, repayments and settlements
- [x] Savings goals
- [x] Upcoming bills
- [x] What-if and purchase check
- [x] Insights, patterns and reports
- [x] CSV statement import
- [x] Detected-payment review
- [x] App lock with PIN and biometrics
- [x] Morning, nightly and budget notifications
- [x] Demo data as an explicit action

No existing feature was removed, renamed or replaced in this pass.

### 3.2 New maturity surface

- [x] First-run welcome gate with explicit policy acceptance
- [x] Opt-in sample data (default off)
- [x] Ten-step skippable, replayable tour
- [x] Versioned Privacy Policy, Terms, Disclaimer and Consent content
- [x] Purpose-specific notification and payment-detection consent
- [x] Consent timestamps and version
- [x] Welcome/tutorial state persisted and migrated for existing installs
- [x] Support screen with contact-status warning and report builder
- [x] Data controls with scope, export, confirmation and full wipe
- [x] Legal hub with acceptance and document access
- [x] Consent screen with optional choices
- [x] Help & support section in Settings
- [x] Searchable Help centre with 12 chapters, 18 FAQ answers and tour replay
- [x] Privacy screen links to the legal hub and data controls
- [x] Notification prompt flag respects notification consent
- [x] Tutorial background blocked from screen readers
- [x] Backup restore from the clipboard, with counts and explicit confirmation
- [x] Restore replaces financial records but preserves device security and consent
- [x] Screenshot and recent-apps blocking (`FLAG_SECURE`) on by default
- [x] Persisted progressive PIN cooldown after five wrong attempts
- [x] Decrypt-failure recovery screen instead of an empty ledger
- [x] Release-signing support through `android/key.properties`

## 4. Privacy and security

| Check | Status | Evidence / note |
|---|---|---|
| Release manifest has no `INTERNET` | ✅ | `android/app/src/main/AndroidManifest.xml` |
| Debug/profile builds document `INTERNET` | ✅ | Debug/profile manifests only |
| Android backup and device transfer disabled | ✅ | `allowBackup="false"`, `data_extraction_rules.xml` |
| Payloads encrypted at rest | ✅ | AES-256-GCM via `DataVault` |
| PIN uses PBKDF2 + legacy migration | ✅ | `SecurityProvider`, `security_test.dart` |
| Full data wipe exists without an account | ✅ | `DataControlsScreen`, `wipeAllData` |
| Detection queue discarded after opt-out | ✅ | `CaptureProvider.load(acceptNative: false)` |
| Notification prompts gated by consent | ✅ | Mirrored `dm.notify.prompt.v1` flag |
| No analytics/ad/crash SDK | ✅ | Dependency and source inspection |
| Screenshots/recents blocked | ✅ | `FLAG_SECURE` via `MainActivity.kt`; default on, user-configurable |
| PIN attempt throttling | ✅ | Persisted progressive cooldown; 30 s to 30 min |
| Decrypt-failure recovery message | ✅ | `DataRecoveryScreen`; export refused while unreadable |
| Restore/import of backup | ✅ | Strict parse and confirmed restore in `BackupService` |
| Device penetration test | ❌ Not run | Pending |
| OEM Keystore matrix | ❌ Not run | Pending |

## 5. Legal and policy

- [x] Privacy Policy drafted and available in-app and as Markdown
- [x] Terms of Service drafted and available in-app and as Markdown
- [x] Financial Disclaimer drafted and available in-app and as Markdown
- [x] Consent and Permissions document drafted
- [x] Support and Complaints document drafted
- [x] Data Retention and Deletion document drafted
- [x] Accessibility document drafted
- [x] In-app beta notice says the policies are not lawyer-reviewed
- [x] Policy version and updated date are stored in one source
- [ ] Operator/legal entity identified
- [ ] Governing law and dispute forum selected
- [ ] Jurisdiction-specific rights and disclosures added
- [ ] Liability clause reviewed
- [ ] Financial-advice/regulated-activity assessment completed
- [ ] Children's/age-rating position confirmed
- [ ] Store privacy policy and support URLs published
- [ ] Data safety / account deletion declarations completed
- [ ] Legal review sign-off recorded
- [ ] Support and privacy contacts monitored and tested

## 6. Store and distribution

- [ ] Play Console (or other store) account ready
- [ ] Release keystore created and backed up
- [ ] Release build signed with the release key
- [x] Version code incremented for the new build (`1.3.1+8`)
- [x] Release-signing configuration path documented and implemented
- [ ] Target SDK meets the store's current requirement
- [ ] App icon, feature graphic and screenshots prepared
- [ ] Store title, short description and full description prepared
- [ ] Content rating questionnaire completed
- [ ] Data safety form matches the actual manifest and storage
- [ ] Privacy policy URL live and reachable
- [ ] Support URL live and monitored
- [ ] Account-deletion declaration prepared (the app has no account; explain local deletion)
- [ ] Financial-features declaration reviewed, if the store requires one
- [ ] Internal testing track set up
- [ ] Closed beta track set up
- [ ] Rollback plan and previous build retained
- [ ] Release notes written
- [ ] Export-compliance / encryption declaration reviewed, if required

## 7. Device QA matrix

At minimum:

| Device / OS | Why | Status |
|---|---|---|
| Android 13+ (API 33+) | `POST_NOTIFICATIONS` runtime permission, notification listener | ❌ Not run |
| Android 12 / 12L | Notification trampoline and exact-alarm behaviour | ❌ Not run |
| Android 10-11 | Legacy notification and storage behaviour | ❌ Not run |
| Android 14+ | Foreground/service and notification-listener changes | ❌ Not run |
| Small phone (≈393 dp wide) | Layout overflow | ✅ Automated layout test only |
| Large phone / tablet | Reflow and max width | ❌ Not run |
| 200% font size | Text reflow | ❌ Not run |
| Reduced motion | Tutorial animation | ❌ Not run |
| TalkBack | Semantics and tour | ❌ Not run |
| Biometric-enrolled device | Unlock success and failure | ❌ Not run |
| OEM with aggressive battery management | Notification delivery | ❌ Not run |
| Notification-listener payment apps | Detection and false positives | ❌ Not run |

## 8. Beta exit criteria

The private beta can be considered ready to expand only when:

1. All eight release blockers in Section 1 are closed or explicitly accepted by
   the operator in writing.
2. The automated suite passes on the release commit: format, analyze, tests.
3. A signed release build installs and launches on at least three Android
   versions without a crash.
4. The full first-run flow, tour, notification permission, payment detection,
   app lock and data wipe pass on a physical device.
5. TalkBack can complete first run and the tour.
6. No severity-1 or severity-2 defect remains open.
7. The support and privacy mailboxes receive and acknowledge a test message.
8. The store data-safety declaration matches the manifest and the Privacy
   Policy.

## 9. Go / no-go

**Current status: NO-GO for public release.**

The product and documentation work is substantially complete, and the automated
checks pass. Public release is blocked by the absent release keystore, the lack
of an installed and device-verified post-change build, the missing support
contact, and the missing legal/operator/store work. Private beta distribution to
known testers can proceed only with an explicit warning that the build is a
beta, that support may be unavailable, and that testers should use non-critical
data and export before wiping.

## Document control

| Item | Value |
|---|---|
| Public? | Yes - published in this repository |
| Status | Not release-ready |
| Blockers | 8 |
| Automated suite | Passing (174 tests, 22 files) |
| Device pass | Partial: Help Centre and tour passed on 1.3.1+8; remaining cases pending |
| Built APK | 1.3.1+8, release-signed with the local AIX key; not installed (would replace the debug-signed build) |
| Signed with release key | Produced - `CN=Ashwin Kumar, OU=AIX, O=AIX, L=India, ST=India, C=IN` |
