# DailyMoney

Smart personal finance tracker built with **Flutter** — local-first, no accounts, no cloud.

## Features

- **Home** — total balance, today's spending money, money map, monthly budget pace, savings goals, upcoming bills, recent activity, and review banners for detected payments and possibly-missing cash
- **Daily budget** — monthly budget split across the days left, adaptive carry-forward / savings / buffer policy, upcoming bills reserved before the allowance is calculated, and money protection that never plans more than the confirmed balance can cover
- **Money map** — confirmed balance split into bills, savings commitments, an optional emergency buffer and genuinely safe-to-spend money; planning reservations never move real bank money
- **What if & purchase check** — deterministic scenarios for a purchase, delayed income, a bill increase or weekly saving; purchase check compares price against today, the month and the protected balance
- **Recovery mode** — when a month goes over, a short 7/14/21/30-day plan lowers the daily allowance by a capped amount without touching savings
- **Expected income** — scholarship, salary or family transfers tracked with a confidence level and kept outside the balance until "mark received" records a real transaction
- **Shared expenses** — split a bill so only your share counts as spending; money owed is tracked separately, repayments are settlements (balance changes, income does not), and paying someone back is a normal expense
- **Patterns & habits** — evidence-backed checks for repeated, rising or duplicate charges and recurring payments, plus plain-language habit observations; both stay silent without enough history
- **Student mode** — optional weekly-first wording, allowance shortcuts and pocket money / scholarship / hostel / study categories
- **Missing expense prompt** — asks whether unusually quiet cash spending was recorded, and never invents or estimates a transaction
- **Upcoming bills** — one-time or monthly items, mark-paid records the expense and advances/removes the bill; edit or delete a bill without recording a transaction
- **Savings goals** — target, saved amount, optional target date, progress and the monthly amount needed to finish on time; dated goals become a protected monthly commitment while the goal itself stays separate from the ledger
- **Reports** — monthly budget performance plus a day-by-day spend / allowance / remaining breakdown
- **Insights** — 6-month income/expense trend chart, expense breakdown by category (donut + top-6 list), daily average, personalised "For you" tips, and an entry point to Patterns
- **Assistant** — on-device, rule-based Q&A for allowance, budget pace, categories, bills, goals, income and tips; no network and no model calls
- **Suggestions** — local rules over category share/spikes, bills due, goal pace, recurring payments, no-spend days, rolled-over money and over-budget states
- **Activity** — searchable, filterable history grouped by day with daily income/expense totals; split rows show your own share (tap to edit, long-press to delete; deleting a split also removes its shared record and any repayments recorded against it)
- **Add/edit** — bottom sheet with type toggle, category chips, date picker, note and an optional split section where only your share counts as spending; amounts accept `1,234.50` or `12,50` input
- **Bank statements** — CSV import from bank/UPI exports (comma, semicolon or tab; Amount or Debit/Credit columns), duplicate-safe, fully offline. Live bank linking would need a regulated Account Aggregator backend
- **Automatic tracking** — optional Android notification listener keeps only payment-like notifications with an amount, queues them locally and shows a review screen before anything reaches the ledger
- **Notifications** — morning allowance greeting (08:00), nightly spending summary (21:00), immediate budget alerts at 20%-left / over the daily allowance, and detected-payment prompts; all toggleable and time-configurable, with briefing text that includes the money map and recovery state
- **Security** - AES-GCM encryption at rest with an Android Keystore key, PBKDF2 PIN + biometric app lock, auto-lock, privacy/permissions screen, default-on screenshot/recents blocking, persistent PIN cooldown, JSON export/restore and full data wipe
- **Settings** — greeting name, currency (8 options), monthly budget (cents supported), allowance policy, money protection, emergency buffer, student mode, notification times, app lock, automatic tracking, statement import, light/dark/system theme, demo data & clear-all, plus a Money plan section linking every planning tool and Help & support entries for the Help centre, policies, consent, support and data controls
- **Onboarding & help** — first-run welcome with explicit policy acceptance and optional sample data, a replayable 10-step tour over the real screens, a searchable Help centre with 12 chapters and 18 verified FAQ answers, a Legal & privacy hub, purpose-specific consent controls, a support/report builder that never invents a contact address, and no-account data export, clipboard restore and deletion controls

Data is stored on-device. Payloads are AES-GCM encrypted with a key held in the Android
Keystore; if a device has no usable keystore the app falls back to plain JSON so it still
works. There are no accounts, no network calls and no cloud sync. A new install starts
with an empty ledger. The welcome screen offers an optional, default-off sample-data
checkbox; sample data can be removed later from Settings → Data management or by a full reset in
Settings → Help & support → Legal & privacy → Data controls.

