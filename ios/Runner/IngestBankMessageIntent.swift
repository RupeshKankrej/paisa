import AppIntents
import Foundation

struct IngestBankMessageIntent: AppIntent {
  static let title: LocalizedStringResource = "Ingest bank message"
  static let openAppWhenRun = false

  @Parameter(title: "Message")
  var text: String

  static var parameterSummary: some ParameterSummary {
    Summary("Ingest \(\.$text)")
  }

  func perform() async throws -> some IntentResult {
    try Inbox.append(text, to: Inbox.url())
    return .result()
  }
}
