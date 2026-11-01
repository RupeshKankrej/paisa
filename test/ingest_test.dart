import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/ingest/ingest.dart';

import 'parser_test.dart' show creditSample, debitSample;

String line(String text, {String at = '2026-10-30T10:15:30Z'}) =>
    jsonEncode({'text': text, 'received_at': at, 'source': 'intent'});

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<IngestStatus>> statuses() async => [
    for (final row in await db.select(db.ingestLog).get()) row.status,
  ];
  Future<List<TransactionRow>> rows() => db.select(db.transactions).get();

  test('the default HDFC sender is seeded', () async {
    final senders = await db.select(db.trackedSenders).get();
    expect(senders.single.matchPattern, 'HDFC Bank');
    expect(senders.single.bank, Bank.hdfc);
  });

  test('debit and credit become uncategorised sms transactions', () async {
    await ingestInbox(db, '${line(debitSample)}\n${line(creditSample)}\n');

    final all = await rows();
    expect(all.map((t) => t.type), [
      TransactionType.debit,
      TransactionType.credit,
    ]);
    final debit = all.first;
    expect(debit.amountPaise, 12000);
    expect(debit.source, TransactionSource.sms);
    expect(debit.categoryId, isNull);
    expect(debit.bank, Bank.hdfc);
    expect(debit.rawText, debitSample);
    expect(debit.occurredAt.day, 30);
    final local = DateTime.utc(2026, 10, 30, 10, 15, 30).toLocal();
    expect(debit.occurredAt.minute, local.minute);
    expect(await statuses(), [IngestStatus.parsed, IngestStatus.parsed]);
  });

  test('a shared message keeps its source', () async {
    await ingestInbox(
      db,
      jsonEncode({
        'text': debitSample,
        'received_at': '2026-10-30T10:15:30Z',
        'source': 'share',
      }),
    );
    expect((await rows()).single.source, TransactionSource.share);
  });

  test('the same message delivered twice creates one transaction', () async {
    await ingestInbox(db, line(debitSample));
    await ingestInbox(db, line(debitSample));
    // Different whitespace, later delivery: same normalised text.
    await ingestInbox(
      db,
      line(
        debitSample.replaceFirst(' To ', '\nTo '),
        at: '2026-10-30T11:00:00Z',
      ),
    );
    expect(await rows(), hasLength(1));
    expect(await statuses(), [IngestStatus.parsed]);
  });

  test('a deleted transaction is not re-imported', () async {
    await ingestInbox(db, line(debitSample));
    await db.delete(db.transactions).go();
    await ingestInbox(db, line(debitSample));
    expect(await rows(), isEmpty);
  });

  test('same ref, amount and date with other text is a duplicate', () async {
    await ingestInbox(db, line(debitSample));
    await ingestInbox(db, line('$debitSample Not You?'));
    expect(await rows(), hasLength(1));
    expect(await statuses(), [IngestStatus.parsed, IngestStatus.ignored]);
  });

  test('same ref on another date is not a duplicate', () async {
    await ingestInbox(db, line(debitSample));
    await ingestInbox(
      db,
      line(debitSample.replaceFirst('30/10/26', '31/10/26')),
    );
    expect(await rows(), hasLength(2));
  });

  test('manual expenses do not trigger the ref guard', () async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            type: TransactionType.debit,
            amountPaise: 12000,
            occurredAt: DateTime(2026, 10, 30),
            source: TransactionSource.manual,
          ),
        );
    await ingestInbox(db, line(debitSample));
    expect(await rows(), hasLength(2));
  });

  test('untracked messages are ignored without keeping their text', () async {
    await ingestInbox(db, line('Your OTP is 123456'));
    final log = await db.select(db.ingestLog).getSingle();
    expect(log.status, IngestStatus.ignored);
    expect(log.rawText, isNull);
    expect(await rows(), isEmpty);
  });

  test('tracked messages with no template fail and keep raw text', () async {
    const message = 'HDFC Bank\nsomething new';
    await ingestInbox(db, line(message));
    final failed = await db.watchFailedMessages().first;
    expect(failed.single.rawText, message);
    expect(await rows(), isEmpty);
  });

  test('a corrupt line fails visibly and later lines still import', () async {
    await ingestInbox(db, 'not json\n{"text":1}\n${line(debitSample)}\n');
    expect(await db.watchFailedMessages().first, hasLength(2));
    expect(await rows(), hasLength(1));
  });

  test('a new sender makes its messages parse', () async {
    await db
        .into(db.trackedSenders)
        .insert(
          TrackedSendersCompanion.insert(
            label: 'Other',
            matchPattern: 'sent rs',
            bank: Bank.hdfc,
          ),
        );
    await ingestInbox(db, line(debitSample));
    expect((await rows()).single.bank, Bank.hdfc);
  });

  test('lines older than the last processed one are skipped', () async {
    await ingestInbox(db, line(debitSample));
    await ingestInbox(db, line(creditSample, at: '2026-10-29T10:00:00Z'));
    expect(await rows(), hasLength(1));
    expect(await statuses(), [IngestStatus.parsed, IngestStatus.ignored]);
    expect((await db.select(db.ingestLog).get()).last.rawText, creditSample);
  });

  test('messages in the same second are both kept', () async {
    await ingestInbox(db, '${line(debitSample)}\n${line(creditSample)}');
    expect(await rows(), hasLength(2));
  });

  test(
    'upgrading a version 1 database keeps data and seeds the sender',
    () async {
      final dir = await Directory.systemTemp.createTemp('paisa');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/paisa.sqlite');

      // Rewinds a fresh database to what Phase 1 installed on the phone.
      final v1 = AppDatabase(NativeDatabase(file));
      await v1.select(v1.categories).get();
      await v1.customStatement('DROP TABLE settings');
      await v1.delete(v1.trackedSenders).go();
      await v1.customStatement('DROP TABLE categories');
      await v1.customStatement('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          color INTEGER NOT NULL, icon TEXT NOT NULL,
          sort_order INTEGER NOT NULL,
          is_archived INTEGER NOT NULL DEFAULT 0)
      ''');
      // Colours as Phase 1 seeded them, plus one the palette never had.
      await v1.customStatement('''
        INSERT INTO categories (name, color, icon, sort_order) VALUES
          ('Food', 0xFFE57373, 'restaurant', 0),
          ('Other', 0xFF123456, 'category', 7)
      ''');
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final categories = await upgraded.select(upgraded.categories).get();
      expect(categories.map((c) => (c.name, c.type)), [
        ('Food', CategoryType.expense),
        ('Other', CategoryType.expense),
        ('Salary', CategoryType.income),
        ('Investments', CategoryType.income),
      ]);
      Category named(String name) =>
          categories.firstWhere((c) => c.name == name);
      expect(named('Food').color, 0xFF5AA9F5);
      expect(named('Food').emoji, '🍽️');
      expect(named('Food').id, 1, reason: 'links stay');
      expect(named('Other').color, 0xFF123456);
      expect(named('Other').emoji, '📦');
      final sender = await upgraded.select(upgraded.trackedSenders).getSingle();
      expect(sender.matchPattern, 'HDFC Bank');
      await ingestInbox(upgraded, line(debitSample));
      expect(await upgraded.select(upgraded.transactions).get(), hasLength(1));
    },
  );
}
