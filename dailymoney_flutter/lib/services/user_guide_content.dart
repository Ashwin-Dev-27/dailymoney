import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Single source of truth for the in-app user guide and FAQ.
///
/// When a feature changes, update the matching [GuideChapter] and any
/// [GuideFaq] that mentions it. Keep every statement limited to behaviour that
/// is actually implemented in the app. Chapter ids are stable because FAQ
/// links, search and tests use them.
///
/// This content is a reference manual. It deliberately does not repeat the
/// short interactive tour; the Help Centre links to the tour instead.
@immutable
class GuideChapter {
  const GuideChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.summary,
    required this.icon,
    required this.what,
    required this.why,
    required this.where,
    required this.steps,
    required this.example,
    required this.mistakes,
    this.keywords = const [],
  });

  final String id;
  final int number;
  final String title;
  final String summary;
  final IconData icon;

  /// Plain explanation of the feature.
  final String what;

  /// The problem this feature solves for the user.
  final String why;

  /// Exact place in the app where the feature lives.
  final String where;

  /// Ordered instructions.
  final List<String> steps;

  /// A short, concrete everyday example.
  final String example;

  /// Common problems and how to resolve them.
  final List<GuideMistake> mistakes;

  /// Extra search words that do not appear in the prose.
  final List<String> keywords;

  String get searchText => [
        title,
        summary,
        what,
        why,
        where,
        ...steps,
        example,
        for (final mistake in mistakes) '${mistake.problem} ${mistake.fix}',
        ...keywords,
      ].join(' ');
}

@immutable
class GuideMistake {
  const GuideMistake(this.problem, this.fix);

  /// What the user may be doing or seeing.
  final String problem;

  /// The verified way out.
  final String fix;
}

@immutable
class GuideFaq {
  const GuideFaq({
    required this.id,
    required this.question,
    required this.answer,
    required this.chapterId,
    this.keywords = const [],
  });

  final String id;
  final String question;
  final String answer;

  /// Chapter that explains the answer in full.
  final String chapterId;

  final List<String> keywords;

  String get searchText => [question, answer, ...keywords].join(' ');
}

