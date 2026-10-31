import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../core/theme/tokens.dart';
import '../features/expenses/transaction_sheet.dart';
import 'month_picker.dart';

const _navHeight = 64.0;
const _navGap = 8.0;

/// App bar for a tab: settings button on the left, month dropdown or a title.
AppBar tabAppBar({Widget title = const MonthPicker()}) =>
    AppBar(leading: const _SettingsButton(), leadingWidth: 64, title: title);

/// List bottom padding that clears the pill nav and the FAB above it.
EdgeInsets listClearance(BuildContext context) =>
    EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 88);

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      tooltip: 'Settings',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.textPrimary.withValues(alpha: 0.12),
      ),
      icon: const Icon(Icons.settings, color: AppColors.textPrimary),
      onPressed: () => context.push('/settings'),
    ),
  );
}

/// The round add button every tab shows, lifted clear of the pill nav.
class AddFab extends ConsumerWidget {
  const AddFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    // A Scaffold strips safe-area insets from its FAB, so ask the view. Less 16,
    // the margin the Scaffold already leaves below a FAB.
    padding: EdgeInsets.only(
      bottom:
          max(
            MediaQueryData.fromView(View.of(context)).viewPadding.bottom,
            _navGap,
          ) +
          _navHeight +
          12 -
          16,
    ),
    child: FloatingActionButton(
      heroTag: null, // one per tab, all alive in the shell's IndexedStack
      tooltip: 'Add transaction',
      onPressed: () => openTransactionSheet(context, ref),
      child: const Icon(Icons.add),
    ),
  );
}

/// The large amount under a month dropdown. Long amounts shrink to fit.
class HeroAmount extends StatelessWidget {
  const HeroAmount(this.paise, {super.key});

  final int paise;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        Money.format(paise),
        style: Theme.of(context).textTheme.displayLarge,
      ),
    ),
  );
}

/// Rows in one rounded card with hairlines between them.
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    child: Column(
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const Divider(),
          child,
        ],
      ],
    ),
  );
}

typedef PillNavItem = ({IconData icon, String label});

/// The floating bottom nav (SPEC 5.12).
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PillNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.fromLTRB(16, 0, 16, _navGap),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.round),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: _navHeight,
          padding: const EdgeInsets.all(4),
          color: AppColors.surfaceRaised.withValues(alpha: 0.85),
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(
                  child: _PillNavButton(
                    item: item,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PillNavButton extends StatelessWidget {
  const _PillNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PillNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.bg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.round),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 24),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