## Project layout

```
lib/
  main.dart                      boot: storage → settings → transactions → upcoming → goals → capture → security → expected income → shared
  app.dart                       MaterialApp + lock gate + bottom-nav shell + briefing/capture refresh
  theme.dart                     Material 3 tokens (Inter font, emerald brand, light+dark)
  models/                        Tx (personal share + settlement), UpcomingExpense, SavingsGoal,
                                 ExpectedIncome, SharedExpense, Detection, category catalog
  providers/                     Settings, Transactions, Upcoming, Goals, Capture, Security,
                                 ExpectedIncome, Shared
  services/                      StorageService, DataVault, SecureStore, DemoSeed, DailyBudget,
                                 MoneyPlan, RecoveryPlanner, WhatIfEngine, LeakDetector, HabitEngine,
                                 MissingExpenseDetector, Briefings, BudgetAlerts, NotificationService,
                                 StatementParser, SuggestionEngine, AssistantService, CaptureService,
                                 LegalContent, UserGuideContent, BackupService, CaptureSetup
  screens/                       home, reports, upcoming, stats, transactions, settings, goals,
                                 money map, what-if + purchase check, expected income, shared expenses,
                                 patterns, student mode, assistant, capture, import, pin setup,
                                 privacy, welcome, legal hub, consent, support, data controls,
                                 help centre, data recovery, sheets
  widgets/                       transaction/upcoming tiles, charts (fl_chart), planning widgets,
                                 PIN pad, empty states, tutorial overlay
  utils/format.dart              money/day/month formatting helpers
test/                            174 unit + widget tests (incl. onboarding/legal/consent/help centre,
                                 320-393 dp layout regressions, goals, planning/shared/expected-income
                                 maths, CSV parser, suggestions, assistant, security/vault,
                                 backup/restore, PIN cooldown, screenshot preference, native capture)
assets/fonts/                    Inter (400–800)
android/app/src/main/kotlin/com/dailymoney/app/
                                 MainActivity.kt (FlutterFragmentActivity + capture/privacy channels)
                                 MoneyNotificationListener.kt (payment detection)
android/app/src/main/res/drawable/ic_stat_wallet.xml   notification status-bar icon
```

## Run it (Android only)

This project targets **Android only**; the `windows/` and `web/` platform folders have
been removed. You need the Flutter SDK, the Android SDK with
`platforms;android-36` and `build-tools;36.0.0`, and a JDK 17+ (JDK 21 was used
for development). Install the toolchains outside the repository.

```bash
flutter pub get
flutter devices                  # find your phone / emulator id
flutter run -d <device-id>       # debug run on the device
flutter build apk --release      # release APK
```

The APK is written to:

```
build/app/outputs/flutter-apk/app-release.apk
```

Install it over USB with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

> On Xiaomi/Redmi phones, enable **Developer options → Install via USB** and keep the
> phone unlocked while installing. If MIUI still returns
> `INSTALL_FAILED_USER_RESTRICTED`, install for the primary user explicitly:
>
> ```bash
> adb install -r --user 0 build/app/outputs/flutter-apk/app-release.apk
> ```

## Verify

```bash
flutter analyze                  # 0 issues
flutter test                     # 174/174 passing
flutter build apk --release      # builds app-release.apk (v1.3.1+8)
```

### Documentation

- Internal engineering docs: `../doc/feature-development/` and `../doc/maturity/`
  (`README.md` there separates internal documents from public policy drafts).
- Public policy drafts: `../doc/maturity/privacy-policy.md`,
  `terms-of-service.md`, `financial-disclaimer.md`, and the related transparency
  documents. They describe the current local-only implementation but have not
  been reviewed by a lawyer and are not a claim of regulatory compliance.

### Support contact configuration

The app contains no support address by default. To build with a real contact
route, pass these build-time values (all optional; the support email is the one
that enables the contact route):

```bash
flutter build apk --release \
  --dart-define=DAILYMONEY_SUPPORT_EMAIL=support@example.com \
  --dart-define=DAILYMONEY_SECURITY_EMAIL=security@example.com \
  --dart-define=DAILYMONEY_PRIVACY_EMAIL=privacy@example.com \
  --dart-define=DAILYMONEY_SUPPORT_RESPONSE_TIME="within 5 working days"
```

If `DAILYMONEY_SUPPORT_EMAIL` is empty, the Support screen shows a warning
that no verified contact is configured and still lets the user copy a report.
A genuine monitored address and qualified legal review remain release blockers.

