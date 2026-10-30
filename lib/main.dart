import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

// Phase 0 only: shows the raw App Group inbox so the spike can be checked on the phone.
class _MainAppState extends State<MainApp> {
  static const _inbox = MethodChannel('paisa/inbox');

  String _contents = 'Loading…';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    String contents;
    try {
      final text = await _inbox.invokeMethod<String>('read') ?? '';
      contents = text.isEmpty ? 'Inbox is empty' : text;
    } on PlatformException catch (e) {
      contents = 'Could not read inbox: ${e.message}';
    }
    if (mounted) setState(() => _contents = contents);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('inbox.jsonl'),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_contents),
        ),
      ),
    );
  }
}
