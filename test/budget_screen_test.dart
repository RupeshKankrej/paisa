import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/core/theme/tokens.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/budgets/budget_screen.dart';
import 'package:paisa/features/budgets/categories_screen.dart';

const housing = 1, food = 2, travel = 5;

void main() {
  late AppDatabase db;
  final month = MonthKey.of(DateTime.now());

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

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

  Future<void> typeAmount(WidgetTester tester, String digits) async {
    await tester.longPress(find.byTooltip('Backspace'));
    await tester.pump();
    for (final key in digits.split('')) {
      await tester.tap(find.byKey(Key('key-$key')));
      await tester.pump();
    }
  }

  Future<Map<String?, int>?> stored(WidgetTester tester, int id) async =>
      (await tester.runAsync(() => db.watchBudgetAmounts().first))![id];

  testWidgets('a card shows what is left, and the ring reads spend', (
    tester,
  ) async {
    await db.setSalary(null, 10000000);
    await db.setBudget(travel, null, 1000000);
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.debit,
        amountPaise: 250000,
        occurredAt: MonthKey.start(month),
        source: TransactionSource.manual,
        categoryId: const Value(travel),
      ),
    );
    await pump(tester, const BudgetScreen());
    expect(find.text('₹7,500.00 left'), findsOneWidget);
    expect(find.text('of ₹10,000.00'), findsOneWidget);
    expect(find.text('Add category'), findsOneWidget);
    expect(find.text('Left this month'), findsOneWidget);
  });

  testWidgets('a limit past the salary cannot be saved', (tester) async {
    await db.setSalary(null, 10000000); // 1,00,000
    await db.setBudget(travel, null, 1000000); // 10,000
    await pump(tester, const BudgetScreen());

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    expect(
      find.text('Transportation'),
      findsOneWidget,
      reason: 'only the row behind the sheet, not a tile',
    );
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Food monthly budget'), findsOneWidget);
    expect(find.text('₹90,000.00 budget left'), findsOneWidget);

    await typeAmount(tester, '100000');
    final left = tester.widget<Text>(find.byKey(const Key('budget-left')));
    expect(left.data, '-₹10,000.00 budget left');
    expect(left.style?.color, AppColors.debit);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);
    expect(await stored(tester, food), isNull, reason: 'the arrow did nothing');
    expect(find.textContaining('Food monthly budget'), findsOneWidget);

    await typeAmount(tester, '90000');
    expect(find.text('₹0.00 budget left'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    expect(await stored(tester, food), {null: 9000000});
    expect(find.text('₹90,000.00 left'), findsOneWidget);
  });

  testWidgets('the same block applies when a limit is set from Summary', (
    tester,
  ) async {
    await db.setSalary(null, 100000);
    await pump(tester, const CategoriesScreen());
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await typeAmount(tester, '1001');
    expect(find.text('-₹1.00 budget left'), findsOneWidget);
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);
    expect(await stored(tester, food), isNull);
  });

  testWidgets('a salary override moves the cap for that month only', (
    tester,
  ) async {
    await db.setSalary(null, 100000);
    await db.setSalary(month, 500000);
    await pump(tester, const CategoriesScreen());
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('₹5,000.00 budget left'), findsOneWidget);
  });

  testWidgets('every month replaces an override; blank removes the limit', (
    tester,
  ) async {
    await db.setSalary(null, 10000000);
    await db.setBudget(food, null, 100000);
    await db.setBudget(food, month, 50000);
    await pump(tester, const BudgetScreen());

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every month'));
    await tester.pump();
    await typeAmount(tester, '2000');
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);
    expect(await stored(tester, food), {null: 200000});

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byTooltip('Backspace'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);
    expect(await stored(tester, food), isNull);
    expect(find.text('Food'), findsNothing);
  });

  testWidgets('a blank amount still saves when past a lowered salary', (
    tester,
  ) async {
    await db.setSalary(null, 100000);
    await db.setBudget(food, null, 200000);
    await db.setBudget(travel, null, 200000);
    await pump(tester, const BudgetScreen());
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byTooltip('Backspace'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);
    expect(await stored(tester, food), isNull);
  });

  testWidgets('Allocate updates live, blocks, and saves only on Confirm', (
    tester,
  ) async {
    await db.setSalary(null, 10000000);
    await db.setBudget(travel, null, 1000000);
    await pump(tester, const BudgetScreen());

    await tester.tap(find.byTooltip('Allocate budget'));
    await tester.pumpAndSettle();
    expect(find.text('10% set'), findsOneWidget);
    expect(find.text('₹90,000.00 left to allocate'), findsOneWidget);

    await tester.tap(find.text('Housing'));
    await tester.pumpAndSettle();
    await typeAmount(tester, '95000');
    expect(find.text('-₹5,000.00 budget left'), findsOneWidget);
    await typeAmount(tester, '40000');
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);

    expect(find.text('50% set'), findsOneWidget);
    expect(find.text('₹50,000.00 left to allocate'), findsOneWidget);
    expect(await stored(tester, housing), isNull, reason: 'not yet confirmed');

    // Another row's cap counts the edit not yet saved.
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('₹50,000.00 budget left'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(await stored(tester, housing), {null: 4000000});
    expect(find.text('Allocate your budget'), findsNothing);
    expect(find.text('₹40,000.00 left'), findsOneWidget);
  });

  testWidgets('with no limits, Add category is the dashed tile', (
    tester,
  ) async {
    await pump(tester, const BudgetScreen());
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Income'), findsNothing, reason: 'expense only');
  });
}
