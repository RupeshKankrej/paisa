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
| 7. UI: design system + shell | Theme tokens from 5.12 (dark palette, type scale, radii, category colours), shared widgets (pill bottom nav, floating FAB, filter chips, card list rows, month dropdown, hero number, bottom sheet), app settings button; every existing screen swapped onto the new shell with no behaviour change | Side-by-side with docs/design/reference/ screenshots: nav, chips, cards and FAB match; all Phase 3–5 acceptance checks still pass |
| 8. UI: Activity, Add, Summary | Activity screen (hero total + day-bar chart header, day-grouped cards), month picker sheet (5.13), full-screen Add/Edit sheet with custom keypad and category strip, Summary screen (donut ring with month in the centre, category rows with count, amount and %) | Screens 01–04 and 10 of the reference set reproduced on device; swipe on any chart changes month; swipe-delete, categorise and edit still work; uncategorised rows still dimmed |
| 9. Categories | Category model gains type (expense/income), emoji, colour, sort order; Categories screen (Expense/Income segment, reorderable list, tap-to-edit sheet, swipe-left delete with confirmation that uncategorises transactions, quick-add suggestions, New category); New-category sheet with emoji and colour pickers; category grid sheet with Expense/Income toggle and pencil; category filter sheet from the All categories chip and the Summary pencil; Categories entry in Settings (5.14) | Screens 11–16 and 24–26 reproduced; tap opens the edit sheet and swipe-left shows delete; deleting a category with transactions leaves them uncategorised and still counted; a category added with a custom emoji and colour appears in the add sheet, Summary donut and filter; filter narrows Activity and Summary; reorder persists |
| 10. UI: Budget, Analytics, Settings | Budget screen with per-category budget cards, Add-category picker and keypad sheet with over-salary validation (5.16), allocate sheet; Analytics with 6-period swipe window and amount/percent toggle (5.17), income vs expenses bars, income-left bars, calendar heatmap, grouped Settings list with Categories entry; empty states; light theme variant | Screens 05–09 and 18–23 reproduced; a category budget that would exceed salary cannot be saved; swiping Analytics moves all three cards together; over-salary pie case from 5.8 still handled; app usable in light and dark |
| 11. Motion + Liquid Glass | Animation pass (5.15): sheet, tab and month transitions, count-up numbers, haptics, hero chart swipe; Liquid Glass treatment on bottom nav, FAB, chips, sheets and the widget on iOS 26+, flat fallback below; Reduce Motion / Reduce Transparency honoured; frame-time budget checked with DevTools | No dropped frames scrolling Activity with 500 transactions on the iPhone 15; glass surfaces visibly refract content behind them on iOS 26; widget matches the app's glass look |
| 12. Polish + release | Share Extension, monthly Excel export (5.10) plus CSV/JSON, backup/restore of the SQLite file, app icon, TestFlight build | Installed from TestFlight; export produces a file openable in Numbers/Excel |

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
- Tap or long-press any row, categorised or not → edit sheet (5.4), where its category is chosen from the strip or the category grid sheet (5.14).
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
- The sum of category limits cannot exceed the period's salary; the per-category keypad sheet blocks any amount that would (5.16).

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

### 5.12 Visual design language

The target look is defined by twenty-six reference screenshots stored in `docs/design/reference/` (numbered `01-activity.png` … `26-category-edit-sheet.png`). They come from another app, so the goal is the same layout, density and feel built from our own widgets, not a pixel copy: no third-party logos, icons or seasonal decorations (the ghosts are a Halloween theme, leave them out). Phases 7–11 build toward them. Claude Code should open the relevant screenshot with its image tool before building each screen.

**Tokens (Phase 7, `lib/core/theme/`).**