const List<GuideChapter> kGuideChapters = [
  GuideChapter(
    id: 'getting-started',
    number: 1,
    title: 'Getting started',
    summary: 'The four tabs, the + button and the numbers to check first.',
    icon: LucideIcons.compass,
    what:
        'DailyMoney turns the money you record into a confirmed balance and a '
        'daily spending amount. Home is your dashboard: confirmed balance, '
        'this month\'s income and spending, today\'s allowance, the money map, '
        'savings goals, upcoming bills and recent activity. The bottom bar '
        'switches between Home, Insights, Activity and Settings. The + button '
        'opens a new transaction.',
    why:
        'Use it to answer one question before you spend: how much can I safely '
        'spend today? Every number comes from records you enter or confirm. '
        'The app does not connect to your bank or move money.',
    where:
        'Home tab when the app opens. The + button appears on Home, Insights '
        'and Activity. It is intentionally hidden in Settings.',
    steps: [
      'On first launch, read the welcome. Optionally tick Start with sample '
          'data (about 85 transactions, a few bills and two goals; you can '
          'delete it later). Accept the Terms of Service and Privacy Policy.',
      'Choose Take a quick tour or Explore myself. The tour can be replayed '
          'later from this Help Centre or from Settings.',
      'Open Settings > Account & preferences. Enter your name if you want '
          'greetings to use it, and choose your currency.',
      'Set a monthly budget in the same card, or tap Set your monthly budget '
          'on Home. Press Done to save.',
      'Record money you already have with + > Income. There is no '
          'opening-balance field: your balance is recorded income minus '
          'recorded expenses.',
      'Record each expense with + > Expense. Check the daily card on Home '
          'before your next spend.',
    ],
    example: 'You receive a ₹30,000 salary and record it as income. You set a '
        '₹25,000 monthly budget. Rent of ₹8,000 is recorded earlier this '
        'month, and you spent ₹2,000 yesterday. With 20 days left, the '
        'carry-forward base is (25,000 − 8,000 − 2,000) ÷ 20 = ₹750 for today.',
    mistakes: [
      GuideMistake(
        'My balance is still zero after setting a budget.',
        'A budget is a plan, not cash. Record income to create a confirmed '
            'balance.',
      ),
      GuideMistake(
        'I cannot find the + button in Settings.',
        'It is intentionally hidden there. Open Home, Insights or Activity '
            'and tap +.',
      ),
      GuideMistake(
        'My old amounts look wrong after changing currency.',
        'Changing currency only changes the symbol; it does not convert past '
            'amounts. Set the currency before entering records if you need a '
            'different one.',
      ),
      GuideMistake(
        'Sample data is mixed with my own records.',
        'Open Settings > Data management > Delete all transactions, or delete '
            'individual entries in Activity. Sample records are ordinary '
            'transactions.',
      ),
    ],
    keywords: [
      'start',
      'first',
      'begin',
      'welcome',
      'tour',
      'tabs',
      'home',
      'setup',
      'sample',
      'dashboard',
    ],
  ),
  GuideChapter(
    id: 'budget',
    number: 2,
    title: 'Creating and managing a budget',
    summary: 'Turn a monthly plan into a daily spending number.',
    icon: LucideIcons.wallet,
    what: 'Your monthly budget is the amount you plan to spend in a calendar '
        'month. DailyMoney uses it to split money across the days left, compare '
        'spending with a plan and fill the monthly budget bar. It does not move '
        'money or change your bank balance.',
    why: 'Without a budget, the daily card only asks you to set one. With a '
        'budget, Home shows an allowance, the budget bar, reports and budget '
        'alerts. A realistic budget makes the daily number useful.',
    where:
        'Settings > Account & preferences > Monthly budget. You can also tap '
        'Set your monthly budget on Home, or Set monthly budget in Money map.',
    steps: [
      'Open the Monthly budget field and type the amount you plan to spend '
          'this month. Commas and decimal points are accepted.',
      'Press Done/Enter or tap outside the field. A confirmation appears.',
      'To change it, edit the field and confirm again. The allowance '
          'recalculates immediately.',
      'To remove it, clear the field or enter 0. Home returns to the Set your '
          'monthly budget prompt.',
      'Check the Monthly budget bar on Home. It counts recorded spending plus '
          'unpaid bills reserved for this month, turns amber near the limit '
          'and red when exceeded.',
      'Choose what happens to unused daily money in Money map > Protection & '
          'policy > Unused allowance: Carry forward, Move to savings or Keep as '
          'buffer. The Carry forward unused money switch in Settings is the '
          'same setting.',
    ],
    example: 'A ₹31,000 budget with a ₹4,000 rent bill reserved leaves ₹27,000 '
        'across 31 days, about ₹871 per day. Carry forward lets unspent daily '
        'money raise a later allowance. Move to savings or Keep as buffer '
        'leaves the daily figure fixed.',
    mistakes: [
      GuideMistake(
        'My daily allowance is zero.',
        'The budget may already be used by recorded spending and reserved '
            'bills, or money protection may have capped it. Open Money map > '
            'Today to see which adjustment applied.',
      ),
      GuideMistake(
        'My budget is lower than my bills.',
        'Bills are reserved before the daily split, so an unrealistic budget '
            'leaves nothing to spend. Raise the budget or reduce upcoming '
            'bills.',
      ),
      GuideMistake(
        'The budget bar is red before I have spent everything.',
        'Unpaid bills for this month are reserved too. The bar counts '
            'committed money, not only completed expenses.',
      ),
      GuideMistake(
        'Changing the budget changed my balance.',
        'It should not. A budget is a planning target. If the balance changed, '
            'a transaction was added, edited or deleted.',
      ),
    ],
    keywords: [
      'monthly',
      'limit',
      'plan',
      'allowance',
      'carry',
      'forward',
      'remove',
      'bar',
      'spending',
    ],
  ),
  GuideChapter(
    id: 'income',
    number: 3,
    title: 'Adding income',
    summary: 'Record money received, and keep expected money separate.',
    icon: LucideIcons.trendingUp,
    what: 'Income records money you have actually received. It raises your '
        'confirmed balance and this month\'s income total, and gives money '
        'protection a real balance to work from. Expected income is a separate '
        'planning list and never counts until you mark it received.',
    why: 'Your balance, safe-to-spend amount and the protection cap depend on '
        'recorded income. Recording it also keeps reports and the six-month '
        'chart accurate.',
    where: 'The + button > Income. For money you are waiting for: Settings > '
        'Planning > Expected income.',
    steps: [
      'Tap + on Home, Insights or Activity.',
      'Choose Income. The category list changes to Salary, Freelance, '
          'Investments, Pocket money, Scholarship, Family transfer, Gift and '
          'Other.',
      'Enter a title and the amount received, then choose the closest '
          'category.',
      'Pick the date. You can record a past date up to five years back; future '
          'dates are not available.',
      'Add an optional note and tap Add transaction.',
      'For money you are waiting for, open Settings > Planning > Expected '
          'income, add the amount and expected date, then use Mark received '
          'when it arrives. That is the only step that records it as income, '
          'dated today.',
    ],
    example:
        'Your ₹32,000 salary arrives on the 1st. Record it as income under '
        'Salary. The confirmed balance rises and the money becomes available '
        'to the plan. If a freelance payment is promised for the 20th, keep it '
        'in Expected income until it actually arrives.',
    mistakes: [
      GuideMistake(
        'Expected income is not in my balance.',
        'Expected income is a reminder, not confirmed money. Mark it received '
            'when it arrives.',
      ),
      GuideMistake(
        'I cannot choose a future date.',
        'Transactions record what has happened. Use Expected income or '
            'Upcoming bills for future money.',
      ),
      GuideMistake(
        'A friend repaid me and my income looks inflated.',
        'Record it from Settings > Planning > Shared expenses > Owed to you > '
            'Record receipt. A repayment raises the balance but is a '
            'settlement, not income.',
      ),
      GuideMistake(
        'My balance is negative.',
        'Expenses are recorded without matching income. Add the income that '
            'funded those expenses, or check for a duplicate expense.',
      ),
    ],
    keywords: [
      'salary',
      'freelance',
      'expected',
      'received',
      'money in',
      'credit',
      'pocket money',
      'scholarship',
      'gift',
    ],
  ),
  GuideChapter(
    id: 'expenses',
    number: 4,
    title: 'Recording expenses',
    summary: 'Capture spending, including bills shared with other people.',
    icon: LucideIcons.receiptText,
    what: 'An expense records money that left your account. It reduces the '
        'confirmed balance, counts toward the monthly budget and category '
        'breakdown, and reduces what is left of today\'s allowance. A split '
        'expense lets only your own share count as spending.',
    why:
        'The daily allowance, budget bar, alerts, reports and insights are only '
        'as accurate as the expenses you record. Recording them as they happen '
        'keeps the daily number trustworthy.',
    where:
        'The + button on Home, Insights or Activity, or the + button in Shared '
        'expenses. To review later: Activity tab.',
    steps: [
      'Tap + and leave Expense selected. It is the default.',
      'Enter a title and the total amount that left your account.',
      'If someone shares the cost, turn on Split with someone and enter Your '
          'share. Only your share counts as spending; the rest is tracked as '
          'owed to you under Shared expenses.',
      'Pick a category, check the date, add an optional note and tap Add '
          'transaction.',
      'Confirm the new balance and allowance on Home. The entry appears in '
          'Recent activity and Activity.',
      'To pay a bill from your Upcoming list, open the bill and choose Mark '
          'paid; that creates the expense for you.',
    ],
    example:
        'A ₹900 dinner is split three ways. Enter 900 as the amount and 300 as '
        'your share. Your spending rises by ₹300 and ₹600 appears under Shared '
        'expenses as owed to you. When your friends repay, record the receipt '
        'there.',
    mistakes: [
      GuideMistake(
        'I entered the full bill and my spending looks too high.',
        'Edit the expense, turn on Split with someone and set your share. Do '
            'not record the friends\' portion as income.',
      ),
      GuideMistake(
        'The date I need is missing.',
        'The picker allows the last five years through today. For a future '
            'bill use Upcoming, not an expense.',
      ),
      GuideMistake(
        'I forgot an expense from last week.',
        'Add it with the correct past date. Reports and the allowance update '
            'using that date.',
      ),
      GuideMistake(
        'My category is not in the list.',
        'Categories are fixed. Choose the closest match; the note can hold the '
            'detail.',
      ),
    ],
    keywords: [
      'spend',
      'purchase',
      'split',
      'shared',
      'bill',
      'record',
      'receipt',
      'expense',
      'payment',
    ],
  ),
  GuideChapter(
    id: 'editing',
    number: 5,
    title: 'Editing and deleting transactions',
    summary: 'Correct a wrong amount, date or category, or remove an entry.',
    icon: LucideIcons.pencil,
    what:
        'Every recorded transaction can be corrected. Tapping it opens the same '
        'form used to create it, with Save changes. Long-pressing asks for '
        'confirmation before deleting. Editing or deleting recalculates the '
        'balance, allowance, reports and any linked shared record.',
    why: 'Mistakes happen: a wrong amount, category or date, or a duplicate '
        'entry. Correcting the record keeps every number derived from it '
        'accurate.',
    where: 'Activity tab > tap a transaction to edit, or long-press to delete. '
        'Home\'s Recent activity is a quick view; open Activity to make '
        'changes.',
    steps: [
      'Open Activity and find the entry. Use search, the type filter or the '
          'month arrows if the list is long.',
      'Tap the entry to open Edit transaction.',
      'Change the amount, title, category, split, date or note, then tap Save '
          'changes.',
      'To delete, long-press the entry and read the confirmation. If it is '
          'linked to a split, the message explains what else will be removed.',
      'Tap Delete. The balance and allowance update immediately. There is no '
          'undo.',
    ],
    example:
        'You recorded a ₹450 grocery trip as ₹45. Tap it in Activity, change '
        'the amount to 450 and save. The balance and this month\'s spending '
        'adjust, and the Groceries total is corrected.',
    mistakes: [
      GuideMistake(
        'I deleted the wrong entry.',
        'Deletion has no undo. Re-add the transaction with the original '
            'details. A backup exported before deleting can be restored, but '
            'restore replaces the current records.',
      ),
      GuideMistake(
        'Deleting a split expense also removed repayments.',
        'The confirmation warns when linked repayments exist. Deleting the '
            'original split also removes its shared record and settlement '
            'history. Re-add the expense or adjust the shared record instead.',
      ),
      GuideMistake(
        'The transaction moved to another month after editing.',
        'Reports use the transaction date. Correct the date if the expense '
            'belongs to a different month.',
      ),
      GuideMistake(
        'I cannot edit from Home\'s recent activity.',
        'Open Activity to edit or delete. Home\'s list is for a quick look.',
      ),
    ],
    keywords: [
      'edit',
      'delete',
      'remove',
      'undo',
      'correct',
      'change',
      'long press',
      'mistake',
      'duplicate',
    ],
  ),
  GuideChapter(
    id: 'daily-allowance',
    number: 6,
    title: 'Understanding daily allowance',
    summary: 'How today\'s spending amount is worked out and why it changes.',
    icon: LucideIcons.calculator,
    what: 'The daily allowance is the amount DailyMoney suggests you can spend '
        'today after keeping bills and protected money aside. Left today is the '
        'allowance minus what you have already spent today. It can go '
        'negative; the card then shows Over today in red. It is guidance, not '
        'a limit that blocks entries.',
    why: 'A single daily number is easier to act on than a monthly total. It '
        'helps you pace spending so the month\'s money lasts.',
    where:
        'Home > Today\'s spending money card. The full breakdown is in Money '
        'map > Today (tap the money map strip on Home).',
    steps: [
      'Set a monthly budget.',
      'Record income, expenses and any upcoming bills so the plan has real '
          'numbers.',
      'Read the Home card each morning. It shows the allowance and what is '
          'left after today\'s spending.',
      'Tap the money map strip for the breakdown: allowance before '
          'adjustments, protection cap, recovery cut, spent today and left '
          'today.',
      'Change the budget or unused-money policy in Money map > Protection & '
          'policy if the number does not fit your life.',
      'If the allowance is zero, read the note under the breakdown; it names '
          'the reason.',
    ],
    example: 'With Carry forward on, the base is (budget − spending recorded '
        'outside today − bills reserved this month) ÷ days left in the month, '
        'never below zero. A ₹30,000 budget, ₹5,000 spent before today and 25 '
        'days left gives a ₹1,000 base. If safe-to-spend is lower, money '
        'protection caps the allowance at that lower figure.',
    mistakes: [
      GuideMistake(
        'My allowance changed without a new expense.',
        'It recalculates as the date changes, when a bill is added or marked '
            'paid, when the budget changes, or when protection or recovery '
            'adjusts it. Check Money map > Today.',
      ),
      GuideMistake(
        'Spending today did not reduce the allowance.',
        'Today\'s spending reduces Left today, not the allowance itself. The '
            'allowance is the starting amount for the day.',
      ),
      GuideMistake(
        'My allowance is lower than my budget divided by the days.',
        'Bills, savings commitments, the emergency buffer and money protection '
            'are set aside first. The breakdown shows each deduction.',
      ),
      GuideMistake(
        'I spent over the allowance and the app still accepted it.',
        'The app records reality rather than blocking you. The card shows Over '
            'today and the budget bar turns red. Use What if or a recovery '
            'plan to adjust.',
      ),
    ],
    keywords: [
      'daily',
      'allowance',
      'left today',
      'over',
      'protection',
      'formula',
      'safe to spend',
      'calculation',
      'maths',
    ],
  ),
  GuideChapter(
    id: 'categories',
    number: 7,
    title: 'Managing categories',
    summary: 'Use the fixed category lists to see where money goes.',
    icon: LucideIcons.pieChart,
    what:
        'Every transaction has one category. Income and expense categories are '
        'fixed lists with their own icons and colours. Categories drive the '
        'expense breakdown and help you see where money goes.',
    why: 'A few accurate categories make Insights useful. Choosing the closest '
        'category is enough; the note can carry the detail.',
    where: 'Category chips in the add or edit transaction sheet. Results: '
        'Insights > Expense breakdown.',
    steps: [
      'Open + or tap an existing transaction in Activity.',
      'Choose Expense or Income first; the category list changes to match.',
      'Tap the category that best fits.',
      'Save. The category colour and icon appear in Activity.',
      'Review Insights > Expense breakdown to see the month by category.',
    ],
    example:
        'A bus pass goes under Transport; a hostel mess bill goes under Hostel '
        '& mess. If you are unsure, Other plus a clear note is better than '
        'skipping the record.',
    mistakes: [
      GuideMistake(
        'I cannot add a custom category.',
        'Custom categories are not available. Use the closest fixed category '
            'and put specifics in the note.',
      ),
      GuideMistake(
        'My category disappeared when I changed the type.',
        'Income and expense categories are separate. Pick a category again '
            'after switching type.',
      ),
      GuideMistake(
        'The breakdown total does not match the full bill.',
        'For a split expense only your share counts. The rest is a receivable, '
            'not spending.',
      ),
      GuideMistake(
        'Two similar categories confuse me.',
        'Pick one and stay consistent. For example, use Food & dining for '
            'meals out and Groceries for food bought to cook.',
      ),
    ],
    keywords: [
      'category',
      'categories',
      'tag',
      'breakdown',
      'list',
      'food',
      'transport',
      'other',
      'custom',
    ],
  ),
  GuideChapter(
    id: 'insights',
    number: 8,
    title: 'Monthly spending and insights',
    summary: 'Read the month, the category breakdown and the daily reports.',
    icon: LucideIcons.chartColumn,
    what: 'Insights summarises a month: income, spending, average daily spend, '
        'suggestions, a six-month chart and an expense breakdown by category. '
        'Reports shows each day\'s spending against that day\'s allowance and '
        'the month\'s over/under day counts.',
    why:
        'The daily card helps today; Insights shows the pattern. Use it to spot '
        'categories that consume the budget and days that run over.',
    where:
        'Insights tab in the bottom bar. Reports: the file icon in the Insights '
        'app bar, or the Daily & monthly reports card.',
    steps: [
      'Open Insights.',
      'Use the left and right arrows to choose a month. You can review past '
          'months but cannot move beyond the current month.',
      'Read the month summary: income, expense and average daily spend.',
      'Review suggestions and the six-month chart.',
      'Scroll to Expense breakdown to see category shares.',
      'Open Reports for day-by-day spending against allowance, over/under '
          'days and unspent allowance.',
      'Use Patterns & habits, Savings goals or Money assistant from the same '
          'tab for deeper questions.',
    ],
    example:
        'After two weeks, Insights shows Food & dining is 40% of spending. '
        'Reports shows you went over allowance on the days you ordered dinner '
        'out. You plan those days or adjust the budget.',
    mistakes: [
      GuideMistake(
        'A month has no data.',
        'Only recorded transactions appear. Add missing entries with their real '
            'dates, or check that you selected the right month.',
      ),
      GuideMistake(
        'The total is lower than my bank statement.',
        'DailyMoney only knows what you record or confirm. Import a CSV in '
            'Settings > Import & statements, or add the missing entries.',
      ),
      GuideMistake(
        'Income looks too high.',
        'Check for duplicate income and for repayments recorded as normal '
            'income. Shared repayments belong in Shared expenses, where they '
            'are settlements.',
      ),
      GuideMistake(
        'The chart does not include a category.',
        'A category with no expenses this month is absent. Split expenses count '
            'at your share only.',
      ),
    ],
    keywords: [
      'insights',
      'reports',
      'chart',
      'breakdown',
      'monthly',
      'statistics',
      'average',
      'trend',
      'analysis',
    ],
  ),
  GuideChapter(
    id: 'planning',
    number: 9,
    title: 'Budget planning and purchase simulator',
    summary:
        'Money map, goals, bills and simulations that never touch the ledger.',
    icon: LucideIcons.gitBranch,
    what:
        'Planning tools show what is safe to spend and let you test a decision '
        'before making it. Money map splits confirmed balance into bills, '
        'savings commitments, emergency buffer and safe-to-spend. What if '
        'simulates one change; Can I buy it? checks a single purchase. '
        'Simulations never change the ledger.',
    why: 'A purchase can fit today and still break the rest of the month. '
        'Planning tools show the trade-off before money moves.',
    where:
        'Home > money map strip. Or Settings > Planning > What if & purchase '
        'check, and Money map & protection. Goals and Upcoming bills are on '
        'Home.',
    steps: [
      'Open Money map and review Confirmed balance, Upcoming bills, Savings '
          'commitments, Emergency buffer and Safe to spend.',
      'Set or change the monthly budget if needed.',
      'Add a savings goal with a target and optional date. Use Add money on '
          'the goal as you put money aside; this tracks the goal but does not '
          'move money out of your balance or budget.',
      'Add upcoming bills with due dates. Mark paid when paid; this records an '
          'expense and advances a repeating bill.',
      'For a purchase, open Can I buy it?, enter the price and optional name, '
          'and read the verdict and after-purchase figures.',
      'For a scenario, open What if?, choose One-time purchase, Income '
          'delayed, Bill increases or Save every week, enter the amount and '
          'read the result. Nothing is saved to the ledger.',
    ],
    example:
        'A ₹6,000 phone fits today\'s allowance, but Can I buy it? shows the '
        'rest of the month falls short of your bills. You wait two weeks or '
        'turn the amount into a savings goal instead.',
    mistakes: [
      GuideMistake(
        'The simulation changed my balance.',
        'It should not; simulations are read-only. If the balance changed, a '
            'transaction or bill was edited.',
      ),
      GuideMistake(
        'Safe to spend is lower than my bank balance.',
        'Bills, savings commitments and the emergency buffer are held back. '
            'They are planning allocations, not transfers.',
      ),
      GuideMistake(
        'Marking a bill paid did nothing.',
        'It records an expense dated today and, for a repeating bill, moves it '
            'to next month. Check Activity for the new expense.',
      ),
      GuideMistake(
        'A savings goal is not reducing my balance.',
        'Goals reserve planned money; they do not move cash. The balance '
            'changes only when you record a transaction.',
      ),
    ],
    keywords: [
      'money map',
      'what if',
      'simulate',
      'purchase',
      'goals',
      'bills',
      'upcoming',
      'recovery',
      'safe to spend',
      'buffer',
      'emergency',
      'planning',
    ],
  ),
  GuideChapter(
    id: 'notifications',
    number: 10,
    title: 'Notifications and daily summaries',
    summary:
        'Morning and evening briefings, budget alerts and payment prompts.',
    icon: LucideIcons.bell,
    what: 'DailyMoney can send local notifications: a morning greeting with '
        'today\'s allowance, a nightly summary of spending, budget alerts, and '
        'a prompt when a payment-like notification is detected. Everything is '
        'scheduled on the phone; no server is involved.',
    why: 'Briefings keep the daily number visible without opening the app. '
        'Alerts warn when the budget is running low, and payment prompts help '
        'you record spending quickly.',
    where: 'Settings > Notifications. Payment detection: Settings > Payment '
        'detection. Consent: Settings > Help & support > Consent and '
        'permissions.',
    steps: [
      'Open Settings > Notifications.',
      'Turn on Morning greeting and set a time. The briefing shows the daily '
          'allowance.',
      'Turn on Nightly summary and set a time. It shows what you spent today '
          'and what is left.',
      'Turn on Budget alerts. Android asks for notification permission the '
          'first time you enable one of these features; allow it.',
      'Optional: open Settings > Payment detection > Detect payments in '
          'notifications, then grant notification access in Android. Review '
          'each detected payment under Detected payments before accepting it.',
      'If a notification does not arrive, check Android Settings > Apps > '
          'DailyMoney > Notifications and any battery restrictions.',
    ],
    example:
        'At 8:00 the morning greeting says you have ₹750 for today. At 21:30 '
        'the nightly summary says you spent ₹420 and have ₹330 left. When a '
        'save brings the month to 20% of allowance remaining, a budget alert '
        'fires once.',
    mistakes: [
      GuideMistake(
        'No notifications arrive at all.',
        'Android permission may be off. Enable a notification feature in '
            'Settings and allow notifications, then check the system app '
            'settings.',
      ),
      GuideMistake(
        'Budget alerts appear too often, or never.',
        'Alerts fire only on the save that crosses 20% of the daily allowance '
            'left or uses it up. Later expenses in the same state do not '
            'repeat the alert.',
      ),
      GuideMistake(
        'The morning amount is old.',
        'Open the app or change a record. Briefings are rebuilt from the '
            'latest confirmed numbers when the plan changes.',
      ),
      GuideMistake(
        'Payment detection sees nothing.',
        'Notification access is a separate Android permission. Enable it for '
            'DailyMoney in the system settings. Only payment-like '
            'notifications with an amount are kept.',
      ),
    ],
    keywords: [
      'notifications',
      'reminder',
      'morning',
      'night',
      'summary',
      'alerts',
      'permission',
      'detection',
      'briefing',
      'silent',
    ],
  ),
  GuideChapter(
    id: 'settings',
    number: 11,
    title: 'Settings and personalisation',
    summary: 'Currency, theme, sound, app lock, imports and reminders.',
    icon: LucideIcons.settings,
    what: 'Settings holds your name, currency, budget, planning tools, privacy '
        'controls, notifications, appearance, sound, help and data management. '
        'All preferences are local to this device.',
    why: 'Adjust the app to the way you handle money: your currency, a dark '
        'theme, quieter sounds, a lock on the app and the reminders you want.',
    where: 'Settings tab. Sections: Account & preferences, Planning, Privacy & '
        'security, Payment detection, Import & statements, Notifications, '
        'Appearance, Help & support, Sound & haptics, Data management.',
    steps: [
      'Use Account & preferences for your greeting name, currency, monthly '
          'budget and carry-forward setting.',
      'Use Appearance to choose System, Light or Dark. System follows Android.',
      'Use Sound & haptics for sound effects, volume, vibration and previews.',
      'Use Privacy & security for the app-lock PIN, biometrics, auto-lock, '
          'screenshot blocking and permissions.',
      'Use Planning for Money map, Expected income, Shared expenses, Patterns '
          '& habits, Student mode and What if & purchase check.',
      'Use Import & statements to paste a CSV from a bank or UPI app, review '
          'the rows and import the selected ones.',
      'Use Help & support for this guide, legal documents, consent, support, '
          'the intro animation and tour replay.',
      'Use Data management for demo data and deleting all transactions or '
          'upcoming bills.',
    ],
    example:
        'Set your currency once before entering records, switch to Dark for '
        'evening use, enable an app lock and lower the sound volume. Import '
        'last month\'s CSV to fill missing history.',
    mistakes: [
      GuideMistake(
        'Changing currency converted nothing.',
        'Currency is display-only; no exchange rates are applied. Edit amounts '
            'manually if the values are in a different currency.',
      ),
      GuideMistake(
        'The sound preview is silent.',
        'Check that Sound effects is on and that Android media volume is up. '
            'Haptics are separate and depend on the phone.',
      ),
      GuideMistake(
        'I cannot take screenshots.',
        'Open Settings > Privacy & security and turn off Block screenshots. '
            'This guide uses illustrations because that protection is on by '
            'default.',
      ),
      GuideMistake(
        'An imported row is missing.',
        'Rows already recorded with the same date, amount and description are '
            'skipped as duplicates. Check the import summary.',
      ),
    ],
    keywords: [
      'settings',
      'theme',
      'dark',
      'light',
      'currency',
      'sound',
      'haptics',
      'app lock',
      'import',
      'pin',
      'personalise',
      'appearance',
      'csv',
      'student',
    ],
  ),
  GuideChapter(
    id: 'privacy',
    number: 12,
    title: 'Account, privacy and data management',
    summary:
        'Where records live, how backups work and how to erase everything.',
    icon: LucideIcons.shieldCheck,
    what: 'DailyMoney has no user account, no cloud sync and no analytics. '
        'Records are stored in app-private storage, encrypted with AES-256-GCM '
        'using a key held in the Android Keystore when available. The app has '
        'no internet permission. You can export a JSON backup to the '
        'clipboard, restore it, or erase everything.',
    why: 'Your financial records are sensitive. Understanding storage, backups '
        'and deletion lets you use the app with confidence and keep your own '
        'copy of the data.',
    where: 'Settings > Privacy & security > Permissions & data. Backup and '
        'deletion are under Review or erase all data. Legal documents and '
        'support are under Settings > Help & support.',
    steps: [
      'Review Permissions & data for encryption status, local record counts, '
          'app lock and optional notification permissions.',
      'Export a backup from Data controls > Export a backup. The JSON text is '
          'copied to the clipboard; paste it into a private note or file. The '
          'app does not save a file by itself.',
      'Restore by copying a DailyMoney backup to the clipboard, opening Data '
          'controls > Restore from clipboard, reviewing the counts and '
          'confirming. It replaces transactions, bills, goals, expected income '
          'and shared records, and applies the budget, currency and display '
          'preferences saved in the backup. The app-lock PIN, biometrics, '
          'consent choices, notification settings and tutorial progress stay '
          'as they are on this device.',
      'Delete all data from Data controls > Delete everything, tick I '
          'understand and confirm. This erases financial records, preferences, '
          'tutorial progress, consent records, policy acceptance and the '
          'app-lock PIN. It does not erase backups you already copied '
          'elsewhere.',
      'Report a problem from Settings > Help & support > Support & complaints. '
          'Choose a topic, describe what happened, keep technical details on '
          'if you want, then copy the report and send it through your beta '
          'support channel.',
      'Uninstalling removes the app and its private storage. Export a backup '
          'first if you may need the records.',
    ],
    example:
        'Before switching phones, export a backup and paste it into a private '
        'file. Install DailyMoney on the new phone, copy the backup text and '
        'restore. Do not erase the old phone until the restore is confirmed.',
    mistakes: [
      GuideMistake(
        'I thought backups were automatic.',
        'They are manual. Export whenever you have made important changes and '
            'keep the copy private.',
      ),
      GuideMistake(
        'Restore replaced my current records.',
        'Restore is a replacement, not a merge. Export the current ledger '
            'first if you might need it.',
      ),
      GuideMistake(
        'I deleted all data and my backup is gone.',
        'Deleting app data does not erase a copy saved elsewhere. If you never '
            'exported, the records cannot be recovered.',
      ),
      GuideMistake(
        'I cannot find an account to delete.',
        'DailyMoney has no account. Use Delete all data to erase local records.',
      ),
    ],
    keywords: [
      'privacy',
      'data',
      'storage',
      'encrypt',
      'backup',
      'restore',
      'delete',
      'account',
      'offline',
      'internet',
      'support',
      'security',
      'cloud',
      'sync',
    ],
  ),
];

