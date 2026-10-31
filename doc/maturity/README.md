# DailyMoney maturity documentation

This folder contains the user-facing policy drafts and the internal engineering
documents prepared for the DailyMoney 1.3.1 private beta and the work required
before a public release.

**Status of the public documents:** all seven public documents are beta drafts.
They describe the implementation in this repository, but they have not been
reviewed by a qualified lawyer and are not a claim of legal or regulatory
compliance. The operator's legal identity, the monitored support contacts, the
governing law and the jurisdiction-specific disclosures are still missing.

## Documents

### User-facing drafts

| # | Document | Purpose |
|---|---|---|
| 1 | [Privacy Policy](privacy-policy.md) | What is stored, where it lives, how it is protected, and how to delete it. |
| 2 | [Terms of Service](terms-of-service.md) | Acceptable use, estimates, availability, liability and complaints. |
| 3 | [Financial Disclaimer](financial-disclaimer.md) | Distinguishes estimates from guarantees and states that DailyMoney does not hold or move money. |
| 4 | [Consent and Permissions](consent-and-permissions.md) | Essential processing, optional choices, permission timing and withdrawal. |
| 5 | [Support and Complaints](support-and-complaints.md) | Contact routes, the missing-contact warning and the support configuration keys. |
| 6 | [Data Retention and Deletion](data-retention-and-deletion.md) | The no-account deletion model, scope, retention and what deletion cannot reach. |
| 7 | [Accessibility](accessibility.md) | Implemented accessibility behaviour, known gaps and the manual audit still required. |

### Internal engineering documents

| # | Document | Purpose |
|---|---|---|
| 8 | [Onboarding and Tutorial Specification](onboarding-and-tutorial.md) | Welcome gate, ten-step tour, persistence, accessibility and non-destructive guarantees. |
| 9 | [Security and Privacy Overview](security-and-privacy-overview.md) | Data flow, encryption, app lock, notification capture, threat model and remaining risks. |
| 10 | [Release Readiness Checklist](release-readiness-checklist.md) | What is done, what is pending and what blocks a public release. |
| 11 | [Beta Test Plan](beta-test-plan.md) | Scope, environments, test cases, evidence and exit criteria for the private beta. |
| 12 | [Known Limitations and External Dependencies](known-limitations-and-external-dependencies.md) | Product limits, security limits and dependencies that cannot be solved in the client. |
| 13 | [Release Signing Runbook](release-signing.md) | Keystore creation, private-key configuration, signer verification and debug-to-release migration. |

## Relationship to the in-app documents

The in-app source of truth is `dailymoney_flutter/lib/services/legal_content.dart`.
It defines the policy version, the consent version, the support build keys and
the exact text shown under **Settings > Help & support > Legal & privacy**.

The Help centre is separate from the legal documents. Its chapters and FAQ
answers live in `lib/services/user_guide_content.dart`, describe verified product
behaviour only, and are maintained under
[user-guide.md](../feature-development/user-guide.md). Update that file when a
shipped control, formula or screen label changes; do not add policy claims there.

The Markdown drafts in this folder expand that text for review and for
publication outside the app. If the in-app text changes, update the matching
Markdown document in the same change. Do not let the two drift.

| In-app content | Markdown counterpart |
|---|---|
| Privacy Policy | [privacy-policy.md](privacy-policy.md) |
| Terms of Service | [terms-of-service.md](terms-of-service.md) |
| Financial Disclaimer | [financial-disclaimer.md](financial-disclaimer.md) |
| Consent and Permissions | [consent-and-permissions.md](consent-and-permissions.md) |
| Support screen | [support-and-complaints.md](support-and-complaints.md) |
| Data controls screen | [data-retention-and-deletion.md](data-retention-and-deletion.md) |
| Help centre chapters and FAQ | `lib/services/user_guide_content.dart`; maintainer note: [user-guide.md](../feature-development/user-guide.md) |

## Current evidence (30 October 2026)

- App version: `1.3.1+8` (`com.dailymoney.app`).
- In-app policy version: `1.1`, updated 30 October 2026.
- Consent version: `1.1`.
- `dart format lib test`: 111 files checked, 0 reformatted on the final pass.
- `flutter analyze --no-fatal-infos`: clean, 0 issues
  (`analyze-output.txt`).
- `flutter test`: 174 tests passing across 22 files, including backup/restore,
  storage read-failure, screenshot preference, PIN cooldown and the Help Centre
  content/search/accessibility checks (`test-output.txt`).
- `flutter build apk --release`: succeeded,
  57.8 MB universal APK at
  `dailymoney_flutter/build/app/outputs/flutter-apk/app-release.apk`,
  signed with the local AIX release key. R8 shrinking and Dart obfuscation
  are enabled; debug symbols are in `build/symbols`. `apksigner` reports
  `CN=Ashwin Kumar, OU=AIX, O=AIX, L=India, ST=India, C=IN`. The keystore and
  `key.properties` are gitignored and backed up outside the repository.
- The debug-signed 1.3.1+8 build was installed over the existing install on the
  Redmi test device on 30 October 2026 with data intact. Version `1.3.1 (8)` was
  confirmed on device. Help Centre search, FAQ expansion, chapter detail, tour
  replay and tour steps 1-10 passed; the remaining 1.3.1 device checks are still
  pending.
- No support mailbox is configured in the source tree, so the Support screen
  shows the "not configured" warning.

## Update rules

1. Public text must describe real behaviour. Do not claim a certification, a
   compliance status, a support response time or an integration that does not
   exist.
2. Bump `kLegalVersion` and `kLegalUpdatedOn` in `legal_content.dart` for any
   material policy change, and update the matching Markdown file.
3. Bump `kConsentVersion` when the purpose or scope of an optional processing
   activity changes.
4. Never put a placeholder email address in the app or in these documents. Use
   the `--dart-define` keys documented in `support-and-complaints.md`, or leave
   the contact empty and let the UI show the warning.
5. Keep the engineering documents factual. A check is only "passed" when its
   command or manual test was actually run and the evidence was recorded.
