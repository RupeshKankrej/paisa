import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/main.dart';

void main() {
  testWidgets('five tabs switch, and Categories lists categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
  });
}
