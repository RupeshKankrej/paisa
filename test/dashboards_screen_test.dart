import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/dashboards/dashboards_screen.dart';

const food = 1, travel = 2;

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final month = MonthKey.of(now);
  final start = MonthKey.start(month);
  final today = DateTime(now.year, now.month, now.day);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> add(
    int paise, {
    int? category,
    TransactionType type = TransactionType.debit,
    DateTime? at,
  }) => db.addTransaction(
    TransactionsCompanion.insert(
      type: type,
      amountPaise: paise,
      occurredAt: at ?? start,
      source: TransactionSource.manual,
      categoryId: Value(category),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  // Tall, so all four cards are built without scrolling.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 9000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DashboardsScreen()),
      ),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('empty states show messages, never an empty axis', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No transactions yet.'), findsOneWidget);
    expect(
      find.text('No spending in ${MonthKey.label(month)}.'),
      findsOneWidget,
    );
    expect(find.text('No spending in these dates.'), findsOneWidget);
    expect(
      find.text('Set a salary or category limits to see this chart.'),
      findsOneWidget,
    );
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('month-wise bars match seeded totals, and tapping shows them', (
    tester,
  ) async {
    final last = MonthKey.start(MonthKey.shift(month, -1));
    await add(30000, category: food);
    await add(5000000, type: TransactionType.credit);
    await add(70000, at: last);
    await add(9000000, type: TransactionType.credit, at: last);
    await pump(tester);

    final chart = tester.widget<BarChart>(find.byType(BarChart).first);
    final groups = chart.data.barGroups;
    expect(groups.length, 12);
    expect(groups.last.barRods.map((r) => r.toY), [30000, 5000000]);
    expect(groups[10].barRods.map((r) => r.toY), [70000, 9000000]);
    expect(
      groups.expand((g) => g.barRods).map((r) => r.backDrawRodData.color),
      everyElement(Colors.transparent),
      reason: 'only the red and green bars show',
    );
    expect(
      find.text('${MonthKey.label(month)}: spent ₹300.00, income ₹50,000.00'),
      findsOneWidget,
    );

    // Second group from the right; the axis takes the last 44 points.
    final box = tester.getRect(find.byType(BarChart).first);
    final slot = (box.width - 44) / 12;
    await tester.tapAt(Offset(box.right - 44 - slot * 1.5, box.center.dy));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${MonthKey.label(MonthKey.shift(month, -1))}: '
        'spent ₹700.00, income ₹90,000.00',
      ),
      findsOneWidget,
    );
  });

  testWidgets('more than 12 months scroll, opening on the newest', (
    tester,
  ) async {
    await add(100, at: MonthKey.start(MonthKey.shift(month, -30)));
    await pump(tester);
    final chart = tester.widget<BarChart>(find.byType(BarChart).first);
    expect(chart.data.barGroups.length, 31);
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(scroll.reverse, isTrue);
  });

  testWidgets('day-wise has every day and a dashed average line', (
    tester,
  ) async {
    await add(40000, category: food, at: start);
    await add(5000, type: TransactionType.credit, at: start);
    await pump(tester);

    final chart = tester.widget<BarChart>(find.byType(BarChart).last);
    final length = DateTime(start.year, start.month + 1, 0).day;
    expect(chart.data.barGroups.length, length);
    expect(chart.data.barGroups.first.barRods.single.toY, 40000);
    expect(chart.data.barGroups.last.barRods.single.toY, 0);

    final line = chart.data.extraLinesData.horizontalLines.single;
    expect(line.dashArray, isNotNull);
    expect(line.label.show, isTrue);
    expect(
      chart.data.borderData.border.bottom.width,
      greaterThan(0),
      reason: 'a solid line marks zero',
    );
    expect(line.y, (40000 / now.day).round());
  });

  testWidgets('date range defaults to 30 days with a total and average', (
    tester,
  ) async {
    await add(30000, at: today);
    await add(60000, at: today.subtract(const Duration(days: 29)));
    await add(99900, at: today.subtract(const Duration(days: 30)));
    await pump(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.length, 30);
    expect(find.text('Total ₹900.00, average ₹30.00 a day'), findsOneWidget);
  });

  testWidgets('a range over 90 days is drawn by week', (tester) async {
    await add(30000, at: today);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.date_range));
    await tester.pumpAndSettle();
    final picker = tester.widget<DateRangePickerDialog>(
      find.byType(DateRangePickerDialog),
    );
    expect(picker.lastDate, today);
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
      DateTimeRange(
        start: today.subtract(const Duration(days: 90)),
        end: today,
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.length, 13); // 91 days
    expect(find.textContaining('Shown by week.'), findsOneWidget);
  });

  testWidgets('budget pie: light and dark parts, unallocated, grey, legend', (
    tester,
  ) async {
    await db.setSalary(null, 1000000);
    await db.setBudget(food, null, 200000);
    await db.setBudget(travel, null, 100000);
    await add(50000, category: food);
    await add(150000, category: travel);
    await add(10000);
    await pump(tester);

    final sections = tester
        .widget<PieChart>(find.byType(PieChart))
        .data
        .sections;
    expect(sections.map((s) => s.value), [
      50000, // food, spent
      150000, // food, left
      100000, // travel, full, spend past the limit is not drawn
      700000, // unallocated
      10000, // uncategorised
    ]);
    expect(sections[2].borderSide.color, Colors.red);
    expect(sections[0].borderSide.width, 0);
    expect(sections[1].color.a, lessThan(sections[0].color.a));

    expect(find.text('Unallocated'), findsOneWidget);
    expect(find.text('₹7,000.00'), findsOneWidget);
    expect(
      find.text('Limit ₹1,000.00 · Spent ₹1,500.00 · Remaining -₹500.00'),
      findsOneWidget,
    );
    expect(find.textContaining('Over salary'), findsNothing);
    expect(find.byKey(const Key('salary-ring')), findsNothing);
  });

  testWidgets('budget pie: spend above salary changes header and adds a ring', (
    tester,
  ) async {
    await db.setSalary(null, 100000);
    await db.setBudget(food, null, 50000);
    await add(300000, category: food);
    await add(100000, category: travel); // no limit, still counted
    await pump(tester);

    expect(find.text('Over salary by ₹3,000.00'), findsOneWidget);
    expect(find.textContaining('total spend, ₹4,000.00'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('salary-ring'))).width,
      110.0, // 220 x sqrt(1,000 / 4,000)
    );
    expect(find.textContaining('No limit · Spent ₹1,000.00'), findsOneWidget);
  });

  testWidgets('day-wise and pie follow the month boundary toggle', (
    tester,
  ) async {
    await db.setSalary(null, 100000);
    await add(10000, category: food, at: DateTime(2026, 10, 27));
    await add(20000, category: food, at: DateTime(2026, 10, 28));
    await db.setSalaryDay(28);
    late WidgetRef widgetRef;
    tester.view.physicalSize = const Size(1179, 9000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const DashboardsScreen();
            },
          ),
        ),
      ),
    );
    await settle(tester);
    widgetRef.read(pickedMonthProvider.notifier).state = '2026-11';
    await settle(tester);

    final chart = tester.widget<BarChart>(find.byType(BarChart).last);
    expect(chart.data.barGroups.length, 31, reason: '28 Oct to 27 Nov');
    expect(chart.data.barGroups.first.barRods.single.toY, 20000);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a swipe on the day-wise card changes month', (tester) async {
    await add(5000);
    await pump(tester);
    final card = find.text('Day-wise spend');
    await tester.drag(card, const Offset(100, 0));
    await settle(tester);
    expect(
      find.text('No spending in ${MonthKey.label(MonthKey.shift(month, -1))}.'),
      findsOneWidget,
    );
  });
}
