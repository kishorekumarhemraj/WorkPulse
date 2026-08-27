# Timesheet Entry Grid — Design & Delegation Brief

Status: design only, not implemented.
Target branch: a fresh branch off `develop`.
Companion: `docs/TIMESHEET_CODE_DESIGN.md` (code resolution). See §12 for how
the two interlock.

---

## 1. Where the requirement comes from

The user transcribes WorkPulse's numbers by hand into an IQVIA PeopleSoft
timesheet. That form is the specification. From a screenshot of it:

| Property | Observed |
|---|---|
| Week | **Saturday 08/22 to Friday 08/28** |
| Week total ("Quantity") | 42.50 |
| Rows | 5 |
| Row totals | 5.00, 10.00, 7.50, 10.00, 10.00 |
| Daily totals | Mon–Fri 8.50 each; Sat, Sun **blank** (not `0.00`) |
| Cell precision | Two decimal places — `1.00`, `1.50`, `2.00` |
| Grid columns | Sat · Sun · Mon · Tue · Wed · Thu · Fri · Total, then the coding columns |
| Coding columns | Time Reporting Code, Business Unit PC, **Project ID**, Activity ID, Resource Type, **Resource Category**, **Resource Sub-Category**, Comments |
| Project IDs seen | `ITCMEL19`, `ITCMEL21`, `VEEVA026` |
| Export | The form offers "Download to Excel" |

### The observation that sets the row key

`ITCMEL19` appears on **more than one row**, distinguished only by
**Resource Category** — `660` on one, `670` on another. The same project's
hours are split across two rows by some second dimension.

That dimension is CapEx / OpEx. Confirmed with the user:

| Resource Category | Means |
|---|---|
| `670` | **CapEx** — capitalizable |
| `660` | **OpEx** — operational |

which is exactly what WorkPulse already tracks as `FinancialClassification`.
So **a grid row is keyed by (timesheet code, classification)**, never by code
alone.

The numbers themselves stay out of the app (§11). They are written down here
only so a reader of this brief can check the grid against the real form.

### What the app must *not* try to reproduce

`Time Reporting Code`, `Business Unit PC`, `Activity ID`, `Resource Type`,
`Resource Category` and `Resource Sub-Category` are IQVIA-PeopleSoft columns.
AGENTS.md rules 1 and 2 forbid them in the domain model or the schema. **Do not
add `resourceCategory`, `businessUnit`, `activityId` or any sibling field
anywhere.** The grid reproduces the *shape* of the form — days across, coded
rows down — not its vocabulary. See §11 for the deliberate non-goal.

---

## 2. What this adds to the Time Sheet screen

Two changes, in this order down the page:

1. **An entry grid at the top** — one block per week in the selected range.
   Rows are (code × classification); columns are the seven days; cells are
   decimal hours. This is the thing the user reads while typing into the
   portal.
2. **The existing breakdown tables move into a two-column layout** below it, so
   the analysis that used to require scrolling fits on one screen.

---

## 3. Decisions locked

| # | Decision | Why |
|---|---|---|
| D1 | Grid row key is **(resolved timesheet code, financial classification)** | The portal splits one project ID across two rows by resource category (§1). |
| D2 | **Week start day is a setting**, default Saturday | WorkPulse's week currently starts Sunday (`analytics_model.dart:26`, `now.weekday % 7`). The portal's starts Saturday. Off by one day, every week, silently. |
| D3 | **One grid block per week** in the selected range, capped at 6 | Removes any possibility of the grid and the tables below disagreeing about dates. A month range yields four or five blocks — which is a month of timesheets. |
| D4 | **Every total is the sum of the rounded cells**, never the rounded sum | The portal computes its own totals from what is typed. See §6 — this is the highest-risk part of the whole feature. |
| D5 | **A zero cell renders blank** | Matches the form, and a screen of `0.00` is unreadable. |
| D6 | Rows sort by **code, then classification** — not by size | The user reads down the list while typing. Stable beats interesting. |
| D7 | No portal-specific columns in the model | AGENTS.md rules 1 and 2. |

---

## 4. The model

New in `lib/domain/models/timesheet_model.dart`:

