import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/tx.dart';
import '../providers/settings_provider.dart';
import '../services/missing_expense.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/plan_widgets.dart';
import 'add_edit_sheet.dart';

/// Asks whether a quiet day is real, without inventing a transaction.
class MissingExpenseSheet extends StatelessWidget {
  const MissingExpenseSheet({super.key, required this.check});

  final MissingExpenseCheck check;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final currency = settings.currencyCode;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.warn.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.receiptText,
                    size: 19,
                    color: AppColors.warn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Anything missing?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              check.message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    PlanRow(
                      label: 'Today so far',
                      value: fmtMoney(check.todayExpense, currency),
                    ),
                    PlanRow(
                      label: 'Yesterday',
                      value: fmtMoney(check.yesterdayExpense, currency),
                    ),
                    PlanRow(
                      label: 'Your usual spending day',
                      value: fmtMoney(check.typicalDaily, currency),
                      note: 'Based on ${check.activeDays} active days in the '
                          'last three weeks',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const PlanNote(
              icon: LucideIcons.info,
              text: 'This is only a question. Nothing is added or estimated '
                  'until you record a real payment.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Record a cash expense'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                context
                    .read<SettingsProvider>()
                    .dismissMissingExpense(DateTime.now());
                Navigator.pop(context);
              },
              icon: const Icon(LucideIcons.check, size: 17),
              label: const Text('Nothing missing today'),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ask me later'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddEditSheet(
        prefillType: TxType.expense,
        prefillCategoryId: 'other',
      ),
    );
    if (context.mounted) Navigator.pop(context);
  }
}
