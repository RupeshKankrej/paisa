import 'package:flutter/services.dart';

import '../../data/database.dart';
import 'ingest.dart';

const _inbox = MethodChannel('paisa/inbox');

/// Acks only after the lines are committed, so a crash re-reads them instead of
/// losing them. Loops because a message can arrive while a batch is processed.
Future<void> drainInbox(AppDatabase db) async {
  String text;
  do {
    text = await _inbox.invokeMethod<String>('claim') ?? '';
    await ingestInbox(db, text);
    await _inbox.invokeMethod<void>('ack');
  } while (text.isNotEmpty);
}
