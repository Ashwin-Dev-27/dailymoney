# DailyMoney Beta Test Plan

> **Internal engineering document.** This plan covers the private beta of
> DailyMoney 1.3.1+8. It records what has been automated, what must be tested on
> a device, and how a beta defect is triaged. It does not claim that any listed
> manual test has already passed.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **Build under test:** 1.3.1+8 (`com.dailymoney.app`)
- **Baseline toolchain:** Flutter 3.47.8 / Dart 3.13.7
- **Test data:** synthetic only; no real bank credentials or statements

## 1. Objectives

1. Prove that onboarding, legal acceptance, consent and the tour work on real
   Android devices.
2. Prove that optional permissions are requested only when the related feature
   is enabled and that denial leaves the app usable.
3. Prove that deletion removes every claimed record and that export is honest
   about its limits.
4. Prove that existing financial features still work after the maturity changes.
5. Find device-specific defects in notifications, capture, Keystore, biometrics
   and layout.
6. Produce evidence for the release-readiness checklist.

## 2. Scope

### In scope

- first run, welcome, policy acceptance, sample-data opt-in;
- ten-step tour, skip, replay, reset onboarding;
- legal hub, consent screen, support screen, data controls;
- notification permission and scheduling;
- payment-detection permission, capture, review, opt-out;
- app lock, PIN, biometrics, auto-lock, forgot-PIN wipe, persisted cooldown;
- screenshot/recent-apps blocking and its setting;
- full data wipe, export and clipboard restore, including unreadable-data recovery;
- regression of ledger, budget, money map, recovery, goals, bills, expected
  income, shared expenses, insights, reports, CSV import and what-if;
- accessibility basics: TalkBack, large text, reduced motion;
- upgrade from a pre-maturity install.

### Out of scope

- live bank or Account Aggregator sync (not implemented);
- payment execution (not implemented);
- cloud sync, accounts or multi-device restore (not implemented);
- store review or legal approval;
- performance benchmarking at scale;
- root/jailbreak resistance testing;
- localisation beyond English.

## 3. Environments and devices

### Builds

| Build | Purpose | Status |
|---|---|---|
| Debug | Developer smoke and widget tests | Available |
| Profile | Performance smoke | Not built for this pass |
| Release, debug-signed | Developer upgrade path; preserves data on the existing install | Built (`1.3.1+8`, 57.8 MB); installed over the existing build on the Redmi test device; Help Centre/tour pass complete, remaining cases pending |
| Release, release-signed | Public release candidate and fresh beta installs | Built (`1.3.1+8`, 57.8 MB); uploaded to Firebase App Distribution; not installed on the developer device because of the signature change |

### Minimum device set

1. Android 13+ phone (notification runtime permission).
2. Android 12 phone.
3. Android 10 or 11 phone.
4. A second OEM with aggressive battery management.
5. Small-width phone (≈393 dp) and a large phone/tablet.
6. Device with biometrics enrolled (fingerprint and/or face).
7. Device with at least one payment app that posts notifications.

### Settings to exercise

- fresh install and upgrade install;
- system light, dark and automatic theme;
- font size default and maximum;
- display size default and maximum;
- animations on and off;
- notifications allowed and denied;
- notification access granted and revoked;
- biometrics available, unavailable and unenrolled;
- device locale English (only supported locale).

## 4. Test data rules

- Use synthetic names such as "Test User" and fictional merchants.
- Do not import a real bank statement into a test device that is shared.
- Do not send OTPs, PINs, account numbers or card numbers in a support report.
- Export before any destructive test.
- Restore is available for a DailyMoney JSON backup, but it replaces the current
  financial records. Keep a separate copy of the original synthetic data set and
  confirm the record counts before restoring.
- Reset the app between destructive scenarios.

## 5. Automated baseline

These checks must pass before manual testing starts:

| Check | Command | Expected |
|---|---|---|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | Exit 0 |
| Static analysis | `flutter analyze --no-fatal-infos` | No issues |
| Tests | `flutter test --reporter compact` | All tests pass |
| Narrow layout | Included in the suite | No overflow |
| Release manifest | Inspect merged manifest | No `INTERNET` |

Evidence files:

- `doc/maturity/analyze-output.txt`
- `doc/maturity/test-output.txt`

Automated tests do not replace device tests. They run with `FLUTTER_TEST=true`,
where `SecureStore` bypasses platform calls and encryption is disabled.

## 6. Test cases

Status values: **Automated** (covered by a passing test), **Manual - not run**,
**Manual - pass**, **Manual - fail**, **Blocked**.

