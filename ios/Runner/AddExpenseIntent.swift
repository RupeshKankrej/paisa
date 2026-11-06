import AppIntents
import SwiftUI

/// SPEC 5.19: quick add from Shortcuts, Back Tap or the Action button, on the lock
/// screen too. Writes one inbox line; the app inserts it on its next launch.
struct AddExpenseIntent: AppIntent {
  static let title: LocalizedStringResource = "Add expense in Paisa"
  static let description = IntentDescription("Adds an expense or an income without opening Paisa.")
  static let openAppWhenRun = false

  @Parameter(title: "Type", requestValueDialog: "Expense or Income?")
  var type: QuickAddType

  @Parameter(title: "Amount")
  var amount: Double?

  @Parameter(title: "Category")
  var category: CategoryEntity?

  @Parameter(title: "Name")
  var name: String?

  func perform() async throws -> some IntentResult & ShowsSnippetView {
    let expense = type == .expense
    guard let amount, amount > 0 else {
      throw $amount.needsValueError(
        expense ? "How much did you spend? (₹)" : "How much did you receive? (₹)")
    }
    let paise = Int((amount * 100).rounded())

    if category == nil {
      let options = CategoryEntity.load(expense ? "expense" : "income") + [.skip]
      category = try await $category.requestDisambiguation(among: options, dialog: "Category?")
    }
    let picked = category?.id == CategoryEntity.skip.id ? nil : category

    if name == nil {
      // shortcut: Cancel here still saves, without a name; verify on the device that
      // the prompt accepts an empty Done, else add a Skip choice before it.
      name = (try? await $name.requestValue("Name? Leave empty to skip")) ?? ""
    }
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    try Inbox.appendQuickAdd(
      type: expense ? "debit" : "credit", amountPaise: paise, categoryId: picked?.id,
      name: trimmed.isEmpty ? nil : trimmed, to: Inbox.url())

    let remaining = WidgetSummary.remainingPaise().map { expense ? $0 - paise : $0 }
    return .result(
      view: QuickAddCard(
        expense: expense, paise: paise, category: picked?.title,
        name: trimmed.isEmpty ? nil : trimmed, remainingPaise: remaining))
  }
}

enum QuickAddType: String, AppEnum {
  case expense, income

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Type"
  static let caseDisplayRepresentations: [QuickAddType: DisplayRepresentation] = [
    .expense: "Expense", .income: "Income",
  ]
}

/// A category from categories.json, which the app rewrites whenever they change.
struct CategoryEntity: AppEntity {
  let id: Int
  let title: String
  let type: String

  /// Saves uncategorised. SQLite ids start at 1, so 0 is free.
  static let skip = CategoryEntity(id: 0, title: "Skip", type: "")

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
  static let defaultQuery = CategoryQuery()
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

  /// In the user's order; [type] nil returns both.
  static func load(_ type: String? = nil) -> [CategoryEntity] {
    struct Row: Decodable {
      let id: Int
      let name: String
      let emoji: String
      let type: String
    }
    guard
      let url = try? Inbox.url().deletingLastPathComponent()
        .appendingPathComponent("categories.json"),
      let data = try? Data(contentsOf: url),
      let rows = try? JSONDecoder().decode([Row].self, from: data)
    else { return [] }
    return rows.filter { type == nil || $0.type == type }
      .map { CategoryEntity(id: $0.id, title: "\($0.emoji) \($0.name)", type: $0.type) }
  }
}

struct CategoryQuery: EntityQuery {
  func entities(for identifiers: [Int]) async throws -> [CategoryEntity] {
    (CategoryEntity.load() + [.skip]).filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [CategoryEntity] {
    CategoryEntity.load() + [.skip]
  }
}

enum WidgetSummary {
  static func remainingPaise() -> Int? {
    guard
      let url = try? Inbox.url().deletingLastPathComponent()
        .appendingPathComponent("widget_summary.json"),
      let data = try? Data(contentsOf: url),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return json["remaining_paise"] as? Int
  }
}

struct PaisaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddExpenseIntent(),
      phrases: ["Add expense in \(.applicationName)"],
      shortTitle: "Add expense",
      systemImageName: "plus.circle")
  }
}

/// The result card in the dialog: amount, category, name, what is left.
struct QuickAddCard: View {
  let expense: Bool
  let paise: Int
  let category: String?
  let name: String?
  let remainingPaise: Int?

  private static let income = Color(red: 0x4C / 255, green: 0xC3 / 255, blue: 0x8A / 255)

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(([(expense ? "" : "+") + rupees(paise)] + [category].compactMap { $0 }).joined(separator: " · "))
        .font(.title2.weight(.semibold))
        .foregroundStyle(expense ? Color.primary : Self.income)
      if let name { Text(name).foregroundStyle(.secondary) }
      if let remainingPaise {
        Text("\(rupees(remainingPaise)) left this month")
          .font(.footnote)
          .foregroundStyle(remainingPaise < 0 ? .red : .secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
  }
}

/// Swift twin of Money.short (also in PaisaWidget, a separate target).
func rupees(_ paise: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .currency
  formatter.locale = Locale(identifier: "en_IN")
  formatter.currencySymbol = "₹"
  let text = formatter.string(from: Decimal(paise) / 100 as NSDecimalNumber) ?? ""
  return text.hasSuffix(".00") ? String(text.dropLast(3)) : text
}
