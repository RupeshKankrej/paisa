import SwiftUI
import WidgetKit

struct Summary: Decodable {
  struct TopCategory: Decodable {
    let name: String
    let color: UInt32
    let spentPaise: Int
  }

  let month: String
  let spentPaise: Int
  let salaryPaise: Int?
  let remainingPaise: Int?
  let topCategories: [TopCategory]

  static func load() -> Summary? {
    guard
      let url = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.rupeshkankrej.paisa")?
        .appendingPathComponent("widget_summary.json"),
      let data = try? Data(contentsOf: url)
    else { return nil }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try? decoder.decode(Summary.self, from: data)
  }

  static let sample = Summary(
    month: "2026-10", spentPaise: 4_250_000, salaryPaise: 15_545_300,
    remainingPaise: 11_295_300,
    topCategories: [
      TopCategory(name: "Rent", color: 0xFF5AA9F5, spentPaise: 2_500_000),
      TopCategory(name: "Food", color: 0xFFE8737A, spentPaise: 1_000_000),
    ])
}

/// Swift twin of the Dart Money helper, which the extension cannot call.
func money(_ paise: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .currency
  formatter.locale = Locale(identifier: "en_IN")
  formatter.currencySymbol = "₹"
  return formatter.string(from: Decimal(paise) / 100 as NSDecimalNumber) ?? ""
}

func monthLabel(_ key: String) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "yyyy-MM"
  guard let date = formatter.date(from: key) else { return key }
  formatter.dateFormat = "MMMM yyyy"
  return formatter.string(from: date)
}

struct Entry: TimelineEntry {
  let date: Date
  let summary: Summary?
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry { Entry(date: Date(), summary: .sample) }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(Entry(date: Date(), summary: Summary.load() ?? .sample))
  }

  // The app asks for a reload after every change, so the widget never polls.
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [Entry(date: Date(), summary: Summary.load())], policy: .never))
  }
}

struct Figures: View {
  let summary: Summary

  private var over: Bool { (summary.remainingPaise ?? 0) < 0 }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(monthLabel(summary.month)).font(.caption2).foregroundStyle(.secondary)
      Text("Spent").font(.caption).foregroundStyle(.secondary)
      Text(money(summary.spentPaise)).font(.headline).minimumScaleFactor(0.6).lineLimit(1)
      Text("Remaining").font(.caption).foregroundStyle(.secondary)
      Text(summary.remainingPaise.map(money) ?? "—")
        .font(.headline).minimumScaleFactor(0.6).lineLimit(1)
        .foregroundStyle(over ? .red : .primary)
      if let salary = summary.salaryPaise {
        // A zero salary with any spend reads as full, as on the Home card.
        ProgressView(
          value: Double(salary > 0 ? min(summary.spentPaise, salary) : 1),
          total: Double(max(salary, 1))
        )
        .tint(over ? .red : .accentColor)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct TopCategories: View {
  let categories: [Summary.TopCategory]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(categories, id: \.name) { category in
        HStack(spacing: 6) {
          Circle()
            .fill(
              Color(
                red: Double(category.color >> 16 & 0xFF) / 255,
                green: Double(category.color >> 8 & 0xFF) / 255,
                blue: Double(category.color & 0xFF) / 255)
            )
            .frame(width: 8, height: 8)
          Text(category.name).font(.caption).lineLimit(1)
          Spacer(minLength: 4)
          Text(money(category.spentPaise)).font(.caption).minimumScaleFactor(0.6).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      Link(destination: URL(string: "paisa://add")!) {
        Label("Add expense", systemImage: "plus.circle.fill").font(.caption.weight(.semibold))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct PaisaWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: Entry

  var body: some View {
    Group {
      if let summary = entry.summary {
        if family == .systemMedium {
          HStack(spacing: 16) {
            Figures(summary: summary)
            TopCategories(categories: summary.topCategories)
          }
        } else {
          Figures(summary: summary)
        }
      } else {
        Text("Open Paisa to see this month").font(.caption).foregroundStyle(.secondary)
      }
    }
    .containerBackground(.background, for: .widget)
    .widgetURL(URL(string: "paisa://expenses"))
  }
}

@main
struct PaisaWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PaisaWidget", provider: Provider()) { entry in
      PaisaWidgetView(entry: entry)
    }
    .configurationDisplayName("Paisa")
    .description("Spent and remaining this month.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
