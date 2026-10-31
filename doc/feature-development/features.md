# DailyMoney — 24-Feature Matrix

> Source: Ashwin's feature list (2026-10-27). This file is the single source of truth for
> what is built, what is partial, and what is planned. Update the status column whenever a
> feature ships.

## Status legend

| Symbol | Meaning |
|---|---|
| ✅ Done | Built end-to-end; automated checks pass (device sign-off is tracked in Verification) |
| 🟡 Partial | Some of the feature exists, but a meaningful part is missing |
| ⬜ Planned | Not built yet |

## Matrix

| # | Feature | Status | Where / notes |
|---|---|---|---|
| 1 | Bank Account Connection | 🟡 Partial | Delivered as **CSV statement import** (Settings → Import & statements): reads comma/semicolon/tab exports with Debit/Credit or Amount columns and skips duplicates. A true live connection needs a regulated bank / Account Aggregator backend, which a local-only app cannot provide. |
| 2 | Morning Financial Greeting | ✅ Done | Daily local notification at 08:00 (configurable) with today's allowance. Content refreshes when the app opens or data changes. |
| 3 | Daily Budget Calculation | ✅ Done | `services/daily_budget.dart`: remaining monthly budget ÷ days left, with optional carry-forward and upcoming bills reserved. |
| 4 | Automatic Expense Tracking | ✅ Done | Android `NotificationListenerService` (`MoneyNotificationListener.kt`) reads payment-like notifications with an amount, queues them locally and shows a review banner. Off by default; requires notification access; nothing enters the ledger until the user confirms. No SMS, bank or full-notification scraping. |
| 5 | Real-Time Budget Updates | ✅ Done | Every add/edit/delete and bill payment recomputes the daily allowance and remaining-today figure immediately; budget alerts fire after save. |
| 6 | Remaining Daily Budget | ✅ Done | Home card shows "left today", spent today, and an over-budget state. |
| 7 | Monthly Budget Tracking | ✅ Done | Home monthly budget bar: spent / budget, remaining, exceeded state; reserved bills count as committed. |
| 8 | Nightly Spending Summary | ✅ Done | Daily local notification at 21:00 (configurable): spent today + allowance left. |
| 9 | Income Tracking | ✅ Done | Income categories, monthly income totals and balance. |
| 10 | Expense Categorization | ✅ Done | 22 fixed categories covering food, groceries, shopping, entertainment, bills, hostel, study and other. |
| 11 | Daily Spending History | ✅ Done | Activity day headers show that day's income/expense totals; Reports lists every day of the month. |
| 12 | Monthly Spending Overview | ✅ Done | Home income/expense + Insights monthly summary and average/day. |
| 13 | Budget Alerts | ✅ Done | Immediate local notification when an expense or paid bill crosses the 20%-left line or uses up today's allowance; toggle in Settings. |
| 14 | Spending Notifications | ✅ Done | Detected payments raise a "Payment detected in … · tap to review" notification, and the existing budget alerts notify at the 20%-left and zero-allowance lines. Detection notifications are only posted while automatic tracking is on and notification consent is enabled; with notifications off, detections still queue for in-app review silently. |
| 15 | Unused Budget Tracking | ✅ Done | Carry-forward toggle; daily allowance absorbs underspend from earlier days and shows rolled-over money. |
| 16 | Upcoming Expense Tracking | ✅ Done | One-time and monthly bills; reserved money is removed from the spendable budget; "mark paid" records the expense and advances/removes the bill. Unpaid overdue bills stay reserved until paid; bills can be deleted without recording a transaction. |
| 17 | Spending Insights | ✅ Done | 6-month trend chart, category donut, top-6 categories, daily average, plus a personalised "For you" card. |
| 18 | Savings Goal Tracking | ✅ Done | `models/savings_goal.dart` + `GoalsProvider`: target, saved amount, optional date, progress, monthly amount needed, overdue state, edit/delete. Goals stay separate from the ledger and budget. Shown on Home and a dedicated screen; included in tips and the assistant. |
| 19 | Transaction History | ✅ Done | Search, income/expense filter, month navigation, grouped by day, tap to edit, long-press to delete. |
| 20 | Manual Expense Entry | ✅ Done | Add/edit sheet with amount (accepts `1,234.50` or `12,50`), category, date with preserved time and note. |
| 21 | Personalized Spending Suggestions | ✅ Done | `services/suggestions.dart`: local rules over category share/spikes, bills due, goal pace, recurring payments, no-spend days, rolled-over money and over-budget states. Capped at six tips; every screen works offline. |
| 22 | Financial Assistant | ✅ Done | `services/assistant_service.dart`: on-device rule-based Q&A for allowance, budget pace, categories, bills, goals, income/balance and tips, with starter prompts. No model calls and no network. |
| 23 | Daily and Monthly Reports | ✅ Done | Reports screen from Insights: monthly budget performance + every day's spend/allowance/remaining. |
| 24 | Secure Financial Data | ✅ Done | Local-only storage, no accounts, no cloud. AES-GCM encryption at rest with a key in the Android Keystore (`DataVault` + `SecureStore`), PBKDF2-HMAC-SHA256 PIN digest with legacy upgrade, biometric unlock via `local_auth`, auto-lock when backgrounded, privacy/permissions screen, JSON export, full data wipe, and a no-account Data controls flow. Android backup/device transfer is disabled. Falls back to plain JSON only if the device keystore is unavailable. |