### 6.1 First run and legal

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| FR-01 | Fresh install shows welcome | Install clean, launch | Welcome screen; no ledger records; both checkboxes unchecked | Automated + manual pending |
| FR-02 | Acceptance required | Tap "Take a quick tour" and "Explore myself" before checking | Both disabled | Automated |
| FR-03 | Policy links open | Tap Privacy Policy, Terms, Disclaimer | Full document opens; back returns to welcome | Manual - not run |
| FR-04 | Acceptance recorded | Check the box, continue, reopen Legal & privacy | Version 1.1 and timestamp shown | Automated |
| FR-05 | Sample data off by default | Continue without checking sample data | Ledger stays empty | Automated |
| FR-06 | Sample data opt-in | Check sample data, continue | About 85 transactions, bills and goals appear | Automated |
| FR-07 | Existing install upgrade | Install old build with data, upgrade | No welcome screen; records intact | Automated (state only); device pending |
| FR-08 | Policy version mismatch | Change stored version in a test build | Legal hub shows acceptance form; records remain accessible | Manual - not run |

### 6.2 Tour

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| TR-01 | Start tour | Welcome > Take a quick tour | Step 1 of 10; spotlight on overview | Automated + manual pending |
| TR-02 | Next/Back | Advance through all steps, go back | Correct targets, tabs and progress | Automated (partial) + manual pending |
| TR-03 | Skip | Tap Skip tour on step 1 | Tour closes; `tutorialSkipped` true; no records created | Automated |
| TR-04 | Finish | Complete step 10, close completion card | Tour closes; completed timestamp stored | Automated |
| TR-05 | Replay | Settings > Help & support > Replay guided tour | Starts at step 1; records unchanged | Manual - not run |
| TR-06 | Reset onboarding | Settings > Show welcome and tour again | Welcome appears; records remain | Manual - not run |
| TR-07 | Entry sheet safety | Step 3 > Open the entry sheet > close | Sheet opens; no record saved | Automated (count unchanged) + manual pending |
| TR-08 | Missing data fallback | Empty ledger, steps 4 and 7 | Fallback text; tour continues | Manual - not run |
| TR-09 | Persistence | Advance to step 5, background/kill, reopen | Tour resumes at step 5 | Manual - not run |
| TR-10 | Reduced motion | Enable Remove animations, start tour | No pulse/bob; short transition | Manual - not run |

### 6.3 Consent and permissions

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| CO-01 | Defaults off | Fresh install > Consent | Notifications and payment detection both off | Automated |
| CO-02 | Notification enable | Consent > Notifications on | Android permission requested; both briefings on; timestamp/version recorded | Manual - not run |
| CO-03 | Notification deny | Deny Android permission | Feature stays off; app usable; explanatory message | Manual - not run |
| CO-04 | Master off | Turn Notifications off | Morning/night/budget off; timestamps cleared | Automated |
| CO-05 | Prompt gating | Notifications off, payment detection on, trigger a detection | Detection queues; no review notification is posted | Manual - not run (flag test automated) |
| CO-06 | Payment detection enable | Settings > Automatic tracking > on | Android notification-access dialog; feature only on after grant | Manual - not run |
| CO-07 | Payment detection revoke | Revoke access in Android Settings, resume app | Feature turns itself off | Manual - not run |
| CO-08 | Opt-out snippet drop | Queue a snippet, turn detection off, reopen | Snippet discarded; not imported | Automated |
| CO-09 | Biometric consent | Enable biometrics | Android prompt; flag stored only on success | Manual - not run |
| CO-10 | No startup prompt | Cold start with all optional features off | No permission dialog | Manual - not run |

