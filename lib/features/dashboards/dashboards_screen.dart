import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell_widgets.dart';
import '../../app/month_picker.dart';
import '../../core/theme/tokens.dart';
import '../../core/money.dart';
import '../../core/month_key.dart';
import '../../core/period.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../domain/categories.dart';
import '../../domain/dashboards.dart';
import '../../domain/models.dart';
import 'day_sheet.dart';

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
      appBar: tabAppBar(title: const SizedBox.shrink()),
      floatingActionButton: const AddFab(),
      body: ListView(
        padding: listClearance(context),
        children: const [
          _WindowCards(),
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
    this.subtitle,
  });

  final String title;
  final String? subtitle;
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
            if (subtitle case final subtitle?)
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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

const _incomeCard = 'income', _leftCard = 'left', _calendarCard = 'calendar';
const _dayWiseCard = 'dayWise', _pieCard = 'pie';

/// A card's month: each card swipes and selects on its own.
String _cardMonth(WidgetRef ref, String card) =>
    ref.watch(cardMonthProvider(card)) ??
    Period.containing(DateTime.now(), ref.watch(salaryDayProvider).value).key;

/// The 6 periods around a card's month, and that month's own totals.
({List<MonthTotal> totals, MonthTotal selected}) _windowOf(
  WidgetRef ref,
  String card,
  Map<String, MonthTotal> byKey,
) {
  final month = _cardMonth(ref, card);
  MonthTotal of(String key) => byKey[key] ?? (key: key, spent: 0, income: 0);
  final current = Period.containing(
    DateTime.now(),
    ref.watch(salaryDayProvider).value,
  ).key;
  return (
    totals: [for (final key in periodWindow(month, current)) of(key)],
    selected: of(month),
  );
}

/// Income vs expenses, income left and the calendar (SPEC 5.17).
class _WindowCards extends ConsumerWidget {
  const _WindowCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryDay = ref.watch(salaryDayProvider).value;
    return ref
        .watch(allTransactionsProvider)
        .when(
          error: (error, _) => Text('Could not load: $error'),
          loading: () => const SizedBox(
            height: _chartHeight,
            child: Center(child: CircularProgressIndicator()),
          ),
          data: (rows) {
            final salaryCategories = {
              for (final c in ref.watch(categoriesProvider).value ?? const [])
                if (c.type == CategoryType.income &&
                    nameTaken([c.name], 'Salary'))
                  c.id,
            };
            final byKey = {
              for (final t in withSalaryIncome(
                monthTotals(
                  rows.map((r) => (r.occurredAt, r.type, r.amountPaise)),
                  salaryDay,
                  DateTime.now(),
                ),
                ref.watch(salaryAmountsProvider).value ?? const {},
                {
                  for (final r in rows)
                    if (r.type == TransactionType.credit &&
                        salaryCategories.contains(r.categoryId))
                      Period.containing(r.occurredAt, salaryDay).key,
                },
              ))
                t.key: t,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IncomeExpensesCard(byKey),
                _IncomeLeftCard(byKey),
                _CalendarCard(rows),
              ],
            );
          },
        );
  }
}

