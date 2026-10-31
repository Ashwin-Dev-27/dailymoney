import 'package:flutter/material.dart';

import '../models/tx.dart';
import '../models/category.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Row for a transaction: colored category badge, title, date and amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.settings,
    this.onTap,
    this.onLongPress,
  });

  final Tx tx;
  final SettingsProvider settings;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cat = categoryById(tx.categoryId);
    final isIncome = tx.type.isIncome;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          child: Row(
            children: [
              CategoryBadge(category: cat, size: 44),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.isSharedExpense
                          ? '${cat.label} · share '
                              '${currencyByCode(settings.currencyCode).symbol}'
                              '${fmtAmountInput(tx.personalExpense)}'
                          : tx.note.isEmpty
                              ? '${cat.label} · ${dayLabel(tx.date)}'
                              : '${cat.label} · ${tx.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtSigned(tx.amount, settings.currencyCode,
                    isExpense: !isIncome),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colored circle with the category icon (also used in sheets & legends).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 42,
  });

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        category.icon,
        size: size * 0.46,
        color: category.color,
      ),
    );
  }
}