## Maturity additions — legal, consent, onboarding and controls

Implemented on top of the 24 features without replacing existing screens or data flows:

| Area | Status | Implementation |
|---|---|---|
| First-run welcome | ✅ Done | Welcome gate before the shell; privacy/terms acceptance is explicit and unticked; optional sample-data checkbox is off by default. Existing installs migrate to `welcomeSeen = true` so an upgrade does not look like a first launch. |
| Interactive tutorial | ✅ Done | 10-step overlay over the real Home, Activity, Add, Reports, Insights and Settings controls; optional, skippable, replayable; progress persisted; keyboard shortcuts; reduced-motion handling; `BlockSemantics` hides the shell from screen readers while open. The Add step opens the real entry sheet; nothing is saved. |
| Legal & privacy hub | ✅ Done | Versioned in-app privacy policy, terms, financial disclaimer and consent text in `legal_content.dart`; review timestamp/version stored; a new version is offered for review without blocking existing records. Private-beta notice states the policies are not lawyer-reviewed. |
| Purpose-specific consent | ✅ Done | Separate notification and payment-detection choices, off by default, with version and timestamp; notification prompts and scheduled features follow the notification choice; queued capture snippets are discarded on opt-out. |
| Support & complaints | ✅ Done | In-app report builder with app/Android/device details, topic routing, copy/share, and a visible warning when no support address is configured (`DAILYMONEY_SUPPORT_EMAIL`). No address is invented. |
| Data controls | ✅ Done | Export scope explained, JSON backup, sample-data removal and full local erase from a no-account flow; full reset clears legal/consent/tutorial state and returns to welcome. No fake account-deletion screen. |
| Permission timing | ✅ Done | No startup permission dump. Notification permission is requested only when a notification feature is enabled; payment detection requests Android notification access only when switched on and enables only after the grant is observed; biometric prompt only when enabling unlock. |
| Documentation | ✅ Done | Internal maturity and release docs in `doc/maturity/`; public policy drafts carry beta/not-legally-reviewed banners. See `doc/maturity/README.md` for the internal/public split. |

Known maturity limits: legal review and a genuine support contact are external
dependencies; no post-change APK/device pass has been run; store declarations
(notification access, data safety, account deletion) depend on the distribution
decision. See `doc/maturity/known-limitations-and-external-dependencies.md` and
`release-readiness-checklist.md`.

## Batch plan

### Batch 1 — daily budget engine (complete)

Features: **#2, #3, #5, #6, #8, #11, #13, #15, #16, #23**

- Daily allowance engine with optional carry-forward.
- Upcoming one-time/monthly bills, reserved from the spendable pool, mark-paid flow.
- Home daily card, upcoming section/screen, Activity day totals, Reports screen.
- Morning greeting, nightly summary, and budget alerts via local notifications.
- New settings: name for greetings, carry-forward, notification toggles/times.
- Polish pass:
  - Reserved bills count as committed budget on Home and Reports, with a real
    over-budget amount instead of a clamped "$0.00 over".
  - Overdue unpaid bills stay reserved until paid; past-month reports still ignore
    bills that are only tracked for today.
  - Income-only days no longer count as "spent days"; past months divide the daily
    average by the number of days in the month.
  - Amount fields accept thousands separators and decimal commas; the monthly budget
    keeps cents (e.g. `1,234.50`) instead of rounding or stripping the decimal point.
  - Editing a transaction keeps its time and shows errors after the sheet closes safely.
  - Upcoming bills can be deleted without recording a transaction.
  - Budget alerts are centralized in `services/budget_alerts.dart` and also fire when
    a bill is marked paid, without repeating after the allowance is already spent.
  - Briefings reschedule on app resume and avoid DST drift.

