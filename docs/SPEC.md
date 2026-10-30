# Expense Tracker App — Product & Technical Spec

Oct 30, 2026 · @Rupesh

## 1. Overview

A personal expense tracker for iPhone (Android later) that turns bank SMS alerts into categorised expenses, tracks spend against a monthly salary and per-category budgets, and shows daily, monthly and date-range dashboards. Offline-first, single user, no backend in v1.

**Done means:** the app runs on Rupesh's iPhone 15 from a TestFlight or direct Xcode install, ingests HDFC debit/credit SMS automatically via a Shortcuts automation, supports manual expenses, budgets, all dashboards listed below, and has a home-screen widget.

**Working name:** Paisa (placeholder, rename freely). Currency is INR only in v1; amounts stored as integer paise to avoid float errors.

**How to use this spec with Claude Code:** work through Section 4 phase by phase. Each phase has acceptance criteria; do not start the next phase until the current one passes on a device or simulator. Section 5 holds the detailed behaviour for each feature and is the reference while building that phase.

## 2. Platform decision

**Decision: Flutter (Dart) for the app, with thin native layers — Swift for the iOS App Intent and WidgetKit widget, Kotlin for the Android SMS receiver and widget later.** One codebase carries all UI, parsing, budgeting and chart logic to Android unchanged; only the \~5% that touches the OS is written twice.

### 2.1 The iOS constraint that shapes everything

iOS does not let any third-party app read SMS. There is no permission to ask for. The app therefore cannot "watch" messages the way an Android app can. The workaround is a **Shortcuts personal automation** that the user sets up once:

1. Shortcuts app → Automation → "When I get a message" → filter by sender (the HDFC sender ID, saved as a contact) or by message text containing "HDFC Bank".
2. Action: run the app's **App Intent** ("Ingest bank message") with the message body as input. Set the automation to **Run Immediately** (available since iOS 17), so no tap is needed.
3. The intent runs in the background without opening the app, writes the raw text into a shared inbox (App Group container), and returns.
4. Next time the app opens or resumes, it parses the inbox into expenses.

Risks to validate in Phase 0 before writing any UI: (a) the automation fires for SMS from alphanumeric sender IDs like `VM-HDFCBK`; (b) it fires when iOS sorts the SMS into the Transactions filter; (c) the App Intent is reachable without opening the app. If (a) or (b) fails, fall back to the "contains text" filter. A **Share Extension** (share a message to the app) is the manual fallback and should exist regardless.

### 2.2 Why Flutter over the alternatives

| Option | Verdict | Reason |
| --- | --- | --- |
| Flutter | Chosen | One Dart codebase for iOS + Android; mature SQLite (drift) and charts (fl\_chart); `home_widget` package bridges to WidgetKit and Glance; large body of examples for Claude Code to draw on; hot reload speeds iteration |
| Kotlin Multiplatform + Compose Multiplatform | Runner-up | Kotlin is closest to Java; shared logic is excellent, but iOS Compose UI still has fewer worked examples and widget/intent plumbing is as native as Flutter's anyway |
| Native SwiftUI | No | Fastest iPhone result, but the Android app would be a full rewrite |
| React Native | No | Works, but weaker SQLite/charting story and adds a JS toolchain you don't otherwise use |

### 2.3 What the native layers must do

| Platform | Native code | Purpose |
| --- | --- | --- |
| iOS | `AppIntent` in Swift (`IngestBankMessageIntent`) | Entry point for the Shortcuts automation; appends raw text to the App Group inbox |
| iOS | Share Extension | Manual fallback: share a message to the app |
| iOS | WidgetKit extension (SwiftUI) | Home-screen widget reading a summary JSON from the App Group |
| Android (later) | `BroadcastReceiver` for `SMS_RECEIVED` | Automatic capture; needs `RECEIVE_SMS`; fine for a sideloaded personal app, Play Store would require justification |
| Android (later) | Glance widget | Same summary JSON |

### 2.4 Toolchain and accounts

- macOS with Xcode (the MacBook Air), Flutter stable channel, CocoaPods.
- Apple ID: a free account (Xcode "Personal Team") is enough for everything in this spec. App Groups, App Intents, the widget extension and the Share Extension all work with free provisioning. The costs: the install expires every 7 days (re-run from Xcode to refresh; the automation stops while it is expired), no TestFlight, and at most 10 new bundle IDs per week, so keep the App Intent inside the main app target rather than a separate extension. The **Apple Developer Program (USD 99/year)** is optional and only buys TestFlight and a 1-year signature.
- State management: Riverpod. Database: drift (SQLite). Charts: fl\_chart. Widget bridge: home\_widget. Navigation: go\_router.
- Minimum iOS 17 (needed for Run Immediately automations and modern App Intents).

