import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/format.dart';

/// Donut of expense distribution by category with an in-center total.
class CategoryPie extends StatelessWidget {
  const CategoryPie({
    super.key,
    required this.amountsByCategory,
    required this.currencyCode,
    this.height = 210,
  });

  final Map<String, double> amountsByCategory;
  final String currencyCode;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = amountsByCategory.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No expenses in this month'),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    for (final entry in amountsByCategory.entries) {
      final pct = entry.value / total * 100;
      final cat = categoryById(entry.key);
      sections.add(PieChartSectionData(
        value: entry.value,
        color: cat.color,
        radius: sections.isEmpty ? 56 : 48,
        showTitle: pct >= 4,
        title: pct >= 4 ? '${pct.round()}%' : '',
        titleStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ));
    }

    return SizedBox(
      height: height,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 48,
          sectionsSpace: 2,
          startDegreeOffset: -90,
          sections: sections,
        ),
      ),
    );
  }

  /// Center overlay text — position with a Stack inside the host screen.
  static Widget centeredTotal(String label, double amount, String currencyCode,
      {required Color textColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 2),
        Text(
          fmtMoney(amount, currencyCode),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
