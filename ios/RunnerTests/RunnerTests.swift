import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testAppendWritesOneJsonObjectPerLine() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let multiline = "Sent Rs.120.00\nFrom HDFC Bank A/C *2703 \"quoted\""

    try Inbox.append(multiline, to: url, now: Date(timeIntervalSince1970: 0))
    try Inbox.append("second", to: url)

    let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
    XCTAssertEqual(lines.count, 2)
    let first = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: String])
    XCTAssertEqual(
      first, ["text": multiline, "received_at": "1970-01-01T00:00:00Z", "source": "intent"])
  }

}