### Batch 2 — goals, guidance and security (complete)

Features: **#18, #21, #22, #24**

- Savings goals with progress, target dates and monthly allocation; Home + Goals screen.
- Rule-based personalised suggestions and a local financial assistant built on the same
  budget snapshot, so answers match the numbers on Home.
- AES-GCM encrypted storage keyed from the Android Keystore, PIN + biometric app lock,
  auto-lock, privacy/permissions screen, JSON export and full data wipe.
- CSV statement import as the offline substitute for #1.
- Privacy copy aligned with the real listener behaviour: only payment-like notifications
  with an amount are kept, locally, and only after the user opts in.

### Batch 3 — automatic capture (complete)

Features: **#4, #14**

- Android `NotificationListenerService` that stores a short payment snippet in a
  plaintext pending queue; Dart moves it into encrypted storage on next launch.
- In-app review queue: accept (creates a transaction with category guess), ignore, clear.
- "Payment detected" notification with a tap-to-review deep link; dedupe window and
  blocked-package list to avoid self/system noise.
- Gated by the Settings switch; notification access is requested only when enabled.
- Not published to Play, so no notification-access policy declaration is needed for the
  personal sideload build.

### Batch 4 — bank connection (partial) and assistant (complete)

Features: **#1, #22**

- #1: CSV statement import ships now. A live bank / Account Aggregator connection needs a
  regulated provider, a consent flow and a backend; it is not feasible for a fully local
  offline app.
- #22: rule-based local assistant ships now; an optional LLM chat would require a network
  service and is intentionally not included.

### Batch 5 — advanced money planning (complete in 1.3.0)

Twelve additions built on the existing ledger, budget and settings layers:

1. **What-if simulator** — purchase, delayed income, bill increase and weekly-saving
   scenarios. All output is labelled simulated; nothing is written to the ledger.
2. **Money protection** — safe-to-spend is the confirmed balance minus reserved bills,
   dated-goal commitments and the optional emergency buffer. The allowance is capped at
   `safe-to-spend ÷ days left`; without a confirmed balance the app falls back to the
   budget plan instead of breaking.
3. **Adaptive allowance** — carry forward, move unspent money to savings, or keep it as a
   buffer. The daily allowance and its reason are shown on Home and in Money Map.
4. **Recovery mode** — deterministic 7/14/21/30-day plans spread overspend over up to
   14 days where possible; the daily cut is capped at 50% of the normal allowance, and
   savings are never touched. When the allowance is already ₹0 the sheet explains that
   recovery cannot lower it further instead of offering a no-op plan, and the window is
   capped at the days left in the month with a clear note.
5. **Purchase assistant** — compares a price with today's allowance, the rest of the
   month and the protected balance, with a plain-language verdict and a one-tap record.
6. **Leak detector** — repeated, rising, duplicate, recurring and unusual patterns; every
   item shows the transactions behind it and stays silent without enough history.
7. **Income delay** — expected income has a confidence level and an expected date, stays
   outside the balance and allowance, and only `markReceived` creates real income.
8. **Student mode** — optional weekly-first wording, allowance shortcut, pocket-money /
   scholarship / family-transfer income and hostel / study expense categories.
9. **Missing-expense recovery** — asks after an unusually quiet day and offers to record
   a real cash payment; it never estimates or invents one.
10. **Habit insights** — weekend, category, repeat and no-spend observations from at least
    three weeks of records, with cautious wording.
11. **Shared expenses** — split payments store the user's own share in statistics; the
    remainder is a receivable. Repayments are settlements that affect balance but not
    income; paying someone back is a normal expense; manual shared records track debts
    without touching the balance.
12. **Richer briefings** — morning and night notifications use the Money Plan snapshot and
    include protected money, safe-to-spend and recovery state.

Guardrails kept throughout: expected income and money owed are never confirmed money;
editing or deleting a linked split keeps its shared record in sync; no AI arithmetic is
used for budgets; every new screen has loading/empty/error or quiet states and the Home
page stays a summary rather than one dashboard per feature.

### Batch 6 — in-app help (1.3.1+8)

- **Searchable Help centre** under Settings → Help & support, with 12 chapters covering
  setup, budgets, income, expenses, editing, daily allowance, categories, insights,
  planning, notifications, settings and data management. Every chapter has what/why/
  where/steps/example/mistakes; 18 FAQ answers are limited to verified behaviour.
