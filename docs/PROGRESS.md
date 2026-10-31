# Progress

## Phase 5: Dashboards (2026-10-31)

Status: built on branch `phase-5-dashboards`, not merged. Tests pass and all four charts were viewed on the simulator. Release build installed on the iPhone 15; Rupesh confirmed the date and month pickers and the pie chart on the iPhone. The grey month highlight was removed at Rupesh's request. The fix for the Day-wise spillover below awaits confirmation.

### What was built
- `lib/domain/dashboards.dart`: period totals, daily and weekly buckets, daily average and budget pie slices, in pure Dart.
- `lib/features/dashboards/dashboards_screen.dart`: month-wise bars, day-wise bars with a dashed average, date-range line, budget pie with legend. Replaces the placeholder tab.
- `Money.compact` for chart axes. `Period.shortDate` is now public. `watchAllTransactions` and its provider feed the month-wise and date-range charts. `fl_chart` added. No schema change.

### Decisions
- Over-salary pie: slice angles stay budget shares in both states. The outer edge stands for total spend and the thin ring for salary. The ring radius is the square root of salary / spend, so areas compare truly and the ring stays visible at large overspends. SPEC 5.8 does not say how angles behave here.
- Slice shares follow SPEC literally: Unallocated is salary minus limits, and the uncategorised slice is added on top, so the slices can total more than the salary.
- Spend in a category with no limit has no slice (SPEC: one slice per category with a limit). It gets a legend row and counts in the over-salary total.
- Tapping a month-wise bar shows exact amounts in a line under the chart. Rupesh asked for no grey highlight on the selected month, so the line alone names it. fl_chart's tooltip disappears when the finger lifts and would show raw paise. Day-wise and date-range have no tap (see BACKLOG).
- The month-wise amount axis is on the right, beside the newest months, because the chart opens scrolled there.
- Daily average divides by the days up to today in a period in progress; otherwise a month would look cheaper early on. Past periods use all their days.
- A range of exactly 90 days is daily; 91 or more is by week. The average stays per day. The end date cannot be later than today.
- All credits count as income, as SPEC 3.2 says. The open question in SPEC 8 about refunds and transfers still stands.

- Charts have a solid line at zero, and the day-wise average is coloured and labelled "avg". Rupesh saw bars spilling below zero on Day-wise; reproduced on the simulator, nothing went below zero, but with one large day the dashed average sat just above zero and looked like the zero line.

### Checks
- `flutter analyze`: no issues. `flutter test`: 124 passed.
- Simulator (iPhone 18 Pro, iOS 27.2): temporary build opening on Dashboards, with 14 months seeded directly in the database. Day-wise average 1,006.45 = 31,200 / 31; date-range average 1,040.00 = 31,200 / 30; a 20,000 override showed "Over salary by ₹11,200.00" with the ring. Neither tapping nor the pie legend was viewed there; `simctl` cannot tap, so those are covered by widget tests only. The temporary changes and the simulator data were reverted.

### What to verify on the device
1. Dashboards tab: bars for the last 12 months. Tap a month: exact amounts appear under the chart. Drag right to scroll further back if you have older data.
2. Pick a month in the app bar: day-wise and pie change. Day-wise bars and average look right.
3. Date range: defaults to the last 30 days. Pick more than 90 days: "Shown by week".
4. Set category limits and a salary: half-spent limits are half dark, an overspent one has a red outline, the legend matches Categories.
5. Tap the salary on Home, set an override below this month's spend, return to Dashboards: "Over salary by" and the ring show. Clear the override.
6. Settings: turn on salary day. Day-wise follows the new dates. Turn it off.

### Open issues and setup notes
- Free-team install expires about 2026-11-06.
- A category limit of zero has no visible slice, only a legend row.

## Phase 4: Budgets + Home (2026-10-31)

Status: built on branch `phase-4-budgets-home`, not merged. Tests pass. Rupesh reported that all the device checks below passed on the iPhone 15 (2026-10-31).

