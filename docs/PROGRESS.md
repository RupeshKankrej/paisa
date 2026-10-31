# Progress

## Phase 9: Categories (2026-10-31)

Status: built on branch `phase-9-categories` (from `main`), not merged. Tests pass and the new screens were viewed on the simulator. Device checks below are waiting on Rupesh.

### What was built
- Schema v4: `categories` gains `type` and `emoji`; `icon` is dropped. Ids stay, so transactions and budgets keep their links.
- `lib/domain/categories.dart`: palette, quick adds, name clash, emoji check and filter logic, in pure Dart with tests.
- `category_picker.dart`: one grid sheet for picking and for the multi-select filter, with Expense/Income segment, pencil, Add new.
- `category_edit_sheet.dart`: new and edit, with emoji field, 42 swatches, Archive and Delete.
- `manage_categories_screen.dart`: segment, reorderable list, quick adds, New category. Reached from the pencils and Settings → Categories.
- Filter: stored in `settings`, so it survives a relaunch. It narrows the Activity list, hero and chart, and the Summary donut and rows.
- The add sheet strip follows the row's type; toggling type clears the category. Picking from the other segment of the grid flips the row's type.

### Decisions
- An existing install keeps its 8 categories and gains Salary and Investments (income). Only new installs get the full 5.14 seed. Renaming someone's categories was not safe to assume (see BACKLOG). Existing credits stay tagged as they are.
- Archived categories still give old rows their name and colour, and their spend still gets a Summary row. This closes two BACKLOG items. Their limits no longer count toward limit totals or the budget pie.
- Over salary on Summary always compares all spend with salary. With a filter on, the donut's outline and ring are hidden, as they would describe a subset.
- Tiles start all ticked under All. Unticking one makes a subset, ticking the last returns to All. All and None apply across both types. Tile taps apply at once, with no Confirm.
- A saved row outside the active filter clears the filter, as with the type chips, so it never seems to vanish.
- The Activity filter chip comes first in the row: placed after Uncategorised it was off-screen, so the total looked wrong with no visible reason.
- The Summary pencil sits outside the scrolling chips, and a "N categories" chip shows when a filter is on.
- From the iPhone check, Rupesh asked for two changes. The emoji tile now opens the emoji keyboard through a hidden native field (`paisa/emoji` in `AppDelegate.swift`). Tapping a categorised row opens the edit sheet (SPEC 5.2 updated); an uncategorised row still opens the grid, as its hint and SPEC 5.14 say, and long-press edits any row.
- SPEC 5.14 update (references 24 to 26): the edit sheet is titled "Expense category" or "Income category" with Delete and Save; swipe left on a row deletes; both go through a confirmation sheet with the transaction count. Transactions are never deleted, only moved to Uncategorised. The Archive button is gone, as 5.14 dropped it; the Archived section remains for categories already archived (see BACKLOG).
- The picker's search is gone: SPEC 5.14 and the references have none, though SPEC 5.2 still mentions it.
- Quick-add colours cycle the 5.12 palette. Palette swatches are read by eye from reference 13. Emoji for Education, Kids, Donations, Refunds and Interest are my picks, as no reference shows them.
- References: where SPEC 5.14 and the filenames disagree (see the entry below), the filenames were followed.

### Checks
- `flutter analyze`: no issues. `flutter test`: 168 passed. The emoji keyboard opening was viewed on the simulator; picking an emoji through the native field is covered by a test with a simulated channel only.
- The upgrade test builds a real v1 file and checks ids, emoji, types and colours after migrating to v4.
- Simulator (iPhone 18 Pro, iOS 27.2): temporary entry point with in-memory data, deleted afterwards. Viewed: Categories (income), grid, new sheet, palette, filter, Activity and Summary with a filter. This found the off-screen chip, invisible All/None chips and an underlined name field; the fixes were not viewed again on the simulator. Later, the swipe action, edit sheet and delete confirmation were viewed and match references 24 to 26. Reorder and completing a delete are covered by widget tests only. The simulator still has that temporary build installed.

