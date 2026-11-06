import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database.dart';
import '../../domain/models.dart';
import '../../domain/parser/parser.dart';

const _lastReceivedAtKey = 'last_received_at';

/// Runs the SPEC 5.1 pipeline on the contents of inbox.jsonl. Each line commits
/// on its own, so re-running after a failure is safe: fingerprints skip the
/// lines already done.
Future<void> ingestInbox(AppDatabase db, String jsonl) async {
  for (final line in const LineSplitter().convert(jsonl)) {
    if (line.trim().isEmpty) continue;
    await db.transaction(() => _ingestLine(db, line));
  }
}

({String text, DateTime receivedAt, bool shared})? _decode(String line) {
  final Object? json;
  try {
    json = jsonDecode(line);
  } on FormatException {
    return null;
  }
  if (json case {'text': String text, 'received_at': String receivedAt}) {
    final parsed = DateTime.tryParse(receivedAt);
    if (parsed != null) {
      return (
        text: text,
        receivedAt: parsed,
        shared: json['source'] == 'share',
      );
    }
  }
  return null;
}

Future<void> _ingestLine(AppDatabase db, String line) async {
  final decoded = _decode(line);
  final raw = decoded?.text ?? line;
  final normalised = normaliseMessage(raw);
  final fingerprint = fingerprintOf(normalised);

  Future<void> log(IngestStatus status, {String? refNo, String? rawText}) => db
      .into(db.ingestLog)
      .insert(
        IngestLogCompanion.insert(
          fingerprint: fingerprint,
          ingestedAt: DateTime.now(),
          status: status,
          refNo: Value(refNo),
          rawText: Value(rawText),
        ),
      );

  final seen = await db.ingestLog
      .count(where: (l) => l.fingerprint.equals(fingerprint))
      .getSingle();
  if (seen > 0) return;

  // The fingerprint only guards against re-reading this line after a crash: its
  // received_at has milliseconds, so two equal quick adds are both kept.
  if (_decodeQuickAdd(line) case final add?) {
    await _insertQuickAdd(db, add);
    return log(IngestStatus.parsed);
  }

  if (decoded == null) return log(IngestStatus.failed, rawText: line);

  final last = await (db.select(
    db.settings,
  )..where((s) => s.key.equals(_lastReceivedAtKey))).getSingleOrNull();
  final lastReceivedAt = last == null ? null : DateTime.parse(last.value);
  // Raw text is kept so a line dropped by a device clock change can be recovered.
  if (lastReceivedAt != null && decoded.receivedAt.isBefore(lastReceivedAt)) {
    return log(IngestStatus.ignored, rawText: raw);
  }
  await db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: _lastReceivedAtKey,
          value: decoded.receivedAt.toUtc().toIso8601String(),
        ),
      );

  final bank = await _matchBank(db, normalised);
  if (bank == null) return log(IngestStatus.ignored);

  final parsed = parseMessage(normalised, bank);
  if (parsed == null) return log(IngestStatus.failed, rawText: raw);

  if (await _isDuplicate(db, parsed)) {
    return log(IngestStatus.ignored, refNo: parsed.refNo);
  }

  // The SMS has only a date, so the time of day comes from its arrival.
  final at = decoded.receivedAt.toLocal();
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          type: parsed.type,
          amountPaise: parsed.amountPaise,
          occurredAt: parsed.date.copyWith(
            hour: at.hour,
            minute: at.minute,
            second: at.second,
          ),
          // SPEC 5.18: the name is left for the user to give.
          note: Value(parsed.counterparty),
          accountLast4: Value(parsed.accountLast4),
          bank: Value(bank),
          refNo: Value(parsed.refNo),
          source: decoded.shared
              ? TransactionSource.share
              : TransactionSource.sms,
          rawText: Value(raw),
        ),
      );
  await log(IngestStatus.parsed, refNo: parsed.refNo);
}

typedef _QuickAdd = ({
  TransactionType type,
  int paise,
  DateTime at,
  int? categoryId,
  String? name,
});

/// A SPEC 5.19 line from the quick-add intent, or null for anything else.
_QuickAdd? _decodeQuickAdd(String line) {
  final Object? json;
  try {
    json = jsonDecode(line);
  } on FormatException {
    return null;
  }
  if (json
      case {
        'source': 'quick_add',
        'received_at': String receivedAt,
        'type': String type,
        'amount_paise': int paise,
      }
      when paise > 0) {
    final at = DateTime.tryParse(receivedAt);
    final kind = TransactionType.values.asNameMap()[type];
    if (at == null || kind == null) return null;
    final name = switch (json['name']) {
      final String n when n.trim().isNotEmpty => n.trim(),
      _ => null,
    };
    return (
      type: kind,
      paise: paise,
      at: at.toLocal(),
      categoryId: switch (json['category_id']) {
        final int id => id,
        _ => null,
      },
      name: name,
    );
  }
  return null;
}

/// A deleted category, or one of the other type, saves uncategorised.
Future<void> _insertQuickAdd(AppDatabase db, _QuickAdd add) async {
  final wanted = add.type == TransactionType.debit
      ? CategoryType.expense
      : CategoryType.income;
  final id = add.categoryId;
  final category = id == null
      ? null
      : await (db.select(db.categories)
              ..where((c) => c.id.equals(id) & c.type.equalsValue(wanted)))
            .getSingleOrNull();
  await db.addTransaction(
    TransactionsCompanion.insert(
      type: add.type,
      amountPaise: add.paise,
      occurredAt: add.at,
      counterparty: Value(add.name),
      source: TransactionSource.manual,
      categoryId: Value(category?.id),
    ),
  );
}

Future<Bank?> _matchBank(AppDatabase db, String normalised) async {
  final text = normalised.toLowerCase();
  final senders = await db.select(db.trackedSenders).get();
  for (final sender in senders) {
    if (text.contains(sender.matchPattern.toLowerCase())) return sender.bank;
  }
  return null;
}

/// Second guard from SPEC 5.1: same ref, amount and date as an existing row.
Future<bool> _isDuplicate(AppDatabase db, ParsedMessage parsed) async {
  final refNo = parsed.refNo;
  if (refNo == null) return false;
  final nextDay = parsed.date.copyWith(day: parsed.date.day + 1);
  final matches = await db.transactions
      .count(
        where: (t) =>
            t.refNo.equals(refNo) &
            t.amountPaise.equals(parsed.amountPaise) &
            t.occurredAt.isBiggerOrEqualValue(parsed.date) &
            t.occurredAt.isSmallerThanValue(nextDay),
      )
      .getSingle();
  return matches > 0;
}
