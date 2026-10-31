import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BackdropFilterLayer;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/app/glass.dart';
import 'package:paisa/app/month_picker.dart';
import 'package:paisa/app/shell_widgets.dart';
import 'package:paisa/core/theme/motion.dart';
import 'package:paisa/data/database.dart';
import 'package:paisa/data/providers.dart';
import 'package:paisa/domain/models.dart';
import 'package:paisa/features/expenses/expenses_screen.dart';

Widget _app(Widget home, {GlassStyle? glass}) => ProviderScope(
  overrides: [glassProvider.overrideWith((ref) async => glass)],
  child: MaterialApp(home: Scaffold(body: home)),
);

class _Amount extends StatefulWidget {
  const _Amount();

  @override
  State<_Amount> createState() => _AmountState();
}

class _AmountState extends State<_Amount> {
  var paise = 10000;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => paise = 20000),
    child: CountUpMoney(paise),
  );
}

void main() {
  test('glass needs iOS 26 or later', () {
    expect(glassSupported(true, 'Version 26.0 (Build 23A)'), isTrue);
    expect(glassSupported(true, 'Version 27.2 (Build 24C)'), isTrue);
    expect(glassSupported(true, 'Version 18.5 (Build 22F)'), isFalse);
    expect(glassSupported(false, 'Version 27.2'), isFalse);
    expect(glassSupported(true, 'unknown'), isFalse);
  });

  testWidgets('an amount counts up, and is instant under Reduce Motion', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(const _Amount()));
    expect(find.text('₹100.00'), findsOneWidget);

    await tester.tap(find.byType(_Amount));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('₹100.00'), findsNothing);
    expect(find.text('₹200.00'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('₹200.00'), findsOneWidget);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(const _Amount()));
    await tester.tap(find.byType(_Amount));
    await tester.pump();
    await tester.pump();
    expect(find.text('₹200.00'), findsOneWidget);
  });

  testWidgets('rows fade in up to the cap, and not under Reduce Motion', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    Widget list() => ListView(
      children: [
        for (final i in [0, 9, 10])
          FadeSlideIn(key: ValueKey(i), index: i, child: Text('row $i')),
      ],
    );
    Finder fade(int i) => find.descendant(
      of: find.byKey(ValueKey(i)),
      matching: find.byType(FadeTransition),
    );
    double opacity(int i) =>
        tester.widget<FadeTransition>(fade(i)).opacity.value;

    await tester.pumpWidget(_app(list()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(0), greaterThan(opacity(9))); // staggered
    expect(fade(10), findsNothing);
    await tester.pumpAndSettle();
    expect(opacity(9), 1);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(list()));
    expect(fade(0), findsNothing);
  });

  testWidgets('the nav pill slides between tabs, and is instant when reduced', (
    tester,
  ) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    Widget nav(int selected) => _app(
      PillNavBar(
        items: const [
          (icon: Icons.home, label: 'A'),
          (icon: Icons.star, label: 'B'),
        ],
        selectedIndex: selected,
        onSelected: (_) {},
      ),
    );
    double pillLeft() => tester
        .getTopLeft(
          find.descendant(
            of: find.byType(AnimatedAlign),
            matching: find.byType(DecoratedBox),
          ),
        )
        .dx;

    await tester.pumpWidget(nav(0));
    await tester.pump();
    final start = pillLeft();
    await tester.pumpWidget(nav(1));
    await tester.pump(const Duration(milliseconds: 100));
    final middle = pillLeft();
    await tester.pumpAndSettle();
    final end = pillLeft();
    expect(middle, greaterThan(start));
    expect(end, greaterThan(middle));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pumpWidget(nav(0));
    await tester.pump();
    await tester.pump();
    expect(pillLeft(), start);
  });

  testWidgets('glass paints a backdrop filter', (tester) async {
    Widget surface(GlassStyle? glass) => ProviderScope(
      overrides: [glassProvider.overrideWith((ref) async => glass)],
      child: MaterialApp(
        home: GlassSurface(
          borderRadius: BorderRadius.circular(16),
          child: const TextField(),
        ),
      ),
    );
    await tester.pumpWidget(surface(const GlassStyle()));
    await tester.pump();
    expect(
      tester.layers.whereType<BackdropFilterLayer>(),
      isNotEmpty,
      reason: 'glass paints a backdrop filter',
    );
  });

  testWidgets('a flat surface paints no backdrop filter', (tester) async {
    await tester.pumpWidget(
      _app(
        GlassSurface(
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(height: 40),
        ),
      ),
    );
    await tester.pump();
    expect(tester.layers.whereType<BackdropFilterLayer>(), isEmpty);
  });

  testWidgets('a sheet over a sheet is flat', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context,
              builder: (sheet) => TextButton(
                onPressed: () => showAppSheet<void>(
                  sheet,
                  builder: (_) => const Text('inner'),
                ),
                child: const Text('outer'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        glass: const GlassStyle(),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.layers.whereType<BackdropFilterLayer>(), hasLength(1));
    await tester.tap(find.text('outer'));
    await tester.pumpAndSettle();
    expect(find.text('inner'), findsOneWidget);
    expect(tester.layers.whereType<BackdropFilterLayer>(), hasLength(1));
  });

  testWidgets('a swipe moves the content with the finger, then settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const MonthSwipe(child: SizedBox(height: 100, child: Text('hero')))),
    );
    final start = tester.getTopLeft(find.text('hero')).dx;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('hero')),
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.text('hero')).dx, greaterThan(start));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('hero')).dx, start);
  });

  testWidgets('Activity with 500 rows builds only what is near the screen, '
      'and a swipe-delete and the FAB give haptics', (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    final now = DateTime.now();
    await tester.runAsync(() async {
      for (var i = 0; i < 500; i++) {
        await db.addTransaction(
          TransactionsCompanion.insert(
            type: TransactionType.debit,
            amountPaise: 1000 + i,
            occurredAt: DateTime(now.year, now.month, 1 + i % 28, 9, i % 60),
            source: TransactionSource.manual,
            counterparty: Value('Shop $i'),
          ),
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile), findsWidgets);
    expect(
      find.byType(TransactionTile, skipOffstage: false).evaluate().length,
      lessThan(100),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(haptics, contains('HapticFeedbackType.lightImpact'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
