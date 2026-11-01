import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/motion.dart';
import '../features/budgets/budget_screen.dart';
import '../features/budgets/categories_screen.dart';
import '../features/dashboards/dashboards_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/settings/accounts_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell_widgets.dart';

final router = GoRouter(
  initialLocation: '/expenses',
  redirect: (context, state) => widgetLink(state.uri),
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => _TabShell(shell: shell),
      navigatorContainerBuilder: (context, shell, children) =>
          _SlidingTabs(index: shell.currentIndex, children: children),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/expenses',
              builder: (context, state) => ExpensesScreen(
                addRequest: state.uri.queryParameters['add'],
                addIncome: state.uri.queryParameters['type'] == 'income',
                addCategory: int.tryParse(
                  state.uri.queryParameters['category'] ?? '',
                ),
              ),
            ),
          ],
        ),
        _tab('/categories', const CategoriesScreen()),
        _tab('/budget', const BudgetScreen()),
        _tab('/dashboards', const DashboardsScreen()),
        _tab('/accounts', const AccountsScreen()),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

/// Where a widget tap goes (SPEC 6). Each add link gets a new value, so a second
/// tap opens the sheet again.
String? widgetLink(Uri uri) {
  if (uri.scheme != 'paisa') return null;
  return switch (uri.host) {
    'add' => Uri(
      path: '/expenses',
      queryParameters: {
        ...uri.queryParameters,
        'add': '${DateTime.now().microsecondsSinceEpoch}',
      },
    ).toString(),
    'dashboards' => '/dashboards',
    _ => '/expenses',
  };
}

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

const _navItems = <PillNavItem>[
  (
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: 'Activity',
  ),
  (
    icon: Icons.pie_chart_outline,
    selectedIcon: Icons.pie_chart,
    label: 'Summary',
  ),
  (
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    label: 'Budget',
  ),
  (
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    label: 'Analytics',
  ),
  (
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance,
    label: 'Accounts',
  ),
];

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // lists scroll under the floating pill
      body: shell,
      bottomNavigationBar: PillNavBar(
        items: _navItems,
        selectedIndex: shell.currentIndex,
        onSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}

/// The tabs, kept alive as in an IndexedStack. Changing tab slides the old page
/// out and the new one in from the side it lies on (SPEC 5.15, reference 27).
class _SlidingTabs extends StatefulWidget {
  const _SlidingTabs({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_SlidingTabs> createState() => _SlidingTabsState();
}

class _SlidingTabsState extends State<_SlidingTabs>
    with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  )..addListener(_syncShifts);
  late final _eased = _slide.drive(CurveTween(curve: Curves.easeOutCubic));
  late final _shifts = [for (final _ in widget.children) ValueNotifier(0.0)];
  late final _entries = List.filled(widget.children.length, 0);
  late int _from = widget.index;

  /// Where a page sits now, in screen widths from its place.
  double _offset(int i) {
    final direction = widget.index > _from ? 1.0 : -1.0;
    if (i == widget.index) return direction * (1 - _eased.value);
    if (i == _from) return -direction * _eased.value;
    return 0;
  }

  void _syncShifts() {
    final width = MediaQuery.sizeOf(context).width;
    for (final (i, shift) in _shifts.indexed) {
      shift.value = _offset(i) * width;
    }
  }

  @override
  void didUpdateWidget(_SlidingTabs old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    _from = old.index;
    _entries[widget.index]++;
    if (context.reduceMotion) {
      _slide.value = 1;
    } else {
      _slide.forward(from: 0);
    }
    _syncShifts();
  }

  @override
  void dispose() {
    _slide.dispose();
    for (final shift in _shifts) {
      shift.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _slide,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, child) in widget.children.indexed) _branch(i, child),
      ],
    ),
  );

  Widget _branch(int i, Widget child) {
    final visible = i == widget.index || (i == _from && _slide.isAnimating);
    return TickerMode(
      enabled: visible,
      child: Offstage(
        offstage: !visible,
        child: RepaintBoundary(
          child: FractionalTranslation(
            translation: Offset(visible ? _offset(i) : 0, 0),
            child: TabScope(
              active: i == widget.index,
              entries: _entries[i],
              shift: _shifts[i],
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