## 3. Architecture

All parsing and business logic lives in Dart; native code only moves bytes in and out of the App Group container.

&#91;embedded content: system architecture · iOS capture path, shared container, Flutter core, widget\]

The App Intent and Share Extension only append raw text to `inbox.jsonl`; the Flutter app parses it on launch and resume and writes `widget_summary.json` after every change, which the widget renders.

### 3.1 Project layout

```
paisa/
  lib/
    core/          money (paise), dates, month keys, result types
    data/          drift tables, DAOs, migrations
    domain/        models, budget maths, parser
    features/
      ingest/      inbox reader, bank templates, dedup
      expenses/    list, add/edit, swipe actions
      budgets/     categories, limits, salary
      home/        month summary
      dashboards/  charts
      settings/    tracked senders, data export
    widget/        summary JSON writer (home_widget)
  ios/
    Runner/        Flutter host
    IngestIntent/  AppIntent target (Swift)
    ShareExt/      Share Extension target
    PaisaWidget/   WidgetKit extension (SwiftUI)
  test/            parser golden tests, budget maths tests
```

### 3.2 Data model (drift / SQLite)

| Table | Columns | Notes |
| --- | --- | --- |
| `tracked_senders` | id, label, match\_pattern, bank | Which messages to parse, e.g. `HDFC Bank` or sender `HDFCBK` |
| `categories` | id, name, color, icon, sort\_order, is\_archived | Seeded with defaults (Food, Travel, Rent, Bills, Shopping, Health, Entertainment, Other); user can add/rename |
| `budgets` | id, category\_id, month (nullable), amount\_paise | `month = NULL` is the default limit; a row with a month overrides it for that month |
| `salary` | id, month (nullable), amount\_paise | Same override pattern as budgets |
| `transactions` | id, type (debit/credit), amount\_paise, occurred\_at, counterparty, account\_last4, bank, ref\_no, source (sms/manual/share), category\_id (nullable), note, raw\_text, created\_at, updated\_at | Uncategorised = `category_id IS NULL`; still counted in month totals |
| `ingest_log` | id, fingerprint (unique), ingested\_at, status (parsed/ignored/failed) | Dedup store: fingerprint = SHA-256 of normalised raw text; also keeps `ref_no` when present |

`month` is stored as `YYYY-MM` text and names a period, which is a calendar month or a salary-day period depending on the user's toggle (5.11). All amounts are integer paise. A credit from the tracked account is **income**; a debit is an **expense**. Transfers between own accounts are out of scope for v1 (user can delete them).

### 3.3 Shared files in the App Group

| File | Writer | Reader | Shape |
| --- | --- | --- | --- |
| `inbox.jsonl` | App Intent, Share Extension | Flutter app (then truncated) | One JSON per line: `{"text": "…", "received_at": "ISO-8601", "source": "intent"}` |
| `widget_summary.json` | Flutter app | WidgetKit | `{"month": "2026-10", "spent_paise": …, "salary_paise": …, "remaining_paise": …, "top_categories": [...], "updated_at": "…"}` |

The SQLite file itself stays private to the app in v1; the widget never opens the database.

## 4. Phase plan for Claude Code

Build in this order. Phase 0 is a spike that de-risks the only part we cannot control (iOS message capture); do it before any UI. Each phase ends with the acceptance checks listed; run `flutter test` and a device install before moving on.

