import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/core/theme/tokens.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/features/settings/settings_screen.dart';
import 'package:paisa/main.dart';

void main() {
  testWidgets('adding a tracked sender needs both fields, then saves it', (
    tester,
  ) async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HDFC Bank · HDFC'), findsOneWidget);

    await tester.tap(find.text('Add tracked sender'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));

    await tester.enterText(find.widgetWithText(TextFormField, 'Label'), 'Card');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Message contains'),
      ' HDFCBK ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Card'), findsOneWidget);
    expect(find.text('HDFCBK · HDFC'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Appearance is saved and themes the whole app', (tester) async {
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
          inboxDrainProvider.overrideWithValue(() async {}),
        ],
        child: const PaisaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    AppPalette palette() => tester.element(find.byType(SettingsScreen)).palette;
    for (final (label, mode, expected) in [
      ('Dark', 'dark', AppPalette.dark),
      ('Light', 'light', AppPalette.light),
    ]) {
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => db.watchSetting(appearanceKey).first),
        mode,
      );
      expect(palette().bg, expected.bg);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
