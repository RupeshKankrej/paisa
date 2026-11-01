import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/month_picker.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/quanto_csv.dart';
import 'ai_export.dart';
import 'data_transfer.dart';
import 'workbook.dart';

/// Hands a finished file to the iOS share sheet.
final fileSharerProvider = Provider<Future<void> Function(String, Rect?)>(
  (ref) =>
      (path, origin) => SharePlus.instance.share(
        ShareParams(files: [XFile(path)], sharePositionOrigin: origin),
      ),
);

/// Path of a file the user picked, or null if they cancelled. A null [extension]
/// offers every file, as iOS has no type for a .sqlite backup.
final filePickerProvider = Provider<Future<String?> Function(String?)>(
  (ref) => (extension) async {
    final picked = await FilePicker.pickFiles(
      type: extension == null ? FileType.any : FileType.custom,
      allowedExtensions: extension == null ? null : [extension],
    );
    return picked.isEmpty ? null : picked.single.path;
  },
);

/// Where files are written before sharing and backups are unpacked.
final workDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}_'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// Actions for one row of the Data section; the rows are built in Settings.
class DataActions {
  DataActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  AppDatabase get _db => ref.read(databaseProvider);

  void _say(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message), persist: false));
    }
  }

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  /// Writes the file [write] gives into the work directory and shares it.
  Future<void> _share(String name, Future<void> Function(File) write) async {
    try {
      final dir = await ref.read(workDirectoryProvider)();
      final file = File('${dir.path}/$name');
      await write(file);
      await ref.read(fileSharerProvider)(file.path, _origin());
    } on Exception catch (e) {
      _say('Export failed: $e');
    }
  }

  Future<WorkbookData> _workbookData() async => (
    rows: await _db.select(_db.transactions).get(),
    categories: await _db.watchCategories().first,
    budgets: await _db.watchBudgetAmounts().first,
    salaries: await _db.watchSalaryAmounts().first,
    salaryDay: await _db.watchSalaryDay().first,
  );

  Future<void> exportMonth() async {
    final month = await showMonthSheet(context);
    if (month == null) return;
    await _share(
      workbookFileName(month, await _db.watchSalaryDay().first),
      (f) async => f.writeAsBytes(monthWorkbook(await _workbookData(), month)),
    );
  }

  Future<void> exportAllMonths() => _share(
    'Paisa_all_months.xlsx',
    (f) async => f.writeAsBytes(allMonthsWorkbook(await _workbookData())),
  );

  Future<void> exportCsvFile() => _share(
    'Paisa_Transactions_${_stamp(DateTime.now())}.csv',
    (f) async => f.writeAsString(await exportCsv(_db)),
  );

  Future<void> exportJsonFile() => _share(
    'Paisa_${_stamp(DateTime.now())}.json',
    (f) async => f.writeAsString(await exportJson(_db, DateTime.now())),
  );

  Future<void> exportForAi() => _share(
    'Paisa_for_AI_${_stamp(DateTime.now())}.md',
    (f) async =>
        f.writeAsString(aiReport(await _workbookData(), DateTime.now())),
  );

  Future<void> backup() => _share(
    'Paisa_backup_${_stamp(DateTime.now())}.sqlite',
    (f) => writeBackup(_db, f.path),
  );

  Future<void> importCsv() async {
    final path = await ref.read(filePickerProvider)('csv');
    if (path == null) return;
    final ImportPlan plan;
    try {
      plan = await planImport(
        _db,
        parseQuantoCsv(await File(path).readAsString()),
      );
    } on FormatException catch (e) {
      return _say('Could not read this file. ${e.message}');
    } on FileSystemException {
      return _say('Could not read this file. It must be UTF-8 text.');
    }
    if (!context.mounted) return;
    final count = plan.newRows.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import transactions'),
        content: Text(
          [
            '$count new',
            '${plan.alreadyThere} already in Paisa, skipped',
            if (plan.newCategories.isNotEmpty)
              'New categories: ${plan.newCategories.join(', ')}',
            if (plan.badLines.isNotEmpty)
              'Unreadable, skipped: line ${plan.badLines.join(', ')}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          if (count > 0)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Import $count'),
            ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await applyImport(_db, plan.newRows);
      _say('Imported $count transactions');
    } on Exception catch (e) {
      _say('Import failed, nothing was added: $e');
    }
  }

  Future<void> restore() async {
    final source = await ref.read(filePickerProvider)(null);
    if (source == null) return;
    final dir = await ref.read(workDirectoryProvider)();
    final work = File('${dir.path}/restore_${_stamp(DateTime.now())}.sqlite');
    try {
      final count = await prepareRestore(source, work.path, _db.schemaVersion);
      if (!context.mounted) return;
      final answer = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace all data?'),
          content: Text(
            'Everything in Paisa now is replaced by this backup of $count '
            'transactions. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('backup'),
              child: const Text('Back up first'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('restore'),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (answer == 'backup') return await backup();
      if (answer != 'restore') return;
      await applyRestore(_db, work.path);
      ref.read(pickedMonthProvider.notifier).state = null;
      ref.invalidate(cardMonthProvider);
      _say('Restored $count transactions');
    } on RestoreException catch (e) {
      _say(e.message);
    } on Exception catch (e) {
      _say('Restore failed, your data was not changed: $e');
    } finally {
      if (work.existsSync()) work.deleteSync();
    }
  }
}

const csvFormatNote =
    'CSV uses the Quanto columns. Importing skips rows already in Paisa.';