### What to verify on the device
1. Force-quit and open: your rows, categories and limits are all there, with the same emoji and colours.
2. Settings → Categories: Expense and Income lists, side by side with references 15 and 16. Drag a handle and long-press a row to reorder; force-quit; the order stays and drives the grid and add sheet strip.
3. Quick add: + adds it and removes it from the list.
4. New category: tap the emoji tile and the emoji keyboard opens; pick one; pick a colour; Add. It appears in the add sheet strip, Summary donut (after spending in it) and the filter. A duplicate name, any case, is refused.
5. Activity and Budget: tap a categorised row and the edit sheet opens; tap an uncategorised row and the grid opens. On the Categories screen, compare with references 24 to 26: tap a row, edit and Save. Swipe a row left: the confirmation shows the transaction count; Cancel keeps it. Delete one with transactions from the sheet and one by swipe: rows become uncategorised and dimmed, and totals do not change.
6. Tap an uncategorised row and the add sheet's grid button: compare with references 11 and 14. The pencil opens Categories and back returns to the sheet.
7. Filter chip on Activity and pencil on Summary: None, tick two, chip reads "2 categories"; list, hero, chart, donut and rows narrow. Force-quit; the filter stays. All clears it.
8. Add sheet: Income shows income categories. Save a row outside the filter: the filter clears.
9. Widget figures are unchanged by a filter.

### Open issues and setup notes
- Rupesh's uncommitted SPEC edits were not committed in this phase. They undo the SPEC 5.2 tap-to-edit wording, and 5.17 now says swipe left goes to previous, the opposite of the app's month swipe. The code keeps tap-to-edit and the current month swipe until Rupesh decides.
- If the emoji keyboard is removed in iOS Settings, the tile falls back to the normal keyboard and letters are ignored.
- A tagged category of the other type stays on old rows and shows first in the strip when editing.
- Free-team install expires about 2026-11-07.

## Spec and design update, no phase (2026-10-31)

Status: docs only, on branch `docs-spec-design-update`, not merged. No code changed, so nothing to verify on the device.

### What changed
- SPEC section 4: Phase 9 is now Categories, Phase 10 is Budget, Analytics and Settings, Phase 11 is Motion and Liquid Glass, Phase 12 is Polish and release.
- SPEC 5.13 to 5.17 added or extended: month picker, categories, motion and Liquid Glass, per-category budgets, Analytics swipe and income-left toggle.
- SPEC 5.5: the sum of category limits can no longer exceed the period's salary.
- References 10 to 23 added and listed in `docs/design/reference/README.md`.
- The swipe direction item is removed from BACKLOG, since SPEC 5.13 now states it.

### Open issues
- `docs/design/reference/README.md` still gives Phase 9 for references 05 to 09; SPEC now builds them in Phase 10.
- SPEC 5.14 cites refs 11 and 15 for the grid and 14 and 16 for the Categories screen. The README and filenames say 11 and 14 are the grid, 15 and 16 the screen.

## Phase 8: UI Activity, Add, Summary (2026-10-31)

Status: built on branch `phase-8-ui-activity-summary` (from `phase-7-design-system`, which is not merged), not merged. Tests pass and the three screens were viewed on the simulator. Rupesh confirmed swipe works on the iPhone; the other device checks below are waiting.

### What was built
- Activity: one scrolling page with the gradient header, month caption, hero total and `DayBarChart` (`lib/features/expenses/day_bar_chart.dart`), then chips and day cards. The settings button stays put while the page scrolls under it.
- Add/Edit (`transaction_sheet.dart`, rewritten): near-full-height sheet, hero amount, backspace, reset, delete, chips, category strip with grid button, 3x4 keypad with a light arrow key. This also fixes the drag handle sitting beside the clock.
- Summary (`categories_screen.dart`, rewritten): donut with the month and total in the centre, Expenses/Income chips, rows with count, amount, % pill and budget bar.
- Spec update (5.13, reference 10): `MonthPicker` is now a "This month ▾" caption opening the Select date sheet, with year chips, a 3x4 month grid with future months disabled, the date range in salary-day mode and the swipe tip. It replaces the dropdown on every screen.
- `MonthSwipe`: a horizontal swipe changes the shared month. Right goes back, left goes forward and stops at the current period, as Rupesh asked after trying it. SPEC 5.13 and 5.17 now state this direction for all date swipes. It is on the Activity header, the Summary donut, and the Analytics day-wise and budget cards.
- Activity day bars are drawn in a gradient, as Rupesh asked.
- Pulling Activity down past the top showed the page background above the gradient (Rupesh, iPhone). The header's top colour now extends above it. Checked with a held pull-down on the simulator.
- Fixed the add button sitting under the nav on the iPhone. It read the safe area once, without subscribing, so a first frame with no inset left it 14 points too low. A test reproduced this before the fix.
- Pure helpers with tests: `MonthKey.pickerYears`, `Money.keypadPress`, `keypadText`, `keypadDisplay`; `totalsByCategory` and `percentLabel` in `lib/domain/budget.dart`. No schema change.

