import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
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

  Finder sheetField(String label) => find.widgetWithText(TextFormField, label);

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
    await tester.enterText(sheetField('Name'), ' food ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Already exists'), findsOneWidget);

    await tester.enterText(sheetField('Name'), 'Pets');
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
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(await rows(), isEmpty);

    await tester.enterText(sheetField('Amount'), '1,250.5');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      sheetField('Counterparty or title (optional)'),
      ' Lunch ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

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
    await tester.enterText(sheetField('Amount'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('adding income with the Expenses filter on still shows it', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Expenses'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.enterText(sheetField('Amount'), '50');
    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

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

    expect(
      tester.widget<TextFormField>(sheetField('Amount')).controller!.text,
      '120.00',
    );
    await tester.enterText(sheetField('Amount'), '150');
    // Uncategorised is allowed on an SMS row.
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

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
    expect(find.text('Edit transaction'), findsOneWidget);
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