```dart
/// One week of the entry grid — the shape the user's timesheet form has.
class TimesheetWeek extends Equatable {
  /// Local midnight of the week's first day, on the configured start day.
  final DateTime start;

  /// Exactly seven local midnights, ascending from [start].
  final List<DateTime> days;

  final List<TimesheetGridRow> rows;

  /// Seven entries. Each is the sum of that column's already-rounded cells,
  /// which is what the portal will compute from the typed figures.
  final List<double> dailyTotals;

  /// Sum of every rounded cell. Compare with [exactTotal] to see the drift
  /// rounding introduced.
  final double total;

  /// What was actually tracked, before rounding.
  final Duration exactTotal;

  bool get isEmpty => rows.isEmpty;
}

/// One line of the form.
class TimesheetGridRow extends Equatable {
  /// The resolved timesheet code. Empty string where none could be resolved.
  final String code;

  /// [code], or 'No timesheet code' when it is empty.
  final String codeLabel;

  final FinancialClassification classification;

  /// Exactly seven values, aligned to [TimesheetWeek.days], already rounded
  /// to the configured increment. Zero means "leave the cell blank".
  final List<double> cells;

  /// Sum of [cells]. Not the rounded true total — see §6.
  final double total;

  final Duration exactTotal;

  /// Shown as a subtitle so a row can be traced without leaving the screen.
  final String? projectName;
  final String? optionLabel;   // the release, where the code came from one

  /// True when the code fell back or is missing — carried through from
  /// TimesheetCodeResolution.needsAttention.
  final bool needsAttention;
}
```

Add to `TimesheetData`:

```dart
/// One entry grid per week in range, ascending. Empty when the range holds
/// no sessions.
final List<TimesheetWeek> weeks;

/// True when the range spans more weeks than [maxTimesheetWeeks] and [weeks]
/// was truncated, so the screen can say so rather than quietly showing less.
final bool weeksTruncated;
```

```dart
const int maxTimesheetWeeks = 6;
```

---

## 5. Day attribution — three ways to get this wrong

A cell is "how much of this row's time fell on this local calendar day". Three
traps, all of which produce numbers that look plausible and are wrong.

### 5a. A session can span midnight

Work from 23:00 to 01:00 is two hours on two different days. The service must
intersect each session's span with each day, not bucket the session by its
start time.

```dart
/// How much of [spanStart, spanEnd) falls inside the local calendar day
/// beginning at [dayStart].
Duration overlapOnDay(
  DateTime spanStart,
  DateTime spanEnd,
  DateTime dayStart,
) {
  // DateTime(y, m, d + 1) rolls months and years correctly, and lands on the
  // next local midnight even when that day is 23 or 25 hours long. Adding
  // Duration(days: 1) does not — see 5b.
  final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);
  final s = spanStart.isAfter(dayStart) ? spanStart : dayStart;
  final e = spanEnd.isBefore(dayEnd) ? spanEnd : dayEnd;
  return e.isAfter(s) ? e.difference(s) : Duration.zero;
}
```

### 5b. Daylight saving makes a day 23 or 25 hours long

Never advance a day with `.add(const Duration(days: 1))`. Always construct the
next local midnight with `DateTime(y, m, d + 1)`. The same rule applies to
building the seven `days` of the week — construct each one, do not add 24 hours
seven times.

### 5c. Idle time must be split by day too, not apportioned

`SessionExportRecord.idlePeriods` carries each idle period's own start and end.
When the Net basis is selected, subtract the idle that actually fell on that
day — do not pro-rate the session's total idle across days.

```dart
final grossOnDay = overlapOnDay(sessionStartLocal, sessionEndLocal, day);

var idleOnDay = Duration.zero;
for (final idle in record.idlePeriods) {
  if (idle.resolution != IdleResolution.markIdle) continue;
  idleOnDay += overlapOnDay(idle.startLocal, idle.endLocal, day);
}

final netOnDay = grossOnDay > idleOnDay ? grossOnDay - idleOnDay : Duration.zero;
```

Match how `ExportService` already filters idle: only
`IdleResolution.markIdle` counts (`export_service.dart:157–161`).

### Other rules

- **Convert to local before splitting.** Sessions and idle periods are stored
  UTC. Call `.toLocal()` once, at the top.
- **A running session** has a null `end_time`. `record.grossDuration` already
  measures it to now; use the same end instant so the grid and the tables agree.
- **Sessions outside the week** still appear in `records` when the range is a
  month. Clip them to the week — `overlapOnDay` does this for free.

### Invariant to assert in tests

For any closed session, the sum of `overlapOnDay` across every day it touches
equals its gross duration exactly. Test with a session that spans midnight and
one that spans a whole day.

---

## 6. Rounding — the part that will break if rushed

