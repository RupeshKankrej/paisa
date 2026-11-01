import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

const _channel = MethodChannel('paisa/widget');

/// home_widget can only write to UserDefaults, and SPEC 3.3 wants a file, so the
/// file goes over our own channel and home_widget does the timeline reload.
Future<void> publishWidgetSummary(String json) async {
  await _channel.invokeMethod<void>('write', json);
  for (final kind in const [
    'PaisaWidget',
    'PaisaLeftWidget',
    'PaisaCategoriesWidget',
    'PaisaExpensesWidget',
  ]) {
    await HomeWidget.updateWidget(iOSName: kind);
  }
}