### 6.4 Support and data controls

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| SU-01 | Missing contact | Open Support without build defines | Warning banner; rows say not configured; no invented address | Manual - not run |
| SU-02 | Configured contact | Build with test addresses | Banner gone; correct rows; copy works | Manual - not run |
| SU-03 | Report builder | Choose topic, add text, copy | Structured report with version/state, no amounts/notes | Manual - not run |
| SU-04 | Technical details off | Uncheck the option, copy | Report omits technical block | Manual - not run |
| DC-01 | Export | Data controls > Export | JSON copied; toast reports size | Manual - not run |
| DC-02 | Export contents | Paste JSON in a test editor | Contains transactions/bills/goals/expected/shared/settings; no PIN/detections | Manual - not run |
| DC-03 | Wipe confirmation | Tap Delete all data | Checkbox required before destructive button enabled | Manual - not run |
| DC-04 | Full wipe | Confirm wipe | All records erased; welcome returns; no demo data | Automated (state) + manual pending |
| DC-05 | Wipe cancels | Open dialog, cancel | Nothing changes | Manual - not run |
| DC-06 | PIN wipe | Forgot PIN flow | Full wipe; welcome returns | Manual - not run |
| DC-07 | Restore valid backup | Export a ledger, erase all data, paste the JSON in Restore from clipboard | Counts shown; restore replaces financial records; ledger matches the export | Automated (service) + manual pending |
| DC-08 | Restore rejects bad input | Paste plain text, an unrelated JSON file, a truncated backup and a backup with duplicate IDs | Readable error; nothing is changed | Automated |
| DC-09 | Restore preserves device state | Enable PIN, biometrics and a consent choice, then restore | Financial records are replaced; PIN, biometrics, consent, notifications and tutorial state stay | Automated |
| DC-10 | Export refused while unreadable | Seed a corrupt encrypted payload, open Data controls and tap Export | Recovery path is required; no empty-looking backup is produced | Automated |

### 6.5 Security

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| SE-01 | Set PIN | Set a 4-digit PIN, relaunch | Lock screen appears; correct PIN unlocks | Automated (logic) + manual pending |
| SE-02 | Wrong PIN | Enter wrong PIN | Error; no unlock | Automated |
| SE-03 | Legacy migration | Seed legacy SHA-256 record, unlock | Record upgraded to PBKDF2 | Automated |
| SE-04 | Auto-lock | Background longer than the setting, return | Locks | Manual - not run |
| SE-05 | Biometrics success | Enrolled finger/face | Unlocks | Manual - not run |
| SE-06 | Biometrics cancel | Cancel prompt | Remains locked; PIN still works | Manual - not run |
| SE-07 | Backup disabled | Android backup/transfer screen | DailyMoney excluded | Manual - not run |
| SE-08 | Recents preview | Open recents while unlocked | Hidden by default (`FLAG_SECURE`); shown after the setting is turned off | Manual - not run |
| SE-09 | Encryption status | Permissions & data | Shows On when Keystore works; Unavailable otherwise | Manual - not run |
| SE-10 | Screenshot block | Try a screenshot and screen recording with the default setting on | Both are blocked; the toggle changes the behaviour | Manual - not run |
| SE-11 | PIN cooldown | Enter five wrong PINs, restart the app, keep trying | Cooldown countdown is shown and persisted; the correct PIN is refused until it expires | Automated (logic) + manual pending |
| SE-12 | Unreadable data recovery | Seed a corrupt payload, launch | Recovery screen instead of an empty ledger; erase is explicit; no silent overwrite | Automated (state) + manual pending |

### 6.6 Core regression

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| CR-01 | Add income/expense | Add both types | Balance and activity update | Automated |
| CR-02 | Edit/delete transaction | Edit then delete | Totals and charts update | Automated |
| CR-03 | Daily allowance | Change budget/policy | Allowance recalculates; bills reserved | Automated |
| CR-04 | Money protection | Enable and set buffer | Allowance never exceeds confirmed balance | Automated |
| CR-05 | Recovery mode | Start a 7/14/21/30-day plan | Allowance reduced by capped amount; savings untouched | Automated |
| CR-06 | Bills | Add/edit/mark paid | Reserved amount and upcoming list update | Automated |
| CR-07 | Goals | Add/contribute/delete | Goal totals and money map update | Automated |
| CR-08 | Expected income | Add/mark received | Stays outside balance until received | Automated |
| CR-09 | Shared expense | Add, repay, settle, edit, delete | Personal share, receivable and settlement stay in sync | Automated |
| CR-10 | Split deletion | Delete a split transaction | Repayment records cascade | Automated |
| CR-11 | CSV import | Paste a synthetic statement | Rows parse; duplicates skipped | Automated |
| CR-12 | What-if | Run purchase/delayed income scenarios | Deterministic results; no ledger writes | Automated |
| CR-13 | Insights/reports | Open with demo data | Charts render; no overflow at 393 dp | Automated + manual pending |
| CR-14 | Notifications | Enable morning/night | Notification scheduled and delivered near the time | Manual - not run |
| CR-15 | Boot reschedule | Reboot after enabling | Schedule restored | Manual - not run |
| CR-16 | Budget alert | Cross 80% and 100% of allowance | Alert fires once per threshold per day | Automated (logic) + manual pending |
| CR-17 | Future date cap | Try a date beyond the cap | Input is limited | Automated |

