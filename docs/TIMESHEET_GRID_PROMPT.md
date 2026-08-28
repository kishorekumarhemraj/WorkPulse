# Delegation prompt — Timesheet Entry Grid

Copy everything below the line into the implementing agent.

---

You are working on **WorkPulse**, an offline-first Flutter/Riverpod/SQLite
desktop time tracker at the repo root. Read `AGENTS.md` first and follow its 10
architectural rules — rules 1, 2, 8 and 10 constrain this task directly.

## Your task

Implement the design in **`docs/TIMESHEET_GRID_DESIGN.md`**. Read it in full
before writing any code. It contains the models, the day-splitting and rounding
algorithms with working Dart, the widget spec, the settings, the test plan and a
build order. Follow the build order — steps 2 and 3 are pure functions and pure
services, and getting those green before any UI exists is the point of the
ordering.

## Why this exists

The user reads WorkPulse's numbers and types them by hand into a corporate
timesheet form. That form is a grid: seven day columns across, coded rows down,
decimal hours in the cells. WorkPulse currently reports totals for a whole date
range with no per-day breakdown, so the user has to derive every cell mentally.
You are adding a grid at the top of the Time Sheet screen that has the same
shape as the form they are filling in, and moving the existing breakdown tables
into two columns so they stop requiring a scroll.

## Decisions already made — do not relitigate these

1. **A row is keyed by (timesheet code, financial classification)**, never by
   code alone. The real form splits one project ID across two rows by resource
   category; that second dimension is what WorkPulse tracks as CapEx/OpEx.
2. **Week start day is a setting, defaulting to Sunday.** Aligns with
   WorkPulse's existing week start.
3. **One grid block per week in the selected range**, capped at six.
4. **Every total is the sum of the already-rounded cells**, never the rounded
   sum of exact values.
5. **A zero cell renders blank**, not `0.00`.
6. **Rows sort by code, then classification** — not by size.

## Five things that will bite you if you skip them

- **Sessions cross midnight.** Do not bucket a session by its start time.
  Intersect its span with each local calendar day. §5a has the function.
- **Never advance a day with `.add(Duration(days: 1))`.** A day is 23 or 25
  hours twice a year. Construct the next local midnight with
  `DateTime(y, m, d + 1)`. This applies to building the week's seven days too.
- **Split idle time by day, do not pro-rate it.** `record.idlePeriods` carries
  each period's own start and end. Only `IdleResolution.markIdle` counts, the
  same filter `export_service.dart:157–161` already applies.
- **Round each cell, then sum the rounded cells to get every total.** The portal
  recomputes its own totals from what gets typed, so a row total of `6.67` above
  five cells of `1.33` produces a sheet that does not balance. §6 works the
  example through; the rounding tests are the highest-value tests here.
- **No portal field names anywhere.** `Resource Category`, `Business Unit PC`,
  `Activity ID`, `Time Reporting Code` and `Resource Sub-Category` are the
  user's employer's vocabulary. AGENTS.md rules 1 and 2. The grid reproduces the
  form's *shape*, not its columns. §11 makes this an explicit non-goal.

## Two more traps

- `formatTimesheetHours` (`timesheet_table.dart:17`) returns `'0.00'` for zero
  and is used by the breakdown tables. **Do not change it.** Add a separate
  `formatCell` for the grid.
- Use `colors.surface` for card backgrounds, via `AppCard`. `colors.card` is the
  inset badge and chip tint — using it as a card background is what previously
  rendered this entire screen grey.

## Ordering against the other brief

`docs/TIMESHEET_CODE_DESIGN.md` makes timesheet codes resolve per
(project, release). **Build that first if it has not landed.** If you build this
one first it still works — consume `TimesheetCodeResolution` as the seam and do
not duplicate resolution logic inside the grid service.

## Verify before you push

There is a Flutter SDK available to you — use it. CI runs all three and fails on
any of them:

```
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

`analysis_options.yaml` is stricter than default: `strict-casts`,
`strict-inference`, `strict-raw-types`, plus `prefer_single_quotes`,
`prefer_final_locals`, `prefer_const_constructors`,
`always_declare_return_types`.

## Scope discipline

Build sections 4–10 and 14. Section 11 lists explicit non-goals — portal column
mapping in particular, which is tempting and is a separate design. If you find
something else wrong along the way, note it in your summary rather than fixing
it here.

Work on a branch off `develop`. Do not open a pull request unless asked.
