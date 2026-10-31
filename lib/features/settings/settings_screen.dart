import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/amount_dialog.dart';
import '../../app/shell_widgets.dart';
import '../../core/money.dart';
import '../../core/theme/tokens.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../budgets/manage_categories_screen.dart';

// Rupesh's salary usually lands on the 28th (SPEC 5.1 sample).
const _defaultSalaryDay = 28;

const _appearanceLabels = {
  ThemeMode.system: 'System',
  ThemeMode.light: 'Light',
  ThemeMode.dark: 'Dark',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // Back to the current period, as a month picked under the old rule means
  // different dates under the new one.
  Future<void> _setSalaryDay(WidgetRef ref, int? day) async {
    await ref.read(databaseProvider).setSalaryDay(day);
    ref.read(pickedMonthProvider.notifier).state = null;
  }

  Future<void> _editSalary(
    BuildContext context,
    WidgetRef ref,
    int? salary,
  ) async {
    final result = await showAmountDialog(
      context,
      title: 'Monthly salary',
      fields: [
        (
          label: 'Default',
          initial: salary,
          helper: 'Tap the salary on the Budget tab to change a single month.',
        ),
      ],
    );
    if (result != null) {
      await ref.read(databaseProvider).setSalary(null, result.single);
    }
  }

  Future<void> _pickAppearance(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final MapEntry(key: mode, value: label)
                in _appearanceLabels.entries)
              ListTile(
                title: Text(label),
                trailing: mode == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(databaseProvider).setSetting(appearanceKey, picked.name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senders = ref.watch(trackedSendersProvider).value ?? const [];
    final imported = ref.watch(importedCountProvider).value ?? 0;
    final failed = ref.watch(failedMessagesProvider).value ?? const [];
    final salary = ref.watch(salaryAmountsProvider).value?[null];
    final salaryDay = ref.watch(salaryDayProvider).value;
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionTitle('Preferences'),
          GroupedCard(
            children: [
              _Row(
                icon: Icons.contrast,
                title: 'Appearance',
                value: _appearanceLabels[mode]!,
                onTap: () => _pickAppearance(context, ref, mode),
              ),
              _Row(
                icon: Icons.payments_outlined,
                title: 'Salary',
                value: salary == null ? 'Not set' : Money.format(salary),
                onTap: () => _editSalary(context, ref, salary),
              ),
              SwitchListTile(
                secondary: const _IconTile(Icons.calendar_month_outlined),
                title: const Text('Salary day to salary day'),
                subtitle: const Text('Off means calendar months.'),
                value: salaryDay != null,
                onChanged: (on) =>
                    _setSalaryDay(ref, on ? _defaultSalaryDay : null),
              ),
              if (salaryDay != null)
                ListTile(
                  leading: const _IconTile(Icons.event_outlined),
                  title: const Text('Salary day'),
                  trailing: DropdownButton<int>(
                    value: salaryDay,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (var day = 1; day <= 31; day++)
                        DropdownMenuItem(value: day, child: Text('$day')),
                    ],
                    onChanged: (day) => _setSalaryDay(ref, day),
                  ),
                ),
              _Row(
                icon: Icons.category_outlined,
                title: 'Categories',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManageCategoriesScreen(),
                  ),
                ),
              ),
            ],
          ),
          const _SectionTitle('Messages'),
          GroupedCard(
            children: [
              for (final sender in senders)
                ListTile(
                  leading: const _IconTile(Icons.account_balance_outlined),
                  title: Text(sender.label),
                  subtitle: Text(
                    '${sender.matchPattern} · ${sender.bank.name.toUpperCase()}',
                  ),
                ),
              _Row(
                icon: Icons.add,
                title: 'Add tracked sender',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _AddSenderDialog(ref.read(databaseProvider)),
                ),
              ),
              _Row(
                icon: Icons.mark_email_read_outlined,
                title: 'Imported messages',
                value: '$imported',
              ),
              _Row(
                icon: Icons.sms_failed_outlined,
                title: 'Unparsed messages',
                value: '${failed.length}',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _UnparsedScreen(),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(
              'Only messages containing a tracked pattern are read.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
    child: Text(title, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: context.palette.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
    child: Icon(icon, size: 20, color: context.palette.textSecondary),
  );
}

/// Icon tile, title, trailing value and a chevron when it opens something.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.value, this.onTap});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return ListTile(
      leading: _IconTile(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (value != null)
            Text(value, style: Theme.of(context).textTheme.bodySmall),
          if (onTap != null)
            Icon(Icons.chevron_right, color: context.palette.textSecondary),
        ],
      ),
      onTap: onTap,
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
