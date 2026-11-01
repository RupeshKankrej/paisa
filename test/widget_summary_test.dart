import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/app/router.dart';
import 'package:paisa/core/period.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/domain/widget_summary.dart';

Map<String, dynamic> summary(
  Map<int?, int> spend, {
  int? salary,
  Map<int, ({String name, int color})> categories = const {},
}) => jsonDecode(
  widgetSummaryJson(
    month: '2026-10',
    spend: spend,
    salary: salary,
    categories: categories,
    now: DateTime.utc(2026, 10, 31, 12),
  ),
) as Map<String, dynamic>;

void main() {
  test('has the SPEC 3.3 shape, with spend beyond salary negative', () {
    expect(summary({1: 7000, null: 5000}, salary: 10000), {
      'month': '2026-10',
      'spent_paise': 12000,
      'salary_paise': 10000,
      'remaining_paise': -2000,
      'top_categories': [
        {'name': 'Uncategorised', 'color': 0xFF9E9E9E, 'spent_paise': 5000},
      ],
      'daily_spent_paise': <int>[],
      'quick_categories': <Object>[],
      'updated_at': '2026-10-31T12:00:00.000Z',
    });
  });

  test('no salary leaves salary and remaining null, not a false negative', () {
    final json = summary({null: 100});
    expect(json['salary_paise'], isNull);
    expect(json['remaining_paise'], isNull);
  });

  test('top categories are the three largest, in order', () {
    final json = summary(
      {1: 100, 2: 400, 3: 300, 4: 200},
      categories: {
        for (final id in [1, 2, 3, 4]) id: (name: 'c$id', color: id),
      },
    );
    expect((json['top_categories'] as List).map((c) => c['name']), [
      'c2',
      'c3',
      'c4',
    ]);
    expect(json['spent_paise'], 1000);
  });

  test('deep links', () {
    expect(widgetLink(Uri.parse('paisa://expenses')), '/expenses');
    expect(widgetLink(Uri.parse('paisa://add')), startsWith('/expenses?add='));
    expect(widgetLink(Uri.parse('/home')), isNull);
    expect(widgetLink(Uri.parse('paisa://dashboards')), '/dashboards');
    final income = Uri.parse(widgetLink(Uri.parse('paisa://add?type=income'))!);
    expect(income.queryParameters['type'], 'income');
    expect(income.queryParameters['add'], isNotNull);
    final food = Uri.parse(widgetLink(Uri.parse('paisa://add?category=3'))!);
    expect(food.queryParameters['category'], '3');
  });

  test('follows the database for the current period', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final values = <Map<String, dynamic>>[];
    container.listen(widgetSummaryProvider, (_, json) {
      if (json != null) values.add(jsonDecode(json) as Map<String, dynamic>);
    });
    Future<Map<String, dynamic>> settled(
      bool Function(Map<String, dynamic>) ok,
    ) async {
      for (var i = 0; i < 200; i++) {
        if (values.isNotEmpty && ok(values.last)) return values.last;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('never settled: ${values.lastOrNull}');
    }

    final first = await settled((_) => true);
    expect(first['spent_paise'], 0);
    expect(first['month'], Period.containing(DateTime.now(), null).key);
    final today = DateTime.now();
    expect(
      first['daily_spent_paise'],
      hasLength(DateTime(today.year, today.month + 1, 0).day),
    );
    expect((first['quick_categories'] as List).map((c) => c['name']), [
      'Housing',
      'Food',
      'Groceries',
      'Utilities',
    ]);

    final now = DateTime.now();
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.debit,
        amountPaise: 12000,
        occurredAt: now,
        source: TransactionSource.manual,
      ),
    );
    final spentToday = await settled((v) => v['spent_paise'] == 12000);
    expect(spentToday['remaining_paise'], isNull);
    expect((spentToday['daily_spent_paise'] as List)[now.day - 1], 12000);

    await db.setSalary(null, 100000);
    final withSalary = await settled((v) => v['remaining_paise'] == 88000);
    expect(withSalary['salary_paise'], 100000);

    // A previous month's row does not count.
    final old = DateTime(now.year - 1, now.month, 15);
    await db.addTransaction(
      TransactionsCompanion.insert(
        type: TransactionType.debit,
        amountPaise: 999,
        occurredAt: old,
        source: TransactionSource.manual,
      ),
    );
    await db.setSalary(null, 200000);
    expect(
      (await settled((v) => v['salary_paise'] == 200000))['spent_paise'],
      12000,
    );
  });
}
