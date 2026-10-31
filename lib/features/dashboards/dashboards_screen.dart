import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_widgets.dart';
import '../../core/theme/tokens.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../core/period.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/dashboards.dart';
import '../../domain/models.dart';
import '../budgets/month_summary_card.dart';

const _spentColor = AppColors.expense;
const _incomeColor = AppColors.income;

const _chartHeight = 200.0;
const _axisWidth = 44.0;

Iterable<(DateTime, int)> _debits(List<TransactionRow> rows) => rows
    .where((r) => r.type == TransactionType.debit)
    .map((r) => (r.occurredAt, r.amountPaise));

/// A solid line at zero, so the dashed average is not mistaken for it.
FlBorderData _baseline(BuildContext context) => FlBorderData(
  border: Border(
    bottom: BorderSide(color: Theme.of(context).colorScheme.onSurfaceVariant),
  ),
);

SideTitles _amountAxis() => SideTitles(
  showTitles: true,
  reservedSize: _axisWidth,
  maxIncluded: false,
  getTitlesWidget: (value, meta) => _AxisText(Money.compact(value.round())),
);

SideTitles _bottomAxis(String Function(int index) label, {double? interval}) =>
    SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: interval,
      maxIncluded: false, // the last date label would hang off the edge
      getTitlesWidget: (value, meta) => _AxisText(label(value.toInt())),
    );

FlTitlesData _titles({
  SideTitles? left,
  SideTitles? right,
  required SideTitles bottom,
}) => FlTitlesData(
  topTitles: const AxisTitles(),
  leftTitles: AxisTitles(sideTitles: left ?? const SideTitles()),
  rightTitles: AxisTitles(sideTitles: right ?? const SideTitles()),
  bottomTitles: AxisTitles(sideTitles: bottom),
);

class DashboardsScreen extends ConsumerWidget {
  const DashboardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: tabAppBar(),
      floatingActionButton: const AddFab(),
      body: ListView(
        padding: listClearance(context),
        children: const [
          _MonthWiseCard(),
          _DayWiseCard(),
          _DateRangeCard(),
          _BudgetPieCard(),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.rows,
    required this.child,
  });

  final String title;
  final AsyncValue<List<TransactionRow>> rows;
  final Widget Function(List<TransactionRow> rows) child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            rows.when(
              data: child,
              error: (error, _) => Text('Could not load: $error'),
              loading: () => const SizedBox(
                height: _chartHeight,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Text(message, textAlign: TextAlign.center),
  );
}

class _AxisText extends StatelessWidget {
  const _AxisText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _MonthWiseCard extends ConsumerStatefulWidget {
  const _MonthWiseCard();

  @override
  ConsumerState<_MonthWiseCard> createState() => _MonthWiseCardState();
}

class _MonthWiseCardState extends ConsumerState<_MonthWiseCard> {
  String? _tapped;

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Expenses vs income',
      rows: ref.watch(allTransactionsProvider),
      child: _chart,
    );
  }