### What was built
- `lib/core/period.dart`: `Period.forMonthKey` and `Period.containing` (SPEC 5.11). The transaction query, month picker and Expenses screen all use it. This removes the calendar-only shortcut noted in Phase 3.
- `lib/domain/budget.dart`: override-or-default, spend per category, bar level and fill, in pure Dart.
- `lib/features/home/home_screen.dart`: summary card, uncategorised count with shortcut, last 5 transactions.
- `lib/features/budgets/month_summary_card.dart`: the card shared by Home and Categories. Tapping the salary sets that month's override.
- `lib/features/budgets/categories_screen.dart`: progress bars, grey Uncategorised row, yellow note when limits exceed salary, tap to set limits.
- `lib/app/amount_dialog.dart`: one dialog for salary and limits. Blank removes the amount.
- Settings: default salary, month boundary switch, salary day. No schema change: the day is the `salary_day` row in `settings`.

### Decisions
- The selected month is now shared by Home, Expenses and Categories, in `selectedMonthProvider`. The Expenses filter is also a provider, so the Home shortcut can set it.
- Expenses gained a fourth chip, Uncategorised, so the shortcut's filter is visible and can be cleared.
- Salary day defaults to 28 when the switch is turned on (SPEC 8 open question). Turning it off forgets the day.
- Salary day 1 behaves as calendar months. By the "labelled by the month it ends in" rule, 1 Oct to 31 Oct is October.
- Changing the boundary returns the picker to the current period, because a picked month means different dates under the new rule.
- With no salary set, the card shows "Set salary", a dash for remaining and no bar, not a false negative.
- The uncategorised count includes credits, matching what the filter shows. A salary credit counts until it is categorised.
- An override or limit of zero is allowed and is different from blank.
- The card's salary tap also works on Categories, as it is the same card.

### Checks
- `flutter analyze`: no issues. `flutter test`: 97 passed.
- `period_test` walks every day of 4 years for every salary day from 1 to 31: each date falls in its period, the label is the month the period ends in, and periods have no gaps or overlaps.
- `budgets_home_test` checks Home against a month worked by hand.
- Simulator: Home viewed with seeded messages and a salary of 1,00,000 set directly in the database. Spent 4,800.50 and remaining 95,199.50 match by hand. Only Home was viewed; `simctl` cannot tap, so Categories, dialogs and Settings are covered by widget tests only.

### What to verify on the device
Nothing outstanding. Rupesh confirmed this list:
1. Settings: set a salary. Home shows spent, salary and remaining, and the sums match your own for the month.
2. Home: tap the salary and set an override. Only that month changes; blank restores the default.
3. Home: the uncategorised row opens Expenses filtered to those rows. Last 5 are newest first.
4. Set a low override so spent exceeds salary: remaining turns red, the bar is full, "Over salary by" shows.
5. Categories: tap a category and set a limit. Check green below 70%, amber from 70% to 100%, red above. Without a limit, spend only and no bar.
6. Limits adding up to more than the salary show the yellow note.
7. Settings: turn on salary day. On every tab, October 31 now falls in "November 2026", with "28 Oct – 27 Nov" under it. Turn it off and the totals return.

### Open issues and setup notes
- Free-team install expires about 2026-11-06.
- Spend in an archived category would not appear in a category row, though it still counts in the total. Archiving is not built yet (see BACKLOG).
- The selected month still does not refresh if the app stays open across a month end (see BACKLOG).

## Phase 3: Expenses screen (2026-10-31)

Status: built on branch `phase-3-expenses`, not merged. Tests pass and the list was checked on the simulator. On the iPhone, Rupesh reported that the app is working correctly and that the issues raised are resolved: the undo snackbar covering the add button, the month list, and an edited test message not importing. The cause of the missed import was not isolated. Credit messages were not tried.

