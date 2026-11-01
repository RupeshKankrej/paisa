import UIKit
import UniformTypeIdentifiers

/// Manual fallback for the automation (SPEC 2.3): appends shared text to the inbox.
/// The app parses it on next open, so an alert is the only feedback possible here.
final class ShareViewController: UIViewController {
  private var started = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !started else { return }
    started = true
    Task { await run() }
  }

  private func run() async {
    guard let text = await sharedText() else {
      return finish("Nothing to add", "This share has no text in it.")
    }
    do {
      try Inbox.append(text, to: Inbox.url(), source: "share")
      finish("Sent to Paisa", "It appears when you next open the app.")
    } catch {
      finish("Could not add this", "\(error)")
    }
  }

  private func sharedText() async -> String? {
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    for item in items {
      if let text = item.attributedContentText?.string, !text.isEmpty { return text }
      for provider in item.attachments ?? []
      where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
          as? String, !text.isEmpty
        {
          return text
        }
      }
    }
    return nil
  }

  @MainActor private func finish(_ title: String, _ message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(
      UIAlertAction(title: "OK", style: .default) { [weak self] _ in
        self?.extensionContext?.completeRequest(returningItems: nil)
      })
    present(alert, animated: true)
  }
}
