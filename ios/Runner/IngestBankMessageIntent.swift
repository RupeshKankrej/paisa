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

    try locked(url) {
      // O_APPEND with one write() keeps lines whole if two automations fire together.
      let fd = open(url.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
      guard fd >= 0 else { throw Failure.writeFailed(errno: errno) }
      defer { close(fd) }
      let written = line.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
      guard written == line.count else { throw Failure.writeFailed(errno: errno) }
    }
  }

  /// Moves the inbox aside and returns its text. New messages start a fresh inbox.
  /// A claim left unacked by a crash is returned again, before anything newer.
  static func claim(from url: URL) throws -> String {
    let claimed = claimedURL(for: url)
    let files = FileManager.default
    try locked(url) {
      if !files.fileExists(atPath: claimed.path) && files.fileExists(atPath: url.path) {
        try files.moveItem(at: url, to: claimed)
      }
    }
    guard files.fileExists(atPath: claimed.path) else { return "" }
    // Decoding repairs bad bytes, so one torn line cannot block the inbox forever.
    return String(decoding: try Data(contentsOf: claimed), as: UTF8.self)
  }

  /// Call only after the claimed lines are committed to the database.
  static func ack(for url: URL) throws {
    let claimed = claimedURL(for: url)
    if FileManager.default.fileExists(atPath: claimed.path) {
      try FileManager.default.removeItem(at: claimed)
    }
  }

  private static func claimedURL(for url: URL) -> URL {
    url.appendingPathExtension("claimed")
  }

  // Without this, a writer that opened the inbox just before a claim's rename could
  // write into the claimed file after it was read, and the ack would delete that line.
  // If the lock cannot be opened, carry on: losing the message outright is worse.
  private static func locked(_ url: URL, _ body: () throws -> Void) rethrows {
    let lock = open(url.path + ".lock", O_RDWR | O_CREAT, 0o644)
    defer { if lock >= 0 { close(lock) } }
    if lock >= 0 { flock(lock, LOCK_EX) }
    try body()
  }
}