- **One content source** in `lib/services/user_guide_content.dart`, separate from the UI,
  with stable chapter ids, FAQ-to-chapter links and punctuation-insensitive search.
- **Guided-tour bridge** that closes the help pages and replays the existing 10-step tour
  rather than maintaining a second walkthrough.
- **Accessible layout** capped at 760 dp, with 320 dp and 2x text tests, header semantics,
  icon illustrations and no screenshots (screenshots are blocked by default).

## Verification

_Last updated: 2026-10-31 (maturity hardening plus the in-app Help Centre applied to source; 174 tests pass; the 1.3.1+8 debug-signed build remains installed over the existing build on the Redmi test device with data intact; a release-signed 1.3.1+8 APK was also built and distributed to the private beta; Help Centre and tour device pass completed; remaining device checks pending)._

| Check | Result |
|---|---|
| `flutter analyze --no-fatal-infos` | ✅ Clean — no issues (output saved in `doc/maturity/analyze-output.txt`) |
| `flutter test` | ✅ 174/174 passing (22 files). Adds planning coverage: personal-share spending, settlement income exclusion, shared-record sync/settle/delete, expected income stays outside balance until received, money protection cap and no-balance fallback, dated-goal savings commitment, purchase classifications, recovery spread/cap, leak/habit silence on thin history and duplicate detection, missing-expense prompt, student categories, and morning/night briefing copy and numbers. Audit additions: PBKDF2 PIN records and legacy migration, settlement-edit/type-switch state, split deletion with repayments, backup manifest rules. Maturity additions: welcome gating and no preselected consent, opt-in sample data, tour skip/completion, legal/consent persistence, upgrade migration, full-reset behavior, notification-consent defaults and mirrored prompt flag, and capture-queue discard after detection opt-out. Hardening additions: strict backup parse/restore with record caps, storage read-failure recovery, default-on screenshot blocking, and a persisted progressive PIN cooldown. Help Centre additions: chapter/FAQ integrity, search/filter/clear, chapter sections, discovery and empty state, tour replay, Settings entry, and 320 dp / 2x text layout. Raw output: `doc/maturity/test-output.txt`. |
| Release APK | ✅ `build/app/outputs/flutter-apk/app-release.apk` (57.8 MB), version `1.3.1+8` (`com.dailymoney.app`, versionCode 8), rebuilt with R8 shrinking, Dart obfuscation and a local release key. `apksigner` reports `CN=Ashwin Kumar, OU=AIX, O=AIX, L=India, ST=India, C=IN`. Debug symbols are split into `build/symbols` and are not shipped. |
| 1.3.0 device pass | ✅ Installed on the Redmi with data preserved. Verified: Money Map (safe-to-spend, buckets, protection/policy controls, zero-allowance explanation, per-day matching the allowance), What If (simulation notice, purchase comparison), Patterns (leaks + habits + expandable evidence), Student mode toggle/tools and negative weekly copy ("… over budget per week at this pace"), Expected Income (empty state, add ₹2,500 as "not counted", mark received created exactly one income transaction — balance ₹9,669 → ₹12,169 and income stayed unchanged until receipt), Shared Expenses (₹800 split with ₹300 personal share: balance −₹800 but spending only +₹300 and ₹500 receivable; repayment +₹500 changed the balance without raising income; deleting the split cleared the shared record and showed the empty state), Activity split rows now read "share ₹300", Purchase assistant (₹100 → "Use money planned for later"; ₹20,000 → "Not covered by confirmed money", shortfall ₹7,331), Missing expense (banner after a zero-spend day, sheet shows today/yesterday/usual-day with the "nothing is added" notice, "Record a cash expense" opens a blank expense, "Nothing missing today" dismisses), Recovery (start → allowance ₹230.50 → ₹212.50 and day 1 of 4; active sheet shows only the plan and End; end → allowance restored to ₹230.50; zero-allowance explanation; 7-day choice capped at the 4 days left), and the Activity "share" subtitle. Morning/night briefing copy and numbers are covered by unit tests; scheduled delivery was verified earlier. |
| Full device pass | 🟡 Partial. 1.3.0 passed. The 1.3.1+8 build was installed twice over the existing install on 30 October 2026 with data intact. Verified on 1.3.1+8: Help Centre entry, 12 chapters, `backup` search (2 chapters / 5 answers), FAQ expansion, chapter detail, tour replay from the Help Centre and a chapter page, tour steps 1-10 and completion. Remaining gaps are the other 1.3.1 features below, TalkBack traversal, physical 200% text size, plus external items such as a live bank connection and scripted biometric unlock. |
| Audit pass (2026-10-28) | ✅ Source review + automated tests only; the release APK was **not** rebuilt. Fixed: PBKDF2-HMAC-SHA256 PIN storage with in-place upgrade of old records; settlement state cleared when its type changes; settlement edits/deletes keep `settled` correct; deleting a split removes its repayments and shared record (no orphaned balance inflow); future dates blocked in the entry sheet; Android backup/device-transfer disabled; Activity day totals use personal shares and exclude settlement income; budget alerts fire for captured and shared-expense payments. |
| Maturity pass (2026-10-30) | ✅ Source + automated tests only; **no device verification of these changes yet.** Added: welcome/legal gate with upgrade migration; optional persisted 10-step tour; versioned policies, consent and timestamps; purpose-specific notification/payment-detection consent; consent-gated detection prompts and queued-snippet discard; support/report builder with no invented contact; no-account Data controls with export and full erase; permission timing fixes; accessibility pass (`BlockSemantics`, reduced motion, keyboard); documentation set in `doc/maturity/`. |
| Hardening pass (2026-10-30) | ✅ Source + automated tests + a release build. Added: clipboard restore with strict schema/count validation and explicit confirmation; restore replaces financial records but keeps device security and consent; read-failure tracking and a recovery screen instead of an empty ledger; export refused while unreadable data exists; `FLAG_SECURE` screenshot/recents blocking on by default with a Settings toggle; persisted progressive PIN cooldown (30 s to 30 min); optional release signing through `android/key.properties`. The debug-signed build is installed and the Help Centre plus tour are device-verified; a release-signed APK was also built for fresh beta installs. The remaining hardening checks are still pending. |