/// A card that swipes only its own month, by [months].
Widget _swipeCard(String card, int months, Widget child) => MonthSwipe(
  months: months,
  picked: cardMonthProvider(card),
  child: Card(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

bool _hasData(List<MonthTotal> totals) =>
    totals.any((t) => t.spent != 0 || t.income != 0);

/// Bars for one window, with the selected period as a pill under the axis.
/// Tapping anywhere in a group selects that period.
class _WindowBars extends ConsumerWidget {
  const _WindowBars({
    required this.card,
    required this.totals,
    required this.groups,
    required this.minY,
    required this.maxY,
    required this.axisLabel,
  });

  final String card;
  final List<MonthTotal> totals;
  final List<BarChartGroupData> groups;
  final double minY;
  final double maxY;
  final String Function(double) axisLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = _cardMonth(ref, card);
    final keys = [for (final t in totals) t.key];
    final span = max(maxY, -minY);
    return SizedBox(
      height: _chartHeight,
      child: BarChart(
        BarChartData(
          minY: minY,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: _titles(
            right: SideTitles(
              showTitles: true,
              reservedSize: _axisWidth,
              // Labels fall on multiples from zero; an end that is not one would
              // get its own label, right beside the nearest multiple.
              interval: span / 2,
              maxIncluded: maxY == span,
              minIncluded: minY == 0 || -minY == span,
              getTitlesWidget: (value, meta) => _AxisText(axisLabel(value)),
            ),
            bottom: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: keys[i] == selected
                        ? context.palette.surfaceRaised
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _AxisText(windowLabel(keys, i)),
                );
              },
            ),
          ),
          barTouchData: BarTouchData(
            handleBuiltInTouches: false,
            allowTouchBarBackDraw: true,
            touchCallback: (event, response) {
              final index = response?.spot?.touchedBarGroupIndex;
              if (event is FlTapUpEvent && index != null) {
                ref.read(cardMonthProvider(card).notifier).state = keys[index];
              }
            },
          ),
          barGroups: groups,
        ),
      ),
    );
  }
}

class _IncomeExpensesCard extends ConsumerWidget {
  const _IncomeExpensesCard(this.byKey);

