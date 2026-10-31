import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/core/period.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/budgets/categories_screen.dart';
import 'package:paisa/features/home/home_screen.dart';
import 'package:paisa/features/settings/settings_screen.dart';
import 'package:paisa/main.dart';

const food = 1, travel = 2;

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

  testWidgets('Home totals match a hand-computed month', (tester) async {
    await seedMonth();
    await pump(tester, const HomeScreen());
    expect(find.text('₹1,600.00'), findsOneWidget);
    expect(find.text('₹10,000.00'), findsOneWidget);
    expect(find.text('₹8,400.00'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.16,
    );
    expect(find.textContaining('Over salary'), findsNothing);
    // The uncategorised debit and the uncategorised credit.
    expect(find.text('2 uncategorised'), findsOneWidget);
  });

  testWidgets('spending past the salary turns remaining red and marks it', (
    tester,
  ) async {
    await db.setSalary(null, 10000);
    await add(15000, category: food);
    await pump(tester, const HomeScreen());
    final remaining = tester.widget<Text>(find.text('-₹50.00'));
    expect(remaining.style?.color, Colors.red);
    expect(find.text('Over salary by ₹50.00'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
  });

  testWidgets('no salary shows a prompt, not a false negative remaining', (
    tester,
  ) async {
    await add(15000, category: food);
    await pump(tester, const HomeScreen());
    expect(find.text('Set salary'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Home shows only the last 5 transactions, newest first', (
    tester,
  ) async {
    for (var i = 1; i <= 6; i++) {
      await add(
        100,
        category: food,
        title: 'T$i',
        at: start.add(Duration(minutes: i)),
      );
    }
    await pump(tester, const HomeScreen());
    expect(find.text('T1'), findsNothing);
    expect(find.text('T6'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('T6')).dy,
      lessThan(tester.getTopLeft(find.text('T2')).dy),
    );
  });

  testWidgets('a salary override applies to that month, blank restores it', (
    tester,
  ) async {
    await db.setSalary(null, 1000000);
    await pump(tester, const HomeScreen());

    await tester.tap(find.text('₹10,000.00').first); // salary, then remaining
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
    expect(find.text('₹12,000.50'), findsNWidgets(2)); // salary and remaining

    final next = MonthKey.shift(month, 1);
    expect(await first(tester, db.watchSalaryAmounts()), {
      null: 1000000,
      month: 1200050,
    });
    expect((await first(tester, db.watchSalaryAmounts()))[next], isNull);

    await tester.tap(find.text('Salary').first);
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
    await tester.tap(find.text('1 uncategorised'));
    await settle(tester);

    expect(find.widgetWithText(AppBar, 'Expenses'), findsOneWidget);
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
    await db.setBudget(3, null, 50000); // Rent, nothing spent
    await pump(tester, const CategoriesScreen());

    expect(find.text('₹8,400.00'), findsOneWidget, reason: 'the same top card');
    expect(barOf(tester, 'Food').color, Colors.red);
    expect(barOf(tester, 'Food').value, 1);
    expect(inTile('Food', '₹1,200.50 / ₹1,000.00'), findsOneWidget);
    expect(barOf(tester, 'Travel').color, Colors.amber);
    expect(barOf(tester, 'Rent').color, Colors.green);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Bills'),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(inTile('Bills', '₹0.00'), findsOneWidget);

    expect(inTile('Uncategorised', '₹99.25'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Uncategorised')).dy,
      lessThan(tester.getTopLeft(find.text('Food')).dy),
    );
    expect(find.textContaining('more than the salary'), findsNothing);
  });

  testWidgets('no uncategorised row when nothing is uncategorised', (
    tester,
  ) async {
    await add(100, category: food);
    await pump(tester, const CategoriesScreen());
    expect(find.text('Uncategorised'), findsNothing);
  });

  testWidgets('limits above the salary show a note but are allowed', (
    tester,
  ) async {
    await db.setSalary(null, 100000);
    await db.setBudget(food, null, 80000);
    await pump(tester, const CategoriesScreen());
    expect(find.textContaining('more than the salary'), findsNothing);

    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '500');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(
      find.textContaining('₹1,300.00, more than the salary by ₹300.00'),
      findsOneWidget,
    );
  });

  testWidgets('a limit override replaces the default for one month only', (
    tester,
  ) async {
    await db.setBudget(food, null, 100000);
    await pump(tester, const CategoriesScreen());

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '1,000.00',
    );
    await tester.enterText(find.byType(TextFormField).last, '250');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(inTile('Food', '₹0.00 / ₹250.00'), findsOneWidget);
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
          return const HomeScreen();
        },
      ),
    );
    widgetRef.read(pickedMonthProvider.notifier).state = '2026-11';
    await settle(tester);
    expect(
      find.text('₹1,200.00'),
      findsOneWidget,
      reason: '400 + 800, calendar',
    );

    await tester.runAsync(() => db.setSalaryDay(28));
    await settle(tester);
    expect(
      find.text('₹600.00'),
      findsOneWidget,
      reason: '200 + 400, 28th to 27th',
    );
    expect(find.text('28 Oct – 27 Nov'), findsOneWidget);

    await tester.runAsync(() => db.setSalaryDay(null));
    await settle(tester);
    expect(find.text('₹1,200.00'), findsOneWidget);
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
