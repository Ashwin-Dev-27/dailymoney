import '../models/category.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/money_plan.dart';
import '../services/suggestions.dart';
import '../utils/format.dart';

class AssistantReply {
  const AssistantReply(this.text, {this.followUps = const []});

  final String text;
  final List<String> followUps;
}

/// A local, rule-based financial assistant.
///
/// Answers are computed from the user's own ledger. Nothing is sent anywhere
/// and the app works with no connection.
class AssistantService {
  const AssistantService._();

  static const List<String> starters = [
    'How much can I spend today?',
    'Where is my money going?',
    'Am I on track this month?',
    'What bills are coming up?',
    'How are my savings goals doing?',
    'How can I save more?',
  ];

  static AssistantReply answer(
    String question, {
    required SettingsProvider settings,
    required TransactionsProvider txs,
    required UpcomingProvider upcoming,
    required GoalsProvider goals,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final q = question.toLowerCase().trim();
    final currency = settings.currencyCode;
    final month = DateTime(today.year, today.month);
    final totals = txs.totalsFor(month);
    final snapshot = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
      today: today,
    );

    bool has(List<String> words) => words.any(q.contains);

    if (q.isEmpty) {
      return AssistantReply(
        _snapshotLine(settings, txs, upcoming, goals, today),
        followUps: starters.take(3).toList(),
      );
    }

    if (has(['hello', 'hi ', 'hey']) && q.length <= 24) {
      final name = settings.userName.trim();
      return AssistantReply(
        name.isEmpty
            ? 'Hello! I can explain your allowance, spending, bills and goals '
                'from the data already on this phone.'
            : 'Hello, $name! Ask me about your allowance, spending, bills or '
                'goals — everything is calculated locally.',
        followUps: starters.take(3).toList(),
      );
    }

    if (has(['what can you do', 'help', 'how do you work'])) {
      return const AssistantReply(
        'I work entirely from your own records. You can ask things like:\n'
        '• How much can I spend today?\n'
        '• Am I on track this month?\n'
        '• Where is my money going?\n'
        '• What bills are due?\n'
        '• How are my savings goals doing?\n'
        '• How can I save more?',
        followUps: [
          'How much can I spend today?',
          'Am I on track this month?',
          'How can I save more?',
        ],
      );
    }

    // "Why am I over budget?" deserves an explanation, not just a number.
    if (has(['why']) && has(['over', 'budget', 'spent too much'])) {
      final over = snapshot.monthlyLeft < 0
          ? -snapshot.monthlyLeft
          : -mathMin(snapshot.remainingToday, 0);
      final byCategory = txs.expenseByCategory(month);
      final top = byCategory.isEmpty ? null : byCategory.entries.first;
      final categoryLine = top == null
          ? ''
          : '\nYour biggest category is ${categoryById(top.key).label} at '
              '${fmtMoney(top.value, currency)}.';
      return AssistantReply(
        over <= 0
            ? 'You are not over budget. ${fmtMonthLeft(snapshot.monthlyLeft, currency)}.'
            : 'You are ${fmtMoney(over, currency)} over. '
                '${snapshot.hasBudget ? 'The monthly plan is ${fmtMoney(snapshot.budget, currency)} and ${fmtMoney(snapshot.monthExpense, currency)} is spent' : 'No monthly budget is set yet'}'
                '${snapshot.reservedUpcoming > 0 ? ', with ${fmtMoney(snapshot.reservedUpcoming, currency)} set aside for bills' : ''}.'
                '$categoryLine\n\n'
                'The quickest fix is usually the largest category: cap it for '
                'the remaining ${snapshot.daysLeft} days.',
        followUps: [
          'Where is my money going?',
          'What bills are coming up?',
          'How can I save more?',
        ],
      );
    }

    if (has(['today', 'spend today', 'allowance', 'left to spend'])) {
      if (!snapshot.hasBudget) {
        return AssistantReply(
          'You have spent ${fmtMoney(snapshot.spentToday, currency)} today, but '
          'no monthly budget is set, so I cannot calculate an allowance yet. '
          'Add one in Settings to unlock it.',
          followUps: const [
            'Am I on track this month?',
            'Where is my money going?',
          ],
        );
      }
      if (snapshot.remainingToday < 0) {
        return AssistantReply(
          'Today is ${fmtMoney(-snapshot.remainingToday, currency)} over the '
          'allowance. You have spent ${fmtMoney(snapshot.spentToday, currency)} '
          'against ${fmtMoney(snapshot.allowance, currency)}. '
          '${fmtMonthLeft(snapshot.monthlyLeft, currency)}.',
          followUps: const [
            'Why am I over budget?',
            'How can I save more?',
          ],
        );
      }
      return AssistantReply(
        'You can spend ${fmtMoney(snapshot.remainingToday, currency)} more '
        'today. The allowance is ${fmtMoney(snapshot.allowance, currency)} and '
        '${fmtMoney(snapshot.spentToday, currency)} is already spent. '
        '${snapshot.daysLeft} day${snapshot.daysLeft == 1 ? '' : 's'} left this '
        'month.',
        followUps: const [
          'Am I on track this month?',
          'What bills are coming up?',
        ],
      );
    }

    if (has(['balance'])) {
      return AssistantReply(
        'Your all-time balance is ${fmtMoney(txs.balance, currency)}. '
        'This month you have received ${fmtMoney(totals.income, currency)} and '
        'spent ${fmtMoney(totals.expense, currency)}.',
        followUps: const [
          'Where is my money going?',
          'Am I on track this month?',
        ],
      );
    }

    if (has(['income', 'earned', 'salary', 'received'])) {
      return AssistantReply(
        'Income this month is ${fmtMoney(totals.income, currency)}. '
        '${totals.income > 0 ? 'Your expenses are ${fmtMoney(totals.expense, currency)}, so you kept ${fmtMoney(totals.income - totals.expense, currency)}.' : 'No income is recorded for this month yet.'}',
        followUps: const [
          'Am I on track this month?',
          'How can I save more?',
        ],
      );
    }

    if (has(['save', 'saving', 'goal'])) {
      if (goals.isEmpty) {
        final spare = snapshot.monthlyLeft > 0 ? snapshot.monthlyLeft : 0.0;
        return AssistantReply(
          'You have no savings goals yet. '
          '${spare > 0 ? 'There is ${fmtMoney(spare, currency)} uncommitted in this month\'s budget — even a small automatic amount helps.' : 'Once a budget is set, unused allowance is a natural place to start.'}\n\n'
          'Open Home → Savings goals to create one with a target date; I will '
          'work out the monthly amount needed.',
          followUps: const [
            'Am I on track this month?',
            'What bills are coming up?',
          ],
        );
      }
      final lines = <String>[];
      for (final goal in goals.all.take(3)) {
        final pct = (goal.progress * 100).round();
        final monthly = goal.monthlyNeeded(today);
        lines.add(
          '• ${goal.title}: ${fmtMoney(goal.saved, currency)} of '
          '${fmtMoney(goal.target, currency)} ($pct%)'
          '${goal.isComplete ? ' — complete!' : ', ${fmtMoney(goal.remaining, currency)} to go${goal.targetDate != null ? ' · about ${fmtMoney(monthly, currency)}/month' : ''}'}',
        );
      }
      return AssistantReply(
        'You have ${fmtMoney(goals.totalSaved, currency)} saved across '
        '${goals.count} goal${goals.count == 1 ? '' : 's'}:\n${lines.join('\n')}',
        followUps: const [
          'How can I save more?',
          'What bills are coming up?',
        ],
      );
    }