### 6.7 Help centre

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| HC-01 | Open Help centre | Settings > Help & support > Help centre | Page shows the hero, search, Replay guided tour, 12 chapters and 18 answers | Automated + device passed |
| HC-02 | Search and clear | Search `backup`, then Clear search | 2 chapters and 5 answers; clear returns to browse mode | Automated + device passed |
| HC-03 | Chapter and FAQ | Open chapter 12, expand a related answer | All six sections, related questions, support card and footer render; FAQ links resolve | Automated + device passed |
| HC-04 | Replay from help | Open a chapter, tap Replay guided tour | Help pages close; tour starts at step 1 over the shell; ledger unchanged | Automated + device passed |
| HC-05 | Large text | 200% system font on the Help centre and a chapter page | No clipping or overflow; all actions reachable | Automated at 320 dp/2x; physical device pending |

### 6.8 Accessibility

| ID | Case | Steps | Expected | Status |
|---|---|---|---|---|
| AC-01 | TalkBack welcome | Enable TalkBack, fresh install | Every control has a name, state and role | Manual - not run |
| AC-02 | TalkBack tour | Start tour, swipe through | Step announced; background not focusable; controls reachable | Manual - not run |
| AC-03 | Large text | 200% font, all main screens | No clipping or overflow | Manual - not run |
| AC-04 | Reduced motion | Remove animations, tour | No decorative motion | Manual - not run |
| AC-05 | Contrast | Inspect both themes | Text and indicators meet the chosen target | Manual - not run |
| AC-06 | Touch targets | Measure tour buttons and icon buttons | At least 48 dp effective | Manual - known gap (40 dp) |

## 7. Defect severity

| Severity | Definition | Example | Release impact |
|---|---|---|---|
| S1 - Critical | Data loss, exposure, payment/file corruption, app cannot start | Wipe deletes more than disclosed; export leaks beyond user action; crash on launch | Blocks release |
| S2 - Major | Core feature broken or misleading consent/permission behaviour | Notification requested at startup; payment detection on without access; wrong allowance | Blocks release |
| S3 - Moderate | Workaround exists; secondary flow broken | Tour target missing but fallback works; wrong copy | Fix before public release, may ship beta |
| S4 - Minor | Cosmetic or low-impact | Spacing, wording, animation | Backlog |

A defect is not closed until the fix is verified on the build and, where
automated coverage is practical, a regression test is added.

## 8. Reporting template

```
Build: 1.3.1+8 (versionCode 8)
Device / Android:
Theme / font size / animations:
Area: onboarding | tour | help | consent | support | data | security | core | accessibility
Severity: S1/S2/S3/S4
Steps:
1.
2.
Expected:
Actual:
Frequency:
Screenshots / screen recording:
Exported test data attached? yes/no
```

Do not attach real financial records. Use the in-app Support report and review
it before sending.

## 9. Entry and exit criteria

### Entry

- Automated baseline passes.
- A test build exists and installs on at least one device.
- Testers have synthetic data and know the deletion/export limits.
- The support route for beta testers is known (even if it is a direct channel,
  because the in-app contact is not configured yet).

### Exit

- All S1 and S2 defects closed.
- All release blockers except explicitly accepted legal/store items closed.
- First run, tour, consent, wipe, security and core regression pass on at least
  three Android versions.
- TalkBack and 200% text pass on at least one device.
- The final report lists every test that was not run and why.
- The operator signs off on the residual risks in
  [known-limitations-and-external-dependencies.md](known-limitations-and-external-dependencies.md).

## 10. Current execution status

| Area | Automated | Device |
|---|---|---|
| First run and legal | Covered | Not run |
| Tour | Covered (flow) | Not run |
| Consent and permissions | Partly covered | Not run |
| Support and data controls | Covered, including restore parse/apply | Not run |
| Security | Logic covered, including cooldown and read-failure recovery | Not run |
| Core regression | Covered | Not run |
| Accessibility | Layout only | Not run |

The `1.3.1+8` release exists in two signed forms: the debug-signed build is
installed on the Redmi test device for upgrade testing, and the release-signed
APK is the distribution candidate. The Help Centre and the full ten-step tour
have passed manual device checks; the remaining manual cases in this plan have
not been recorded.

## Document control

| Item | Value |
|---|---|
| Public? | Yes - published for transparency; originally an internal engineering document |
| Test cases | 82 |
| Automated baseline | Passing (174 tests, 22 files) |
| Device execution | Started: debug-signed 1.3.1+8 installed on the Redmi test device; release-signed APK built for fresh installs; Help Centre/tour cases passed; remaining cases pending |
| Exit status | Not met |
