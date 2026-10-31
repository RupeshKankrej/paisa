import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/money.dart';
import '../models.dart';
import 'template.dart';
import 'templates/hdfc.dart';

class ParsedMessage {
  const ParsedMessage({
    required this.type,
    required this.amountPaise,
    required this.date,
    required this.counterparty,
    required this.accountLast4,
    required this.refNo,
  });

  final TransactionType type;
  final int amountPaise;
  final DateTime date;
  final String counterparty;
  final String accountLast4;
  final String? refNo;
}

String normaliseMessage(String text) =>
    text.trim().replaceAll(RegExp(r'\s+'), ' ');

String fingerprintOf(String normalised) =>
    sha256.convert(utf8.encode(normalised)).toString();

List<MessageTemplate> _templatesFor(Bank bank) => switch (bank) {
  Bank.hdfc => hdfcTemplates,
};

/// First template that matches wins. A match with an impossible amount or date
/// returns null, so the message surfaces as failed instead of a wrong expense.
ParsedMessage? parseMessage(String normalised, Bank bank) {
  for (final template in _templatesFor(bank)) {
    final match = template.pattern.firstMatch(normalised);
    if (match == null) continue;
    final amount = Money.tryParse(match.namedGroup('amount')!);
    final date = parseMessageDate(match.namedGroup('date')!);
    if (amount == null || date == null) return null;
    return ParsedMessage(
      type: template.type,
      amountPaise: amount,
      date: date,
      counterparty: match.namedGroup('party')!.trim(),
      accountLast4: match.namedGroup('last4')!,
      refNo: match.groupNames.contains('ref') ? match.namedGroup('ref') : null,
    );
  }
  return null;
}

final _dateParts = RegExp(r'^(\d{2})[/-](\d{2}|[A-Za-z]{3})[/-](\d{2})$');
const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

/// Null when the date does not exist, such as 31/02/26.
DateTime? parseMessageDate(String text) {
  final match = _dateParts.firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month =
      int.tryParse(match[2]!) ?? _months.indexOf(match[2]!.toUpperCase()) + 1;
  final date = DateTime(2000 + int.parse(match[3]!), month, day);
  return date.month == month && date.day == day ? date : null;
}