const List<GuideFaq> kGuideFaqs = [
  GuideFaq(
    id: 'allowance-calculation',
    question: 'How is my daily allowance calculated?',
    answer: 'With Carry forward (the default), the base is (monthly budget − '
        'spending recorded outside today − unpaid bills reserved for this '
        'month) ÷ days left in the month, never below zero. With Move to '
        'savings or Keep as buffer, the base is (budget − reserved bills) ÷ '
        'days in the month.\n\nIf Money protection is on and you have a '
        'positive confirmed balance, the allowance is capped at (balance − '
        'bills − savings commitments − emergency buffer) ÷ days left. An '
        'active recovery plan then subtracts its daily cut. Home shows the '
        'result; Money map > Today shows each adjustment.',
    chapterId: 'daily-allowance',
    keywords: [
      'formula',
      'maths',
      'calculation',
      'base',
      'cap',
      'carry forward'
    ],
  ),
  GuideFaq(
    id: 'exceed-budget',
    question: 'What happens when I exceed my budget?',
    answer: 'Nothing is blocked. DailyMoney records the expense and shows the '
        'remaining amount as negative: Over today in red on Home, and the '
        'monthly bar turns red once spending plus reserved bills pass the '
        'budget. Budget alerts fire only on the save that crosses 20% of the '
        'daily allowance left or uses it up.\n\nYou can adjust the budget, '
        'review upcoming bills, or use Money map > Recovery plan to rebuild a '
        'daily target. The ledger is never changed automatically.',
    chapterId: 'daily-allowance',
    keywords: ['over budget', 'overspend', 'red', 'negative', 'limit'],
  ),
  GuideFaq(
    id: 'edit-expense',
    question: 'Can I edit a previous expense?',
    answer:
        'Yes. Open Activity, tap the transaction, change any field and tap Save '
        'changes. The date can be changed within the last five years through '
        'today. Editing recalculates the balance, allowance and reports from '
        'the transaction\'s date.',
    chapterId: 'editing',
    keywords: ['change', 'correct', 'previous', 'past', 'edit'],
  ),
  GuideFaq(
    id: 'delete-transaction',
    question: 'What happens if I delete a transaction?',
    answer:
        'Long-press it in Activity and confirm. It is removed from the ledger, '
        'the balance and reports recalculate, and there is no undo. Deleting a '
        'split expense also removes its linked shared record and any '
        'repayments recorded for it; the confirmation says what will go. '
        'Deleting a repayment reverses the settlement on the shared record.',
    chapterId: 'editing',
    keywords: ['remove', 'undo', 'delete', 'split', 'repayment'],
  ),
  GuideFaq(
    id: 'internet',
    question: 'Does the app require an internet connection?',
    answer: 'No. DailyMoney has no internet permission. The money assistant, '
        'reports and planning tools all run locally. There is no account, '
        'cloud sync or analytics. Backups are copied to the clipboard for you '
        'to store yourself.',
    chapterId: 'privacy',
    keywords: ['offline', 'online', 'wifi', 'network', 'connection'],
  ),
  GuideFaq(
    id: 'storage',
    question: 'Where is my financial data stored?',
    answer: 'Only in app-private storage on this phone. Payloads are encrypted '
        'with AES-256-GCM when the Android Keystore is available; if '
        'encryption is unavailable, Permissions & data says so. There is no '
        'server copy.',
    chapterId: 'privacy',
    keywords: ['encrypted', 'phone', 'device', 'local', 'cloud', 'server'],
  ),
  GuideFaq(
    id: 'report-problem',
    question: 'How can I report a problem?',
    answer:
        'Open Settings > Help & support > Support & complaints. Choose a topic '
        '(Bug report, Incorrect calculation, Privacy complaint, Security '
        'issue, Accessibility issue or Other), describe what happened and the '
        'steps to reproduce it, then Copy report and send it through your beta '
        'support channel. Technical details include the app version and '
        'platform if you leave that switch on.\n\nIf your build has no support '
        'address configured, the screen says so; the copied report still works '
        'through the channel that provided the beta.',
    chapterId: 'privacy',
    keywords: ['bug', 'support', 'contact', 'help', 'complaint', 'feedback'],
  ),
  GuideFaq(
    id: 'delete-data',
    question: 'How can I delete my data?',
    answer:
        'Open Settings > Privacy & security > Permissions & data > Review or '
        'erase all data. Under Delete everything, tick I understand and '
        'confirm. This erases transactions, bills, goals, expected income, '
        'shared records, detected payments, preferences, tutorial progress, '
        'consent records, policy acceptance and the app-lock PIN. There is no '
        'account to delete.\n\n'
        'Export a backup first. Deletion cannot be undone and does not erase '
        'backups you already saved elsewhere. Uninstalling also removes the '
        'app\'s private storage.',
    chapterId: 'privacy',
    keywords: ['erase', 'wipe', 'reset', 'remove all', 'delete everything'],
  ),
  GuideFaq(
    id: 'expected-income',
    question: 'What is the difference between expected and recorded income?',
    answer:
        'Recorded income has actually arrived. It raises the confirmed balance '
        'and income totals. Expected income is a planning reminder and never '
        'enters the balance, allowance or income statistics.\n\nWhen the money '
        'arrives, open Settings > Planning > Expected income, choose Mark '
        'received and confirm. That records an income transaction dated today. '
        'Removing an expected entry later does not touch income already '
        'recorded.',
    chapterId: 'income',
    keywords: ['expected', 'pending', 'salary', 'received', 'promised'],
  ),
  GuideFaq(
    id: 'currency',
    question: 'Why did changing currency not convert my amounts?',
    answer: 'Currency is a display setting only. DailyMoney does not download '
        'exchange rates and does not rewrite past amounts. Changing it changes '
        'the symbol used from then on. If the numbers are in another currency, '
        'edit them manually.',
    chapterId: 'settings',
    keywords: ['exchange', 'conversion', 'symbol', 'rupee', 'dollar', 'euro'],
  ),
  GuideFaq(
    id: 'custom-categories',
    question: 'Can I create my own categories?',
    answer:
        'No. DailyMoney uses fixed income and expense categories, each with its '
        'own icon and colour. Choose the closest category and put the specific '
        'detail in the transaction note. A fixed list keeps the category '
        'breakdown consistent across months.',
    chapterId: 'categories',
    keywords: ['custom', 'new category', 'add category', 'tag'],
  ),
  GuideFaq(
    id: 'budget-alert',
    question: 'Why did I not get a budget alert?',
    answer:
        'Check that Budget alerts is on in Settings > Notifications and that '
        'Android allows DailyMoney notifications. Alerts are not sent for '
        'every expense: one fires only on the save that crosses 20% of the '
        'daily allowance left or uses up today\'s allowance. A later expense '
        'in the same state does not repeat it. Battery restrictions can also '
        'delay notifications.',
    chapterId: 'notifications',
    keywords: ['alert', 'notification', 'permission', 'warning', '80%'],
  ),
  GuideFaq(
    id: 'bill-paid',
    question: 'What does Mark paid do on an upcoming bill?',
    answer:
        'It records the bill as an expense dated today, then removes it from '
        'the upcoming list. If Repeats every month is on, the bill moves to the '
        'same day next month instead of disappearing. The confirmation shows '
        'the amount before anything is recorded.',
    chapterId: 'planning',
    keywords: ['bill', 'paid', 'upcoming', 'recurring', 'rent'],
  ),
  GuideFaq(
    id: 'split-expense',
    question: 'How does splitting an expense work?',
    answer: 'Enter the full amount that left your account, turn on Split with '
        'someone and enter your share. Only your share counts as spending. The '
        'rest becomes a receivable under Shared expenses, not income.\n\nWhen '
        'someone repays you, use Record receipt there. It raises your balance '
        'and reduces what is owed, but it is treated as a settlement, so income '
        'statistics stay accurate.',
    chapterId: 'expenses',
    keywords: ['split', 'share', 'friends', 'owed', 'settlement', 'repayment'],
  ),
  GuideFaq(
    id: 'multiple-devices',
    question: 'Can I use DailyMoney on more than one phone?',
    answer:
        'There is no sync between devices. To move records, export a backup on '
        'the first phone, store the JSON text privately, then restore it on the '
        'second phone. Restore replaces the records on that phone and applies '
        'the budget, currency and display preferences stored in the backup; it '
        'does not merge two ledgers.',
    chapterId: 'privacy',
    keywords: ['sync', 'devices', 'phone', 'tablet', 'transfer', 'backup'],
  ),
  GuideFaq(
    id: 'allowance-zero',
    question: 'Why is my daily allowance zero?',
    answer: 'The month\'s budget may already be used by recorded spending and '
        'reserved bills, or Money protection may have capped the allowance to '
        'the confirmed money left after bills, savings commitments and the '
        'emergency buffer. An active recovery plan can also reduce it to zero. '
        'Open Money map > Today to see the exact adjustment and its reason.',
    chapterId: 'daily-allowance',
    keywords: ['zero', 'no allowance', 'nothing left', 'cap', 'protection'],
  ),
  GuideFaq(
    id: 'backup-security',
    question: 'Are exported backup copies encrypted?',
    answer:
        'No. The app\'s own storage is encrypted, but an exported backup is '
        'readable JSON text. Keep the clipboard copy or saved file private, and '
        'remember that Delete all data does not erase copies you stored '
        'elsewhere.',
    chapterId: 'privacy',
    keywords: ['backup', 'json', 'encrypted', 'plain text', 'clipboard'],
  ),
  GuideFaq(
    id: 'uninstall',
    question: 'What happens if I uninstall the app?',
    answer: 'Uninstalling removes the app and its private storage, including '
        'records and preferences. There is no account or cloud copy to restore '
        'from automatically. Export a backup first if you may install '
        'DailyMoney again or move to another phone.',
    chapterId: 'privacy',
    keywords: ['uninstall', 'remove app', 'reinstall', 'data loss'],
  ),
];

