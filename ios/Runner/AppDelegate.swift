import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var emojiInput: EmojiInput?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    emojiInput = EmojiInput(
      channel: FlutterMethodChannel(
        name: "paisa/emoji", binaryMessenger: engineBridge.applicationRegistrar.messenger()))

    FlutterMethodChannel(
      name: "paisa/accessibility", binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "reduceTransparency" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(UIAccessibility.isReduceTransparencyEnabled)
    }

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

/// Flutter cannot ask iOS for the emoji keyboard, but a native field can.
private final class EmojiTextField: UITextField {
  override var textInputMode: UITextInputMode? {
    UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
  }

  // Without this iOS restores the last keyboard used instead of asking above.
  override var textInputContextIdentifier: String? { "" }
}

/// A hidden field that only summons the keyboard; the tile is drawn in Flutter.
private final class EmojiInput: NSObject, UITextFieldDelegate {
  private let channel: FlutterMethodChannel
  private var field: EmojiTextField?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "open":
        self?.open()
        result(nil)
      case "close":
        self?.close()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func open() {
    close()
    let window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
    let field = EmojiTextField(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    field.alpha = 0
    field.keyboardAppearance = .dark
    field.delegate = self
    window?.addSubview(field)
    field.becomeFirstResponder()
    self.field = field
  }

  private func close() {
    field?.resignFirstResponder()
    field?.removeFromSuperview()
    field = nil
  }

  func textField(
    _ textField: UITextField, shouldChangeCharactersIn range: NSRange,
    replacementString string: String
  ) -> Bool {
    if !string.isEmpty { channel.invokeMethod("typed", arguments: string) }
    return false
  }
}
