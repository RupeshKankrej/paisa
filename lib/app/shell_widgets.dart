import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../core/theme/motion.dart';
import '../core/theme/tokens.dart';
import '../features/expenses/transaction_sheet.dart';
import 'glass.dart';
import 'month_picker.dart';

const _navHeight = 64.0;
const _navGap = 8.0;

/// App bar for a tab: settings button on the left, month dropdown or a title.
AppBar tabAppBar({Widget title = const MonthPicker(), List<Widget>? actions}) =>
    AppBar(
      leading: const _SettingsButton(),
      leadingWidth: 64,
      title: title,
      actions: actions,
    );

/// App bar for a tab whose page scrolls under it, month dropdown in the page.
AppBar floatingTabAppBar() => tabAppBar(title: const SizedBox.shrink());

/// Where a page under [floatingTabAppBar] starts, measured from a context above
/// its Scaffold, which has not yet added the bar to the insets.
double belowFloatingBar(BuildContext context) =>
    MediaQuery.paddingOf(context).top + kToolbarHeight;

/// List bottom padding that clears the pill nav and the FAB above it.
EdgeInsets listClearance(BuildContext context) =>
    EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 88);

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) => Center(
    child: GlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.round),
      child: IconButton(
        tooltip: 'Settings',
        icon: Icon(Icons.settings, color: context.palette.textPrimary),
        onPressed: () => context.push('/settings'),
      ),
    ),
  );
}

/// The round add button every tab shows, lifted clear of the pill nav.
class AddFab extends ConsumerStatefulWidget {
  const AddFab({super.key});

  @override
  ConsumerState<AddFab> createState() => _AddFabState();
}

class _AddFabState extends ConsumerState<AddFab> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Reading the view does not subscribe to it, and the first frame on a phone
  // can have no safe area yet, which left the button under the pill.
  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) => Padding(
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
    child: GlassSurface(
      borderRadius: BorderRadius.circular(AppRadii.round),
      color: context.palette.accent,
      opacity: 0.78,
      child: FloatingActionButton(
        heroTag: null, // one per tab, all alive in the shell's IndexedStack
        tooltip: 'Add transaction',
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        onPressed: () {
          HapticFeedback.lightImpact();
          openTransactionSheet(context, ref);
        },
        child: const Icon(Icons.add),
      ),
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
      child: CountUpMoney(
        paise,
        style: Theme.of(context).textTheme.displayLarge,
      ),
    ),
  );
}

/// An amount that counts to its new value when it changes (SPEC 5.15).
class CountUpMoney extends StatelessWidget {
  const CountUpMoney(this.paise, {super.key, this.style});

  final int paise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
    tween: IntTween(end: paise),
    duration: context.motion(),
    curve: Curves.easeOut,
    builder: (context, value, _) => Text(Money.format(value), style: style),
  );
}

/// A small count or percentage beside an amount.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: context.palette.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadii.chip),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
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

/// The floating bottom nav (SPEC 5.12). Its selector is a lens that lifts out of
/// the bar while it travels, follows a drag along the bar and springs to a tab
/// (SPEC 5.15).
class PillNavBar extends StatefulWidget {
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
  State<PillNavBar> createState() => _PillNavBarState();
}

class _PillNavBarState extends State<PillNavBar> with TickerProviderStateMixin {
  static const _padding = 4.0;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 26,
  );

  /// The selector's position in tabs, so 1.5 is halfway from the second to the third.
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  late final _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  late int _target;
  var _dragging = false;
  var _slot = 1.0;

  @override
  void initState() {
    super.initState();
    _target = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(PillNavBar old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != _target && !_dragging) {
      _glideTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _glideTo(int index, {double velocity = 0}) {
    _target = index;
    if (context.reduceMotion) {
      _position.value = index.toDouble();
      _lift.value = 0;
      return;
    }
    _lift.forward();
    _position
        .animateWith(
          SpringSimulation(
            _spring,
            _position.value,
            index.toDouble(),
            velocity,
          ),
        )
        .then((_) {
          if (mounted && !_dragging) _lift.reverse();
        });
  }

  void _dragStart(DragStartDetails _) {
    _dragging = true;
    _position.stop();
    _lift.forward();
  }

  void _dragUpdate(DragUpdateDetails details) {
    _position.value = (_position.value + details.delta.dx / _slot).clamp(
      -0.25,
      widget.items.length - 0.75,
    );
  }

  void _dragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx / _slot;
    // A flick carries on to where it would land, as a scroll does.
    final index = (_position.value + velocity * 0.12).round().clamp(
      0,
      widget.items.length - 1,
    );
    _glideTo(index, velocity: velocity);
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  void _dragCancel() {
    _dragging = false;
    _glideTo(widget.selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final reduced = context.reduceMotion;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, _navGap),
      child: SizedBox(
        height: _navHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _slot = (constraints.maxWidth - _padding * 2) / items.length;
            return GestureDetector(
              onHorizontalDragStart: reduced ? null : _dragStart,
              onHorizontalDragUpdate: reduced ? null : _dragUpdate,
              onHorizontalDragEnd: reduced ? null : _dragEnd,
              onHorizontalDragCancel: reduced ? null : _dragCancel,
              child: AnimatedBuilder(
                animation: Listenable.merge([_position, _lift]),
                builder: (context, _) {
                  final lift = Curves.easeOut.transform(_lift.value);
                  final center = _padding + _slot * (_position.value + 0.5);
                  // It stretches along its travel and thins, like a drop.
                  final stretch = (_position.velocity.abs() * 0.04).clamp(
                    0.0,
                    0.2,
                  );
                  final restHeight = _navHeight - _padding * 2;
                  final width =
                      lerpDouble(_slot, _slot * 1.3, lift)! * (1 + stretch);
                  final height =
                      lerpDouble(restHeight, _navHeight * 1.22, lift)! *
                      (1 - stretch / 2);
                  Positioned place(Widget child) => Positioned(
                    left: center - width / 2,
                    top: (_navHeight - height) / 2,
                    width: width,
                    height: height,
                    child: IgnorePointer(child: child),
                  );
                  final lit = _position.value.round();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GlassSurface(
                          borderRadius: BorderRadius.circular(AppRadii.round),
                          // Flat, plain surface would match the cards and the
                          // pill would vanish.
                          color: context.palette.surfaceRaised,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              place(
                                DecoratedBox(
                                  key: const Key('nav-pill'),
                                  decoration: BoxDecoration(
                                    color: context.palette.bg.withValues(
                                      alpha: 0.7 * (1 - lift),
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.round,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(_padding),
                                child: Row(
                                  children: [
                                    for (final (i, item) in items.indexed)
                                      Expanded(
                                        child: _PillNavButton(
                                          item: item,
                                          selected: i == widget.selectedIndex,
                                          lit: i == lit,
                                          onTap: () => widget.onSelected(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Above the bar, so it bends the icons and overhangs.
                      if (lift > 0) place(GlassLens(strength: lift)),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PillNavButton extends StatelessWidget {
  const _PillNavButton({
    required this.item,
    required this.selected,
    required this.lit,
    required this.onTap,
  });

  final PillNavItem item;
  final bool selected;

  /// Under the selector now, which during a drag is not yet [selected].
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = lit
        ? context.palette.textPrimary
        : context.palette.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent, // the selector sits behind
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
