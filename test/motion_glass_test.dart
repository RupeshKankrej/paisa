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

  group('nav selector', () {
    // A notifier, as a pumped-in new home does not reach a built route.
    final tab = ValueNotifier(0);
    setUp(() => tab.value = 0);
    Widget nav([ValueChanged<int>? onSelected]) => _app(
      Align(
        alignment: Alignment.bottomCenter,
        child: ValueListenableBuilder(
          valueListenable: tab,
          builder: (_, selected, _) => PillNavBar(
            items: const [
              (icon: Icons.home, selectedIcon: Icons.home, label: 'A'),
              (icon: Icons.star, selectedIcon: Icons.star, label: 'B'),
              (icon: Icons.add, selectedIcon: Icons.add, label: 'C'),
            ],
            selectedIndex: selected,
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    );
    double pillCenter(WidgetTester tester) =>
        tester.getCenter(find.byKey(const Key('nav-pill'))).dx;

    testWidgets('lifts into a lens, glides to the tab and settles', (
      tester,
    ) async {
      await tester.pumpWidget(nav());
      await tester.pump();
      final start = pillCenter(tester);
      expect(find.byType(GlassLens), findsNothing);

      tab.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(GlassLens), findsOneWidget);
      expect(pillCenter(tester), greaterThan(start));

      await tester.pumpAndSettle();
      expect(find.byType(GlassLens), findsNothing);
      expect(pillCenter(tester), greaterThan(start));
    });

    testWidgets('follows a drag and selects the nearest tab on release', (
      tester,
    ) async {
      final selected = <int>[];
      await tester.pumpWidget(nav(selected.add));
      await tester.pump();
      final start = pillCenter(tester);
      final slot =
          tester.getCenter(find.text('B')).dx -
          tester.getCenter(find.text('A')).dx;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('A')),
      );
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.moveBy(Offset(slot * 1.8 - 30, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GlassLens), findsOneWidget);
      expect(selected, isEmpty); // nothing changes until release
      expect(pillCenter(tester), greaterThan(start + slot));

      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, [2]);
      expect(find.byType(GlassLens), findsNothing);
    });

    testWidgets('is instant with no lens under Reduce Motion', (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pumpWidget(nav());
      await tester.pump();
      final start = pillCenter(tester);
      tab.value = 1;
      await tester.pump();
      await tester.pump();
      expect(find.byType(GlassLens), findsNothing);
      expect(pillCenter(tester), greaterThan(start));
      expect(tester.hasRunningAnimations, isFalse);
    });
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

  testWidgets('an entrance runs from 0 to 1, replays on its key, and is 1 when '
      'reduced', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final key = ValueNotifier(0);
    var progress = 0.0;
    final app = _app(
      ValueListenableBuilder(
        valueListenable: key,
        builder: (_, value, _) => Entrance(
          replayKey: value,
          builder: (_, p, _) {
            progress = p;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(app);
    await tester.pump(const Duration(milliseconds: 100));
    expect(progress, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(progress, 1);

    key.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(progress, lessThan(1));
    await tester.pumpAndSettle();

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    key.value = 2;
    await tester.pump();
    await tester.pump();
    expect(progress, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a month swipe carries off, then the next month comes in', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [glassProvider.overrideWith((ref) async => null)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: MonthSwipe(child: SizedBox(height: 100, child: Text('hero'))),
          ),
        ),
      ),
    );
    final start = tester.getTopLeft(find.text('hero')).dx;
    final before = container.read(pickedMonthProvider);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('hero')),
    );
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    // Under the finger, past the drag slop already taken off.
    expect(tester.getTopLeft(find.text('hero')).dx, greaterThan(start + 30));
    await gesture.up();
    await tester.pump();
    expect(
      container.read(pickedMonthProvider),
      before,
    ); // not until it has left
    await tester.pumpAndSettle();
    expect(container.read(pickedMonthProvider), isNot(before));
    expect(tester.getTopLeft(find.text('hero')).dx, start);

    // The current period has nothing after it, so a left swipe only gives a bit.
    container.read(pickedMonthProvider.notifier).state = null;
    await tester.pump();
    final picked = container.read(pickedMonthProvider);
    await tester.drag(find.text('hero'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(container.read(pickedMonthProvider), picked);
    expect(tester.getTopLeft(find.text('hero')).dx, start);
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
