import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paisa/main.dart';

void main() {
  const channel = MethodChannel('paisa/inbox');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('shows inbox contents', (tester) async {
    messenger.setMockMethodCallHandler(channel, (_) async => '{"text":"hi"}\n');
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    expect(find.textContaining('{"text":"hi"}'), findsOneWidget);
  });

  testWidgets('shows the error when the App Group is unavailable', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'inbox', message: 'no group'),
    );
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    expect(find.text('Could not read inbox: no group'), findsOneWidget);
  });
}
