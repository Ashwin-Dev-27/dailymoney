# DailyMoney Support and Complaints

> **Beta draft - not legally reviewed.** This document describes the support
> workflow of DailyMoney 1.3.1+8. It is a private-beta draft and has not been
> reviewed for consumer-protection, dispute-resolution or accessibility
> requirements. It is not a claim of compliance.

- **Version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)

## 1. Current contact status

The default build publishes one support inbox:

**Ashwinkumar.cs27@gmail.com**

It is used for general support, privacy complaints and security reports unless a
dedicated address is supplied at build time. The app does not promise a
response-time target unless one is configured and displayed. Delivery should be
tested before each public release.

The report builder still copies a report to the clipboard. Users should not send
one-time passwords, PINs, full account numbers or card numbers.

## 2. How the app reads the contact configuration

The contacts are build-time values in
`lib/services/legal_content.dart` using `String.fromEnvironment`:

| Build key | Used for | Fallback |
|---|---|---|
| `DAILYMONEY_SUPPORT_EMAIL` | General support, bugs, incorrect calculations, accessibility | Defaults to `Ashwinkumar.cs27@gmail.com`. |
| `DAILYMONEY_PRIVACY_EMAIL` | Privacy complaints, access, retention, consent, deletion | Falls back to `DAILYMONEY_SUPPORT_EMAIL` if empty. |
| `DAILYMONEY_SECURITY_EMAIL` | Suspected exposure, bypass or unsafe behaviour | Falls back to `DAILYMONEY_SUPPORT_EMAIL` if empty. |
| `DAILYMONEY_SUPPORT_RESPONSE_TIME` | Optional published response target | If empty, the app says no response-time target is published. |

`hasConfiguredSupportContact` is true when the general support address is
non-empty. The default build satisfies it. A build that explicitly sets
`DAILYMONEY_SUPPORT_EMAIL` to an empty value shows the warning again; this is
intended for custom builds, not for public releases.

### Building with contacts

PowerShell example:

```powershell
flutter build apk --release `
  --dart-define=DAILYMONEY_SUPPORT_EMAIL=support@example.com `
  --dart-define=DAILYMONEY_PRIVACY_EMAIL=privacy@example.com `
  --dart-define=DAILYMONEY_SECURITY_EMAIL=security@example.com `
  --dart-define=DAILYMONEY_SUPPORT_RESPONSE_TIME="2 business days"
```

Bash example:

```bash
flutter build apk --release \
  --dart-define=DAILYMONEY_SUPPORT_EMAIL=support@example.com \
  --dart-define=DAILYMONEY_PRIVACY_EMAIL=privacy@example.com \
  --dart-define=DAILYMONEY_SECURITY_EMAIL=security@example.com \
  --dart-define=DAILYMONEY_SUPPORT_RESPONSE_TIME="2 business days"
```

Do not hard-code a placeholder address. Do not use an address that is not
monitored. Verify delivery before shipping the build.

## 3. What the Support screen contains

**Settings > Help & support > Support & complaints** provides:

1. A contact-status banner that warns when general support is not configured.
2. Three contact routes: general support, privacy complaint, security issue.
   Each route shows either the configured address with a copy button or a
   "not configured" warning.
3. A report builder with a topic selector:
   - Bug report
   - Incorrect calculation
   - Privacy complaint
   - Security issue
   - Accessibility issue
   - Other
4. A free-text field for what the user expected and what happened.
5. An optional "Include technical details" checkbox.
6. A **Copy report** button that writes a structured report to the clipboard.
7. Guidance on what not to send and what the app cannot recover.

### Technical details in a report

When the checkbox is on, the report includes:

- app version;
- platform name;
- policy version and consent version;
- whether encryption at rest is on;
- whether an app-lock PIN is enabled;
- notification consent and payment-detection state;
- transaction, upcoming-bill, savings-goal and detected-payment counts;
- whether the tutorial was completed.

It explicitly states that no transaction amounts, notes, names, account numbers
or notification text are included. The user can uncheck the option.

The report is copied to the clipboard, not sent automatically. The app has no
network permission and no server, so it cannot submit the report itself.