The portal recomputes the Total column and the daily summary from the numbers
typed into the cells. So the totals WorkPulse shows must be **the totals the
portal will arrive at**, or the user submits a sheet that does not balance.

### The failure this prevents

A task worked 1h 20m a day for five days is 1.3333 h per day and 6.6667 h for
the week.

- Naive: cells show `1.33`, row total shows `6.67`. The user types five
  `1.33`s. The portal computes `6.65`. The week does not add up, and the user
  has to hunt for the missing 0.02.
- Correct: cells show `1.33`, row total shows `6.65` — what the portal will
  say. The 0.017 h lost to rounding is reported separately, once, so it is
  visible rather than hidden.

### The rule

1. Round **each cell** to the configured increment, half away from zero.
2. **Row total** = sum of that row's rounded cells.
3. **Daily total** = sum of that column's rounded cells.
4. **Week total** = sum of every rounded cell.
5. Show `exactTotal` beside the week total whenever the two differ, as a quiet
   note — never as an error.

```dart
/// One cell, rounded to [increment] hours and cleaned of float dust.
///
/// `toStringAsFixed(2)` then reparse because increments like 0.05 and 0.01 are
/// not exact in binary, and 8.499999999999998 must not reach the screen.
double roundCell(Duration d, double increment) {
  if (d <= Duration.zero) return 0;
  final hours = d.inSeconds / 3600.0;
  final steps = (hours / increment).round();
  return double.parse((steps * increment).toStringAsFixed(2));
}

/// Any total. Re-rounded to kill accumulated dust from summing doubles.
double sumCells(Iterable<double> cells) =>
    double.parse(cells.fold(0.0, (a, b) => a + b).toStringAsFixed(2));
```

### Increment

A setting: `0.01`, `0.05`, `0.25`, `0.50`. **Default `0.25`.** The observed
sheet uses `1.00`, `1.50`, `2.00`, so quarter-hour granularity produces figures
that can be typed straight in. At `0.01` the user has to re-round every cell by
hand, which is the work this feature exists to remove.

### Display

```dart
String formatCell(double hours) => hours == 0 ? '' : hours.toStringAsFixed(2);
```

Note this differs from the existing `formatTimesheetHours`
(`timesheet_table.dart:17–20`), which returns `'0.00'` for zero. **Do not
change that function** — the breakdown tables below still use it. Add a new one.

---

## 7. Week framing

New setting `timesheetWeekStartDay`, an `int` using Dart's own convention
(`DateTime.monday == 1` … `DateTime.sunday == 7`). **Default
`DateTime.saturday`.**

```dart
/// Local midnight of the week containing [date], on [weekStartDay].
DateTime weekStartFor(DateTime date, int weekStartDay) {
  final day = DateTime(date.year, date.month, date.day);
  final delta = (day.weekday - weekStartDay + 7) % 7;
  return DateTime(day.year, day.month, day.day - delta);
}
```

Walk from the range's start to its end, one week at a time, emitting a
`TimesheetWeek` for each week that holds at least one session. Stop after
`maxTimesheetWeeks` and set `weeksTruncated`.

**Do not touch `DashboardTimeRange.thisWeek`** (`analytics_model.dart:26`),
which starts on Sunday and is what every other screen uses. The grid's week is
its own concept and must not change the dashboard's.

---

## 8. The grid widget

New — `lib/features/timesheet/widgets/timesheet_entry_grid.dart`.

### Layout

```
┌─ Week of Sat 22 Aug – Fri 28 Aug ───────────────── 42.50 h ─ [Copy] ─┐
│ Code       Class   Sat   Sun   Mon   Tue   Wed   Thu   Fri   Total   │
├──────────────────────────────────────────────────────────────────────┤
│ ITCMEL19   CapEx               1.00  1.00  1.00  1.00  1.00    5.00  │
│ ITCMEL19   OpEx                2.00  2.00  2.00  2.00  2.00   10.00  │
│ ITCMEL21   CapEx               1.50  1.50  1.50  1.50  1.50    7.50  │
│ ITCMEL21   OpEx                2.00  2.00  2.00  2.00  2.00   10.00  │
│ VEEVA026   CapEx               2.00  2.00  2.00  2.00  2.00   10.00  │
├──────────────────────────────────────────────────────────────────────┤
│ Total                          8.50  8.50  8.50  8.50  8.50   42.50  │
└──────────────────────────────────────────────────────────────────────┘
```

### Rules