    if (has(['bill', 'upcoming', 'due', 'rent', 'subscription'])) {
      final bills = upcoming.all.take(4).toList();
      if (bills.isEmpty) {
        return const AssistantReply(
          'No upcoming bills are tracked. Add rent, utilities or subscriptions '
          'from Home → Upcoming bills so they are set aside before you spend.',
          followUps: [
            'How much can I spend today?',
            'How can I save more?',
          ],
        );
      }
      final lines = bills
          .map((b) => '• ${b.title} — ${fmtMoney(b.amount, currency)} '
              '(${dueLabel(b.dueDate)})')
          .join('\n');
      return AssistantReply(
        '${upcoming.count} upcoming item${upcoming.count == 1 ? '' : 's'}, '
        'with ${fmtMoney(upcoming.reservedForMonth(month), currency)} set aside '
        'from this month:\n$lines',
        followUps: const [
          'How much can I spend today?',
          'Am I on track this month?',
        ],
      );
    }

    if (has(['where', 'category', 'categories', 'most', 'top', 'going'])) {
      final byCategory = txs.expenseByCategory(month);
      if (byCategory.isEmpty) {
        return const AssistantReply(
          'No expenses are recorded this month yet, so there is no category '
          'breakdown to show.',
          followUps: [
            'How much can I spend today?',
            'What bills are coming up?',
          ],
        );
      }
      final total = byCategory.values.fold(0.0, (a, b) => a + b);
      final lines = byCategory.entries.take(4).map((e) {
        final pct = total <= 0 ? 0 : (e.value / total * 100).round();
        return '• ${categoryById(e.key).label} — '
            '${fmtMoney(e.value, currency)} ($pct%)';
      }).join('\n');
      return AssistantReply(
        'This month you have spent ${fmtMoney(total, currency)}:\n$lines',
        followUps: const [
          'Am I on track this month?',
          'How can I save more?',
        ],
      );
    }

