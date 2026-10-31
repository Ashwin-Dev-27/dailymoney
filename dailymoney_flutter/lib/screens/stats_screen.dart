import 'dart:math' as math show max;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/upcoming_provider.dart';
import '../services/suggestions.dart';
import '../theme.dart';
import '../widgets/daily_money_footer.dart';

import '../utils/format.dart';
import '../widgets/month_chart.dart';
import '../widgets/category_pie.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';
import 'assistant_screen.dart';
import 'goals_screen.dart';
import 'patterns_screen.dart';
import 'reports_screen.dart';

/// Insight page: money trend over recent months and category breakdown.
class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    this.categoriesAnchor,
    this.insightsAnchor,
  });

  /// Optional targets used by the guided tour.
  final GlobalKey? categoriesAnchor;
  final GlobalKey? insightsAnchor;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = monthOf(DateTime.now());
  }

  void _shift(int delta) => setState(() => _month = monthAdd(_month, delta));

  bool get _atCurrentMonth => sameMonth(_month, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final txs = context.watch<TransactionsProvider>();
    final upcoming = context.watch<UpcomingProvider>();
    final goals = context.watch<GoalsProvider>();

    final totals = txs.totalsFor(_month);
    final byCategory = txs.expenseByCategory(_month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final daysElapsed =
        _atCurrentMonth ? math.max(1, DateTime.now().day) : daysInMonth;
    final avgDaily = totals.expense / daysElapsed;
    final suggestions = _atCurrentMonth && txs.count > 0
        ? SuggestionEngine.build(
            settings: settings,
            txs: txs,
            upcoming: upcoming,
            goals: goals,
          )
        : const <Suggestion>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('Insights', style: TextStyle(color: scheme.onSurface)),
        actions: [
          IconButton(
            tooltip: 'Money assistant',
            onPressed: () => _openAssistant(context),
            icon: const Icon(LucideIcons.sparkles, size: 20),
          ),
          IconButton(
            tooltip: 'Daily and monthly reports',
            onPressed: () => _openReports(context),
            icon: const Icon(LucideIcons.fileText, size: 20),
          ),
        ],
      ),
      body: txs.count == 0
          ? const Padding(
              padding: EdgeInsets.only(top: 80, left: 16, right: 16),
              child: emptyTransactions,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              children: [
                // Month switcher
                Row(
                  children: [
                    _roundBtn(
                        context, LucideIcons.chevronLeft, () => _shift(-1)),
                    Expanded(
                      child: Center(
                        child: Text(
                          monthLabel(_month),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    _roundBtn(
                      context,
                      LucideIcons.chevronRight,
                      _atCurrentMonth ? null : () => _shift(1),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (suggestions.isNotEmpty) ...[
                  _SuggestionsCard(suggestions: suggestions),
                  const SizedBox(height: 12),
                ],
                KeyedSubtree(
                  key: widget.insightsAnchor,
                  child: _MonthSummary(
                    income: totals.income,
                    expense: totals.expense,
                    avgDaily: avgDaily,
                    currencyCode: settings.currencyCode,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openReports(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              LucideIcons.fileText,
                              size: 17,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily & monthly reports',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  "Every day's spend against your allowance",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight,
                              size: 18, color: scheme.outline),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(LucideIcons.target, size: 20),
                        title: const Text('Savings goals'),
                        subtitle: Text(
                          goals.isEmpty
                              ? 'Set a target and track progress'
                              : '${fmtMoney(goals.totalSaved, settings.currencyCode)} '
                                  'saved · ${goals.count} '
                                  'goal${goals.count == 1 ? '' : 's'}',
                        ),
                        trailing: Icon(LucideIcons.chevronRight,
                            size: 18, color: scheme.outline),
                        onTap: () => _openGoals(context),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      ListTile(
                        leading: const Icon(LucideIcons.scanSearch, size: 20),
                        title: const Text('Patterns & habits'),
                        subtitle: const Text(
                          'Repeated charges and how you spend, with evidence',
                        ),
                        trailing: Icon(LucideIcons.chevronRight,
                            size: 18, color: scheme.outline),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PatternsScreen(),
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      ListTile(
                        leading: const Icon(LucideIcons.sparkles, size: 20),
                        title: const Text('Money assistant'),
                        subtitle: const Text(
                          'Ask about your allowance, bills and goals',
                        ),
                        trailing: Icon(LucideIcons.chevronRight,
                            size: 18, color: scheme.outline),
                        onTap: () => _openAssistant(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last 6 months',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        MonthChart(
                          data: txs.monthlySeries(months: 6, ending: _month),
                          currencyCode: settings.currencyCode,
                        ),
                        const SizedBox(height: 8),
                        const _Legend(
                          colors: [AppColors.income, AppColors.expense],
                          labels: ['Income', 'Expense'],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  key: widget.categoriesAnchor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (byCategory.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: EmptyState(
                              icon: LucideIcons.pieChart,
                              title: 'Nothing spent yet',
                              message:
                                  'Expenses you record in ${monthLabel(_month)} will appear here.',
                            ),
                          )
                        else ...[
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CategoryPie(
                                amountsByCategory: byCategory,
                                currencyCode: settings.currencyCode,
                              ),
                              CategoryPie.centeredTotal(
                                'Total spent',
                                totals.expense,
                                settings.currencyCode,
                                textColor: scheme.onSurface,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._legendRows(context, byCategory),
                        ],
                      ],
                    ),
                  ),
                ),
                const DailyMoneyFooter(),
              ],
            ),
    );
  }

  List<Widget> _legendRows(
      BuildContext context, Map<String, double> byCategory) {
    final total = byCategory.values.fold(0.0, (a, b) => a + b);
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (final e in byCategory.entries.take(6)) {
      final cat = categoryById(e.key);
      final pct = total > 0 ? e.value / total * 100 : 0.0;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            CategoryBadge(category: cat, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              '${pct.round()}%',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.outline,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              fmtMoney(e.value, context.read<SettingsProvider>().currencyCode),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ));
    }
    return rows;
  }

  void _openReports(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsScreen(initialMonth: _month),
      ),
    );
  }

  void _openGoals(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  void _openAssistant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AssistantScreen()),
    );
  }

  Widget _roundBtn(BuildContext context, IconData icon, VoidCallback? onTap) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: scheme.outlineVariant.withValues(alpha: 0.25),
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.suggestions});

  final List<Suggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 17, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For you',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  'Personalised',
                  style: TextStyle(fontSize: 10.5, color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < suggestions.length; i++) ...[
              _SuggestionRow(suggestion: suggestions[i]),
              if (i < suggestions.length - 1)
                Divider(
                  height: 18,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion});

  final Suggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (suggestion.tone) {
      SuggestionTone.warning => AppColors.warn,
      SuggestionTone.positive => AppColors.income,
      SuggestionTone.neutral => scheme.primary,
    };
    final icon = switch (suggestion.icon) {
      SuggestionIcon.budget => LucideIcons.circleDollarSign,
      SuggestionIcon.warning => LucideIcons.triangleAlert,
      SuggestionIcon.category => LucideIcons.pieChart,
      SuggestionIcon.calendar => LucideIcons.calendarClock,
      SuggestionIcon.goal => LucideIcons.target,
      SuggestionIcon.trend => LucideIcons.trendingUp,
      SuggestionIcon.recurring => LucideIcons.repeat,
      SuggestionIcon.sparkles => LucideIcons.sparkles,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                suggestion.body,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.outline,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.income,
    required this.expense,
    required this.avgDaily,
    required this.currencyCode,
  });

  final double income;
  final double expense;
  final double avgDaily;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String caption, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        cell('Income', fmtMoney(income, currencyCode), AppColors.income),
        const SizedBox(width: 10),
        cell('Expense', fmtMoney(expense, currencyCode), AppColors.expense),
        const SizedBox(width: 10),
        cell('Avg/day', fmtMoney(avgDaily, currencyCode),
            const Color(0xFF6366F1)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors, required this.labels});

  final List<Color> colors;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, l) in labels.indexed) ...[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            l,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.outline,
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 18),
        ],
      ],
    );
  }
}
