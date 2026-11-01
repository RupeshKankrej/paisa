import SwiftUI
import WidgetKit

struct Summary: Decodable {
  struct TopCategory: Decodable {
    let name: String
    let color: UInt32
    let spentPaise: Int
  }

  struct QuickCategory: Decodable {
    let id: Int
    let name: String
    let emoji: String
  }

  let month: String
  let spentPaise: Int
  let salaryPaise: Int?
  let remainingPaise: Int?
  let topCategories: [TopCategory]
  let dailySpentPaise: [Int]
  let quickCategories: [QuickCategory]

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
    ],
    dailySpentPaise: (0..<30).map { $0 % 3 == 0 ? 0 : ($0 * 37 % 11) * 20_000 },
    quickCategories: [
      QuickCategory(id: 0, name: "Housing", emoji: "🏠"),
      QuickCategory(id: 0, name: "Food", emoji: "🍽️"),
      QuickCategory(id: 0, name: "Entertainment", emoji: "🍿"),
      QuickCategory(id: 0, name: "Investments", emoji: "📈"),
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

/// Like Money.short: drops only empty paise, and never rounds.
func moneyShort(_ paise: Int) -> String {
  let text = money(paise)
  return text.hasSuffix(".00") ? String(text.dropLast(3)) : text
}

func monthLabel(_ key: String) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "yyyy-MM"
  guard let date = formatter.date(from: key) else { return key }
  formatter.dateFormat = "MMMM"
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

// MARK: - Views

private let accent = Color(red: 0.16, green: 0.83, blue: 0.70)
private let tileRadius: CGFloat = 22

struct Tile<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        LinearGradient(
          colors: [.white.opacity(0.07), .white.opacity(0.025)],
          startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
  }
}

/// A tile that opens the app at [url], the only tap a static widget can do.
struct ActionTile<Content: View>: View {
  let url: String
  let label: String
  @ViewBuilder let content: Content

  var body: some View {
    Link(destination: URL(string: url)!) { Tile { content } }
      .accessibilityLabel(label)
  }
}

struct SymbolTile: View {
  let symbol: String
  let url: String
  let label: String

  var body: some View {
    ActionTile(url: url, label: label) {
      Image(systemName: symbol).font(.title2.weight(.semibold)).foregroundStyle(accent)
    }
  }
}

/// What is left of the salary, the arc being what is spent. With no salary set
/// there is nothing to be left of, so it shows the spend.
struct LeftRing: View {
  let summary: Summary

  private var over: Bool { (summary.remainingPaise ?? 0) < 0 }

  private var spentShare: Double {
    guard let salary = summary.salaryPaise else { return 0 }
    // A zero salary with any spend reads as full, as on the Budget ring.
    guard salary > 0 else { return summary.spentPaise > 0 ? 1 : 0 }
    return min(Double(summary.spentPaise) / Double(salary), 1)
  }

  var body: some View {
    Tile {
      ZStack {
        Circle().stroke(.white.opacity(0.14), lineWidth: 9)
        Circle()
          .trim(from: 0, to: spentShare)
          .stroke(over ? .red : accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 2) {
          Text(summary.remainingPaise == nil ? "Spent" : "Left")
            .font(.caption).foregroundStyle(.secondary)
          Text(moneyShort(summary.remainingPaise ?? summary.spentPaise))
            .font(.subheadline.weight(.bold))
            .foregroundStyle(over ? .red : .white)
            .minimumScaleFactor(0.5).lineLimit(1)
        }
        .padding(.horizontal, 16)
      }
      .padding(12)
    }
  }
}

struct DayBars: View {
  let days: [Int]

  var body: some View {
    GeometryReader { size in
      let most = max(days.max() ?? 0, 1)
      HStack(alignment: .bottom, spacing: 2.5) {
        ForEach(days.indices, id: \.self) { i in
          ZStack(alignment: .bottom) {
            Capsule().fill(.white.opacity(0.05))
            if days[i] > 0 {
              Capsule()
                .fill(accent)
                .frame(
                  height: max(size.size.height * CGFloat(days[i]) / CGFloat(most), 3))
            }
          }
        }
      }
    }
  }
}

private func grid(_ tiles: [AnyView]) -> some View {
  VStack(spacing: 5) {
    HStack(spacing: 5) {
      tiles[0]
      tiles[1]
    }
    HStack(spacing: 5) {
      tiles[2]
      tiles[3]
    }
  }
}

