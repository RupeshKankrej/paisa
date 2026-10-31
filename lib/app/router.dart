import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/budgets/categories_screen.dart';
import '../features/dashboards/dashboards_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';

final router = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) => widgetLink(state.uri),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _TabShell(shell: shell),
      branches: [
        _tab('/home', const HomeScreen()),
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
        _tab('/dashboards', const DashboardsScreen()),
        _tab('/settings', const SettingsScreen()),
      ],
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

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Dashboards',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
