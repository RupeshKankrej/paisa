import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/app/month_picker.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/core/period.dart';
import 'package:paisa/core/theme/tokens.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/budgets/budget_screen.dart';
import 'package:paisa/features/budgets/categories_screen.dart';
import 'package:paisa/features/expenses/expenses_screen.dart';
import 'package:paisa/features/settings/settings_screen.dart';
import 'package:paisa/main.dart';

const food = 2, travel = 5;

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final month = MonthKey.of(now);
  final start = MonthKey.start(month);

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
    String title = 'Row',
  }) => db.addTransaction(
    TransactionsCompanion.insert(
      type: type,
      amountPaise: paise,
      occurredAt: at ?? start.add(const Duration(hours: 9)),
      counterparty: Value(title),
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

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: screen),
      ),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  // runAsync: a drift stream's first event needs real time inside testWidgets.
  Future<T> first<T>(WidgetTester tester, Stream<T> stream) async =>
      (await tester.runAsync(() => stream.first)) as T;

  Finder inTile(String title, String text) => find.descendant(
    of: find.widgetWithText(ListTile, title),
    matching: find.text(text),
  );

  LinearProgressIndicator barOf(WidgetTester tester, String title) =>
      tester.widget(
        find.descendant(
          of: find.widgetWithText(ListTile, title),
          matching: find.byType(LinearProgressIndicator),
        ),
      );

  // Worked by hand: debits 1,200.50 + 300.25 + 99.25 = 1,600.00. The credit and
  // last month's debit are left out. 10,000.00 - 1,600.00 = 8,400.00.
  Future<void> seedMonth() async {
    await db.setSalary(null, 1000000);
    await add(120050, category: food);
    await add(30025, category: travel);
    await add(9925);
    await add(5000000, type: TransactionType.credit, title: 'Pay');
    await add(777700, at: start.subtract(const Duration(days: 1)));
  }

  double? ringValue(WidgetTester tester) => tester
      .widget<CircularProgressIndicator>(
        find.byKey(const Key('salary-left-ring')),
      )
      .value;

  testWidgets('Budget totals match a hand-computed month', (tester) async {
    await seedMonth();
    await pump(tester, const BudgetScreen());
    expect(find.text('₹8,400.00'), findsOneWidget);
    expect(find.text('of ₹10,000.00'), findsOneWidget);
    expect(ringValue(tester), 0.84);
    expect(find.textContaining('Over salary'), findsNothing);
    // The uncategorised debit and the uncategorised credit.
    expect(find.text('2 uncategorised'), findsOneWidget);
  });

  testWidgets('spending past the salary turns remaining red and marks it', (
    tester,
  ) async {
    await db.setSalary(null, 10000);
    await add(15000, category: food);
    await pump(tester, const BudgetScreen());
    final remaining = tester.widget<Text>(find.text('-₹50.00'));
    expect(remaining.style?.color, AppColors.debit);
    expect(find.text('Over salary by ₹50.00'), findsOneWidget);
    expect(ringValue(tester), 0);
  });

  testWidgets('no salary shows a prompt, not a false negative remaining', (
    tester,
  ) async {
    await add(15000, category: food);
    await pump(tester, const BudgetScreen());
    expect(find.text('Set salary'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(ringValue(tester), 0);
  });

  testWidgets('a salary override applies to that month, blank restores it', (
    tester,
  ) async {
    await db.setSalary(null, 1000000);
    await pump(tester, const BudgetScreen());

    await tester.tap(find.text('of ₹10,000.00'));
    await tester.pumpAndSettle();
    expect(find.text('Salary for ${MonthKey.label(month)}'), findsOneWidget);
    final field = find.byType(TextFormField);
    await tester.enterText(field, '.');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);
    await tester.enterText(field, '12,000.50');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('of ₹12,000.50'), findsOneWidget);

    final next = MonthKey.shift(month, 1);
    expect(await first(tester, db.watchSalaryAmounts()), {
      null: 1000000,
      month: 1200050,
    });
    expect((await first(tester, db.watchSalaryAmounts()))[next], isNull);

    await tester.tap(find.text('of ₹12,000.50'));
    await tester.pumpAndSettle();
    await tester.enterText(field, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(await first(tester, db.watchSalaryAmounts()), {null: 1000000});
  });

  testWidgets('the uncategorised shortcut opens Expenses filtered to them', (
    tester,
  ) async {
    await add(100, title: 'Loose');
    await add(200, title: 'Sorted', category: food);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          inboxDrainProvider.overrideWithValue(() async {}),
        ],
        child: const PaisaApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Budget'));
    await settle(tester);
    await tester.tap(find.text('1 uncategorised'));
    await settle(tester);

    expect(find.byType(ExpensesScreen), findsOneWidget);
    expect(find.text('Loose'), findsOneWidget);
    expect(find.text('Sorted'), findsNothing);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Uncategorised'),
    );
    expect(chip.selected, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Categories: bars by ratio, spend only without a limit', (
    tester,
  ) async {
    await seedMonth();
    await db.setBudget(food, null, 100000); // 120% with 1,200.50 spent
    await db.setBudget(travel, null, 40000); // 75% with 300.25 spent
    await db.setBudget(1, null, 50000); // Housing, nothing spent
    await pump(tester, const CategoriesScreen());

    expect(find.text('₹8,400.00 left of ₹10,000.00'), findsOneWidget);
    expect(find.text('₹1,600.00'), findsOneWidget, reason: 'donut centre');
    expect(barOf(tester, 'Food').color, Colors.red);
    expect(barOf(tester, 'Food').value, 1);
    expect(inTile('Food', '₹1,200.50'), findsOneWidget);
    expect(inTile('Food', 'of ₹1,000.00'), findsOneWidget);
    expect(inTile('Food', '75.03%'), findsOneWidget); // 1,200.50 of 1,600.00
    expect(
      tester
          .widgetList<PieChart>(find.byType(PieChart))
          .single
          .data
          .sections
          .map((s) => s.value),
      [9925, 120050, 30025],
      reason: 'uncategorised first, then by spend; the credit is left out',
    );
    expect(barOf(tester, 'Transportation').color, Colors.amber);
    expect(barOf(tester, 'Housing').color, Colors.green);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Utilities'),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(inTile('Utilities', '₹0.00'), findsOneWidget);

    expect(inTile('Uncategorised', '₹99.25'), findsOneWidget);
    expect(inTile('Uncategorised', '1'), findsOneWidget);
    expect(find.byKey(const Key('salary-ring')), findsNothing);
    expect(
      tester.getTopLeft(find.text('Uncategorised')).dy,
      lessThan(tester.getTopLeft(find.text('Food')).dy),
    );
    expect(find.textContaining('more than the salary'), findsNothing);
  });

  testWidgets('the month picker and a swipe on the donut both work', (
    tester,
  ) async {
    await add(5000, category: food);
    await pump(tester, const CategoriesScreen());
    await tester.drag(find.byType(PieChart), const Offset(100, 0));
    await settle(tester);
    expect(
      find.text('₹50.00'),
      findsNothing,
      reason: 'previous month is empty',
    );
    await tester.drag(find.byType(PieChart), const Offset(-100, 0));
    await settle(tester);
    expect(find.text('₹50.00'), findsWidgets);

    await tester.tap(find.byType(MonthPicker));
    await tester.pumpAndSettle();
    expect(find.text('Select date'), findsOneWidget);
  });

  testWidgets('Summary marks spend past the salary on the donut', (
    tester,
  ) async {
    await db.setSalary(null, 10000);
    await add(15000, category: food);
    await pump(tester, const CategoriesScreen());
    expect(find.text('Over salary by ₹50.00'), findsOneWidget);
    expect(find.byKey(const Key('over-salary-outline')), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(const Key('salary-ring')),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(ring.value, closeTo(2 / 3, 0.001));
  });

  testWidgets('the Income chip shows only categories with income', (
    tester,
  ) async {
    await db.setBudget(food, null, 100000);
    await add(5000, category: food);
    await add(70000, category: travel, type: TransactionType.credit);
    await pump(tester, const CategoriesScreen());
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pumpAndSettle();
    expect(find.text('₹700.00'), findsNWidgets(2), reason: 'centre and row');
    expect(inTile('Transportation', '100.00%'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('no uncategorised row when nothing is uncategorised', (
    tester,
  ) async {
    await add(100, category: food);
    await pump(tester, const CategoriesScreen());
    expect(find.text('Uncategorised'), findsNothing);
  });

  testWidgets('limits left above a lowered salary show a note', (tester) async {
    await db.setSalary(null, 100000);
    await db.setBudget(food, null, 80000);
    await pump(tester, const CategoriesScreen());
    expect(find.textContaining('more than the salary'), findsNothing);

    await tester.runAsync(() => db.setSalary(null, 50000));
    await settle(tester);
    expect(
      find.textContaining('₹800.00, more than the salary by ₹300.00'),
      findsOneWidget,
    );
  });

  testWidgets('a limit override from Summary replaces it for one month only', (
    tester,
  ) async {
    await db.setSalary(null, 1000000);
    await db.setBudget(food, null, 100000);
    await pump(tester, const CategoriesScreen());

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('₹1,000'), findsOneWidget);
    await tester.tap(
      find.text('${MonthKey.label(month).split(' ').first} only'),
    );
    await tester.pump();
    await tester.longPress(find.byTooltip('Backspace'));
    await tester.pump();
    for (final key in ['2', '5', '0']) {
      await tester.tap(find.byKey(Key('key-$key')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);

    expect(inTile('Food', 'of ₹250.00'), findsOneWidget);
    expect((await first(tester, db.watchBudgetAmounts()))[food], {
      null: 100000,
      month: 25000,
    });
  });

  testWidgets('the month boundary toggle re-computes every total at once', (
    tester,
  ) async {
    // Picked explicitly so the test does not depend on today's date.
    await db.setSalary(null, 1000000);
    await add(10000, category: food, at: DateTime(2026, 10, 27, 23, 59));
    await add(20000, category: food, at: DateTime(2026, 10, 28));
    await add(40000, category: food, at: DateTime(2026, 11, 27, 23, 59));
    await add(80000, category: food, at: DateTime(2026, 11, 28));

    late WidgetRef widgetRef;
    await pump(
      tester,
      Consumer(
        builder: (context, ref, _) {
          widgetRef = ref;
          return const BudgetScreen();
        },
      ),
    );
    widgetRef.read(pickedMonthProvider.notifier).state = '2026-11';
    await settle(tester);
    expect(
      find.text('₹8,800.00'),
      findsOneWidget,
      reason: '10,000 less 400 + 800, calendar',
    );

    await tester.runAsync(() => db.setSalaryDay(28));
    await settle(tester);
    expect(
      find.text('₹9,400.00'),
      findsOneWidget,
      reason: '10,000 less 200 + 400, 28th to 27th',
    );
    expect(find.text('28 Oct – 27 Nov'), findsOneWidget);

    await tester.runAsync(() => db.setSalaryDay(null));
    await settle(tester);
    expect(find.text('₹8,800.00'), findsOneWidget);
  });

  testWidgets('overrides survive a boundary flip, keyed on the label', (
    tester,
  ) async {
    await db.setSalary('2026-11', 123400);
    await db.setSalaryDay(28);
    await db.setSalaryDay(null);
    expect((await first(tester, db.watchSalaryAmounts()))['2026-11'], 123400);
  });

  testWidgets('Settings sets the default salary and the salary day', (
    tester,
  ) async {
    await pump(tester, const SettingsScreen());
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Salary day'), findsNothing);

    await tester.tap(find.text('Salary'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1,55,453');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('₹1,55,453.00'), findsOneWidget);
    expect((await first(tester, db.watchSalaryAmounts()))[null], 15545300);

    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(find.text('Salary day'), findsOneWidget);
    expect(await first(tester, db.watchSalaryDay()), 28);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('27').last);
    await settle(tester);
    expect(await first(tester, db.watchSalaryDay()), 27);

    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(await first(tester, db.watchSalaryDay()), isNull);
    expect(find.text('Salary day'), findsNothing);
  });

  test('a salary-day period excludes the day the next one starts', () async {
    await add(100, at: DateTime(2026, 10, 27, 23, 59, 59), title: 'before');
    await add(200, at: DateTime(2026, 10, 28), title: 'first');
    await add(300, at: DateTime(2026, 11, 27, 23, 59, 59), title: 'last');
    await add(400, at: DateTime(2026, 11, 28), title: 'after');
    final rows = await db
        .watchTransactions(Period.forMonthKey('2026-11', 28))
        .first;
    expect(rows.map((r) => r.counterparty), ['last', 'first']);
  });
}