### Decisions
- The donut shows spend share, as reference 03 does, so slices match the % pills. SPEC 5.12 says the budget pie becomes this donut; the budget pie stays on Analytics so nothing is lost (see BACKLOG).
- Over salary on the donut: a red outline, "Over salary by", and a thin inner ring whose sweep is salary / spend.
- Summary lost the spent/salary/remaining card to match the reference. One line under the donut keeps the picture from SPEC 5.7 ("₹X left of ₹Y"). Editing the salary override is on the Budget tab only.
- Uncategorised stays the top row per SPEC 5.7, then categories by amount. Zero-spend categories stay listed so a limit can be set. The Income chip lists only categories with income, without bars or limit editing.
- Row amount and % pill are stacked, not in one line as in the reference, because paise leave a name too little room.
- Sheet icons: refresh resets the sheet to its opening values, as the reference's meaning is unknown. Delete shows only when editing from Activity and uses the same 5-second undo. The clear button deletes one digit on tap and clears all on long press.
- Chips: the reference's Personal slot is the Expense/Income toggle (SPEC 5.3). A read-only account chip shows only when a row has an account number. Note and "from SMS" are chips, since SPEC 5.3 and 5.4 keep them.
- A category picked from the grid moves to the front of the strip. A tap in the strip does not move it, so rows do not jump.
- The first validation error shows under the amount: "Enter an amount", then "Pick a category".
- Swipe covers the whole Activity header, including the caption and hero, not only the chart, to give a larger target. The minimum swipe is 32 points.
- The Analytics month-wise and date-range charts do not swipe. Month-wise already scrolls sideways and date-range has its own dates. Phase 10 replaces them with the 6-period window (5.17).
- Swiping back has no floor, and the year chips stretch to include the selected year.
- Caption wording: "This month", the month name within the current year, month and year otherwise. In salary-day mode the range stays under the caption (5.11).
- Not added: search, Monthly, All accounts and sort chips (already in BACKLOG), and the sheet's overflow menu.

### Checks
- `flutter analyze`: no issues. `flutter test`: 147 passed. The Activity picker tests caught it sitting under the transparent app bar, where it could not be tapped; fixed with `belowFloatingBar`.
- Simulator (iPhone 18 Pro, iOS 27.2): temporary entry point with in-memory data, since `simctl` cannot tap. Activity, the add sheet, and Summary in the normal and over-salary states were viewed. This found colliding day labels (fl_chart ignores `interval` on bar titles) and dim Summary amounts. Both are fixed; the label fix has a widget test, but neither fix was viewed again on the simulator. The swipe and the month sheet were then driven with synthetic touches on the simulator and viewed: September's rows and bars appeared, and the sheet matches reference 10. The edit sheet was not viewed; other gestures are covered by widget tests only. The simulator still has that temporary debug build installed.

### What to verify on the device
1. Side by side with `docs/design/reference/01` to `04` and `10`: Activity, add sheet, Summary, month sheet.
2. Force-quit and open: the + sits above the nav on every tab.
3. Swipe right on the Activity header: previous month's rows and bars. Swipe left: forward, stopping at this month. Same on the Summary donut and the Analytics day-wise and budget cards. Vertical scrolling still works when starting on the chart.
4. Tap the caption: pick another year and month. Later months cannot be tapped. With salary day on, the range shows under the grid.
5. Activity: tap to categorise, swipe to delete with Undo, chips filter, uncategorised rows dimmed.
6. +: type an amount with paise on the keypad, backspace, long-press backspace to clear. Pick a date, toggle Income, add a name and note, pick from the strip and from the grid including New category. The arrow saves.
7. Long-press an SMS row: amount and date editable, "from SMS" shows the raw text, reset restores, delete offers Undo.
8. Summary: slices and % add up, tap a row to set a limit, bar colours, yellow note, Income chip.
9. Over salary: set an override below spend on the Budget tab, see the outline, ring and red line on Summary. Clear it.
10. Widget still updates after adding from the new sheet, and `paisa://add` opens it.

