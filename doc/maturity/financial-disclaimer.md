# DailyMoney Financial Disclaimer

> **Beta draft - not legally reviewed.** This disclaimer describes DailyMoney
> 1.3.1+8 as implemented in this repository. It is a private-beta draft, has not
> been reviewed by a qualified lawyer or financial regulator, and is not a claim
> that the app complies with financial-advice, lending, payments or
> consumer-credit rules.

- **Version:** 1.2
- **Last updated:** 30 October 2026
- **App version described:** 1.3.1+8 (`com.dailymoney.app`)

## 1. Estimates, not guarantees

Daily allowance, remaining budget, money-map reservations, recovery plans,
what-if scenarios, purchase checks and future projections are estimates. They
are calculated from the records and settings you provide. They are not bank
balances and are not guarantees.

If a transaction is missing, duplicated, recorded on the wrong date, or
categorised incorrectly, every figure that depends on it can change. Review your
records and reconcile them with your bank or payment provider when accuracy
matters.

## 2. DailyMoney does not hold or move money

DailyMoney does not:

- hold money or act as a wallet;
- execute payments or transfer funds;
- connect directly to a bank or Account Aggregator;
- act as a payment service, remittance service or custodian;
- lend money, arrange credit or provide a credit score;
- place a hold or reservation on a real bank account.

Marking a bill as paid or accepting a detected payment only changes your local
records. Reserved bills, savings goals and protected buckets are planning
allocations. They do not move or lock money in a real account.

## 3. Where the numbers come from

- **Confirmed balance** is computed from the transactions you recorded. It is
  not a live bank balance.
- **Reserved bills** are upcoming expenses the app subtracts before calculating
  spendable money.
- **Savings commitments** are dated goal amounts the app treats as reserved for
  planning.
- **Money protection** caps the daily allowance at the confirmed balance left
  after protected buckets. It cannot create money that is not in the ledger.
- **Recovery mode** lowers the daily allowance for a chosen period. It does not
  move savings or borrow money.
- **What-if and purchase check** results are simulations. They are not written
  to the ledger unless you choose to record a real transaction.
- **Expected income** stays outside the balance until you mark it received,
  which records a real income transaction.
- **Shared expenses** treat your personal share as spending and money owed to
  you as a receivable. A repayment is a settlement, not income.
- **Detected payments** are suggestions from notification text. They are not
  confirmed payments until you review and accept them.

## 4. Alerts and notifications

Budget alerts and daily briefings are conveniences. Android may delay or suppress
a notification because of battery restrictions, permission changes, reboot
timing or operating-system policy. Do not rely on a notification as the only
warning before a payment or due date.

Notifications are scheduled inexactly. They may arrive a few minutes late, or
not at all if the device blocks background work.

## 5. Not professional advice

DailyMoney is not a financial adviser, tax adviser, investment adviser, lender,
credit counsellor or accountant. Its observations and tips are general rules
over your own records. They do not consider your full circumstances and are not
a recommendation to buy, borrow, invest, lend or take any other financial
action.

For significant decisions, consult a qualified professional who can review your
complete situation.

## 6. Accuracy and reconciliation

You are responsible for the accuracy of what you enter. The app does not verify
that a transaction occurred, that an amount matches a bank statement, or that a
bill was actually paid. Use the original bank, employer, merchant or tax records
where accuracy matters.

The app has no server and cannot recover a deleted record. Export a JSON backup
before deleting data or uninstalling the app. You can restore that backup from
the clipboard in Data controls, but restore replaces the financial records then
on the device, so check the record counts before confirming.

## 7. Legal-review questions

1. Do any outputs constitute regulated financial advice in the intended
   distribution countries?
2. Is the "estimates, not guarantees" wording prominent enough for consumer
   law?
3. Should the disclaimer appear at first run, at each estimate, or both?
4. Are there jurisdiction-specific warnings required for budgeting, credit or
   investment-adjacent features?
5. Does the app store require a financial-features declaration?

## Document control

| Item | Value |
|---|---|
| In-app source | `lib/services/legal_content.dart` |
| In-app version | 1.1 |
| Review status | Not legally reviewed |
| Regulated-advice assessment | Not performed |
| Operator details | Missing |
