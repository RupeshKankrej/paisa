import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testAppendWritesOneJsonObjectPerLine() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let multiline = "Sent Rs.120.00\nFrom HDFC Bank A/C *2703 \"quoted\""

    try Inbox.append(multiline, to: url, now: Date(timeIntervalSince1970: 0))
    try Inbox.append("second", to: url, source: "share")

    let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
    XCTAssertEqual(lines.count, 2)
    let first = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: String])
    XCTAssertEqual(
      first, ["text": multiline, "received_at": "1970-01-01T00:00:00Z", "source": "intent"])
    XCTAssertTrue(lines[1].contains("\"source\":\"share\""))
  }

  func testClaimKeepsUnackedLinesAndNewArrivals() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("inbox.jsonl")

    XCTAssertEqual(try Inbox.claim(from: url), "")
    try Inbox.append("first", to: url)
    XCTAssertTrue(try Inbox.claim(from: url).contains("first"))

    // Arrives mid-processing, then the app dies before acking.
    try Inbox.append("second", to: url)
    let retried = try Inbox.claim(from: url)
    XCTAssertTrue(retried.contains("first"))
    XCTAssertFalse(retried.contains("second"))

    try Inbox.ack(for: url)
    XCTAssertTrue(try Inbox.claim(from: url).contains("second"))
    try Inbox.ack(for: url)
    XCTAssertEqual(try Inbox.claim(from: url), "")
  }

  func testQuickAddLineMatchesSpec() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }

    try Inbox.appendQuickAdd(
      type: "debit", amountPaise: 12000, categoryId: 3, name: "Chai", to: url,
      now: Date(timeIntervalSince1970: 0.123))
    try Inbox.appendQuickAdd(
      type: "credit", amountPaise: 100, categoryId: nil, name: nil, to: url)

    let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
    let first = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? NSDictionary)
    XCTAssertEqual(
      first,
      [
        "source": "quick_add", "received_at": "1970-01-01T00:00:00.123Z", "type": "debit",
        "amount_paise": 12000, "category_id": 3, "name": "Chai",
      ] as NSDictionary)
    XCTAssertFalse(lines[1].contains("category_id"))
    XCTAssertFalse(lines[1].contains("name"))
  }
}
