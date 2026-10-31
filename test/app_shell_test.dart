import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/app/shell_widgets.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/features/budgets/categories_screen.dart';
import 'package:paisa/features/dashboards/dashboards_screen.dart';
import 'package:paisa/features/expenses/expenses_screen.dart';
import 'package:paisa/features/home/home_screen.dart';
import 'package:paisa/features/settings/accounts_screen.dart';
import 'package:paisa/features/settings/settings_screen.dart';
import 'package:paisa/main.dart';

void main() {
  testWidgets('five tabs switch, and Categories lists categories', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 102); // home indicator
    tester.view.viewPadding = const FakeViewPadding(bottom: 102);
    addTearDown(tester.view.reset);
    var drains = 0;
    final published = <String>[];
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          inboxDrainProvider.overrideWithValue(() async => drains++),
          widgetPublisherProvider.overrideWithValue(
            (json) async => published.add(json),
          ),
          trackedSendersProvider.overrideWith((ref) => Stream.value(const [])),
          importedCountProvider.overrideWith((ref) => Stream.value(0)),
          failedMessagesProvider.overrideWith((ref) => Stream.value(const [])),
          categoriesProvider.overrideWith(
            (ref) => Stream.value(const [
              Category(
                id: 1,
                name: 'Food',
                color: 0xFFE57373,
                icon: 'restaurant',
                sortOrder: 0,
                isArchived: false,
              ),
            ]),
          ),
        ],
        child: const PaisaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(drains, 1, reason: 'the inbox is read on launch');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(drains, 2, reason: 'and again on resume');

    final bar = find.byType(PillNavBar);
    Finder tab(String label) =>
        find.descendant(of: bar, matching: find.text(label));

    expect(find.byType(ExpensesScreen), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(FloatingActionButton)).dy,
      lessThan(tester.getTopLeft(find.byType(ClipRRect).last).dy),
      reason: 'the add button sits above the pill',
    );
    for (final (label, screen) in [
      ('Budget', HomeScreen),
      ('Analytics', DashboardsScreen),
      ('Accounts', AccountsScreen),
      ('Activity', ExpensesScreen),
    ]) {
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    }

    await tester.tap(tab('Summary'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(PillNavBar), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);

    // The add sheet opens from a tab other than Activity, and only once.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    expect(published, isNotEmpty, reason: 'the widget summary is written');

    Future<void> openLink(String link) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': link}),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await openLink('paisa://expenses');
    expect(find.byType(ExpensesScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await openLink('paisa://add');
    expect(find.byType(BottomSheet), findsOneWidget);

    // Left open and tapped again from the widget: no second sheet on top.
    await openLink('paisa://add');
    expect(find.byType(BottomSheet), findsOneWidget);

    // The Expenses link leaves it open too, so typed input is not lost.
    await openLink('paisa://expenses');
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
