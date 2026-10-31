import '../providers/expected_income_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shared_provider.dart';
import '../providers/upcoming_provider.dart';
import '../utils/format.dart';
import 'daily_budget.dart';

/// Ready-to-schedule notification copy.
class Briefing {
  const Briefing({required this.title, required this.body});

  final String title;
  final String body;
}

/// Builds the morning and evening briefings from confirmed numbers.
///
/// Expected income is mentioned only with an explicit "expected" label and is
/// never added to the allowance. Shared money is described as owed, not owned.
class Briefings {
  const Briefings._();

  static Briefing morning({
    required SettingsProvider settings,
    required DailyBudgetSnapshot snapshot,
    required UpcomingProvider upcoming,
    required ExpectedIncomeProvider expected,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final currency = settings.currencyCode;
    final name = settings.userName.trim();
    final title = name.isEmpty ? 'Good morning!' : 'Good morning, $name!';

    if (!snapshot.hasBudget) {
      final parts = <String>[
        'Set a monthly budget to unlock your daily spending allowance.',
      ];
      final arriving = _arrivingToday(expected, today);
      if (arriving > 0) {
        parts.add('${fmtMoney(arriving, currency)} is expected today, '
            'but it is not counted until it arrives.');
      }
      return Briefing(title: title, body: parts.join(' '));
    }

    final parts = <String>[];
    if (snapshot.remainingToday < 0) {
      parts.add('You are ${fmtMoney(-snapshot.remainingToday, currency)} over '
          "today's allowance.");
    } else {
      parts.add(
        'You can spend ${fmtMoney(snapshot.remainingToday, currency)} today.',
      );
    }

    if (snapshot.protectionApplied) {
      parts.add('Bills, savings and your buffer are protected.');
    } else if (snapshot.recoveryApplied) {
      final day = settings.recoveryDayNumber(today);
      parts.add('Recovery plan day ${day < 1 ? 1 : day} is active.');
    }

    final dueToday = _billsDueToday(upcoming, today);
    if (dueToday.total > 0) {
      parts.add(
        '${fmtMoney(dueToday.total, currency)} due today'
        '${dueToday.firstTitle.isEmpty ? '' : ' · ${dueToday.firstTitle}'}.',
      );
    }

    final arriving = _arrivingToday(expected, today);
    if (arriving > 0) {
      parts
          .add('${fmtMoney(arriving, currency)} expected today (not counted).');
    }

    parts.add('${fmtMonthLeft(snapshot.monthlyLeft, currency)}.');
    return Briefing(title: title, body: parts.join(' '));
  }

  static Briefing night({
    required SettingsProvider settings,
    required DailyBudgetSnapshot snapshot,
    required UpcomingProvider upcoming,
    required SharedProvider shared,
    required ExpectedIncomeProvider expected,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final currency = settings.currencyCode;
    final name = settings.userName.trim();
    final title =
        name.isEmpty ? "Tonight's spending summary" : 'Good night, $name';

    if (!snapshot.hasBudget) {
      return Briefing(
        title: title,
        body: 'You spent ${fmtMoney(snapshot.spentToday, currency)} today. '
            'Set a budget to track a daily allowance.',
      );
    }

    final parts = <String>[
      'You spent ${fmtMoney(snapshot.spentToday, currency)} today.',
    ];
    if (snapshot.spentToday <= 0) {
      parts.add('No spending recorded — that is a no-spend day.');
    }
    if (snapshot.remainingToday < 0) {
      parts.add('You are ${fmtMoney(-snapshot.remainingToday, currency)} over '
          "today's allowance. Tomorrow is a fresh start.");
    } else if (snapshot.remainingToday < 0.005) {
      parts.add("Today's allowance is fully used. Tomorrow is a fresh start.");
    } else {
      parts.add('${fmtMoney(snapshot.remainingToday, currency)} of today\'s '
          'allowance is left.');
    }

    final nextBill = _nextBill(upcoming, today, currency);
    if (nextBill.isNotEmpty) parts.add(nextBill);

    final owed = shared.owedToMe;
    if (owed > 0.005) {
      parts.add('${fmtMoney(owed, currency)} is still owed to you.');
    }

    final next = expected.nextPending;
    if (next != null) {
      final label = _dateLabel(next.expectedDate, today);
      parts.add('${fmtMoney(next.amount, currency)} expected $label '
          '(not counted yet).');
    }

    return Briefing(title: title, body: parts.join(' '));
  }

  static double _arrivingToday(ExpectedIncomeProvider expected, DateTime day) {
    var total = 0.0;
    for (final item in expected.pending) {
      if (item.expectedDate.year == day.year &&
          item.expectedDate.month == day.month &&
          item.expectedDate.day == day.day) {
        total += item.amount;
      }
    }
    return total;
  }

  static ({double total, String firstTitle}) _billsDueToday(
    UpcomingProvider upcoming,
    DateTime day,
  ) {
    var total = 0.0;
    var first = '';
    for (final item in upcoming.all) {
      if (item.dueDate.year == day.year &&
          item.dueDate.month == day.month &&
          item.dueDate.day == day.day) {
        total += item.amount;
        if (first.isEmpty) first = item.title;
      }
    }
    return (total: total, firstTitle: first);
  }

  /// The next tracked bill within three days, or an empty string.
  static String _nextBill(
    UpcomingProvider upcoming,
    DateTime now,
    String currency,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    for (final item in upcoming.all) {
      final due = DateTime(
        item.dueDate.year,
        item.dueDate.month,
        item.dueDate.day,
      );
      final diff = due.difference(today).inDays;
      if (diff < 0 || diff > 3) continue;
      final when = diff == 0
          ? 'today'
          : diff == 1
              ? 'tomorrow'
              : 'in $diff days';
      return 'Next bill: ${item.title} '
          '${fmtMoney(item.amount, currency)} $when.';
    }
    return '';
  }

  static String _dateLabel(DateTime date, DateTime today) {
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    if (diff > 1) return 'in $diff days';
    return 'since ${dayLabel(date)}';
  }
}