- One `AppCard` per week. Background `colors.surface`, never `colors.card` —
  `card` is the inset badge and chip tint, and using it as a card background is
  what previously rendered this whole screen grey.
- Column widths: code `160`, classification `84`, each day `64`, total `76`.
  Wrap in `LayoutBuilder` + `SingleChildScrollView(scrollDirection:
  Axis.horizontal)` with `math.max(constraints.maxWidth, minWidth)`, the same
  pattern `timesheet_table.dart` already uses.
- Every figure uses `AppTypography.numeric` with tabular figures, right
  aligned, so the columns line up as digits.
- Today's column gets a faint `colors.accent` tint so the eye lands on it.
- Weekend columns that are empty stay visible — the portal has them and the
  columns must correspond one-to-one.
- The classification cell uses the existing `classification_style.dart` colours
  and always pairs colour with the text label, never colour alone.
- A row with `needsAttention` shows a small warning icon in the code cell with
  a tooltip saying which project and release fell back.
- Empty state: "No tracked time in this week" inside the card, so the week
  block still appears and the user knows it was checked.

### Copy as TSV

A `Copy` button in each week's header, using `Clipboard.setData` from
`flutter/services`:

- Header line: `Code`, `Classification`, then the seven day labels
  (`Sat 22 Aug`), then `Total`.
- One line per row, tab separated, **empty string for a zero cell** so it pastes
  into Excel as a blank.
- A final `Total` line.
- Confirm with the existing `AppSnackBar`.

---

## 9. Two-column layout for the breakdown tables

Below the grid sit the existing sections: by project, by task, categories
within each classification, and one per reportable attribute. They currently
stack full width.

New — `lib/features/timesheet/widgets/timesheet_section_columns.dart`.

- **Two columns at or above `Breakpoints.medium` (1000)**, one below. Use the
  existing token; do not invent a new breakpoint.
- Gap `Spacing.lg` between columns and between sections in a column.
- **In single-column mode, sections keep their original order.** The balancing
  below applies only in two-column mode. Getting this wrong scrambles the
  reading order on narrow windows.

### Balancing

Flutter has no masonry without a package, and adding one is not warranted.
Distribute with a deterministic greedy pass over an estimated height, which
keeps roughly the intended order while stopping one column running three times
the other:

```dart
/// Splits [sections] across two columns, each going to whichever column is
/// currently shorter.
///
/// Greedy rather than optimal on purpose: it keeps sections close to their
/// intended reading order, which matters more in a report than perfect
/// balance, and it is a pure function so the packing is testable without a
/// widget tree.
List<List<T>> packIntoTwoColumns<T>(
  List<T> sections,
  double Function(T) estimateHeight,
) {
  final columns = [<T>[], <T>[]];
  final heights = [0.0, 0.0];
  for (final section in sections) {
    final target = heights[0] <= heights[1] ? 0 : 1;
    columns[target].add(section);
    heights[target] += estimateHeight(section);
  }
  return columns;
}
```

Estimate a section's height as `headerHeight + rowCount * rowHeight` using the
constants the table already lays out with. It does not need to be exact — it
needs to be monotonic in row count and deterministic.

### Per-section rules

- Each section keeps its own `overflow-x` scroll container. At half width this
  matters more, not less — **the page body must never scroll sideways**.
- Do not shrink the font to fit. Let the table scroll inside its card.

---

## 10. Settings

Two new values, in the existing settings store (`AppSettings` /
`settingsRepository`). Follow whatever pattern `idleThreshold` uses.

| Setting | Type | Default | UI |
|---|---|---|---|
| `timesheetWeekStartDay` | `int` (1–7, Dart convention) | `DateTime.saturday` | Select of the seven days |
| `timesheetRoundingIncrement` | `double` | `0.25` | Select: 0.01, 0.05, 0.25, 0.50 |

Group them under a **"Time Sheet"** heading in Settings, with helper text
explaining that they exist to match the organisation's timesheet form.

---

## 11. Out of scope

State these as non-goals. Do not build them.

- **Portal column mapping.** Storing the user's `Business Unit PC`,
  `Activity ID`, `Resource Type`, `Resource Category` or `Resource Sub-Category`
  so the grid can print them verbatim.

  **The user was asked and declined it outright — this is not a deferred
  decision.** Those columns are constant enough to be muscle memory, and a
  configuration screen to avoid retyping them would cost more than it saves.
  Do not build it, and do not propose it back.

  (For the record, in case it is ever revisited: `Resource Sub-Category` was
  observed as `663` on the ITCMEL rows and `662` on the VEEVA026 row, so it
  appears to track the project. The user has not confirmed what drives it. It
  does not matter while this remains out of scope.)
