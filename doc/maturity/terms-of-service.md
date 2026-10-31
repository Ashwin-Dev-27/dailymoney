# DailyMoney Terms of Service

> **Beta draft - not legally reviewed.** These terms describe DailyMoney
> 1.3.1+8 as implemented in this repository. They are a private-beta draft, have
> not been reviewed by a qualified lawyer, and are not a claim of compliance
> with consumer-protection, financial-services or app-store rules. The operator
> identity, governing law, dispute forum and liability wording must be completed
> and reviewed before public release.

- **Terms version:** 1.1
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)
- **Operator:** Not identified in this repository (release blocker)

## 1. Acceptance

By installing or using DailyMoney you agree to these terms and acknowledge the
Privacy Policy. If you do not agree, do not use the app and uninstall it.

These terms apply to the DailyMoney Android app. They do not create an account
or a continuing service relationship. The welcome screen requires an explicit
acceptance before the app can be entered; the acceptance version and time are
recorded on the device.

## 2. What DailyMoney is

DailyMoney is a personal record-keeping and budgeting tool. It helps you record
income and expenses, plan a monthly budget, reserve money for bills and goals,
and explore estimates.

DailyMoney does **not**:

- hold, transfer or custody money;
- execute payments or act as a payment service;
- connect directly to a bank or Account Aggregator;
- provide credit, lending, investment or regulated financial advice;
- provide tax, accounting or legal advice;
- guarantee that an estimate, alert or projection will be correct.

Bank statement import is a manual, offline paste-and-parse feature. It does not
create a live bank connection.

## 3. Your responsibilities

- Enter information that is accurate enough for your own purposes. Budget
  calculations and projections depend on what you enter.
- Keep your device, app lock and exported backups secure.
- Use the app only for lawful personal money management and do not use it to
  deceive, defraud or harm another person.
- Do not attempt to bypass the app lock, extract another person's data, reverse
  engineer the app for misuse, or interfere with its operation.
- Do not rely on the app as the only record of a payment, bill or financial
  obligation. Keep the original bank, employer or merchant records where they
  matter.
- Do not send one-time passwords, PINs, full account numbers, card numbers or
  bank credentials in a support message.

## 4. Your data

Your records belong to you. DailyMoney claims no ownership of the financial
information you enter.

The app stores data on your device. You are responsible for exporting a backup
before deleting data, uninstalling the app, or moving to another device. Android
cloud backup and device-to-device transfer are disabled because the encryption
key cannot travel with the data.

You can restore a DailyMoney JSON backup from the clipboard in Data controls.
Restore replaces the financial records currently on the device; it does not
restore the app-lock PIN, biometrics, consent choices, notification settings or
tutorial state. Keep the exported copy until you have checked the restored
records.

The app has no account and no server copy. DailyMoney cannot recover a deleted
record, a lost device backup or a PIN that you forget except through the
on-device reset flows described in the app.

## 5. Estimates, not guarantees

Daily allowance, remaining budget, money-map reservations, recovery plans,
what-if scenarios, purchase checks and future projections are estimates
produced from the information available to the app. They are not guarantees
that money will be available, that a bill will be affordable, or that a
projection will come true.

If a transaction is missing, duplicated, recorded on the wrong date, or
categorised incorrectly, every figure that depends on it can change. Review
your records and reconcile them with your bank or payment provider when
accuracy matters.

The app is not a substitute for professional financial, tax, investment or legal
advice. For decisions with significant consequences, consult a qualified
professional.

## 6. Availability and changes

DailyMoney is provided on an as-is and as-available basis. The app may change,
lose a feature, or stop being distributed. Local features can stop working if
the operating system, device storage or Keystore changes.

We do not promise uninterrupted or error-free operation. Notifications are
scheduled inexactly and may be delayed or suppressed by the operating system or
device battery settings. A notification must not be the only warning you rely on
before a payment or due date.

The app may be distributed as a private beta. Beta builds can be unstable, can
change without notice, and may contain defects that are fixed only in a later
build.

## 7. Paid features

DailyMoney currently has no paid features, subscriptions or in-app purchases.
If paid features are added, the price, billing period, renewal, cancellation and
refund terms will be shown before purchase and handled through the app store
that processes the payment.

## 8. Intellectual property

The DailyMoney name, app, visual design, source code and documentation are
protected by applicable intellectual property laws. You receive a personal,
non-exclusive, non-transferable licence to use the app for your own money
management. You may not redistribute, sell or claim authorship of the app except
where the law expressly allows it.

Open-source packages used by the app remain subject to their own licences. Your
entered data is not covered by this licence.

## 9. Complaints and disputes

Start with **Settings > Help & support > Support & complaints**. Include the app
version, what you expected, what happened, and whether the issue concerns a
calculation, privacy, security or accessibility. Do not send one-time passwords,
full bank account numbers or card numbers.

**This beta build does not publish a monitored support contact or a response-time
target.** A verified support contact must be configured before public release.
Nothing in this section limits rights you have under mandatory consumer law.

Governing law and the forum for disputes are **not selected** in this draft.
They must be confirmed for the countries where the app is distributed. Any
choice of law remains subject to mandatory protections that apply where you
live.

## 10. Limitation of liability

> **Draft wording requiring legal review.** This clause is included so the
> product behaviour can be reviewed, not because it has been validated for any
> jurisdiction.

To the fullest extent permitted by applicable law, DailyMoney is not liable for
indirect, incidental or consequential loss, loss of data, loss of profit, or a
financial decision made in reliance on an estimate, alert or projection in the
app.

Nothing in these terms excludes or limits liability that cannot lawfully be
excluded, including mandatory consumer rights. The scope and wording of this
section require review by a qualified lawyer before public release.

## 11. Privacy

The Privacy Policy explains what is stored, where it lives, how it is protected
and how to delete it. The app is local-first: it has no account, no DailyMoney
server and no analytics SDK. Payment detection and notifications are optional
and off until you enable them.

## 12. Changes and contact

These terms have a version and an updated date. A new version will be offered
for review in the Legal & privacy screen. The app does not block access to your
existing records while a new version is pending. If you do not agree to a change,
stop using the app and delete your data.

Contact routes are listed on the Support & complaints screen. A verified
support and legal contact must be configured before public release.

## 13. Open legal-review questions

1. Who is the contracting party, and what entity/address must appear in the
   terms?
2. Which consumer law and governing law apply to the intended distribution
   countries?
3. Is the limitation-of-liability wording enforceable, and what mandatory
   carve-outs are required?
4. Are the app's estimates or budget suggestions regulated financial advice in
   any target jurisdiction?
5. What complaint-handling period and escalation route must be published?
6. Are the beta disclaimers and "as-is" wording enforceable against consumers?
7. Does the app store require a separate terms link, EULA or subscription
   disclosure?
8. What age rating and child-user terms apply?

## Document control

| Item | Value |
|---|---|
| In-app source | `lib/services/legal_content.dart` |
| In-app version | 1.1 |
| In-app updated date | 29 October 2026 |
| Review status | Not legally reviewed |
| Operator / governing law | Missing |
| Monitored legal contact | Missing |