| Token | Value | Used for |
| --- | --- | --- |
| `bg` | near-black navy `#121619`; Activity header fades from `#1E3A4C` to `bg` | Page background, hero gradient |
| `surface` | `#1C2227` | Cards, chips, keypad keys, bottom-nav pill |
| `surfaceRaised` | `#262D33` | Selected chip, pressed key |
| `textPrimary` / `textSecondary` | `#FFFFFF` / `#8A949C` | Numbers and labels / captions, axis ticks |
| `accent` | `#F2F2F2` | FAB and primary button (light button on dark) |
| `income` / `expense` | `#4CC38A` / `#5AA9F5` | Analytics bars, pills |
| Category colours | blue `#5AA9F5`, coral `#E8737A`, violet `#7B6CF6`, orange `#F2A65A`, amber `#F0C36A`, purple `#B36CF6`, pink `#F07AC8`, green `#4CC38A` | Category icon border, donut slices, calendar cells; seeded per category |
| Radii | cards 20, chips and keys 16, FAB and icon tiles 999 |  |
| Type | display 56/700 for hero amounts, 34/700 for donut centre, 17/500 body, 13/400 captions; system font (SF Pro on iOS, Roboto on Android) |  |

**Shared components (Phase 7).** Floating pill bottom nav with five items (Activity, Summary, Budget, Analytics, Accounts; `Accounts` can stay a placeholder until multi-account exists); round light FAB bottom-right on every tab; horizontally scrolling filter chips (search icon chip first, then Expenses/Income, Monthly, All accounts, sort); day-grouped card list with the day total right-aligned in the group header; category icon tile = emoji on `surface` with a 2 px border in the category colour; month dropdown as a small caption with a chevron above a large number; round translucent settings button top-left.

**Per screen.**

| Ref | Screen | What to match |
| --- | --- | --- |
| 01 | Activity (our Expenses screen) | Gradient header, "This month ▾" caption, hero spend amount, faint day-wise bar chart for the period with 0 axis labels, filter chips, grouped cards, FAB |
| 02 | Add / Edit | Full-height sheet: refresh and delete icons top, hero amount with a clear button, date chip, account chip, name chip, scrollable category strip with a "more" grid button, 3×4 custom keypad with a light arrow key to confirm |
| 03–04 | Summary (our Categories screen) | Thick donut ring of category slices, month and total in the centre, same chips, category rows: icon tile, name, count badge, amount, % pill. Our spec adds the per-category budget bar under each row and the uncategorised grey row |
| 05 | Budget | Large ring "Left this month ▾ / ₹X of ₹Y" (salary is the ring total); budgeted categories listed under it as cards with a ring-style icon, "₹a left / of ₹b"; "Add category" row at the end of the card; pencil button edits. See 5.16 |
| 06 | Allocate budget sheet | "X% set · ₹a / ₹b" progress with "₹c left to allocate", category rows with amount and % that update live, sticky Confirm; tapping a row opens the per-category keypad sheet (refs 20–21). See 5.16 |
| 07 | Analytics (top) | Chip row, card with Income/Expenses legend and totals, grouped rounded bars per month with k-formatted axis, selected month pill under the axis; horizontal swipe moves the 6-month window (5.17) |
| 08 | Analytics (bottom) | "Income left" bar card with an amount / percent segmented toggle and dashed outline bars for months with no income; Calendar heatmap: 7-column grid, cell intensity by spend, k-formatted amounts, grey cells for zero days; both swipe with the same window (5.17) |
| 09 | Settings | Grouped list with icon tiles, trailing value and chevron, toggles; sections Preferences and Privacy & security; our Month start day row is the 5.11 toggle |

**Charts.** Keep fl\_chart but theme it: rounded bar caps, no grid lines, axis labels in `textSecondary`, bar glow via a soft shadow. The budget pie from 5.8 becomes the Summary donut; the over-salary case keeps its thin inner ring and red outline.

**Motion** is specified in 5.15 and built in Phase 11.

### 5.13 Month picker

Reference `10-month-picker.png`. Tapping any "This month ▾" / "September ▾" caption opens a bottom sheet titled **Select date**:

- A horizontally scrolling row of year chips, current year first and selected (outlined), going back to the earliest year with data (minimum 5 years).
- A 3×4 grid of month chips. The selected month is outlined; months after the current month in the current year are disabled (dimmed, not tappable).
- Tapping a month closes the sheet and updates every screen bound to the selected period. The selection is app-wide, not per screen.
- In salary-day mode (5.11) the chip label stays the month name; the date range shows as a caption under the grid ("28 Sep – 27 Oct").
- Footer tip: "Swipe on any chart to change months". Horizontal swipe on the Activity header chart, Summary donut and Analytics bars moves one period: **swipe right = previous, swipe left = next**; next stops at the current period. Every date-related swipe follows this direction.

### 5.14 Categories

References `11-category-grid.png` to `16-categories-income.png`. Categories are typed: **expense** or **income**. The `categories` table from 3.2 gains `type`, `emoji` and keeps `color` and `sort_order`. Income categories replace the plain "credit" bucket: an income transaction can be tagged Salary, Investments, etc., and the salary used for budgeting (5.5) stays a separate setting.

**Category grid sheet (ref 11, 15).** Opened from the Add/Edit sheet's "more" grid button. Expense/Income segmented control at the top; 4-column grid of tiles (emoji + name, truncated with an ellipsis); dashed "Add new" tile at the end; pencil button top-right opens the Categories screen.

**New category sheet (ref 12, 13).** Title "New expense category" / "New income category". Name field (auto-focused); emoji button opening the system emoji keyboard (default emoji 🎯); colour button that expands a 42-swatch palette below the Add button, selected swatch ringed. Add is disabled until a name is entered. Names are unique per type, case-insensitive.

**Categories screen (ref 14, 16).** Back button, title "Categories", Expense/Income segment, then the user's categories as a reorderable card list (drag handle on the right, long-press to reorder; order drives every grid and list). Row actions (refs 24–26): tap a row → "Expense category" / "Income category" edit sheet pre-filled with name, emoji and colour, with Delete (left) and Save (right) buttons; swipe left on a row → red trash action, same as the expenses list. Both delete paths open a confirmation sheet: trash icon, "Are you sure you want to delete this category?", a red "Delete category" button and Cancel. Deleting never removes transactions: every transaction in that category is set to uncategorised (\`category\_id = NULL\`) and its budget limits are removed; the confirmation copy says so ("Its N transactions will be moved to Uncategorised"). Below: **Quick adds**, a fixed suggestion list per type with a "+" that adds it in one tap and removes it from the suggestions. Expense suggestions: Miscellaneous, Loan, Bills, Healthcare, Taxi, Public transport, Pets, Gifts, Travel, Education, Kids, Donations. Income suggestions: Part-time, Savings, Emergency fund, Tips, Retirement fund, Refunds, Interest. Sticky "New category" button at the bottom. Reachable from the pencil buttons and from Settings → Categories.

**Category filter sheet.** Opened from the "All categories" chip on Activity and from the pencil on Summary. Same grid as the category grid sheet, but tiles are multi-select (ticked tiles are outlined in their colour); "All" and "None" shortcuts; Expense/Income toggle; pencil to the Categories screen; "Add new" tile. The chip label becomes "3 categories" when a subset is active and the filter persists until cleared. The filter applies to the Activity list, its header chart, the Summary donut and rows.

**Seed data.** Expense: Housing, Food, Groceries, Utilities, Transportation, Shopping, Clothes, Going out, Entertainment, Subscriptions, Extras, Medicines, Investments. Income: Salary, Investments. Each with the emoji shown in the references and a colour from the 5.12 palette.

### 5.15 Motion and Liquid Glass

**Motion.** Sheets slide up with a drag handle and dim the page behind; bottom-nav selection animates the pill (200 ms, ease-out); hero numbers count up on period change (200 ms); category tiles and list rows fade-and-slide in on first appearance (staggered 20 ms, capped at 10 items); swipe-delete reveals a red background and the card springs back on cancel; haptics on FAB, Confirm, Add, swipe-delete and reorder. All motion checks `MediaQuery.disableAnimations` / iOS Reduce Motion and collapses to instant transitions when set.

