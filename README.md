# Paisa

A personal expense tracker for iPhone that turns bank SMS alerts into categorised expenses, tracks spend against a monthly salary and per-category budgets, and shows daily, monthly and date-range dashboards. Offline-first, single user, no backend. Built with Flutter so the same codebase can ship to Android later.

> Built phase by phase with Claude Code from `docs/SPEC.md`. The spec is the source of truth; this README is the tour.

## Features

- **Automatic capture from bank SMS** — an iOS Shortcuts automation hands HDFC debit/credit messages to the app's App Intent; the app parses them into expenses and income. Duplicates are fingerprinted and ignored. Unparsed messages are kept for manual review.
- **Manual expenses** — floating `+` button, custom keypad, category strip, date and note.
- **Categories** — typed expense/income categories with your own emoji and colour, reorderable, with quick-add suggestions. Deleting a category moves its transactions to *Uncategorised* rather than deleting them.
- **Uncategorised expenses still count** — they show dimmed until you tag them, but are always included in totals.
- **Salary and budgets** — a default monthly salary with per-month overrides; per-category limits that cannot add up to more than the salary.
- **Month boundary toggle** — calendar month, or salary-day to salary-day (e.g. 28th–27th).
- **Dashboards** — month-wise income vs expenses, income left (amount or %), day-wise spend, date-range chart, calendar heatmap, budget donut with over-salary handling. Swipe any chart to change period.
- **Home-screen widget** — WidgetKit widget showing spent / remaining for the current period.
- **Excel export** — one workbook per month (Expenses, Income, Summary sheets), plus CSV/JSON and SQLite backup/restore.
- **Dark UI with Liquid Glass** on iOS 26, flat fallback below; honours Reduce Motion and Reduce Transparency.

## How SMS capture works on iOS

iOS does not let apps read SMS, so capture runs through a Shortcuts automation that you set up once on the phone:

1. Shortcuts → Automation → **When I get a message** → filter on sender `HDFCBK` (or message contains "HDFC Bank").
2. Action: **Ingest bank message** (the app's App Intent) with the message text as input. Set **Run Immediately**.
3. The intent appends the raw text to the app's shared inbox; the app parses it on next launch or resume.

Fallback: share any message to Paisa from the Messages share sheet.

Supported banks: HDFC (UPI debit, NEFT/IMPS credit). Adding a bank is a template file in `lib/domain/parser/templates/` plus golden tests.

## Tech stack

| Layer | Choice |
| --- | --- |
| UI and logic | Flutter (Dart), Riverpod, go_router |
| Storage | drift (SQLite), amounts stored as integer paise |
| Charts | fl_chart |
| iOS native | Swift App Intent, Share Extension, WidgetKit extension (SwiftUI), App Group container |
| Widget bridge | home_widget |
| Export | `excel` package |

Minimum iOS 17 (needed for Run Immediately automations); Liquid Glass surfaces require iOS 26.

## Project layout

```
lib/
  core/          money (paise), dates, Period helper, theme tokens
  data/          drift tables, DAOs, migrations
  domain/        models, budget maths, SMS parser + bank templates
  features/      ingest, expenses, categories, budgets, home, dashboards, settings
  widget/        widget_summary.json writer
ios/
  Runner/        Flutter host + IngestBankMessageIntent
  ShareExt/      Share Extension
  PaisaWidget/   WidgetKit extension
docs/
  SPEC.md        full product + technical spec
  PROGRESS.md    per-phase build log
  BACKLOG.md     ideas not yet in scope
  design/reference/   the screenshots the UI was built to match
test/            parser golden tests, Period and budget maths tests
```

## Getting started

Requirements: macOS with Xcode, Flutter stable, CocoaPods, an iPhone. A free Apple ID (Xcode "Personal Team") is enough; the install expires every 7 days and must be re-run from Xcode.

```bash
git clone https://github.com/RupeshKankrej/paisa.git
cd paisa
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cd ios && pod install && cd ..
flutter run -d <your-iphone>
```

First time on the phone:

1. Open the `ios/Runner.xcworkspace` in Xcode, select your Personal Team under Signing & Capabilities for **Runner**, **ShareExt** and **PaisaWidget**, and make sure all three share the same App Group.
2. On the iPhone, trust the developer certificate (Settings → General → VPN & Device Management).
3. Set up the Shortcuts automation described above.
4. In the app: Settings → Salary, Settings → Month boundary, then allocate budgets from the Budget tab.

Tests and checks:

```bash
dart format lib test
flutter analyze --fatal-infos
flutter test
```

The same three run in CI on every pull request (`.github/workflows/flutter-ci.yml`); the iOS build job is manual-trigger only.

## Privacy

Everything stays on the device. No accounts, no analytics, no network calls. Bank messages are stored locally only so unparsed ones can be reviewed; account numbers are shown as last-4 only. Exports and backups are files you choose where to send. Real bank messages must never be committed — `docs/samples/real/` and `*.xlsx` are git-ignored.

## Roadmap

- **Android** — same Flutter code plus a Kotlin SMS receiver and Glance widget.
- **AI monthly summary** — anonymised category totals sent to the Claude API for a short summary and one suggestion.
- Multiple accounts and banks, recurring-expense detection, iCloud backup, Siri "add expense", Face ID lock. See `docs/BACKLOG.md`.

## Contributing to your own repo

One phase per Claude Code session, named `phase-N-<name>`; branches `phase-N-<name>`; PRs use `.github/PULL_REQUEST_TEMPLATE.md`. Change `docs/SPEC.md` first, then the code.

## Licence

Personal project. No licence granted; all rights reserved.