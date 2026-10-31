import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/main.dart';

void main() {
  testWidgets('five tabs switch, and Categories lists categories', (
    tester,
  ) async {
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

    final bar = find.byType(NavigationBar);
    Finder tab(String label) =>
        find.descendant(of: bar, matching: find.text(label));

    for (final label in ['Home', 'Expenses', 'Dashboards', 'Settings']) {
      await tester.tap(tab(label));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, label), findsOneWidget);
    }

    await tester.tap(tab('Categories'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsOneWidget);

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
    expect(find.widgetWithText(AppBar, 'Expenses'), findsOneWidget);
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
