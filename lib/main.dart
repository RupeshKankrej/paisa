import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';

void main() {
  runApp(const ProviderScope(child: PaisaApp()));
}

class PaisaApp extends ConsumerStatefulWidget {
  const PaisaApp({super.key});

  @override
  ConsumerState<PaisaApp> createState() => _PaisaAppState();
}

class _PaisaAppState extends ConsumerState<PaisaApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _drainInbox();
        ref.invalidate(widgetSummaryProvider);
      },
    );
    _drainInbox();
    ref.listenManual(widgetSummaryProvider, (_, json) {
      if (json == null) return;
      ref
          .read(widgetPublisherProvider)(json)
          .catchError(
            (Object e) => debugPrint('Widget update failed: ${e.runtimeType}'),
          );
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  // Only the type is logged: database errors can quote bank messages. Unacked
  // lines stay in the inbox and are retried on the next resume.
  void _drainInbox() => ref
      .read(inboxDrainProvider)()
      .catchError(
        (Object e) => debugPrint('Inbox ingest failed: ${e.runtimeType}'),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Paisa',
      theme: appTheme(),
      routerConfig: router,
    );
  }
}
