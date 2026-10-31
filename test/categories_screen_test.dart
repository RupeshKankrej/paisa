import 'package:drift/drift.dart' show DatabaseConnection, OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/core/theme/app_theme.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/budgets/categories_screen.dart';
import 'package:paisa/features/budgets/manage_categories_screen.dart';
import 'package:paisa/features/expenses/expenses_screen.dart';

const food = 2, transportation = 5;

void main() {
  late AppDatabase db;
  final start = MonthKey.start(MonthKey.of(DateTime.now()));

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> add(String title, int paise, int? category) => db.addTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.debit,
      amountPaise: paise,
      occurredAt: start.add(const Duration(hours: 9)),
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
        child: MaterialApp(theme: appTheme(), home: screen),
      ),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  // In table order unless sorted: streams hang under the widget test's fake clock.
  Future<List<String>> names(CategoryType type) async => [
    for (final c in await db.select(db.categories).get())
      if (c.type == type && !c.isArchived) c.name,
  ];

  testWidgets('segment switches lists and a quick add leaves the suggestions', (
    tester,
  ) async {
    await pump(tester, const ManageCategoriesScreen());
    expect(find.text('Housing'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Housing'), findsNothing);

    await tester.tap(find.byTooltip('Add Tips'));
    await settle(tester);
    expect(find.byTooltip('Add Tips'), findsNothing);
    expect(await names(CategoryType.income), ['Salary', 'Investments', 'Tips']);
  });

  testWidgets('dragging the handle reorders and persists', (tester) async {
    await pump(tester, const ManageCategoriesScreen(type: CategoryType.income));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle).last),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    await settle(tester);
    final income =
        await (db.select(db.categories)
              ..where((c) => c.type.equalsValue(CategoryType.income))
              ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
            .get();
    expect(income.map((c) => c.name), ['Investments', 'Salary']);
    expect(
      tester.getTopLeft(find.text('Investments')).dy,
      lessThan(tester.getTopLeft(find.text('Salary')).dy),
    );
  });

  testWidgets('editing renames; delete confirms and uncategorises', (
    tester,
  ) async {
    await add('Lunch', 100, food);
    await pump(tester, const ManageCategoriesScreen());

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense category'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('category-name')), 'Meals');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Meals'), findsOneWidget);

    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect((await db.select(db.transactions).getSingle()).categoryId, food);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(find.text('Meals'), findsNothing);
    expect((await db.select(db.transactions).getSingle()).categoryId, isNull);
  });

  testWidgets('archive moves a row to Archived, and unarchive brings it back', (
    tester,
  ) async {
    await pump(tester, const ManageCategoriesScreen());
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
    await settle(tester);
    expect(await names(CategoryType.expense), isNot(contains('Food')));
    await tester.scrollUntilVisible(
      find.text('Archived'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Unarchive'));
    await settle(tester);
    expect(await names(CategoryType.expense), contains('Food'));
  });

  testWidgets('a row in an archived category keeps its category on Activity', (
    tester,
  ) async {
    await add('Lunch', 100, food);
    await db.setCategoryArchived(food, true);
    await pump(tester, const Scaffold(body: ExpensesScreen()));
    await tester.scrollUntilVisible(
      find.text('Lunch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Tap to categorise'), findsNothing);
  });

  testWidgets('the filter chip narrows Activity and persists until cleared', (
    tester,
  ) async {
    await add('Lunch', 10000, food);
    await add('Cab', 5000, transportation);
    await add('Unknown', 2500, null);
    await pump(tester, const Scaffold(body: ExpensesScreen()));
    expect(find.text('₹175.00'), findsWidgets);

    final chip = find.widgetWithText(ChoiceChip, 'All categories');
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'None'));
    await settle(tester);
    await tester.tap(find.text('Food').last);
    await settle(tester);
    await tester.tapAt(const Offset(10, 10)); // scrim
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '1 category'), findsOneWidget);
    expect(find.text('Cab'), findsNothing);
    expect(find.text('Unknown'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Lunch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('₹100.00'),
      findsWidgets,
      reason: 'hero follows the filter',
    );
    final saved = await db.select(db.settings).get();
    expect(saved.single.value, '$food');
  });

  testWidgets('the Summary pencil filters the donut, not the salary line', (
    tester,
  ) async {
    await add('Lunch', 10000, food);
    await add('Cab', 5000, transportation);
    await db.setSalary(null, 12000);
    await db.setCategoryFilter({transportation});
    await pump(tester, const Scaffold(body: CategoriesScreen()));

    expect(find.text('Over salary by ₹30.00'), findsOneWidget);
    expect(find.byKey(const Key('over-salary-outline')), findsNothing);
    expect(find.text('Food'), findsNothing);
    expect(find.text('100.00%'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '1 category'), findsOneWidget);

    await tester.tap(find.byTooltip('Filter categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'All'));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);
    expect(find.byKey(const Key('over-salary-outline')), findsOneWidget);
  });

  testWidgets('a custom category reaches the add sheet strip and the filter', (
    tester,
  ) async {
    await db.addCategory(
      name: 'Pets',
      type: CategoryType.expense,
      emoji: '🐶',
      color: 0xFFFFFFFF,
    );
    await pump(tester, const Scaffold(body: ExpensesScreen()));

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.textContaining('🐶'), findsOneWidget);
    expect(find.textContaining('Salary'), findsNothing, reason: 'income');

    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Salary'), findsOneWidget);
    expect(find.textContaining('🐶'), findsNothing);
  });
}
