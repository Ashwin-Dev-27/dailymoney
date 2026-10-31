# DailyMoney

A local-first personal finance tracker for Android, built with Flutter.
No accounts, no cloud sync, and no internet permission — the ledger never leaves
the device unless the user explicitly exports it.

**Current version:** 1.3.1 (versionCode 8) · Android 7.0+ · package `com.dailymoney.app`

## What it does

- **Daily allowance** — splits the monthly budget across the days left, reserves
  upcoming bills first, and supports carry-forward, savings and buffer policies.
- **Money map** — separates confirmed balance into bills, savings commitments,
  an optional emergency buffer and genuinely safe-to-spend money.
- **Bills, goals and expected income** — upcoming payments, savings targets and
  confidence-rated income that stays outside the balance until received.
- **Shared expenses** — split a bill so only your share counts as spending;
  repayments are tracked as settlements, not income.
- **Insights and patterns** — six-month trends, category breakdown, recurring
  charge detection, habit observations and plain-language suggestions.
- **Reports and what-if tools** — monthly performance, a purchase check and
  deterministic scenarios for a bill increase, delayed income or extra saving.
- **Statement import** — offline CSV import from bank/UPI exports, duplicate-safe.
- **Optional payment detection** — an Android notification listener that keeps
  only payment-like notifications with an amount and queues them for review.
  Nothing enters the ledger automatically.
- **Security** — AES-256-GCM encryption at rest with an Android Keystore key,
  PBKDF2 PIN, biometric unlock, auto-lock, screenshot blocking and a full data wipe.
- **Help Centre** — 12 in-app chapters, 18 verified FAQs and a replayable
  10-step tour over the real screens.

## Repository layout

```
dailymoney_flutter/     Flutter app (Android only)
  lib/                  models, providers, services, screens, widgets, utils
  test/                 174 unit and widget tests
  android/              Gradle project, manifest, native notification listener
doc/
  feature-development/  feature matrix and user guide
  maturity/             release readiness, privacy, security, accessibility,
                        consent, retention and policy drafts
  setup/                setup report and device screenshots
```

## Build and test

Requirements: Flutter 3.47+, Dart 3.4+, JDK 17+ and the Android SDK
(compileSdk 36, build-tools 36.0.0).

```bash
cd dailymoney_flutter
flutter pub get
flutter analyze
flutter test
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

The APK is written to `dailymoney_flutter/build/app/outputs/flutter-apk/app-release.apk`.

Release builds are signed with a local keystore when
`android/key.properties` exists. Without it Gradle falls back to the debug key,
which is for local testing only and must not be distributed. The keystore,
`key.properties`, Firebase config and obfuscation symbols are intentionally
**not** in this repository.

## Security and privacy

- Ledger data is encrypted with AES-256-GCM; the key lives in the Android
  Keystore and does not travel with backups.
- The PIN is stored as a salted PBKDF2-HMAC-SHA256 digest (100,000 iterations),
  never in plain text. Five wrong attempts start a persisted cooldown.
- The app declares no `INTERNET` permission. There are no accounts, analytics
  SDKs, ads or cloud calls.
- Android cloud backup and device-to-device transfer are disabled.
- The optional notification listener ignores OTP/login messages and system apps,
  and only queues payment-like notifications for manual review.
- Backups are manual JSON exports to the clipboard. Restore replaces financial
  records only; PIN, biometrics, consent, notification settings and tutorial
  progress stay on the device.

## Documentation

- [Documentation index](doc/README.md) — every document in `doc/`, grouped by purpose.
- [Security policy](SECURITY.md) — how to report a vulnerability privately.
- [App README](dailymoney_flutter/README.md) — features, layout, build notes,
  security details and known limits.
- [Feature matrix](doc/feature-development/features.md)
- [User guide](doc/feature-development/user-guide.md)
- [Release readiness](doc/maturity/release-readiness-checklist.md)
- [Security and privacy overview](doc/maturity/security-and-privacy-overview.md)
- [Release signing runbook](doc/maturity/release-signing.md)

The policy documents under `doc/maturity/` are drafts that describe the current
implementation. They have not been reviewed by a lawyer and are not a claim of
regulatory compliance.

## Status and limitations

- Android only. The Windows/web platform folders are not part of this project.
- Local-first by design: no cloud sync, multi-device support or live bank link.
- Reports uses a simple budget split; Home is the authoritative daily allowance.
- Earlier budget values are not stored, so past-month reports use the current
  monthly budget.
- Accessibility has been tested at 2x text scaling and 320–393 dp widths, but a
  full TalkBack and contrast audit is still outstanding.
- Beta builds are currently distributed through Firebase App Distribution, not
  the Play Store.

## Credits

Developed by **AIX — Independent Software Studio**
Founder: Ashwin Kumar (India)
Contact: Ashwinkumar.cs27@gmail.com

AIX is an independent software studio, not a registered company.

## License

Copyright © 2026 AIX. All rights reserved.

This repository is published for viewing and evaluation. No license is granted
to copy, modify, redistribute or use the source in another product without
written permission. See [LICENSE](LICENSE) for the full terms.
