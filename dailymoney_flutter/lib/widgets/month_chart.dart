import 'dart:math' as math show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

typedef MonthPoint = ({DateTime month, double income, double expense});

/// Grouped income/expense bars across the recent months.
class MonthChart extends StatelessWidget {
  const MonthChart({
    super.key,
    required this.data,
    required this.currencyCode,
    this.height = 210,
  });

  final List<MonthPoint> data;
  final String currencyCode;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grid = scheme.outlineVariant.withValues(alpha: 0.45);
    final maxIncome = data.map((p) => p.income).fold(0.0, math.max);
    final maxExpense = data.map((p) => p.expense).fold(0.0, math.max);
    final maxY = math.max(maxIncome, maxExpense) * 1.18;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 100 : maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1E293B),
              tooltipMargin: 8,
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                fmtMoney(rod.toY, currencyCode),
                TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.brightness == Brightness.dark
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: bottomLeftCompact,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      shortMonthLabel(data[i].month),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.outline,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: grid, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          groupsSpace: 6,
          barGroups: [
            for (final (i, p) in data.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: p.income,
                    color: AppColors.income,
                    width: 12,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: p.expense,
                    color: AppColors.expense.withValues(alpha: 0.85),
                    width: 12,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget bottomLeftCompact(double v, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(
        fmtCompact(v),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