> **Device state restored on 2026-10-28:** the monthly budget is back to **₹1,234.50**
> and the test entries (`Recovery test` ₹300, `Scholarship` ₹2,500,
> `Received · Dinner split` ₹500, `Dinner split` ₹800 and its shared record) are
> deleted. Balance is back to ₹9,669 with ₹4,450 income and ₹2,078 spending.

### Device checklist (run when the Redmi is connected)

1. `adb install -r build/app/outputs/flutter-apk/app-release.apk` and confirm v1.3.1 (8) in Settings. Use the release-signed APK for fresh installs and beta distribution; the debug-signed build stays on the developer device for upgrade testing.
2. On a clean install, confirm the welcome/legal gate shows unticked policy acceptance and an unticked sample-data option; accept without sample data and confirm the tour is offered once. On an upgraded install, confirm the welcome gate does not reappear.
3. Set a monthly budget, then add an expense and confirm the Home card updates immediately.
4. Add an upcoming bill, confirm the reserved amount reduces "left today" and raises the
   Home/Reports "committed" bar, then mark it paid and confirm the expense is recorded.
5. Edit an upcoming bill and use "Delete bill"; confirm no transaction is created.
6. Type `1,200` and `12,50` in amount fields; both should save with the right value.
   Set the monthly budget to `1,234.50` and confirm it is not rounded or multiplied.
7. Open Reports from Home and from Insights; check month navigation and daily rows.
8. Toggle carry-forward and the briefing times; confirm the values persist across a restart.
9. Trigger a budget alert from both an expense and a bill payment; confirm each appears
   once, at the 20%-left warning and when the allowance is used up.
10. Schedule a morning/night time a few minutes ahead and confirm both briefings arrive.
11. Security: set a 4-digit PIN, background/foreground the app, confirm the lock screen,
    unlock with the PIN, enable fingerprint unlock and test it, then change the PIN.
    Enter five wrong PINs and confirm the countdown; restart the app and confirm the
    countdown persists and the correct PIN is still refused until it expires.
    Confirm screenshots and the recents preview are blocked by default, then turn off
    **Block screenshots** and confirm they are allowed again.
12. Privacy: export the JSON backup from **Help & support → Legal & privacy → Data controls**, confirm it contains the ledger but no PIN, then erase all data and confirm the app returns to the welcome screen with legal/consent/tour state reset. Paste the exported JSON into **Restore from clipboard**, confirm the record counts and the explicit checkbox, and verify the ledger is restored while the PIN and consent state remain as they were on the device.
13. Automatic tracking: enable the switch, grant notification access, trigger a payment
    notification from another app (or use the instrumentation note in the runbook) and
    confirm the banner/review screen appears; accept one and confirm the ledger entry.