- Editing hours from the grid. The grid is read-only; time is edited in the
  Time Log.
- Submitting to, or scraping from, any external timesheet system. V1 is
  offline, zero network (AGENTS.md rule 8).
- Suggested text for the portal's Comments column.
- Changing `DashboardTimeRange.thisWeek` or any other screen's week.
- Changing `formatTimesheetHours` (`timesheet_table.dart:17`).

---

## 12. Relationship to the code-resolution design

`docs/TIMESHEET_CODE_DESIGN.md` makes a timesheet code resolve per
*(project, release)* rather than per project. **Build that first.** The grid's
row key is the code it produces.

If the two are built out of order, the grid still works — it consumes
`TimesheetCodeResolution`, which is the seam. Without the resolution work that
value is just the project's single code, so a project with three releases
collapses to one row per classification instead of three. Correct, but less
useful. Do not duplicate resolution logic inside the grid service.

---

## 13. Tests

`test/unit/services/timesheet_grid_service_test.dart` (new):

**Day attribution**
- A session from 23:30 to 00:30 puts 30 minutes on each of two days.
- The per-day parts of any closed session sum exactly to its gross duration.
- An idle period is subtracted from the day it actually fell on, not spread.
- Only `IdleResolution.markIdle` idle is subtracted.
- A session entirely outside the week contributes nothing.
- Advancing days uses local-midnight construction — assert a session crossing
  midnight lands on two distinct `days` entries.

**Rounding** — the highest-value tests in this feature
- Five cells of 1h 20m at increment 0.01 give a row total of `6.65`, **not**
  `6.67`.
- Daily totals equal the sum of that column's rounded cells.
- The week total equals the sum of every rounded cell.
- `exactTotal` differs from `total` in that case, and the difference is
  reported rather than swallowed.
- At increment 0.25, 1h 20m rounds to `1.25`; 1h 24m rounds to `1.50`.
- A zero-duration cell yields `0`, and `formatCell` renders it as `''`.

**Week framing**
- With `weekStartDay = DateTime.saturday`, a Wednesday date yields a week
  starting the previous Saturday and `days` running Sat → Fri.
- With `DateTime.monday`, the same date yields Mon → Sun.
- A one-month range yields four or five week blocks in ascending order.
- A range longer than `maxTimesheetWeeks` truncates and sets `weeksTruncated`.
- A week with no sessions is omitted, not emitted empty.

**Row identity and order**
- One project with CapEx and OpEx sessions yields **two rows sharing a code**.
- Rows sort by code then classification, and the order does not change when the
  Net/Gross toggle flips.
- Sessions with no resolvable code collect into one row that sorts last.

`test/unit/timesheet_section_columns_test.dart` (new):
- `packIntoTwoColumns` puts each section in the shorter column.
- Given equal heights it fills left first, deterministically.
- An empty list yields two empty columns rather than throwing.

`test/widget/timesheet_view_test.dart` (extend):
- The grid renders one card per week, with eight header cells plus the code and
  class columns.
- A zero cell renders as blank, not `0.00`.
- Below `Breakpoints.medium` the sections render in one column in their
  original order; at or above it, two columns.
- A `needsAttention` row shows its warning icon.

Use `tester.view.physicalSize` to drive the breakpoint tests, as
`attributes_ui_test.dart` already does.

---

## 14. Build order

Each step leaves the app working.

1. **Settings** — `timesheetWeekStartDay` and `timesheetRoundingIncrement`,
   with their Settings UI. Nothing consumes them yet.
2. **`overlapOnDay`, `weekStartFor`, `roundCell`, `sumCells`** as pure
   functions with their unit tests. No models, no UI. These are where the bugs
   would be; get them green first.
3. **`TimesheetWeek` / `TimesheetGridRow` models**, and the grid build inside
   the timesheet service. Extend the service tests. Still no UI.
4. **`TimesheetEntryGrid` widget**, rendered at the top of the Time Sheet.
   Feature complete at this point.
5. **Copy as TSV.**
6. **Two-column section layout** — independent of 1–5 and can be done by
   someone else in parallel.

Steps 2 and 3 are pure and fully testable without a widget tree. If time runs
short, stopping after 4 delivers the whole point of the feature.
