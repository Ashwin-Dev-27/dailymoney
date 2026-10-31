# DailyMoney Product Structure Audit (1.3.1+8)

## AIX Developer Identity
- Product: DailyMoney
- Developer brand: AIX
- Brand type: Independent Software Studio
- Founder and owner: Ashwin Kumar
- Support email: Ashwinkumar.cs27@gmail.com
- Country: India
- Footer: Developed by AIX · Founded by Ashwin Kumar

## Navigation (bottom nav)
1. Home (index 0)
2. Insights (index 1)
3. Activity (index 2)
4. Settings (index 3)

## Screens inventory
| Screen | Location | Purpose | Notes |
|---|---|---|---|
| Splash | lib/screens/splash_screen.dart | Branded intro | Cinematic, skippable |
| Welcome | lib/screens/welcome_screen.dart | First-run legal + optional sample data + tour offer | |
| Home | lib/screens/home_screen.dart | Balance, allowance, goals, recent activity | |
| Transactions/Activity | lib/screens/transactions_screen.dart | Transaction list, edit/delete | |
| Add/Edit sheet | lib/screens/add_edit_sheet.dart | Create/edit transaction | |
| Insights (Stats) | lib/screens/stats_screen.dart | Charts, patterns | |
| Reports | lib/screens/reports_screen.dart | Monthly reports | |
| Patterns | lib/screens/patterns_screen.dart | Habit insights | |
| Money map | lib/screens/money_map_screen.dart | Money flow | |
| What-if | lib/screens/what_if_screen.dart | Scenario simulation | |
| Purchase assistant | lib/screens/purchase_assistant_screen.dart | Purchase check | |
| Expected income | lib/screens/expected_income_screen.dart | Expected income tracking | |
| Shared expenses | lib/screens/shared_screen.dart | Shared expense tracking | |
| Goals | lib/screens/goals_screen.dart | Savings goals | |
| Upcoming/bills | lib/screens/upcoming_screen.dart | Bills tracking | |
| Student mode | lib/screens/student_screen.dart | Student-specific view | |
| Capture | lib/screens/capture_screen.dart | Payment detection | |
| Assistant | lib/screens/assistant_screen.dart | Money assistant | |
| Settings | lib/screens/settings_screen.dart | All preferences | |
| Legal hub | lib/screens/legal_hub_screen.dart | Policies & acceptance | |
| Privacy | lib/screens/privacy_screen.dart | Privacy details | |
| Consent | lib/screens/consent_screen.dart | Optional consents | |
| Support | lib/screens/support_screen.dart | Support & complaints | |
| Data controls | lib/screens/data_controls_screen.dart | Export/restore/wipe | |
| Data recovery | lib/screens/data_recovery_screen.dart | Corrupt data recovery | |
| Lock/PIN | lib/screens/lock_screen.dart, pin_setup_screen.dart | App lock | |
| Import | lib/screens/import_screen.dart | Bank statement import | |
| Recovery sheet | lib/screens/recovery_sheet.dart | Recovery plan | |
| Missing expense sheet | lib/screens/missing_expense_sheet.dart | Missing expense prompt | |
| Help centre | lib/screens/help_centre_screen.dart | Searchable manual, 12 chapters, 18 FAQ answers, tour replay | Content in `services/user_guide_content.dart` |

## Settings sections (current)
1. Account & preferences (currency, name, budget, allowance policy, money protection, emergency buffer, student mode, recovery)
2. Planning (money map, expected income, shared, patterns, student tools)
3. Privacy & security (PIN, biometrics, screenshot blocking)
4. Payment detection (automatic tracking)
5. Import & statements (CSV import)
6. Notifications (briefings, alerts)
7. Appearance (theme)
8. Help & support (Help centre, legal, consent, support, replay tour, reset onboarding)
9. Sound & haptics (sound, volume, haptics, previews)
10. Data management (demo data, backup/restore, wipe)

## Consolidation notes
- Theme/sound/haptics/appearance should be grouped under "Appearance & Sound".
- Security/data/privacy already partially grouped.
- Help & support now groups the Help centre, legal, consent and support; no separate About menu is planned.
- Income/expenses/history already under Activity/Transactions.
- Reports/analytics under Insights/Reports.

## Recommended actions
- Add "About & Support" section with AIX identity and contact actions.
- Keep existing sections but rename for clarity.
- No feature removal without dependency checks (all features retained).

## Status
Inventory complete. Implementation focused on About & Support section and settings grouping labels.