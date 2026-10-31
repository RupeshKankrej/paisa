import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/month_key.dart';
import 'package:paisa/core/theme/app_theme.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/expenses/expenses_screen.dart';
import 'package:paisa/features/ingest/ingest.dart';

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10, 30);

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
    String title, {
    int paise = 12000,
    DateTime? at,
    TransactionType type = TransactionType.debit,
    TransactionSource source = TransactionSource.sms,
    int? categoryId,
    String? rawText,
  }) => db.addTransaction(
    TransactionsCompanion.insert(
      type: type,
      amountPaise: paise,
      occurredAt: at ?? today,
      counterparty: Value(title),
      source: source,
      categoryId: Value(categoryId),
      rawText: Value(rawText),
    ),
  );

  Future<List<TransactionRow>> rows() => db.select(db.transactions).get();

  // runAsync: drift's in-memory queries need real time, not the fake test clock.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // The outer Scaffold stands in for the tab shell.
        child: MaterialApp(
          theme: appTheme(),
          home: const Scaffold(body: ExpensesScreen()),
        ),
      ),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  Future<void> press(WidgetTester tester, String keys) async {
    for (final key in keys.split('')) {
      await tester.tap(find.byKey(Key('key-$key')));
      await tester.pump();
    }
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('key-save')));
    await settle(tester);
  }

  String sheetAmount(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('sheet-amount'))).data!;

  Future<void> pickInStrip(WidgetTester tester, String name) async {
    final item = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.textContaining(name),
    );
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pump();
  }

  testWidgets('groups by day newest first; uncategorised rows are dimmed', (
    tester,
  ) async {
    // The 2nd keeps both rows in the current month on any test date.
    final monthStart = DateTime(now.year, now.month);
    await add(
      'Older',
      at: monthStart.add(const Duration(hours: 9)),
      categoryId: 1,
    );
    await add('Newer', at: monthStart.add(const Duration(days: 1, hours: 9)));
    await add('Last month', at: monthStart.subtract(const Duration(days: 1)));
    await pumpScreen(tester);

    expect(find.text('Last month'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Newer')).dy,
      lessThan(tester.getTopLeft(find.text('Older')).dy),
    );
    expect(find.textContaining('Tap to categorise'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Newer'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Older'), matching: find.byType(Opacity)),
      findsNothing,
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    final lastMonth = MonthKey.shift(MonthKey.of(now), -1);
    await tester.tap(find.text(MonthKey.label(lastMonth)).last);
    await settle(tester);
    expect(find.text('Last month'), findsOneWidget);
    expect(find.text('Newer'), findsNothing);
  });

  testWidgets('the month picker offers the last 12 months with no data', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    final current = MonthKey.of(now);
    expect(
      find.text(MonthKey.label(MonthKey.shift(current, -11))),
      findsWidgets,
    );
    expect(
      find.text(MonthKey.label(MonthKey.shift(current, -12))),
      findsNothing,
    );
    expect(find.text(MonthKey.label(MonthKey.shift(current, 1))), findsNothing);
  });

  testWidgets('filter chips separate expenses and income', (tester) async {
    await add('Shop');
    await add('Salary', type: TransactionType.credit);
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Shop'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Shop'), findsOneWidget);
  });

  testWidgets('credit title shows the first 40 characters', (tester) async {
    final descriptor = 'N' * 60;
    await add(descriptor, type: TransactionType.credit);
    await pumpScreen(tester);
    expect(find.text('N' * 40), findsOneWidget);
  });

  testWidgets('tapping a row picks a category and saves immediately', (
    tester,
  ) async {
    await add('Shop');
    await pumpScreen(tester);

    await tester.tap(find.text('Shop'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'tra');
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsNothing);
    await tester.tap(find.text('Travel'));
    await settle(tester);

    final travel = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Travel'))).getSingle();
    expect((await rows()).single.categoryId, travel.id);
    expect(find.textContaining('Tap to categorise'), findsNothing);
  });

  testWidgets('New category rejects a duplicate, then creates and assigns', (
    tester,
  ) async {
    await add('Shop');
    await pumpScreen(tester);

    await tester.tap(find.text('Shop'));
    await settle(tester);
    await tester.tap(find.text('New category'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      ' food ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Already exists'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Pets');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    final pets = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Pets'))).getSingle();
    expect(pets.sortOrder, 8);
    expect((await rows()).single.categoryId, pets.id);
  });

  testWidgets('swipe deletes, undo restores the same row', (tester) async {
    await add('Shop', categoryId: 1);
    await pumpScreen(tester);
    final before = (await rows()).single;

    await tester.drag(find.text('Shop'), const Offset(-600, 0));
    await settle(tester);
    expect(await rows(), isEmpty);
    expect(find.text('Shop'), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await rows()).single, before);
    expect(find.text('Shop'), findsOneWidget);
  });

  testWidgets('undo snackbar goes away after 5 seconds', (tester) async {
    await add('Shop');
    await pumpScreen(tester);

    await tester.drag(find.text('Shop'), const Offset(-600, 0));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Undo'), findsOneWidget);
    await tester.pumpAndSettle(); // the timer starts once it has fully entered
    expect(
      tester.getBottomLeft(find.byType(SnackBar)).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byType(FloatingActionButton)).dy,
      ),
      reason: 'the snackbar must not cover the add button',
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(await rows(), isEmpty);
  });

  testWidgets('a deleted SMS is not imported again', (tester) async {
    const text =
        'Sent Rs.120.00 From HDFC Bank A/C *2703 To SHOP '
        'On 30/10/26 Ref 630329677868';
    final line = jsonEncode({
      'text': text,
      'received_at': '2026-10-30T10:00:00+05:30',
      'source': 'intent',
    });
    await tester.runAsync(() async {
      await ingestInbox(db, line);
      await db.deleteTransaction((await rows()).single.id);
      await ingestInbox(db, line);
      expect(await rows(), isEmpty);
    });
  });

  testWidgets('manual add requires amount and category, then saves', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('Nothing here for this month'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(sheetAmount(tester), '₹0');
    await save(tester);
    expect(find.text('Enter an amount'), findsOneWidget);
    await press(tester, '1250.509');
    expect(sheetAmount(tester), '₹1,250.50', reason: 'no third decimal');
    await save(tester);
    expect(find.text('Pick a category'), findsOneWidget);
    expect(await rows(), isEmpty);

    await tester.tap(find.byTooltip('Backspace'));
    await tester.pump();
    expect(sheetAmount(tester), '₹1,250.5');
    await pickInStrip(tester, 'Food');
    await tester.tap(find.byTooltip('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' Lunch ');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await save(tester);

    final row = (await rows()).single;
    expect(row.amountPaise, 125050);
    expect(row.type, TransactionType.debit);
    expect(row.source, TransactionSource.manual);
    expect(row.counterparty, 'Lunch');
    expect(row.note, isNull);
    expect(row.categoryId, isNotNull);
    expect(DateUtils.isSameDay(row.occurredAt, now), isTrue);
    expect(find.text('Lunch'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TransactionTile),
        matching: find.text('₹1,250.50'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a zero amount is rejected', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await press(tester, '0');
    await save(tester);
    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('the sheet fits a phone and the grid picks any category', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'no overflow');

    await tester.tap(find.byTooltip('All categories'));
    await settle(tester);
    await tester.tap(find.text('Other').last);
    await settle(tester);
    await press(tester, '5');
    await save(tester);

    final other = await (db.select(
      db.categories,
    )..where((c) => c.name.equals('Other'))).getSingle();
    expect((await rows()).single.categoryId, other.id);
  });

  testWidgets('adding income with the Expenses filter on still shows it', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Expenses'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await press(tester, '50');
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    await pickInStrip(tester, 'Food');
    await save(tester);

    expect((await rows()).single.type, TransactionType.credit);
    expect(
      find.descendant(
        of: find.byType(TransactionTile),
        matching: find.text('+₹50.00'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('long press edits an SMS row, showing its raw text', (
    tester,
  ) async {
    const raw = 'Sent Rs.120.00 From HDFC Bank';
    await add('Shop', rawText: raw);
    await pumpScreen(tester);
    final before = (await rows()).single;

    await tester.longPress(find.text('Shop'));
    await settle(tester);
    expect(find.text('from SMS'), findsOneWidget);
    expect(find.text(raw), findsNothing);
    await tester.tap(find.text('from SMS'));
    await tester.pumpAndSettle();
    expect(find.text(raw), findsOneWidget);

    expect(sheetAmount(tester), '₹120');
    await tester.tap(find.byTooltip('Backspace'));
    await tester.pump();
    await tester.tap(find.byTooltip('Backspace'));
    await tester.pump();
    await press(tester, '50');
    expect(sheetAmount(tester), '₹150');
    await tester.tap(find.byTooltip('Reset'));
    await tester.pump();
    expect(sheetAmount(tester), '₹120');
    await tester.tap(find.byTooltip('Backspace'));
    await tester.pump();
    await tester.tap(find.byTooltip('Backspace'));
    await tester.pump();
    await press(tester, '50');
    // Uncategorised is allowed on an SMS row.
    await save(tester);

    final after = (await rows()).single;
    expect(after.amountPaise, 15000);
    expect(after.occurredAt, before.occurredAt);
    expect(after.source, TransactionSource.sms);
    expect(after.rawText, raw);
    expect(after.categoryId, isNull);
  });

  testWidgets('a manual row being edited has no SMS section', (tester) async {
    await add('Lunch', source: TransactionSource.manual, categoryId: 1);
    await pumpScreen(tester);
    await tester.longPress(find.text('Lunch'));
    await settle(tester);
    expect(find.text('from SMS'), findsNothing);
    expect(find.bySemanticsLabel('Edit transaction'), findsOneWidget);
  });

  testWidgets('delete in the edit sheet removes the row with an undo', (
    tester,
  ) async {
    await add('Lunch', categoryId: 1);
    await pumpScreen(tester);
    final before = (await rows()).single;

    await tester.longPress(find.text('Lunch'));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete'));
    await settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(await rows(), isEmpty);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await rows()).single, before);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('the add sheet has no delete button', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    expect(find.byTooltip('Delete'), findsNothing);
  });

  testWidgets('the day bars cover the period and leave out credits', (
    tester,
  ) async {
    await add('Shop', paise: 5000);
    await add('Pay', paise: 900000, type: TransactionType.credit);
    await pumpScreen(tester);

    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    final last = DateTime(now.year, now.month + 1, 0).day;
    expect(data.barGroups, hasLength(last));
    expect(data.barGroups[now.day - 1].barRods.single.toY, 5000);
    expect(data.maxY, 5000, reason: 'the credit does not set the scale');
    expect(find.text('₹50'), findsOneWidget, reason: 'the top axis label');
  });

  test('a day total is its spend, or its income when nothing was spent', () {
    TransactionRow row(TransactionType type, int paise) => TransactionRow(
      id: paise,
      type: type,
      amountPaise: paise,
      occurredAt: DateTime(2026, 10, 30),
      source: TransactionSource.manual,
      createdAt: DateTime(2026, 10, 30),
      updatedAt: DateTime(2026, 10, 30),
    );
    final debit = row(TransactionType.debit, 10000);
    final credit = row(TransactionType.credit, 5000);
    expect(dayTotal([debit, credit]), '₹100.00');
    expect(dayTotal([credit]), '+₹50.00');
  });
}