    if (has(['tip', 'advice', 'suggest', 'better', 'improve'])) {
      final tips = SuggestionEngine.build(
        settings: settings,
        txs: txs,
        upcoming: upcoming,
        goals: goals,
        now: today,
      );
      if (tips.isEmpty) {
        return const AssistantReply(
          'Nothing stands out yet. Record a few more expenses and I will '
          'surface patterns worth acting on.',
          followUps: starters,
        );
      }
      final lines =
          tips.take(3).map((t) => '• ${t.title}: ${t.body}').join('\n\n');
      return AssistantReply(
        'Based on your last few weeks:\n\n$lines',
        followUps: const [
          'How much can I spend today?',
          'How are my savings goals doing?',
        ],
      );
    }

    if (has(['spent'])) {
      return AssistantReply(
        'You have spent ${fmtMoney(snapshot.spentToday, currency)} today and '
        '${fmtMoney(totals.expense, currency)} this month. '
        '${snapshot.hasBudget ? fmtMonthLeft(snapshot.monthlyLeft, currency) : 'Set a budget to see how that compares with a plan.'}',
        followUps: const [
          'Where is my money going?',
          'How much can I spend today?',
        ],
      );
    }

    if (has(['track', 'on track', 'doing', 'month', 'budget', 'plan'])) {
      if (!snapshot.hasBudget) {
        return AssistantReply(
          'No monthly budget is set, so there is no plan to compare against. '
          'You have spent ${fmtMoney(totals.expense, currency)} this month. '
          'Set a budget in Settings and I can track the pace for you.',
          followUps: const [
            'How much can I spend today?',
            'Where is my money going?',
          ],
        );
      }
      final pct = snapshot.budget <= 0
          ? 0
          : (snapshot.monthExpense / snapshot.budget * 100).round();
      return AssistantReply(
        '${fmtMoney(snapshot.monthExpense, currency)} of '
        '${fmtMoney(snapshot.budget, currency)} used ($pct%). '
        '${fmtMonthLeft(snapshot.monthlyLeft, currency)}'
        '${snapshot.reservedUpcoming > 0 ? ', after setting aside ${fmtMoney(snapshot.reservedUpcoming, currency)} for bills' : ''}.\n\n'
        'Today\'s allowance is ${fmtMoney(snapshot.allowance, currency)} with '
        '${fmtMoney(snapshot.spentToday, currency)} spent so far.',
        followUps: const [
          'How much can I spend today?',
          'Where is my money going?',
        ],
      );
    }

    return AssistantReply(
      '${_snapshotLine(settings, txs, upcoming, goals, today)}\n\n'
      'Try asking about today\'s allowance, this month\'s budget, bills, '
      'categories, savings goals or tips.',
      followUps: starters.take(3).toList(),
    );
  }

  static String _snapshotLine(
    SettingsProvider settings,
    TransactionsProvider txs,
    UpcomingProvider upcoming,
    GoalsProvider goals,
    DateTime today,
  ) {
    final currency = settings.currencyCode;
    final month = DateTime(today.year, today.month);
    final totals = txs.totalsFor(month);
    final snapshot = MoneyPlan.snapshotFor(
      settings: settings,
      txs: txs,
      upcoming: upcoming,
      goals: goals,
      today: today,
    );
    final buffer = StringBuffer(
      'This month: ${fmtMoney(totals.expense, currency)} spent',
    );
    if (snapshot.hasBudget) {
      buffer.write(' of ${fmtMoney(snapshot.budget, currency)}'
          '${snapshot.monthlyLeft < 0 ? ' (over by ${fmtMoney(-snapshot.monthlyLeft, currency)})' : ' (${fmtMoney(snapshot.monthlyLeft, currency)} left)'}');
    }
    buffer.write('. Today: ${fmtMoney(snapshot.spentToday, currency)} spent');
    if (snapshot.hasBudget) {
      buffer.write(
        snapshot.remainingToday < 0
            ? ', ${fmtMoney(-snapshot.remainingToday, currency)} over the allowance'
            : ', ${fmtMoney(snapshot.remainingToday, currency)} left',
      );
    }
    buffer.write('.');
    if (goals.count > 0) {
      buffer.write(
        ' Saved for goals: ${fmtMoney(goals.totalSaved, currency)}.',
      );
    }
    return buffer.toString();
  }

  static double mathMin(double a, double b) => a < b ? a : b;
}