| Phase | Scope | Acceptance |
| --- | --- | --- |
| 0. Capture spike | Empty Flutter app + Swift `IngestBankMessageIntent` (in the main app target) writing to App Group `inbox.jsonl`; Shortcuts automation set up by hand on the iPhone; signed with the free Personal Team | Send yourself a test SMS containing "HDFC Bank"; `inbox.jsonl` gains a line without the app opening. Record which automation filter worked |
| 1. Foundation | Project scaffold (Riverpod, go\_router, drift), tables from 3.2, seed categories, money/date utilities, app theme, bottom tab shell (Home, Expenses, Categories, Dashboards, Settings) | App launches on simulator and device; `flutter test` passes on money and month-key helpers |
| 2. Parser + ingest | Dart parser with per-bank templates (HDFC debit, HDFC credit), fingerprint dedup, `ingest_log`, inbox reader on launch/resume, Settings screen to add tracked senders | Golden tests pass for the two sample messages in 5.1; same message delivered twice creates one transaction |
| 3. Expenses screen | Month picker, list grouped by day, uncategorised rows greyed, tap-to-categorise sheet, swipe-left delete with undo snackbar, edit sheet, manual add via FAB | All of 5.2 to 5.4 verified on device |
| 4. Budgets + Home | Salary (default + per-month override), per-category limits (default + per-month override), month-boundary toggle and Period helper (5.11), Home summary (spent / remaining / month picker), Categories screen with coloured progress bars | All of 5.5 to 5.7 verified; totals match a hand-computed month |
| 5. Dashboards | Month-wise expense vs income bars, day-wise spend for a month, date-range chart, budget pie with over-salary handling | All of 5.8 verified against seeded data, including a month where spend > salary |
| 6. Widget | `home_widget` bridge writing `widget_summary.json`; WidgetKit extension with small + medium families; App Group entitlement on all targets | Widget on the home screen shows current-month spent/remaining and updates after adding an expense |
| 7. Polish + release | Share Extension, monthly Excel export (5.10) plus CSV/JSON, backup/restore of the SQLite file, app icon, TestFlight build | Installed from TestFlight; export produces a file openable in Numbers/Excel |

### 4.1 Working agreement for Claude Code

- One phase per session; start by reading this spec and the previous phase's notes in `docs/PROGRESS.md`, end by updating that file.
- Never widen a phase. Anything discovered goes into `docs/BACKLOG.md`.
- Parser and budget maths are pure Dart with no Flutter imports, so they are unit-testable and reusable on Android.
- Every amount in the UI is formatted through one `Money` helper (`₹1,55,453.00`, Indian grouping).
- Prefer `flutter run` on the physical iPhone for Phases 0, 2, 6 and 7; the simulator cannot receive SMS or run the Shortcuts automation end to end.

## 5. Feature specifications

### 5.1 Message ingestion and parsing

**Tracked senders.** Settings lists tracked senders; each has a label, a bank (HDFC in v1; the enum is extensible) and a match rule. A message is parsed only if it matches a tracked sender's rule; everything else is ignored and logged as `ignored`. Default seed: one HDFC rule matching text that contains `HDFC Bank`.

**Parsing pipeline.** `inbox.jsonl` → normalise whitespace → fingerprint (SHA-256 of normalised text) → skip if fingerprint in `ingest_log` → try each template for the matched bank in order → first match wins → insert transaction with `source = sms`, `category_id = NULL` → log `parsed`. No template match → log `failed` and keep `raw_text` so the user can see it under Settings → Unparsed messages and add it manually.

**HDFC templates (regex, case-insensitive, multiline).** Capture groups are named.

| Template | Fields | Sample |
| --- | --- | --- |
| HDFC UPI debit | `Sent Rs.(?<amount>[\d,]+\.?\d*)` · `From HDFC Bank A/C \*(?<last4>\d{4})` · `To (?<party>.+)` · `On (?<date>\d{2}/\d{2}/\d{2})` · `Ref (?<ref>\d+)` | `Sent Rs.120.00 From HDFC Bank A/C *2703 To MAHESHWARI ENTERPRISES On 30/10/26 Ref 630329677868` |
| HDFC credit | `INR (?<amount>[\d,]+\.?\d*) deposited in HDFC Bank A/c XX(?<last4>\d{4}) on (?<date>\d{2}-[A-Z]{3}-\d{2}) for (?<party>.+?)\.Avl bal` | `Update! INR 1,55,453.00 deposited in HDFC Bank A/c XX2703 on 28-OCT-26 for NEFT Cr-HSBC0560002-DEEL EOR PRIVATE LIMITED-RUPESH KANKREJ-HSBCN30100693396.Avl bal INR 2,44,485.78.` |

Date formats to support: `DD/MM/YY`, `DD-MMM-YY`, `DD-MM-YY`. Two-digit years map to 20YY. Amount strips commas and converts to paise. For credits, `party` keeps the whole NEFT/IMPS descriptor; the UI shows the first 40 characters.

**Dedup.** Fingerprint is the primary key. As a second guard, if a new transaction has the same `ref_no`, `amount_paise` and `occurred_at` date as an existing one, treat it as a duplicate. Manual expenses are never deduped. The last processed `received_at` is stored in settings so the inbox reader can also skip stale lines if the file is ever replayed.

**Other banks later.** Adding a bank = adding a template file in `domain/parser/templates/<bank>.dart` plus golden tests; no UI change.