14. Savings goals: create one with a target date, contribute, confirm progress on Home and
    the goal screen, and confirm the assistant reports it.
15. CSV import: paste a bank/UPI statement, confirm duplicate rows are skipped, then import.
16. Assistant/Insights: ask "How much can I spend today?" and "Where is my money going?";
    confirm the Insights "For you" card and both answers agree with Home.
17. Cleanup: set the monthly budget back to **₹1,234.50** and remove the test records
    `Recovery test` ₹300, `Scholarship` ₹2,500 and `Received · Dinner split` ₹500.
    Then run `adb shell svc power stayon false` to restore the phone's sleep behaviour.
18. Money Map: open from Home and Settings; confirm bills, savings commitments, buffer,
    safe-to-spend and the allowance explanation match Home. Toggle protection and change
    the allowance policy; confirm the allowance and its reason update.
19. What If: run a purchase, delayed income, bill increase and weekly saving; confirm every
    result is labelled simulated and no ledger entry is created. Use the purchase check for
    a cheap, tight and unaffordable price and confirm the verdicts differ.
20. Expected income: add a future scholarship/family transfer; confirm it appears as
    "not counted", the balance is unchanged, and "mark received" creates exactly one income
    transaction (a second tap must not duplicate it).
21. Shared: add an expense with "Split with someone" and a smaller personal share; confirm
    spending uses only your share, the receivable appears in Shared/Settings, recording a
    repayment settles it without raising income, and deleting the settled expense removes
    both the expense and its repayment entries so the balance returns to its earlier value.
22. Patterns: open from Home, Insights and Settings; confirm evidence expands and that a
    thin ledger shows a quiet/empty state instead of invented claims.
23. Student mode: enable it, confirm weekend/weekly numbers, quick pocket money / hostel /
    study entry, and that disabling it hides the Student shortcut without changing data.
24. Missing expense: with several days of history, leave today quiet until the evening and
    confirm the Home banner and sheet appear; dismissing suppresses it for the day and
    recording a cash expense adds a real transaction. Then test recovery: exceed the
    allowance, start a short plan, and confirm the daily allowance drops by the shown cut
    and ends cleanly.
25. Briefings: set a morning/night time a few minutes ahead and confirm the text includes
    the current protected/safe-to-spend state and any active recovery plan.
26. Audit regressions: set a PIN, restart and unlock; edit a settlement and switch it to
    Expense (settlement state must clear); delete a split that has a repayment (both
    entries disappear); try a future date in Add (the picker stops at today); trigger a
    budget alert from a captured payment and a shared repayment; confirm Android backup is
    unavailable for the app and the JSON export still works.
27. Welcome: on a clean install, try Continue with policies unticked (must stay disabled);
    tick policies only and confirm no sample transactions are created. Repeat with sample
    data ticked and confirm sample rows are clearly removable in Settings → Data
    management.
28. Tour: run it once, use Back/Next/Skip, confirm progress persists across restart, replay
    from Settings → Help & support or Help centre → Replay guided tour, confirm the Add step
    opens the real sheet without saving, and confirm the app behind the overlay is hidden
    from TalkBack.
29. Reduced motion: enable Android "Remove animations", replay the tour, and confirm it
    transitions without the animated spotlight/pointer.
30. Consent: with notifications off, enable payment detection and trigger a payment
    notification — the item must queue without a review-prompt notification. Enable
    notifications and confirm the prompt returns. Disable detection while a native snippet
    is queued; confirm the snippet is dropped on next open.
31. Permission timing: deny the notification permission from a notification toggle and
    confirm the rest of the app works; grant it later from the same toggle. Revoke Android
    notification access while detection is on, background and resume, and confirm detection
    turns itself off.
32. Legal: open every policy, the consent screen, Support & complaints (confirm the warning
    when no support address is built in), and Data controls. Confirm the policies show
    version 1.1, export, sample-data removal, full erase, and that the app returns to the
    welcome screen after erase. Restore the exported backup and check the record counts.
33. Support report: build a report and use copy/share; confirm no address is shown when
    `DAILYMONEY_SUPPORT_EMAIL` is empty and that a configured address appears when built
    with the dart-define.
34. Help Centre: open Settings → Help & support → Help centre; search `allowance` and
    `backup`, open a chapter and confirm all six sections, expand a FAQ and follow its
    chapter link, use Clear search, replay the tour from the Help Centre, and repeat at
    200% text size on a 320 dp-wide layout.
