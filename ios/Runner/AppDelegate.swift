import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    FlutterMethodChannel(
      name: "paisa/inbox", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "claim": result(try Inbox.claim(from: Inbox.url()))
        case "ack":
          try Inbox.ack(for: Inbox.url())
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "inbox", message: "\(error)", details: nil))
      }
    }

    FlutterMethodChannel(
      name: "paisa/widget", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "write", let json = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        // Atomic, so the widget can never read a half-written file.
        try Data(json.utf8).write(
          to: Inbox.url().deletingLastPathComponent()
            .appendingPathComponent("widget_summary.json"),
          options: .atomic)
        result(nil)
      } catch {
        result(FlutterError(code: "widget", message: "\(error)", details: nil))
      }
    }
  }
}