### 5.2 Expenses screen

- Month selector in the app bar (dropdown; default current month; same component as Home).
- List grouped by day, newest first. Each row: category icon/colour (or a grey placeholder), counterparty, amount (debits red-ish, credits green-ish), time.
- **Uncategorised rows are rendered at 50% opacity** with a "Tap to categorise" hint. They still count in all totals.
- Tap a row → category picker bottom sheet (grid of categories, search, "New category" at the end). Choosing one saves immediately.
- Long-press or an edit icon → edit sheet (5.4).
- **Swipe left** → red delete background → on release, delete with a 5-second undo snackbar. Deleting an SMS-sourced expense keeps its `ingest_log` fingerprint so it is not re-imported.
- FAB at bottom-right with a plus icon → manual add sheet (5.3).
- Credits (income) appear in the same list with a filter chip to show All / Expenses / Income.

### 5.3 Manual expense

Bottom sheet with: amount (numeric keypad, required), type (expense/income, default expense), category (required for manual), date (default today), counterparty/title (optional), note (optional). Saves with `source = manual`.

### 5.4 Edit expense

Same sheet as 5.3 pre-filled. For SMS-sourced rows the amount and date are editable but a small "from SMS" tag shows the original raw text in an expandable section.

### 5.5 Salary and budgets

- **Salary.** Settings → Salary: a default monthly amount. On the Home screen, tapping the salary figure opens "Salary for \<Month>" where the user can set an override for that month only. Resolution: `salary(month) = override(month) ?? default`.
- **Category limits.** Categories screen → tap a category → set a default monthly limit. Same per-month override rule as salary. Categories without a limit show spend only, no bar.
- Sum of category limits can exceed salary; show a yellow note on the Categories screen when it does, but allow it.

### 5.6 Home screen

Top card, always for the selected month (default current, dropdown to change):

- Spent this month (sum of debits), Salary (resolved), Remaining = Salary − Spent. Remaining turns red when negative.
- A thin progress bar of Spent / Salary, capped visually at 100% with an overflow marker when spent exceeds salary.
- Below: last 5 transactions and a count of uncategorised items with a shortcut to the Expenses screen filtered to them.

### 5.7 Categories screen

- Same top card as Home (spent / salary / remaining) so the user never loses the overall picture.
- One row per category: name, spent / limit, progress bar coloured by ratio: green < 70%, amber 70–100%, red > 100%. Uncategorised spend appears as its own grey row at the top when non-zero.
- Month selector as on Home.

### 5.8 Dashboards

All charts use fl\_chart and the same month/date pickers. Empty states show a short message, never an empty axis.

| Chart | Behaviour |
| --- | --- |
| Month-wise expenses vs income | Grouped bars, one pair per month, last 12 months by default; scrollable further back. Tapping a bar shows the exact amounts |
| Day-wise spend | Bars for each day of the selected month (default current). Days with no spend render as zero-height. A dashed horizontal line marks the daily average |
| Date-range spend | Start and end date pickers (default last 30 days). Line of daily spend plus a total and average in the header. If the range exceeds 90 days, aggregate by week |
| Budget pie | See below |

**Budget pie.** One slice per category with a limit, plus an "Unallocated" slice for `salary − Σ limits` when positive. Each slice is drawn in its category colour at light opacity for the full limit, and dark opacity for the portion spent (so a slice half-dark = half of that budget used). Spend beyond a category's limit fills the slice fully dark and adds a red outline. **Over-salary case:** when total spend exceeds salary, the pie is drawn with the outer ring representing total spend instead of salary, the salary boundary is shown as a thin ring inside it, and the header reads "Over salary by ₹X". Uncategorised spend is a grey slice. A legend lists category, limit, spent, remaining.

### 5.9 Settings

Tracked senders · Salary default · Categories (manage, reorder, archive) · Unparsed messages · Month boundary (5.11) · Export: Excel per month (5.10), CSV, JSON · Backup/restore · About. No login, no cloud sync in v1.

### 5.10 Monthly Excel export

From Settings → Export, or from the overflow menu on the Expenses screen, the user picks a month (same month picker as everywhere else) and gets an `.xlsx` file via the iOS share sheet (save to Files, AirDrop, mail). Use the `excel` Dart package; no native code.

Workbook layout:

| Sheet | Contents |
| --- | --- |
| `Expenses` | One row per debit: Date, Time, Counterparty, Category (or "Uncategorised"), Amount (₹, number format with Indian grouping), Source (SMS/Manual), Note, Ref no. Sorted by date. A bold total row at the bottom |
| `Income` | Same columns for credits |
| `Summary` | Salary for the month, total spent, remaining, then one row per category: Limit, Spent, Remaining, % used |

File name: `Paisa_<YYYY-MM>.xlsx` (or `Paisa_<start>_<end>.xlsx` when the period is salary-day based, see 5.11). Amounts are written as numbers, not strings, so Excel can sum them. A "Export all months" option writes one workbook with a sheet per month.

### 5.11 Month boundary: calendar or salary day

Settings → Month boundary: a toggle between **Calendar month** (1st to last day, the default) and **Salary day to salary day**, with a day-of-month picker (1–31) that appears when the second option is chosen. Changing the toggle or the day re-computes every screen immediately; stored transactions are untouched.

Rules when salary-day mode is on with salary day `D`:

- A period runs from day `D` of one month to day `D − 1` of the next, inclusive. For `D = 28`: 28 Oct – 27 Nov.
- If a month has fewer days than `D` (e.g. `D = 31` in November), the period starts on that month's last day.
- The period is **labelled by the month it ends in** (28 Oct – 27 Nov is "November 2026"), because that is the salary that funds it. The month picker shows the label with the date range underneath.
- `salary`, `budgets` and the widget summary continue to key on the period label (`YYYY-MM`), so overrides survive a toggle flip.
- Day-wise and date-range charts use the period's real dates. The month-wise bar chart uses period totals.

Implementation: one pure function `Period.forMonthKey(key, settings)` and `Period.containing(date, settings)` in `core/`, used by every query; never compute month ranges inline in screens. Unit-test both modes, including the 31st and February cases.

## 6. iOS home-screen widget

A WidgetKit extension (SwiftUI) that reads `widget_summary.json` from the App Group; it never touches SQLite or the Flutter engine. The Flutter app rewrites the JSON and calls `WidgetCenter.reloadAllTimelines` (via `home_widget`) after every transaction, budget or salary change.

- Families: `systemSmall` and `systemMedium` in v1; lock-screen (`accessoryRectangular`) is a nice-to-have.
- Content is still to be decided; the JSON already carries month, spent, salary, remaining, top categories and `updated_at`, so the widget can start as "Spent / Remaining this month" with a progress bar and grow from there without changing the bridge.
- Tapping the widget deep-links to the Expenses screen (`paisa://expenses`); a secondary small button on the medium family deep-links to the manual-add sheet (`paisa://add`).
- Because the SMS intent does not run the Flutter engine, the widget lags until the app is next opened. If that proves annoying, Phase 7+ can port the two HDFC regexes to Swift so the intent updates the summary directly.

## 7. Future phases

**Android.** Same Flutter code. Add a Kotlin `BroadcastReceiver` for `android.provider.Telephony.SMS_RECEIVED` that appends to the app's private inbox file, plus a Glance widget reading the same `widget_summary.json`. Needs `RECEIVE_SMS` at runtime; fine for a sideloaded APK, Google Play would require a declaration form. Optionally a one-time import of historical SMS via `READ_SMS` to backfill months.

**AI summary.** A "This month" card that sends an anonymised aggregate (category totals, counts, deltas vs last month, never counterparty names unless the user opts in) to the Claude API and shows a 3–4 sentence summary and one suggestion. Needs an API key stored in the iOS Keychain, a settings toggle, and a cached result per month. Keep the prompt and schema in `features/ai/`.

**Other candidates (backlog, not committed):** multiple accounts and banks, recurring expense detection, iCloud backup of the SQLite file, Siri "add expense" intent, Face ID lock.

## 8. Open questions

- [ ] Does the Shortcuts message automation fire for `VM-HDFCBK`-style senders on your iPhone 15 and iOS version? (Phase 0 answers this; try sender-contact filter first, then text-contains.)
- [ ] Is a weekly re-install from Xcode acceptable long-term, or will you want the Apple Developer Program later for TestFlight and year-long signing?
- [ ] Should credits other than salary (refunds, cashbacks, transfers from your own accounts) count as income, or be tagged as a separate "Transfer" type and excluded from income charts?
- [ ] Month boundary is now a user toggle (5.11). Should the salary-day picker default to the day your HDFC credit usually lands (28th), or stay blank until set?
- [ ] Default category list: keep the seed in 3.2 or start from your own?
- [ ] App name: keep "Paisa" or pick another before Phase 1 (bundle ID and App Group ID derive from it).