  Widget _chart(List<TransactionRow> rows) {
    final salaryDay = ref.watch(salaryDayProvider).value;
    final now = DateTime.now();
    final totals = monthTotals(
      rows.map((r) => (r.occurredAt, r.type, r.amountPaise)),
      salaryDay,
      now,
    );
    if (rows.isEmpty) return const _EmptyChart('No transactions yet.');

    final selectedKey = _tapped ?? Period.containing(now, salaryDay).key;
    final selected = totals.firstWhere(
      (t) => t.key == selectedKey,
      orElse: () => totals.last,
    );
    final top = totals.map((t) => max(t.spent, t.income)).reduce(max) * 1.1;

    BarChartRodData rod(int paise, Color color) => BarChartRodData(
      toY: paise.toDouble(),
      color: color,
      width: 8,
      borderRadius: BorderRadius.zero,
      // Lets a tap anywhere above a short bar still select its month.
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        toY: top,
        color: Colors.transparent,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 4,
          children: [
            _Swatch(_spentColor),
            const Text('Spent'),
            const SizedBox(width: 8),
            _Swatch(_incomeColor),
            const Text('Income'),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final slot = (constraints.maxWidth - _axisWidth) / 12;
            return SizedBox(
              height: _chartHeight,
              // Newest at the right; earlier months scroll in from the left.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: SizedBox(
                  width: slot * totals.length + _axisWidth,
                  child: Semantics(
                    label: [
                      for (final t in totals.reversed)
                        '${MonthKey.label(t.key)}: spent '
                            '${Money.format(t.spent)}, income '
                            '${Money.format(t.income)}',
                    ].join('. '),
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: top,
                        alignment: BarChartAlignment.spaceAround,
                        borderData: _baseline(context),
                        gridData: const FlGridData(drawVerticalLine: false),
                        titlesData: _titles(
                          right: _amountAxis(),
                          bottom: _bottomAxis((i) {
                            final key = totals[i].key;
                            final name = MonthKey.label(key).substring(0, 3);
                            return key.endsWith('-01')
                                ? '$name\n${key.substring(0, 4)}'
                                : name;
                          }),
                        ),
                        barTouchData: BarTouchData(
                          handleBuiltInTouches: false,
                          allowTouchBarBackDraw: true,
                          touchCallback: (event, response) {
                            final index = response?.spot?.touchedBarGroupIndex;
                            if (event is FlTapUpEvent && index != null) {
                              setState(() => _tapped = totals[index].key);
                            }
                          },
                        ),
                        barGroups: [
                          for (final (i, t) in totals.indexed)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 2,
                              barRods: [
                                rod(t.spent, _spentColor),
                                rod(t.income, _incomeColor),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Text(
          '${MonthKey.label(selected.key)}: spent '
          '${Money.format(selected.spent)}, income '
          '${Money.format(selected.income)}',
        ),
      ],
    );
  }
}

class _DayWiseCard extends ConsumerWidget {
  const _DayWiseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return _ChartCard(
      title: 'Day-wise spend',
      rows: ref.watch(transactionsProvider(month)),
      child: (rows) {
        final period = Period.forMonthKey(
          month,
          ref.watch(salaryDayProvider).value,
        );
        final days = dailySpend(_debits(rows), period.start, period.end);
        final total = sumPaise(days.map((d) => d.paise));
        if (total == 0) {
          return _EmptyChart('No spending in ${MonthKey.label(month)}.');
        }
        final average = dailyAverage(days, DateTime.now());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text('Average ${Money.format(average)} a day'),
            SizedBox(
              height: _chartHeight,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: days.map((d) => d.paise).reduce(max) * 1.1,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: _baseline(context),
                  gridData: const FlGridData(drawVerticalLine: false),
                  titlesData: _titles(
                    left: _amountAxis(),
                    bottom: _bottomAxis(
                      (i) => i % 5 == 0 ? '${days[i].start.day}' : '',
                    ),
                  ),
                  // The built-in tooltip would show raw paise.
                  barTouchData: BarTouchData(enabled: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: average.toDouble(),
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 1.5,
                        dashArray: const [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.only(bottom: 2),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          labelResolver: (_) => 'avg',
                        ),
                      ),
                    ],
                  ),
                  barGroups: [
                    for (final (i, day) in days.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: day.paise.toDouble(),
                            color: _spentColor,
                            width: 5,
                            borderRadius: BorderRadius.zero,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DateRangeCard extends ConsumerStatefulWidget {
  const _DateRangeCard();

  @override
  ConsumerState<_DateRangeCard> createState() => _DateRangeCardState();
}

class _DateRangeCardState extends ConsumerState<_DateRangeCard> {
  DateTimeRange? _picked;

  static String _label(DateTime date) =>
      '${Period.shortDate(date)} ${date.year}';

  Future<void> _pick(DateTimeRange current, DateTime today) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDateRange: current,
    );
    if (picked != null) setState(() => _picked = picked);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range =
        _picked ??
        DateTimeRange(
          start: DateTime(today.year, today.month, today.day - 29),
          end: today,
        );
    return _ChartCard(
      title: 'Date range',
      rows: ref.watch(allTransactionsProvider),
      child: (rows) {
        final days = dailySpend(
          _debits(rows),
          range.start,
          DateTime(range.end.year, range.end.month, range.end.day + 1),
        );
        final total = sumPaise(days.map((d) => d.paise));
        final weekly = days.length > maxDailyRange;
        final points = weekly ? weeklySpend(days) : days;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text('${_label(range.start)} – ${_label(range.end)}'),
              onPressed: () => _pick(range, today),
            ),
            if (total == 0)
              const _EmptyChart('No spending in these dates.')
            else ...[
              Text(
                'Total ${Money.format(total)}, average '
                '${Money.format(dailyAverage(days, now))} a day'
                '${weekly ? '. Shown by week.' : ''}',
              ),
              SizedBox(
                height: _chartHeight,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    // A one-day range still needs a non-zero width.
                    maxX: max(1, points.length - 1).toDouble(),
                    minY: 0,
                    maxY: points.map((p) => p.paise).reduce(max) * 1.1,
                    borderData: _baseline(context),
                    gridData: const FlGridData(drawVerticalLine: false),
                    // The built-in tooltip would show raw paise.
                    lineTouchData: const LineTouchData(enabled: false),
                    titlesData: _titles(
                      left: _amountAxis(),
                      bottom: _bottomAxis(
                        (i) => Period.shortDate(points[i].start),
                        interval: max(1, (points.length / 4).ceil()).toDouble(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (final (i, point) in points.indexed)
                            FlSpot(i.toDouble(), point.paise.toDouble()),
                        ],
                        color: _spentColor,
                        barWidth: 2,
                        dotData: FlDotData(show: points.length == 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BudgetPieCard extends ConsumerWidget {
  const _BudgetPieCard();

  static const _radius = 110.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return _ChartCard(
      title: 'Budget',
      rows: ref.watch(transactionsProvider(month)),
      child: (rows) {
        final categories = ref.watch(categoriesProvider).value ?? const [];
        final budgets = ref.watch(budgetAmountsProvider).value ?? const {};
        final salary = resolveAmount(
          ref.watch(salaryAmountsProvider).value ?? const {},
          month,
        );
        final spend = spendOf(rows);
        final limits = {
          for (final c in categories)
            c.id: ?resolveAmount(budgets[c.id] ?? const {}, month),
        };
        final pie = budgetPie(limits, spend, salary);
        final byId = {for (final c in categories) c.id: c};
        final over = pie.overSalaryBy > 0;
        final ring = pie.salaryRing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (over)
              Text(
                'Over salary by ${Money.format(pie.overSalaryBy)}',
                style: const TextStyle(color: Colors.red),
              ),
            if (pie.isEmpty)
              const _EmptyChart(
                'Set a salary or category limits to see this chart.',
              )
            else ...[
              SizedBox(
                height: _radius * 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 0,
                        sectionsSpace: 0,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: [
                          for (final slice in pie.slices)
                            ..._sections(slice, byId[slice.categoryId]),
                        ],
                      ),
                    ),
                    if (ring != null)
                      IgnorePointer(
                        child: Container(
                          key: const Key('salary-ring'),
                          width: _radius * 2 * ring,
                          height: _radius * 2 * ring,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (over && salary != null)
                Text(
                  'The outer edge is total spend, '
                  '${Money.format(sumPaise(spend.values))}. '
                  'The thin ring is the salary, ${Money.format(salary)}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            for (final slice in pie.slices)
              _LegendRow.slice(slice, byId[slice.categoryId]),
            for (final c in categories)
              if (!limits.containsKey(c.id) && (spend[c.id] ?? 0) > 0)
                _LegendRow(
                  Color(c.color),
                  c.name,
                  'No limit · Spent ${Money.format(spend[c.id]!)}',
                ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> _sections(PieSlice slice, Category? category) {
    final color = category == null ? Colors.grey : Color(category.color);
    PieChartSectionData section(
      int paise,
      Color color, {
      BorderSide border = BorderSide.none,
    }) => PieChartSectionData(
      value: paise.toDouble(),
      color: color,
      radius: _radius,
      showTitle: false,
      borderSide: border,
    );
    return [
      if (slice.dark > 0)
        section(
          slice.dark,
          color,
          border: slice.over
              ? const BorderSide(color: Colors.red, width: 2)
              : BorderSide.none,
        ),
      if (slice.light > 0) section(slice.light, color.withValues(alpha: 0.3)),
    ];
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.color, this.name, this.detail, {this.over = false});

  factory _LegendRow.slice(PieSlice slice, Category? category) =>
      switch (slice.kind) {
        SliceKind.unallocated => _LegendRow(
          Colors.grey.withValues(alpha: 0.3),
          'Unallocated',
          Money.format(slice.size),
        ),
        SliceKind.uncategorised => _LegendRow(
          Colors.grey,
          'Uncategorised',
          'Spent ${Money.format(slice.spent)}',
        ),
        SliceKind.category => _LegendRow(
          category == null ? Colors.grey : Color(category.color),
          category?.name ?? '',
          'Limit ${Money.format(slice.size)} · '
          'Spent ${Money.format(slice.spent)} · '
          'Remaining ${Money.format(slice.size - slice.spent)}',
          over: slice.over,
        ),
      };

  final Color color;
  final String name;
  final String detail;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Row(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: _Swatch(color)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              Text(
                detail,
                style: over ? small?.copyWith(color: Colors.red) : small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