### Security notes

- All payloads are AES-GCM encrypted with a random 256-bit key kept in the Android
  Keystore (`flutter_secure_storage`). The plaintext PIN is never stored; only a
  PBKDF2-HMAC-SHA256 digest (100,000 iterations) lives in the Keystore. Older salted
  SHA-256 PIN records are verified once and upgraded in place.
- A PIN enables the in-app lock and the optional fingerprint/face unlock. Auto-lock runs
  when the app leaves the foreground (immediately, 15 s, 1 min or 5 min). Five wrong
  PINs start a persisted cooldown (30 s, then 1, 2, 5, 15 and 30 min); the delay survives
  a restart and the correct PIN is refused until it expires.
- Screenshot and recent-apps blocking is on by default (`FLAG_SECURE`) and can be
  turned off in Settings → Security & privacy → Block screenshots.
- If a stored payload exists but cannot be decrypted or parsed, the app shows a recovery
  screen instead of an empty ledger. Erasing is a separate, explicit choice; an export
  is refused while unreadable data is present so it cannot look like a valid empty backup.
- If the keystore is unavailable (for example in widget tests) new writes fall back to
  plain JSON and the PIN screen stays off; this is deliberate so the app never becomes
  unopenable on a device without keystore support. Existing encrypted payloads without
  their key are reported through the recovery screen, not silently discarded.
- Settings → Help & support → Legal & privacy → Data controls exports a JSON backup
  (ledger, bills, goals, expected income, shared records and selected preferences; no
  PIN) and restores one from the clipboard. Restore replaces financial records only;
  the PIN, biometrics, consent choices, notification settings and tutorial state stay
  with the device. Export the current records first if you may need them.
- Android cloud backup and device-to-device transfer are disabled for DailyMoney. The
  vault key stays in the Keystore and cannot travel with a backup, so a restored copy
  would only contain unreadable payloads. Use the JSON export/restore above to move data
  deliberately.

### Known limits

- Reports uses a simple budget split for its daily allowance and does not replay the
  money-protection or recovery caps shown on Home. Home remains the live "what can I
  spend today" answer; Reports is a spending record.
- Earlier budget values are not stored, so a past month's report uses the current
  monthly budget rather than the budget that was set at the time.

### Automatic tracking notes

- Off by default. Enabling it asks for Android notification access and opens the system
  screen where it can be granted.
- The listener ignores DailyMoney itself and system apps, skips OTP/login messages, and
  keeps a notification only when it contains payment wording plus a detectable amount.
  Detections are deduplicated for 10 minutes and capped at 20 in the native queue.
- A short snippet (title + amount + app label) is queued in plaintext preferences for the
  next app open; the Dart side merges it into encrypted storage and clears the queue. If
  payment-detection consent is off, the queue is cleared without importing.
- Detected-payment review-prompt notifications respect the separate notification
  consent; with notifications off, detections still queue for in-app review silently.
- Nothing enters the ledger automatically: accept or ignore each item on the review
  screen. On Redmi/Xiaomi, disable battery restrictions for DailyMoney so the listener
  keeps running in the background.

### Notification notes

- Notification permission is requested only when you enable a notification feature in
  Settings, not at first launch. Android 13+ can also change the permission in system
  settings later.
- Briefings are scheduled inexactly (no exact-alarm permission), so delivery may be a
  few minutes off.
- On Xiaomi/Redmi, allow **Autostart** and disable battery restrictions for DailyMoney
  if scheduled briefings do not arrive.
- Briefing text is refreshed whenever the app opens, resumes, or a transaction/setting
  changes; until then the last scheduled message is repeated.
- Budget alerts are immediate and fire once per threshold — at 20% of the daily
  allowance left, then when the allowance is used up. They also fire after marking a
  bill paid, and reset the next day.

## Signing

The release build is signed with a private key when `android/key.properties` exists.
Without it, Gradle falls back to the **debug signing key** so local release builds still
work; a debug-signed release is for local testing only and must not be distributed.
Create the keystore, configure `android/key.properties`, and follow the migration notes
in `../doc/maturity/release-signing.md`. The same key must sign every update of an
installed release.

## Dependencies

provider · shared_preferences · fl_chart · lucide_icons_flutter · intl · uuid ·
flutter_local_notifications · timezone · flutter_timezone · flutter_secure_storage ·
cryptography · local_auth · csv

> Note: the original `lucide_icons` package is abandoned and incompatible with
> Flutter 3.47 (`IconData` is now a `final class`); this project uses the maintained
> fork `lucide_icons_flutter`.
