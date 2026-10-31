import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _TabShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/expenses',
              builder: (context, state) =>
                  ExpensesScreen(addRequest: state.uri.queryParameters['add']),
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
  return uri.host == 'add'
      ? '/expenses?add=${DateTime.now().microsecondsSinceEpoch}'
      : '/expenses';
}

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

const _navItems = <PillNavItem>[
  (icon: Icons.receipt_long, label: 'Activity'),
  (icon: Icons.pie_chart_outline, label: 'Summary'),
  (icon: Icons.account_balance_wallet_outlined, label: 'Budget'),
  (icon: Icons.bar_chart, label: 'Analytics'),
  (icon: Icons.account_balance_outlined, label: 'Accounts'),
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