**Liquid Glass.** iOS 26 introduces Liquid Glass; Flutter's own Cupertino widgets do not yet render it (tracking issue flutter/flutter#170310), so the app ships a hand-built glass surface and swaps to native where it pays off:

| Element | Treatment |
| --- | --- |
| Bottom nav pill, FAB, filter chips, settings button | `GlassSurface` widget: `BackdropFilter` blur 20–30 px + slight saturation boost + 1 px inner highlight; at most two stacked glass layers on screen |
| Sheets (month picker, add/edit, category grids) | Same surface; content behind stays visible through the sheet's top edge |
| Native option | Evaluate `liquid_glass_native` (real SwiftUI glass via platform views, iOS 26+, fallback below) for the tab bar and sheets; adopt it only if scrolling stays at 120 Hz on the iPhone 15 |
| Below iOS 26 and on Android | Flat `surface` colour, no blur |
| Widget | WidgetKit on iOS 26 applies glass automatically to system containers; keep the widget's own background transparent and use `containerBackground` so it adopts the system look |

Reduce Transparency turns every glass surface into the flat `surface` colour. Frame budget: measure with Flutter DevTools on the physical phone; the Activity list with 500 transactions must stay under 8 ms per frame at 120 Hz.

### 5.16 Budget screen and per-category budgets

References `18-budget-with-category.png` to `21-budget-keypad-over.png`. Refines 5.5 and 5.7 for the new look.

**Budget screen (ref 18).** Ring shows `remaining / salary` for the selected period. Below it, one card listing every category that has a limit: ring-style icon tile (the ring fills with the category colour as its budget is used), name, "₹left left" over "of ₹limit"; a final **Add category** row with a "+" tile. Tapping a category row opens its keypad sheet (below). Tapping Add category opens the **category grid sheet from 5.14** (expense categories only, showing only those without a limit); picking one opens its keypad sheet. The pencil opens the Allocate sheet.

**Allocate sheet (ref 06, 19).** Header card: "N% set", "₹allocated / ₹salary", thin progress bar in `income` green, "₹unallocated left to allocate". Every expense category is listed with its limit and share of salary; tapping a row opens that category's keypad sheet, and the header updates live when the sheet returns. Confirm saves all limits for the period.

**Per-category keypad sheet (ref 20–21).** Title "🏠 Housing monthly budget"; subtitle "₹X budget left" = salary − (all other limits) − (this amount as typed). Hero amount, clear button, 3×4 keypad, arrow key to save, back chevron, Done in the top bar. **Validation:** when the typed amount makes the subtitle negative, the subtitle turns red ("−₹10,000 budget left"), the arrow key and Done are disabled, and the sheet cannot be submitted. The limit is the salary resolved for the selected period (5.5), so a per-month salary override raises or lowers the cap for that month only. The "sum of limits can exceed salary" allowance in 5.5 is withdrawn.

### 5.17 Analytics swipe and income-left toggle

References `22-analytics-range.png`, `23-analytics-calendar-range.png`. The Analytics page shows a **6-period window** (e.g. Dec '25 – May) with the selected period highlighted as a pill under the axis. A horizontal swipe anywhere on the income/expenses card or the income-left card moves the window: **swipe right = previous 6 periods, swipe left = next 6**, stopping when the window's last period is the current one. Both cards and the calendar heatmap always show the same window and selected period; tapping a bar selects that period and the calendar jumps to it. The first label in a window that crosses a year carries the year ("Dec '25").

**Income left card.** Segmented toggle top-right: coin icon = amount, % icon = share of that period's income. Amount mode plots `income − expenses` per period; percent mode plots `(income − expenses) / income`, and a period with zero income draws a dashed outline bar with no value. The header number follows the toggle for the selected period. The choice persists across launches.

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