### What was built
- `lib/features/expenses/expenses_screen.dart`: list grouped by day, uncategorised rows at 50% opacity with a hint, All / Expenses / Income chips, swipe-left delete with a 5-second undo, FAB. Long-press opens the edit sheet.
- `lib/features/expenses/transaction_sheet.dart`: one sheet for add and edit, with an expandable "from SMS" section showing the raw text.
- `lib/features/budgets/category_picker.dart`: grid, search and "New category". `CategoryAvatar` holds the icon-name mapping.
- `lib/app/month_picker.dart`: the dropdown Home will reuse in Phase 4.
- `MonthKey.start` and `MonthKey.range`. No schema change.
- The Expenses screen has its own `ScaffoldMessenger`, so the undo snackbar lifts the FAB. Rupesh saw it covered on the iPhone with the shell's messenger.

### Decisions
- The month picker lists at least the last 12 months, stretched to cover the oldest and newest transactions. Rupesh found that listing only months with data showed just October.
- After a save, the screen moves to the saved row's month and clears a filter that would hide it, so a saved row never seems to vanish.
- "New category" asks only for a name. The colour cycles through the seed palette and the icon is the generic one.
- A new manual row uses the chosen date with the current time. An edit keeps the original time.
- Deleting another row while an undo is showing ends the earlier undo; that delete becomes final.
- Credits show a leading `+` on the amount, so colour is not the only signal.
- `Money.tryParse` now returns null above 15 rupee digits. It used to throw or overflow, and the amount field now takes typed input.

### Checks
- `flutter analyze`: no issues. `flutter test`: 74 passed.
- Removing `persist: false` makes the snackbar test fail: Flutter otherwise keeps a snackbar with an action up indefinitely.
- Simulator (iPhone 18 Pro, iOS 27.2): messages seeded through the inbox appear grouped by day, dimmed, with long titles cut and Indian grouping. Only the list was viewed; `simctl` cannot tap, so gestures and sheets are covered by widget tests only.

### What to verify on the device
Rupesh's report did not go through this list item by item, and credit messages are still untried. A real UPI credit is known to land in Unparsed (see BACKLOG).
1. Expenses tab: real messages grouped by day, newest first, uncategorised rows dimmed.
2. Tap a row: picker opens, search filters, choosing saves and undims. "New category" creates and assigns.
3. Swipe left: red background, row goes, Undo restores it. Without Undo the snackbar goes after 5 seconds and the row stays gone after a force-quit.
4. Delete an SMS row, send the same SMS text again: it does not come back.
5. FAB: decimal keypad appears, the sheet stays above it, amount and category are required, the row saves.
6. Long-press an SMS row: amount and date editable, "from SMS" expands to the raw text.
7. Chips filter; the month dropdown switches months.

### Open issues and setup notes
- Months are calendar months only, in `watchTransactions`. Phase 4 replaces this with `Period`.
- The selected month is set when the tab is first built, so leaving the app open across a month end keeps the old month until changed.
- Free-team install expires about 2026-11-06.

## Phase 2: Parser + ingest (2026-10-31)

Status: built on branch `phase-2-parser-ingest` (from `phase-1-foundation`), not merged. Acceptance tests pass. On the iPhone, Rupesh confirmed a test SMS in the debit format raised Imported messages, and one with different wording reached Unparsed messages. Rupesh also confirmed a real HDFC message parsed correctly and an added sender survives a force-quit.

### What was built
- `lib/domain/parser/`: normaliser, SHA-256 fingerprint, date parsing and the first-match-wins parser, in pure Dart. Templates are in `templates/hdfc.dart`. The patterns run on normalised text, so a line break in the SMS is a single space. All three date formats work in both templates.
- `lib/features/ingest/ingest.dart`: the SPEC 5.1 pipeline, committing each line in its own database transaction. `inbox_reader.dart` drains the inbox on launch and resume.
- `lib/features/settings/settings_screen.dart`: list and add tracked senders, imported count, read-only Unparsed messages list.
- Schema v2: a `settings` key/value table and the seeded HDFC sender, for new databases and through a migration. `bank` columns now hold the `Bank` enum.
- Native inbox: `claim` renames `inbox.jsonl` to `inbox.jsonl.claimed` under a file lock shared with the intent, and `ack` deletes it after the database commit. This replaces the "then truncated" in SPEC 3.3: truncating could lose a line on a crash or during a concurrent write.

