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

enum Inbox {
  enum Failure: Error {
    case appGroupUnavailable
    case writeFailed(errno: Int32)
  }

  static func url() throws -> URL {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.rupeshkankrej.paisa")
    else { throw Failure.appGroupUnavailable }
    return container.appendingPathComponent("inbox.jsonl")
  }

  static func append(_ text: String, to url: URL, now: Date = Date()) throws {
    var line = try JSONSerialization.data(
      withJSONObject: [
        "text": text,
        "received_at": ISO8601DateFormatter().string(from: now),
        "source": "intent",
      ],
      options: [.sortedKeys, .withoutEscapingSlashes])
    line.append(0x0A)

    // O_APPEND with one write() keeps lines whole if two automations fire together.
    let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
    guard fd >= 0 else { throw Failure.writeFailed(errno: errno) }
    defer { close(fd) }
    let written = line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    guard written == line.count else { throw Failure.writeFailed(errno: errno) }
  }

  static func read() throws -> String {
    let url = try url()
    guard FileManager.default.fileExists(atPath: url.path) else { return "" }
    return try String(contentsOf: url, encoding: .utf8)
  }
}