### Open issues and setup notes
- The sheet's keypad has fixed-height keys. Fits on the iPhone 15; a larger accessibility text size has not been tried.
- Small slices have barely rounded corners, as the corner radius is limited by slice width.

## Phase 7: UI design system + shell (2026-10-31)

Status: built on branch `phase-7-design-system`, not merged. Tests pass and the tabs were viewed on the simulator. Rupesh reported all the device checks below passed on the iPhone 15 (2026-10-31).

### What was built
- `lib/core/theme/`: SPEC 5.12 tokens and a dark `ThemeData`. Cards, chips, FAB, sheets and dividers get their look from the theme.
- `lib/app/shell_widgets.dart`: pill nav, round settings button, `AddFab`, `HeroAmount`, `GroupedCard`, `tabAppBar`.
- Tabs: Activity (Expenses), Summary (Categories), Budget (Home), Analytics (Dashboards), Accounts (placeholder). Settings is a pushed route behind the top-left button.
- Activity: hero spend, horizontally scrolling chips, day-grouped cards with a day total. `CategoryAvatar` is now an emoji tile with a 2 px category-colour border. The month dropdown is a small caption with a chevron.
- Schema v3: existing categories move to the 5.12 colours, matched by old colour. No other data changes.

### Decisions
- The app now opens on Activity, the first tab, not Home. This and the FAB and hero below are the only additions to "no behaviour change".
- Home stands in as the Budget tab until Phase 9, so its summary, salary override and uncategorised shortcut stay reachable.
- The FAB is on every tab as SPEC asks and opens the same add sheet. After a save it moves to the row's month, as Expenses already did. The open-sheet guard moved to a provider, so a widget link cannot stack on a sheet opened from any tab.
- Not added: search, Monthly, All accounts and sort chips. They have no behaviour behind them yet (see BACKLOG). The existing four filters stay.
- Debit amounts stay red-ish per SPEC 5.2 (`AppColors.debit`), though the reference shows white. Credits use `income`.
- Icon tiles are round, per the SPEC radii table (`AppRadii.round`). The reference shows rounded squares; it is a one-line change in `CategoryAvatar`.
- Dark only until Phase 9, so the app ignores the system light setting for now.
- A day total is the day's spend, or its income with a plus if nothing was spent.
- The undo snackbar now floats above the FAB rather than lifting it, as both sit above the pill.
- Emoji come from the stored Material icon names, so no icon column changed. New categories still get the generic one.
- Left for Phase 8 and 9: Activity gradient and day-bar chart, donut, custom keypad, chart restyle, nav animation. The form inside the add sheet is only restyled.

### Checks
- `flutter analyze`: no issues. `flutter test`: 130 passed, including the FAB clearing the pill with a home-indicator inset, FAB on each tab, Settings push and back, the colour migration (a colour outside the old palette is untouched) and day totals.
- Simulator (iPhone 18 Pro, iOS 27.2): temporary entry point cycling routes, since `simctl` cannot tap. Activity, Summary, Budget, Analytics, Accounts, Settings and the add sheet were viewed. This found and fixed the FAB under the pill, an unreadable selected chip and a white progress track. Gestures are covered by widget tests only. The simulator still has that temporary debug build installed.

### What to verify on the device
Nothing outstanding. Rupesh confirmed this list:
1. Force-quit and open: opens on Activity, your data is there, categories show the new colours and emoji.
2. Side by side with `docs/design/reference/01` and `03`: nav, chips, cards, FAB.
3. Each tab switches, and the + opens the add sheet on all five. Save one from Summary.
4. Top-left button opens Settings, back returns. Salary day and senders still work.
5. Activity: tap to categorise, long-press to edit, swipe to delete, Undo above the +, chips filter, month dropdown switches, uncategorised rows dimmed.
6. Budget: salary override, uncategorised shortcut. Summary: limits, bar colours, yellow note. Analytics: all four charts, including an override below spend for the over-salary ring. Clear it.
7. Widget: spent and remaining still match, links open Expenses and the add sheet. Categories on the medium widget use the new colours.

### Open issues and setup notes
- A failing widget test that skips its teardown leaves `flutter test` idle rather than exiting: a drift stream stays open. Look at the log before assuming a real hang.
- The add sheet at full height reaches the status bar, so its drag handle sits beside the clock. Phase 8 replaces this sheet.
- The month dropdown is as wide as its longest month, so the current month sits slightly off-centre.

