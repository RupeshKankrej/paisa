import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme/tokens.dart';

import 'package:flutter/services.dart';

/// The hero amount as typed, with a backspace that clears all on a long press.
class KeypadAmount extends StatelessWidget {
  const KeypadAmount(this.amount, {super.key, required this.onChanged});

  final String amount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 48), // balances the backspace
      Expanded(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Money.keypadDisplay(amount),
              key: const Key('sheet-amount'),
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
        ),
      ),
      GestureDetector(
        onLongPress: () => onChanged(''),
        // A tooltip's own long press would win the gesture and block the clear.
        child: Tooltip(
          message: 'Backspace',
          triggerMode: TooltipTriggerMode.manual,
          child: IconButton(
            icon: const Icon(Icons.backspace_outlined),
            color: context.palette.textSecondary,
            onPressed: amount.isEmpty
                ? null
                : () => onChanged(amount.substring(0, amount.length - 1)),
          ),
        ),
      ),
    ],
  );
}

/// The 3x4 keypad with an arrow key to confirm. A null [onSubmit] disables it.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey, required this.onSubmit});

  final ValueChanged<String> onKey;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget digit(String key) => _Key(
      key: Key('key-$key'),
      color: palette.surface,
      onTap: () => onKey(key),
      child: Text(
        key,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      ),
    );
    return Column(
      spacing: 8,
      children: [
        for (final row in const ['123', '456', '789'])
          Row(
            spacing: 8,
            children: [
              for (final key in row.split('')) Expanded(child: digit(key)),
            ],
          ),
        Row(
          spacing: 8,
          children: [
            Expanded(child: digit('.')),
            Expanded(child: digit('0')),
            Expanded(
              child: _Key(
                key: const Key('key-save'),
                color: onSubmit == null ? palette.surface : palette.accent,
                onTap: onSubmit == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onSubmit!();
                      },
                child: Icon(
                  Icons.arrow_forward,
                  color: onSubmit == null ? palette.textSecondary : palette.bg,
                  semanticLabel: 'Save',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.onTap,
    required this.child,
    required this.color,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(AppRadii.chip),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(height: 60, child: Center(child: child)),
    ),
  );
}
