import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';

typedef AmountField = ({String label, int? initial, String? helper});

/// Returns one amount per field, null where left blank, or null if cancelled.
Future<List<int?>?> showAmountDialog(
  BuildContext context, {
  required String title,
  required List<AmountField> fields,
}) => showDialog<List<int?>>(
  context: context,
  builder: (_) => _AmountDialog(title, fields),
);

class _AmountDialog extends StatefulWidget {
  const _AmountDialog(this.title, this.fields);

  final String title;
  final List<AmountField> fields;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _form = GlobalKey<FormState>();
  late final _controllers = [
    for (final field in widget.fields)
      TextEditingController(
        text: field.initial == null
            ? ''
            : Money.format(field.initial!).replaceFirst('₹', ''),
      ),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop([
      for (final controller in _controllers)
        controller.text.trim().isEmpty ? null : Money.tryParse(controller.text),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, field) in widget.fields.indexed)
              TextFormField(
                controller: _controllers[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(
                  labelText: field.label,
                  prefixText: '₹',
                  helperText: field.helper,
                  helperMaxLines: 2,
                ),
                validator: (text) =>
                    text!.trim().isEmpty || Money.tryParse(text) != null
                    ? null
                    : 'Enter an amount',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