/// Finds a chapter by its stable id.
GuideChapter? guideChapterById(String id) {
  for (final chapter in kGuideChapters) {
    if (chapter.id == id) return chapter;
  }
  return null;
}

/// FAQs that belong to [chapterId], in display order.
List<GuideFaq> guideFaqsForChapter(String chapterId) => [
      for (final faq in kGuideFaqs)
        if (faq.chapterId == chapterId) faq,
    ];

/// Chapters matching every word in [query].
///
/// An empty query returns the full list. Matching is case-insensitive and
/// ignores punctuation, so "internet?" and "daily  allowance" both work.
List<GuideChapter> searchGuideChapters(String query) {
  final terms = _searchTerms(query);
  if (terms.isEmpty) return kGuideChapters;
  return [
    for (final chapter in kGuideChapters)
      if (_matches(chapter.searchText, terms)) chapter,
  ];
}

/// FAQs matching every word in [query], with the same rules as chapters.
List<GuideFaq> searchGuideFaqs(String query) {
  final terms = _searchTerms(query);
  if (terms.isEmpty) return kGuideFaqs;
  return [
    for (final faq in kGuideFaqs)
      if (_matches(faq.searchText, terms)) faq,
  ];
}

List<String> _searchTerms(String query) {
  final normalised = query
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalised.isEmpty) return const [];
  return normalised.split(' ');
}

bool _matches(String text, List<String> terms) {
  final haystack = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  for (final term in terms) {
    if (!haystack.contains(term)) return false;
  }
  return true;
}
