import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/category.dart';
import '../models/upcoming_expense.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'transaction_tile.dart';

/// A bill row shared by Home and the Upcoming screen.
class UpcomingTile extends StatelessWidget {
  const UpcomingTile({
    super.key,
    required this.item,
    required this.currencyCode,
    this.onTap,
    this.onMarkPaid,
  });

  final UpcomingExpense item;
  final String currencyCode;
  final VoidCallback? onTap;
  final VoidCallback? onMarkPaid;

  static Color dueColor(BuildContext context, DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    if (diff < 0) return AppColors.expense;
    if (diff <= 1) return AppColors.warn;
    return Theme.of(context).colorScheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cat = categoryById(item.categoryId);
    final color = dueColor(context, item.dueDate);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          child: Row(
            children: [
              CategoryBadge(category: cat, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.repeatMonthly) ...[
                          Icon(
                            LucideIcons.repeat,
                            size: 11,
                            color: scheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Monthly · ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            dueLabel(item.dueDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onMarkPaid != null)
                IconButton(
                  onPressed: onMarkPaid,
                  tooltip: 'Mark paid',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    LucideIcons.circleCheck,
                    size: 21,
                    color: AppColors.income,
                  ),
                ),
              const SizedBox(width: 2),
              Text(
                fmtMoney(item.amount, currencyCode),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
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