### Decisions
- Patterns are case-insensitive "text contains", not regex. The Shortcuts intent passes only the message text, so sender IDs cannot be matched.
- `occurred_at` is the date in the SMS plus the time of day it arrived, because the SMS has no time.
- Audit rows use `ignored`, since SPEC has no separate status: ref-guard duplicates (with `ref_no`) and stale lines (with raw text). Untracked messages are `ignored` with no text kept, as they may be private.
- A line that is not valid JSON is logged `failed` and shown under Unparsed, and later lines still import.
- The imported count and Unparsed list are in this phase because 5.1 requires the list and the Expenses screen is Phase 3.

### Checks
- `flutter analyze`: no issues. `flutter test`: 57 passed, including goldens for both 5.1 samples, duplicate delivery and the v1 to v2 migration.
- Swift `RunnerTests` on the simulator (iOS 27.2): 2 passed, including claim, retry and ack.
- Simulator, real app and method channel: a line appended to the App Group inbox became one transaction on resume; the same line delivered again added none, and the inbox file was gone after each drain.
- Release build installed on the iPhone 15 with `devicectl`. Test SMSes triggered the automation: the debit-format one raised Imported, and one with other wording appeared under Unparsed, as reported by Rupesh.

### What to verify on the device
Nothing outstanding from the Phase 2 list, except that the report did not say whether the real message was a debit or a credit. If the other type lands in Unparsed, its template needs fixing.

### Open issues and setup notes
- During testing the intent twice received text that was not the SMS: one run sent the literal words `Shortcut Input` (matched by fingerprint), and an earlier run's text is unknown. Both are `ignored` rows and do not appear in Settings. After the input pill was re-checked, a real SMS came through. The exact cause was not isolated.
- Real wording that differs from a template lands in Unparsed, not in a wrong expense.
- Any HDFC text matching the tracked pattern with no template, such as an OTP, is `failed` and its text is stored and shown under Unparsed. That follows SPEC 5.1.
- The stale-line skip follows SPEC 5.1. If the phone's clock is moved backwards, a genuine new message can be skipped. It stays in `ingest_log` as `ignored` with its raw text, but no screen shows it.
- A database error leaves the claimed file in place and retries on the next resume. A line that always throws would block the inbox; none is known.
- Transactions cannot be seen in the app until Phase 3. Imported and Unparsed are the only view for now.
- The `inbox.jsonl.lock` file in the App Group is expected and stays there.
- `xcodebuild test` shuts down the simulator afterwards, so boot it again before using `simctl`.

## Phase 1: Foundation (2026-10-31)

Status: built on branch `phase-1-foundation`, not merged. Rupesh confirmed it on the iPhone.

### What was built
- Riverpod, go_router and drift. The generated `lib/data/database.g.dart` is committed; regenerate with `dart run build_runner build`.
- `lib/data/database.dart`: all six tables from SPEC 3.2, with the 8 categories seeded when the database is created.
- `lib/core/money.dart` (`format`, `tryParse`) and `lib/core/month_key.dart` (`of`, `shift`, `label`), pure Dart with tests.
- `lib/app/`: theme (light and dark) and the five-tab shell. Categories lists the seeded rows so the database is exercised on a device; the other four tabs are placeholders.
- Removed the Phase 0 inbox screen and its test. The Swift intent, `Inbox` and the `paisa/inbox` channel are unchanged, for the Phase 2 reader.

### Additions to the SPEC 3.2 schema
- `ingest_log.raw_text` (nullable): SPEC 5.1 must show the text of failed messages, and those have no transaction row.
- `ingest_log.ref_no` (nullable): SPEC 3.2 says the log keeps it but lists no column.
- Unique indexes on `budgets` and `salary`, so a category or the salary can have only one default and one override per month.