  final Map<String, MonthTotal> byKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:totals, selected: current) = _windowOf(ref, _incomeCard, byKey);
    final top = max(
      1,
      totals.map((t) => max(t.spent, t.income)).reduce(max),
    ).toDouble();
    BarChartRodData rod(int paise, Color color) => BarChartRodData(
      toY: paise.toDouble(),
      color: color,
      width: 14,
      borderRadius: BorderRadius.circular(6),
      // Lets a tap above a short bar still select its period.
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        toY: top,
        color: Colors.transparent,
      ),
    );
    Widget legend(String label, Color color, int paise) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          _Swatch(color),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Money.format(paise),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return _swipeCard(
      _incomeCard,
      analyticsWindow,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 16,
            children: [
              legend('Income', _incomeColor, current.income),
              legend('Expenses', _spentColor, current.spent),
            ],
          ),
          if (!_hasData(totals))
            const _EmptyChart('No transactions in these months.')
          else
            Semantics(
              label: [
                for (final t in totals)
                  '${MonthKey.label(t.key)}: income '
                      '${Money.format(t.income)}, expenses '
                      '${Money.format(t.spent)}',
              ].join('. '),
              child: _WindowBars(
                card: _incomeCard,
                totals: totals,
                minY: 0,
                maxY: top * 1.05,
                axisLabel: (value) => Money.compact(value.round()),
                groups: [
                  for (final (i, t) in totals.indexed)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 3,
                      barRods: [
                        rod(t.income, _incomeColor),
                        rod(t.spent, _spentColor),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IncomeLeftCard extends ConsumerWidget {
  const _IncomeLeftCard(this.byKey);

  final Map<String, MonthTotal> byKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:totals, selected: current) = _windowOf(ref, _leftCard, byKey);
    final percent = ref.watch(incomeLeftPercentProvider).value ?? false;
    final values = [
      for (final t in totals)
        percent ? incomeLeftPercent(t) : (t.income - t.spent).toDouble(),
    ];
    final known = values.nonNulls;
    // A percentage scale always shows the whole of 100%.
    final top = max<double>(percent ? 100 : 1, known.fold(0, max));
    final bottom = min<double>(0, known.fold(0, min));
    final selected = percent
        ? incomeLeftPercent(current)
        : (current.income - current.spent).toDouble();
    String format(double value) =>
        percent ? '${value.round()}%' : Money.compact(value.round());
    return _swipeCard(
      _leftCard,
      analyticsWindow,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Income left',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        selected == null
                            ? '—'
                            : percent
                            ? format(selected)
                            : Money.format(selected.round()),
                        key: const Key('income-left'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              _AmountPercentToggle(
                percent: percent,
                onChanged: (value) => ref
                    .read(databaseProvider)
                    .setSetting(incomeLeftPercentKey, value ? '1' : null),
              ),
            ],
          ),
          if (!_hasData(totals))
            const _EmptyChart('No transactions in these months.')
          else
            _WindowBars(
              card: _leftCard,
              totals: totals,
              minY: bottom,
              maxY: top,
              axisLabel: format,
              groups: [
                for (final (i, value) in values.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      if (value == null)
                        BarChartRodData(
                          toY: top,
                          width: 30,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: context.palette.textSecondary,
                          ),
                          borderDashArray: const [4, 4],
                        )
                      else
                        BarChartRodData(
                          toY: value,
                          width: 30,
                          color: value < 0 ? AppColors.debit : _incomeColor,
                          borderRadius: BorderRadius.circular(8),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: top,
                            color: Colors.transparent,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AmountPercentToggle extends StatelessWidget {
  const _AmountPercentToggle({required this.percent, required this.onChanged});

  final bool percent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget button(IconData icon, String tooltip, bool value) => IconButton(
      tooltip: tooltip,
      isSelected: percent == value,
      style: IconButton.styleFrom(
        backgroundColor: percent == value ? palette.bg : Colors.transparent,
      ),
      icon: Icon(
        icon,
        size: 20,
        color: percent == value ? palette.textPrimary : palette.textSecondary,
      ),
      onPressed: () => onChanged(value),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadii.round),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.toll_outlined, 'Show amount', false),
          button(Icons.percent, 'Show percent', true),
        ],
      ),
    );
  }
}

class _CalendarCard extends ConsumerWidget {
  const _CalendarCard(this.rows);

  final List<TransactionRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = _cardMonth(ref, _calendarCard);
    final salaryDay = ref.watch(salaryDayProvider).value;
    final period = Period.forMonthKey(month, salaryDay);
    final days = dailySpend(_debits(rows), period.start, period.end);
    final most = days.map((d) => d.paise).fold(0, max);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final caption = Theme.of(context).textTheme.bodySmall;
    return _swipeCard(
      _calendarCard,
      1,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calendar', style: caption),
              Text(
                MonthKey.label(month),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (salaryDay != null) Text(period.rangeLabel, style: caption),
            ],
          ),
          Row(
            children: [
              for (final letter in 'MTWTFSS'.split(''))
                Expanded(
                  child: Text(
                    letter,
                    textAlign: TextAlign.center,
                    style: caption,
                  ),
                ),
            ],
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.8,
            children: [
              // Monday first, as in the reference.
              for (var i = 1; i < days.first.start.weekday; i++)
                const SizedBox.shrink(),
              for (final day in days)
                _DayCell(
                  key: ValueKey(day.start),
                  day,
                  most,
                  day.start == today,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(this.day, this.most, this.today, {super.key});

  final Bucket day;
  final int most;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    void open() => showDaySheet(context, day.start);
    return Semantics(
      label: '${Period.shortDate(day.start)}: ${Money.format(day.paise)}',
      button: true,
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: open,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: day.paise == 0
                ? palette.surfaceRaised
                : AppColors.expense.withValues(
                    alpha: heatLevel(day.paise, most),
                  ),
            borderRadius: BorderRadius.circular(10),
            border: today ? Border.all(color: palette.textPrimary) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                '${day.start.day}',
                style: TextStyle(
                  fontSize: 11,
                  color: day.paise == 0
                      ? palette.textSecondary
                      : palette.textPrimary,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  // shortcut: no rupee sign, it does not fit a seventh of the card.
                  Money.compact(day.paise).replaceFirst('₹', ''),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: day.paise == 0
                        ? palette.textSecondary
                        : palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayWiseCard extends ConsumerWidget {
  const _DayWiseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = _cardMonth(ref, _dayWiseCard);
    return MonthSwipe(
      picked: cardMonthProvider(_dayWiseCard),
      child: _ChartCard(
        title: 'Day-wise spend',
        subtitle: MonthKey.label(month),
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
      ),
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
    final month = _cardMonth(ref, _pieCard);
    return MonthSwipe(
      picked: cardMonthProvider(_pieCard),
      child: _ChartCard(
        title: 'Budget',
        subtitle: MonthKey.label(month),
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
              if (!c.isArchived)
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
      ),
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
