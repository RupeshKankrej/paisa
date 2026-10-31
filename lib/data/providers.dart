import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ingest/inbox_reader.dart';
import 'database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(databaseProvider).watchCategories(),
);

final trackedSendersProvider = StreamProvider<List<TrackedSender>>(
  (ref) => ref.watch(databaseProvider).watchTrackedSenders(),
);

final importedCountProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchImportedCount(),
);

final failedMessagesProvider = StreamProvider<List<IngestLogRow>>(
  (ref) => ref.watch(databaseProvider).watchFailedMessages(),
);

/// Launch and resume can overlap, and two drains must not share one claimed file.
final inboxDrainProvider = Provider<Future<void> Function()>((ref) {
  Future<void>? running;
  return () =>
      running ??= drainInbox(ref.read(databaseProvider))
          .whenComplete(() => running = null);
});
