import 'dart:convert';

import 'budget.dart';

const _uncategorisedColor = 0xFF9E9E9E;

/// The widget_summary.json text (SPEC 3.3). [spend] maps category id to debits,
/// null being uncategorised. Salary and remaining are null when no salary is set.
String widgetSummaryJson({
  required String month,
  required Map<int?, int> spend,
  required int? salary,
  required Map<int, ({String name, int color})> categories,
  required DateTime now,
}) {
  final spent = sumPaise(spend.values);
  final top = [
    for (final MapEntry(key: id, value: paise) in spend.entries)
      if (id == null)
        (name: 'Uncategorised', color: _uncategorisedColor, paise: paise)
      else if (categories[id] case final c?)
        (name: c.name, color: c.color, paise: paise),
  ]..sort((a, b) => b.paise.compareTo(a.paise));
  return jsonEncode({
    'month': month,
    'spent_paise': spent,
    'salary_paise': salary,
    'remaining_paise': salary == null ? null : salary - spent,
    'top_categories': [
      for (final c in top.take(3))
        {'name': c.name, 'color': c.color, 'spent_paise': c.paise},
    ],
    'updated_at': now.toUtc().toIso8601String(),
  });
}
