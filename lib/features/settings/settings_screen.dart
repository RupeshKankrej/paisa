import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senders = ref.watch(trackedSendersProvider).value ?? const [];
    final imported = ref.watch(importedCountProvider).value ?? 0;
    final failed = ref.watch(failedMessagesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Tracked senders'),
            subtitle: Text('Only messages containing a pattern are read.'),
          ),
          for (final sender in senders)
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(sender.label),
              subtitle: Text(
                '${sender.matchPattern} · ${sender.bank.name.toUpperCase()}',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add tracked sender'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _AddSenderDialog(ref.read(databaseProvider)),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Imported messages'),
            trailing: Text('$imported'),
          ),
          ListTile(
            title: const Text('Unparsed messages'),
            trailing: Text('${failed.length}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _UnparsedScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSenderDialog extends StatefulWidget {
  const _AddSenderDialog(this.db);

  final AppDatabase db;

  @override
  State<_AddSenderDialog> createState() => _AddSenderDialogState();
}

class _AddSenderDialogState extends State<_AddSenderDialog> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _pattern = TextEditingController();
  Bank _bank = Bank.hdfc;

  @override
  void dispose() {
    _label.dispose();
    _pattern.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await widget.db
        .into(widget.db.trackedSenders)
        .insert(
          TrackedSendersCompanion(
            label: Value(_label.text.trim()),
            matchPattern: Value(_pattern.text.trim()),
            bank: Value(_bank),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add tracked sender'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
              validator: _required,
            ),
            TextFormField(
              controller: _pattern,
              decoration: const InputDecoration(labelText: 'Message contains'),
              validator: _required,
            ),
            DropdownButtonFormField<Bank>(
              initialValue: _bank,
              decoration: const InputDecoration(labelText: 'Bank'),
              items: [
                for (final bank in Bank.values)
                  DropdownMenuItem(
                    value: bank,
                    child: Text(bank.name.toUpperCase()),
                  ),
              ],
              onChanged: (bank) => setState(() => _bank = bank!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}

class _UnparsedScreen extends ConsumerWidget {
  const _UnparsedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(failedMessagesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Unparsed messages')),
      body: failed.isEmpty
          ? const Center(child: Text('No unparsed messages'))
          : ListView(
              children: [
                for (final message in failed)
                  ListTile(title: SelectableText(message.rawText ?? '')),
              ],
            ),
    );
  }
}