struct ActionsLayout: View {
  let summary: Summary

  var body: some View {
    HStack(spacing: 5) {
      LeftRing(summary: summary)
      grid([
        AnyView(SymbolTile(symbol: "plus", url: "paisa://add?type=income", label: "Add income")),
        AnyView(SymbolTile(symbol: "minus", url: "paisa://add", label: "Add expense")),
        AnyView(SymbolTile(symbol: "list.bullet", url: "paisa://expenses", label: "Activity")),
        AnyView(
          SymbolTile(symbol: "chart.bar.fill", url: "paisa://dashboards", label: "Analytics")),
      ])
    }
  }
}

struct CategoriesLayout: View {
  let summary: Summary

  var body: some View {
    HStack(spacing: 5) {
      LeftRing(summary: summary)
      grid(
        (0..<4).map { i in
          // Fewer than four categories leaves blank tiles, keeping the grid's shape.
          guard i < summary.quickCategories.count else { return AnyView(Tile { EmptyView() }) }
          let category = summary.quickCategories[i]
          return AnyView(
            ActionTile(url: "paisa://add?category=\(category.id)", label: "Add to \(category.name)") {
              Text(category.emoji).font(.title)
            })
        })
    }
  }
}

struct ExpensesLayout: View {
  let summary: Summary

  var body: some View {
    HStack(spacing: 5) {
      Tile {
        VStack(alignment: .leading, spacing: 2) {
          Text("\(monthLabel(summary.month)) expenses")
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
          Text(moneyShort(summary.spentPaise))
            .font(.title2.weight(.bold)).foregroundStyle(.white)
            .minimumScaleFactor(0.5).lineLimit(1)
          Spacer(minLength: 8)
          DayBars(days: summary.dailySpentPaise)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      VStack(spacing: 5) {
        SymbolTile(symbol: "plus", url: "paisa://add?type=income", label: "Add income")
        SymbolTile(symbol: "minus", url: "paisa://add", label: "Add expense")
      }
      .frame(width: 76)
    }
  }
}

// MARK: - Widgets

/// The shared dark card, whichever layout sits on it. In iOS 26's Clear and
/// Tinted home-screen styles the system drops this background for its glass.
struct Card<Content: View>: View {
  let summary: Summary?
  @ViewBuilder let content: (Summary) -> Content

  var body: some View {
    Group {
      if let summary {
        content(summary).padding(5)
      } else {
        Text("Open Paisa to see this month")
          .font(.caption).foregroundStyle(.secondary).padding()
      }
    }
    .environment(\.colorScheme, .dark)
    .containerBackground(for: .widget) {
      LinearGradient(
        colors: [Color(red: 0.13, green: 0.16, blue: 0.18), Color(red: 0.06, green: 0.08, blue: 0.09)],
        startPoint: .top, endPoint: .bottom)
    }
    .widgetURL(URL(string: "paisa://expenses"))
  }
}

struct OverviewView: View {
  @Environment(\.widgetFamily) private var family
  let entry: Entry

  var body: some View {
    Card(summary: entry.summary) { summary in
      if family == .systemMedium {
        ActionsLayout(summary: summary)
      } else {
        LeftRing(summary: summary)
      }
    }
  }
}

// Keeps the first widget's kind, so one already on the home screen stays there.
struct PaisaWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PaisaWidget", provider: Provider()) { entry in
      OverviewView(entry: entry)
    }
    .configurationDisplayName("Left this month")
    .description("What is left, with quick add buttons.")
    .contentMarginsDisabled()
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct PaisaCategoriesWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PaisaCategoriesWidget", provider: Provider()) { entry in
      Card(summary: entry.summary) { CategoriesLayout(summary: $0) }
    }
    .configurationDisplayName("Quick categories")
    .description("What is left, and your first four categories.")
    .contentMarginsDisabled()
    .supportedFamilies([.systemMedium])
  }
}

struct PaisaExpensesWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PaisaExpensesWidget", provider: Provider()) { entry in
      Card(summary: entry.summary) { ExpensesLayout(summary: $0) }
    }
    .configurationDisplayName("Month's expenses")
    .description("Spend this month, day by day.")
    .contentMarginsDisabled()
    .supportedFamilies([.systemMedium])
  }
}

@main
struct PaisaWidgets: WidgetBundle {
  var body: some Widget {
    PaisaWidget()
    PaisaCategoriesWidget()
    PaisaExpensesWidget()
  }
}
