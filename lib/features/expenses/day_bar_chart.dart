import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/period.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../domain/dashboards.dart';
import '../../domain/models.dart';

/// The Activity header's faint bars, one per day of the period (SPEC 5.12).
class DayBarChart extends StatelessWidget {
  const DayBarChart({super.key, required this.rows, required this.period});

  final List<TransactionRow> rows;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final days = dailySpend(
      rows
          .where((r) => r.type == TransactionType.debit)
          .map((r) => (r.occurredAt, r.amountPaise)),
      period.start,
      period.end,
    );
    final peak = days.fold(0, (a, d) => d.paise > a ? d.paise : a);
    final maxY = peak == 0 ? 1.0 : peak.toDouble();
    final caption = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceBetween,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  interval: maxY,
                  getTitlesWidget: (value, meta) => Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      value == 0 || peak == 0 ? '0' : Money.compact(peak),
                      style: caption,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  // Bar charts ask for every bar's title and ignore `interval`.
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt() % 7 == 0
                        ? '${days[value.toInt()].start.day}'
                        : '',
                    style: caption,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (final (i, day) in days.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: day.paise.toDouble(),
                      width: 6,
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          context.palette.textPrimary.withValues(alpha: 0.15),
                          context.palette.textPrimary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: context.palette.textPrimary.withValues(
                          alpha: 0.05,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