## Phase 6: Widget (2026-10-31)

Status: built on branch `phase-6-widget`, not merged. Tests pass. Rupesh reported all the device checks below passed on the iPhone 15 (2026-10-31), including the fix for stacked sheets.

### What was built
- `lib/domain/widget_summary.dart`: builds the SPEC 3.3 JSON, in pure Dart.
- `widgetSummaryProvider` in `lib/data/providers.dart`: rebuilds when the current period's transactions, salary, categories or the salary day change. `lib/main.dart` publishes each new value and refreshes on resume.
- `lib/widget/widget_bridge.dart` and a `paisa/widget` channel in `AppDelegate.swift`: atomic write of `widget_summary.json` to the App Group, then a `home_widget` reload.
- `ios/PaisaWidget/`: WidgetKit extension with small and medium families, App Group entitlement, bundle ID `com.rupeshkankrej.paisa.PaisaWidget`, embedded in Runner.
- Deep links: the `paisa` URL scheme and a router redirect. `paisa://expenses` opens Expenses and `paisa://add` opens the add sheet.

### Decisions
- `home_widget` can only write to UserDefaults, so the file SPEC 3.3 asks for goes over our own channel, and `home_widget` only does the reload.
- The widget is labelled with the month from the JSON, not "this month". After a month end, or while SMS rows wait for the app to open (SPEC 6), it shows the period its figures belong to.
- Swift cannot call the Dart Money helper, so the widget has its own `money()`. `₹1,55,453.00`, `-₹2,000.00` and `₹0.05` were checked by running it.
- Medium shows the top 3 categories by spend and an add link. Small shows spent, remaining and the bar only.
- With no salary set, the widget shows a dash for remaining and no bar, as on Home.
- A widget link leaves an open add or edit sheet in place. Rupesh saw this when tapping the widget with the add sheet left open: Expenses is behind the sheet. Closing it would lose typed input. A second add link no longer stacks another sheet; a test reproduced that bug before the fix.
- Budget limits are not in the summary, so a limit change does not rewrite the file. SPEC 6 lists budget changes, but nothing in the JSON depends on them.

### Checks
- `flutter analyze`: no issues. `flutter test`: 129 passed (the shell test gained the open-sheet cases), including the summary following the database and both links through the platform navigation message.
- Simulator (iPhone 18 Pro, iOS 27.2): the app wrote `widget_summary.json` with spent 4,800.50 and salary 1,00,000, matching the seeded data. `simctl openurl` stops at an "Open in Paisa?" prompt that cannot be tapped, so real URL delivery from iOS is untested. The widget UI has not been rendered anywhere yet.
- Release build signed with the free team, including the extension and its App Group.

### What to verify on the device
Nothing outstanding. Rupesh confirmed this list:
1. Long-press the home screen, add the Paisa widget, small and medium. Spent and remaining match Home.
2. Open the app, add an expense, go home: the widget figures change.
3. Tap the small widget, from both a force-quit and a running app: Expenses opens.
4. Tap "Add expense" on the medium widget, from both states: the add sheet opens. Tap the rest of the medium widget: Expenses opens. With the add sheet left open, tap "Add expense" again: closing the sheet once returns to Expenses.
5. Set a salary override below spend: remaining turns red and the bar is full. Clear it.
6. Turn on salary day: the widget month follows the period label. Turn it off.

### Open issues and setup notes
- Free-team install now expires about 2026-11-07. The widget also stops working when the install expires.
- SMS rows reach the widget only after the app next opens, as SPEC 6 expects.

## Phase 5: Dashboards (2026-10-31)

Status: built on branch `phase-5-dashboards` and merged to `main` by Rupesh (PR #7). A force-push dropped the merge from `main`; Rupesh restored it in `f7b583f`. Tests pass. Rupesh reported the device checks below passed on the iPhone 15 (2026-10-31).

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
Nothing outstanding. Rupesh confirmed date and month pickers, the pie chart, tapping a month for its amounts, and Day-wise following salary-day dates. On the spillover fix, Rupesh reported "daywise is not hitting zero line", read here as bars no longer crossing it; on the simulator they end exactly on the line. Scrolling back and "Shown by week" were not named individually.
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
