# DailyMoney documentation

Documentation for the Android app in [`../dailymoney_flutter`](../dailymoney_flutter).
DailyMoney has no backend and no public API, so there is no API contract or
database schema document. The code layout is described in the
[app README](../dailymoney_flutter/README.md), and the data flow and threat
model are in the
[security and privacy overview](maturity/security-and-privacy-overview.md).

## Product and features

| Document | What it covers |
|---|---|
| [Feature matrix](feature-development/features.md) | The 24 shipped features, their implementation and verification evidence. |
| [User guide](feature-development/user-guide.md) | The in-app Help Centre chapters and FAQ answers; the source of truth for shipped behaviour. |
| [Feature development log](feature-development/README.md) | How the feature set was built and checked. |

## Maturity, security and release

Start with the [maturity index](maturity/README.md), which separates the
user-facing policy drafts from the internal engineering documents.

| Document | What it covers |
|---|---|
| [Release readiness checklist](maturity/release-readiness-checklist.md) | What is done, what is pending and what blocks a public release. |
| [Beta test plan](maturity/beta-test-plan.md) | Scope, environments, test cases, evidence and exit criteria. |
| [Release signing runbook](maturity/release-signing.md) | Keystore creation, signing configuration, signer verification and migration. |
| [Security and privacy overview](maturity/security-and-privacy-overview.md) | Data flow, encryption, app lock, notification capture, threat model and risks. |
| [Known limitations](maturity/known-limitations-and-external-dependencies.md) | Product and security limits that cannot be solved in the client. |
| [Onboarding and tutorial](maturity/onboarding-and-tutorial.md) | Welcome gate, ten-step tour, persistence and guarantees. |
| [Consent and permissions](maturity/consent-and-permissions.md) | Permission timing, optional choices and withdrawal. |
| [Data retention and deletion](maturity/data-retention-and-deletion.md) | The no-account deletion model and what deletion cannot reach. |
| [Support and complaints](maturity/support-and-complaints.md) | Contact routes and the support configuration keys. |
| [Accessibility](maturity/accessibility.md) | Implemented behaviour and the manual audit still required. |
| [Product structure audit](maturity/product-structure-audit.md) | Navigation, screens and the AIX developer identity. |

### Policy drafts

[Privacy policy](maturity/privacy-policy.md) ·
[Terms of service](maturity/terms-of-service.md) ·
[Financial disclaimer](maturity/financial-disclaimer.md)

These describe the current local-only implementation. They are drafts, have not
been reviewed by a lawyer, and are not a claim of regulatory compliance.

## Setup evidence

| Document | What it covers |
|---|---|
| [Setup report](setup/setup-report.md) | Toolchain, project creation, early device checks and decisions. |
| [Screenshots](setup/) | Device and earlier web-target screenshots captured during setup. |
| [Analyze output](maturity/analyze-output.txt) | Last recorded `flutter analyze` result. |
| [Test output](maturity/test-output.txt) | Last recorded `flutter test` result. |

## Documentation rules

- The app README is the entry point for building and running the project.
- In-app Help Centre content lives in
  `dailymoney_flutter/lib/services/user_guide_content.dart`; update
  [user-guide.md](feature-development/user-guide.md) when a shipped control,
  formula or screen label changes.
- In-app policy text lives in
  `dailymoney_flutter/lib/services/legal_content.dart`; keep the matching
  Markdown draft in sync.
- Do not add policy claims to the user guide, or product behaviour claims to the
  policy drafts.