### Checks
- `flutter analyze`: no issues. `flutter test`: 35 passed.
- Release build installed on the iPhone 15 (iOS 27.2). Rupesh confirmed the tabs switch, the 8 categories show, and a force-quit and reopen launches from the home screen with no duplicates.
- Simulator (iOS 27.2): debug build launches. The runtime was installed with `xcodebuild -downloadPlatform iOS`.

### What to verify on the device
Nothing outstanding for Phase 1.

### Open issues and setup notes
- The app no longer shows captured messages until Phase 2. The intent still appends to `inbox.jsonl`, and nothing reads or truncates it.
- Install updates with `xcrun devicectl device install app`, not `flutter install`. It installs over the app, so the data and the developer trust stay.
- Phase 2 must seed the default HDFC tracked sender (SPEC 5.1), in a migration if the database already exists on the phone. Phase 1 seeded categories only.
- SPEC mentions a settings store (5.1 last `received_at`, 5.11 month boundary), but 3.2 has no table for it. Phases 2 and 4 need to add one.
- Category icons are stored as Material icon names. The name-to-icon mapping comes with the first screen that shows them.
- Not built, as nothing uses them yet: `result types` and date helpers beyond `MonthKey` (SPEC 3.1). `Period` is Phase 4.
- App name: kept "Paisa".

## Phase 0: Capture spike (2026-10-30)

Status: acceptance passed on iPhone 15, iOS 27.2, as reported by Rupesh. Branch `phase-0-capture-spike`, not merged.

### What was built
- Empty Flutter app, iOS only, minimum iOS 17, bundle ID `com.rupeshkankrej.paisa`, signed with the free Personal Team.
- `ios/Runner/IngestBankMessageIntent.swift`: the App Intent, in the main app target, appends one JSON line to `inbox.jsonl` in App Group `group.com.rupeshkankrej.paisa`. It does not open the app.
- `lib/main.dart`: temporary screen showing the raw inbox, read over the `paisa/inbox` method channel in `AppDelegate.swift`. Replace it in Phase 1.
- `doc/` renamed to `docs/` to match CLAUDE.md and the spec.

### Automation that worked
Shortcuts → Automation → Message → Message Contains `HDFC Bank`, sender blank, Run Immediately → Ingest bank message, with the message as input.

The sender filter was not tried. A test SMS from another phone cannot come from `VM-HDFCBK`.

### Checks
- `flutter analyze`: no issues. `flutter test`: 2 passed.
- Swift `RunnerTests` (line format) passed on the iPhone.
- Rupesh confirmed on the device that the capture works ("yes it is working").

### What to verify on the device
Confirmed by Rupesh: real HDFC alerts for both money sent and money received trigger the automation and appear in the app, using the text filter. This covers real bank senders (SPEC 2.1 risk a).

Not separately confirmed:
- Whether those alerts were sorted into Transactions when they fired (SPEC 2.1 risk b).
- Whether it writes while the phone is locked. A message before the first unlock after a restart may fail, because of iOS file protection.

### Open issues and setup notes
- The free-team install expires after 7 days and the automation stops until it is re-run from Xcode. Next expiry is about 2026-11-06.
- Reinstalling with `flutter install` uninstalls first. iOS can then drop the developer trust, so redo Settings → General → VPN & Device Management → Trust.
- Use release builds. Debug builds will not launch from the home screen without a Mac attached.
- `xcodebuild test` on the device replaces the release build, so rebuild and reinstall afterwards.
- Homebrew's Flutter ships `gen_snapshot_arm64` with the macOS quarantine flag, and macOS kills it (exit -9). This was fixed by removing the flag from that one file with `xattr -d com.apple.quarantine`. A Flutter upgrade may bring it back, and 45 other Flutter files still carry the flag.
- No iOS simulator runtime is installed, so Swift tests run on the phone. Phase 1 acceptance needs a simulator, which can be added in Xcode → Settings → Components.
- The app name is still an open question in SPEC section 8. The bundle and App Group IDs use "paisa", so decide before Phase 1.
- The Phase 2 inbox reader must not lose lines appended while it reads and truncates `inbox.jsonl`.