## 4. What to include in a complaint

### General support / bug report

- App version (from the Legal & privacy screen).
- Android version and device model.
- The screen you were on.
- What you expected and what happened.
- Steps to reproduce, if known.
- Whether the issue happens after a restart.

### Incorrect calculation

- The screen and the number that looks wrong.
- The numbers you expected and saw.
- The relevant transactions, budget, bills or goals, described without sending
  bank credentials.
- Whether a protection, recovery, carry-forward or student-mode setting was
  active.

### Privacy complaint

- What you want to access, correct or delete.
- Which screen or feature is involved.
- Whether the request concerns notifications, payment detection, export or the
  app lock.
- Because there is no account, deletion is performed on the device in **Data
  controls**. The app cannot delete a copy that you saved elsewhere.

### Security issue

- Enough detail to reproduce the issue without exposing another person's data.
- The app version and Android version.
- Whether the device is rooted or running a custom ROM, if relevant.
- Do not send OTPs, PINs, full account numbers or card numbers.

### Accessibility issue

- The screen and control.
- The assistive technology in use (TalkBack, Switch Access, large text, colour
  correction, etc.).
- What you expected and what happened.
- Whether the issue is visual, motor, hearing or cognitive.

## 5. What not to send

Do not send:

- one-time passwords or login codes;
- app-lock PINs;
- full bank account numbers, card numbers or CVVs;
- bank passwords or net-banking credentials;
- another person's financial records without their permission;
- screenshots that show sensitive data you do not want copied.

The app cannot recover a forgotten PIN or a deleted record. Use the on-device
reset flows if you accept the data loss.

## 6. Response expectations

No response-time target is promised unless `DAILYMONEY_SUPPORT_RESPONSE_TIME` is
configured and shown at the top of the Support screen. Even when a target is
published, it is a target, not a guarantee.

The beta build has no ticketing system, no SLA and no escalation queue. The
operator must define these before public release.

## 7. Complaint handling process to define before release

The following process is **not implemented** and must be agreed with the
operator:

1. **Intake:** a monitored mailbox or form for each route.
2. **Acknowledgement:** who replies, from which address, and within what period.
3. **Triage:** severity levels for data loss, security, privacy, accessibility
   and calculation defects.
4. **Investigation:** who has access to the report, and how long it is kept.
5. **Resolution:** fix, workaround, or explanation.
6. **Escalation:** the route for an unresolved complaint, including any
   regulator or dispute body required in the distribution jurisdiction.
7. **Record keeping:** what complaint records are kept, where, and for how long,
   without putting financial details in an unsecured inbox.
8. **Security disclosure:** a coordinated disclosure policy and a safe channel
   for vulnerability reports.

Until this exists, the app must remain a private beta.

## 8. Support configuration test plan

Before shipping a build with contacts:

1. Build with all three addresses and a response-time string.
2. Confirm the warning banner is gone.
3. Confirm each row shows the intended address.
4. Tap each copy button and confirm the clipboard contains the address.
5. Build without `DAILYMONEY_SUPPORT_EMAIL` and confirm the warning returns and
   no address is fabricated.
6. Send a test message to each address and confirm it arrives in a monitored
   inbox.
7. Confirm the published response time is realistic and staffed.
8. Confirm the privacy and security addresses do not forward to an unmonitored
   personal inbox.

## 9. Legal-review questions

1. What consumer-complaint handling period and escalation route are required in
   the distribution countries?
2. Must the app publish a postal address, company number or data-protection
   officer?
3. What records of complaints must be retained, and for how long?
4. Is a security disclosure policy or safe-harbour statement required?
5. Does the app store require a support contact in the listing and in the app?
6. Are accessibility complaints subject to a separate response standard?

## Document control

| Item | Value |
|---|---|
| In-app source | `lib/services/legal_content.dart`, `lib/screens/support_screen.dart` |
| General support configured | **No** |
| Privacy contact configured | **No** |
| Security contact configured | **No** |
| Response-time target | **Not published** |
| Release status | Blocked until a monitored route exists |
