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

const food = 2, travel = 5;

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
    expect(find.text('No transactions in these months.'), findsNWidgets(2));
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

  testWidgets('the window has 6 periods, and tapping a bar selects one', (
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
    expect(groups.length, 6);
    expect(groups.last.barRods.map((r) => r.toY), [5000000, 30000]);
    expect(groups[4].barRods.map((r) => r.toY), [9000000, 70000]);
    expect(find.text('₹50,000.00'), findsWidgets);

    // Second group from the right; the axis takes the last 44 points.
    final box = tester.getRect(find.byType(BarChart).first);
    final slot = (box.width - 44) / 6;
    await tester.tapAt(Offset(box.right - 44 - slot * 1.5, box.center.dy));
    await settle(tester);
    expect(find.text('₹90,000.00'), findsWidgets);
    expect(find.text('₹700.00'), findsWidgets);
  });

  group('a tap selects its month', () {
    Future<Rect> chart(WidgetTester tester) async {
      final last = MonthKey.start(MonthKey.shift(month, -1));
      await add(30000);
      await add(5000000, type: TransactionType.credit);
      await add(70000, at: last);
      await add(9000000, type: TransactionType.credit, at: last);
      await pump(tester);
      return tester.getRect(find.byType(BarChart).first);
    }

    testWidgets('on the month label', (tester) async {
      final box = await chart(tester);
      final slot = (box.width - 44) / 6;
      await tester.tapAt(Offset(box.right - 44 - slot * 1.5, box.bottom - 12));
      await settle(tester);
      expect(find.text('₹90,000.00'), findsWidgets);
    });

    testWidgets('in the gap beside the bars', (tester) async {
      final box = await chart(tester);
      final slot = (box.width - 44) / 6;
      await tester.tapAt(Offset(box.right - 44 - slot * 1.95, box.center.dy));
      await settle(tester);
      expect(find.text('₹90,000.00'), findsWidgets);
    });

    testWidgets('but not on the amount axis', (tester) async {
      final box = await chart(tester);
      await tester.tapAt(Offset(box.right - 10, box.center.dy));
      await settle(tester);
      expect(find.text('₹50,000.00'), findsWidgets);
    });
  });

  testWidgets('each card swipes and selects on its own', (tester) async {
    final older = MonthKey.shift(month, -6);
    await add(123400, at: MonthKey.start(older));
    await add(5000);
    await pump(tester);
    Text left() => tester.widget<Text>(find.byKey(const Key('income-left')));
    expect(find.text(MonthKey.label(month)), findsNWidgets(3));
    expect(left().data, '-₹50.00');

    await tester.drag(find.byType(BarChart).first, const Offset(100, 0));
    await settle(tester);
    expect(find.text('₹1,234.00'), findsOneWidget, reason: 'its legend moved');
    expect(left().data, '-₹50.00', reason: 'income left did not');
    expect(find.text(MonthKey.label(month)), findsNWidgets(3));

    await tester.drag(find.byType(BarChart).at(1), const Offset(100, 0));
    await settle(tester);
    expect(left().data, '-₹1,234.00');

    await tester.drag(find.text('Calendar'), const Offset(100, 0));
    await settle(tester);
    expect(
      find.text(MonthKey.label(MonthKey.shift(month, -1))),
      findsOneWidget,
      reason: 'the calendar moved one month, day-wise and pie stayed',
    );
    expect(find.text(MonthKey.label(month)), findsNWidgets(2));

    await tester.drag(find.text('Calendar'), const Offset(-100, 0));
    await settle(tester);
    await tester.drag(find.text('Calendar'), const Offset(-100, 0));
    await settle(tester);
    expect(
      find.text(MonthKey.label(month)),
      findsNWidgets(3),
      reason: 'no further than the current period',
    );
  });

  testWidgets('a tapped bar changes only its own card', (tester) async {
    final last = MonthKey.start(MonthKey.shift(month, -1));
    await add(70000, at: last);
    await add(5000);
    await pump(tester);
    Text left() => tester.widget<Text>(find.byKey(const Key('income-left')));

    final box = tester.getRect(find.byType(BarChart).first);
    final slot = (box.width - 44) / 6;
    await tester.tapAt(Offset(box.right - 44 - slot * 1.5, box.center.dy));
    await settle(tester);
    expect(find.text('₹700.00'), findsOneWidget, reason: 'its legend');
    expect(left().data, '-₹50.00');
  });

  group('the day sheet', () {
    Future<void> openDay(WidgetTester tester) async {
      await tester.tap(find.byKey(ValueKey(DateTime(start.year, start.month))));
      await settle(tester);
    }

    Text total(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('day-total')));

    Future<void> seed() async {
      await db.addTransaction(
        TransactionsCompanion.insert(
          type: TransactionType.debit,
          amountPaise: 9000,
          occurredAt: start.add(const Duration(hours: 9)),
          source: TransactionSource.manual,
          counterparty: const Value('Lunch'),
          categoryId: const Value(food),
        ),
      );
      await add(100000, at: start.add(const Duration(hours: 10)));
      await add(5000, type: TransactionType.credit);
      await add(7700, at: start.add(const Duration(days: 1)));
    }

    testWidgets('lists only that day\'s expenses with their total', (
      tester,
    ) async {
      await seed();
      await pump(tester);
      await openDay(tester);
      expect(total(tester).data, '-₹1,090.00');
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('₹77.00'), findsNothing);
      expect(find.text('+₹50.00'), findsNothing);

      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.text('Total amount'), findsNothing);
    });

    testWidgets('a tap edits, and the edit shows at once', (tester) async {
      await seed();
      await pump(tester);
      await openDay(tester);
      await tester.tap(find.text('Lunch'));
      await settle(tester);
      expect(find.byKey(const Key('sheet-amount')), findsOneWidget);
      await tester.tap(find.byTooltip('Backspace'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('key-save')));
      await settle(tester);
      expect(find.byKey(const Key('sheet-amount')), findsNothing);
      expect(total(tester).data, '-₹1,009.00');
    });

    testWidgets('a swipe deletes, and Undo restores it', (tester) async {
      await seed();
      await pump(tester);
      await openDay(tester);
      await tester.drag(find.text('Lunch'), const Offset(-600, 0));
      await settle(tester);
      expect(find.text('Lunch'), findsNothing);
      expect(total(tester).data, '-₹1,000.00');

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Lunch'), findsOneWidget);
      expect(total(tester).data, '-₹1,090.00');
    });

    testWidgets('a day with no expenses says so', (tester) async {
      await pump(tester);
      await openDay(tester);
      expect(find.text('No expenses on this day'), findsOneWidget);
    });
  });

  testWidgets('salary counts as income, once, with other credits', (
    tester,
  ) async {
    await db.setSalary(null, 10000000); // 1,00,000
    await add(500000, type: TransactionType.credit); // 5,000, a refund
    await add(2000000); // 20,000 spent
    final last = MonthKey.start(MonthKey.shift(month, -1));
    final salary = (await tester.runAsync(() => db.watchCategories().first))!
        .firstWhere((c) => c.name == 'Salary');
    await add(
      9000000,
      category: salary.id,
      type: TransactionType.credit,
      at: last,
    );
    await pump(tester);
    expect(
      find.text('₹1,05,000.00'),
      findsOneWidget,
      reason: 'salary + refund',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('income-left'))).data,
      '₹85,000.00',
    );
    final groups = tester
        .widget<BarChart>(find.byType(BarChart).first)
        .data
        .barGroups;
    expect(groups.last.barRods.first.toY, 10500000);
    expect(
      groups[4].barRods.first.toY,
      9000000,
      reason: 'the tagged credit alone',
    );
  });

  testWidgets('income left: the toggle persists, zero income is dashed', (
    tester,
  ) async {
    await add(2500000, type: TransactionType.credit);
    await add(500000);
    await add(100, at: MonthKey.start(MonthKey.shift(month, -1)));
    await pump(tester);
    Text header() => tester.widget<Text>(find.byKey(const Key('income-left')));
    expect(header().data, '₹20,000.00');
    BarChart left() => tester.widget<BarChart>(find.byType(BarChart).at(1));
    expect(left().data.barGroups[4].barRods.single.toY, -100);

    await tester.tap(find.byTooltip('Show percent'));
    await settle(tester);
    expect(header().data, '80%');
    expect(left().data.barGroups.last.barRods.single.toY, 80);
    final none = left().data.barGroups[4].barRods.single;
    expect(none.borderDashArray, isNotNull);
    expect(none.color, Colors.transparent);
    expect(
      await tester.runAsync(() => db.watchSetting(incomeLeftPercentKey).first),
      isNotNull,
    );
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
    widgetRef.read(cardMonthProvider('dayWise').notifier).state = '2026-11';
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
