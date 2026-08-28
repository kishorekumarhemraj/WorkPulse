# PDF Report — Redesign Design & Delegation Brief

The exported PDF should read as an **infographic that summarises what
happened**, be more colourful while staying professional, and carry every
piece of session metadata the app holds. Two pieces of copy come out of the
header and footer.

Companion prompt: `docs/PDF_REPORT_PROMPT.md`.

Current implementation: `lib/domain/services/pdf_report_service.dart` (1094
lines), generated via `ExportService.generatePdf` and run from three places
through `PdfReportExport.run`.

---

## 1. What is actually wrong today

The existing report is not ugly. It is **the wrong shape**: a stack of
sections that grows linearly with the range.

```
banner → 4 KPI cards → breakdown box → task table → notes callout
       → one bordered card per session, forever
```

`_buildSessionTimeline` (`pdf_report_service.dart:842`) emits a ~70pt bordered
card for **every** session. A one-week range with 40 sessions is roughly ten
pages of near-identical cards. The document is a *transcript*, not a
*summary* — which is why the request reads "give a summary of what has
happened".

### Metadata the app holds and the PDF never shows

| Missing | Where it lives | Why it matters |
|---|---|---|
| **Financial classification (CapEx / OpEx / Unclassified)** | `SessionExportRecord.classification` | Zero occurrences of the word in the whole file. This is a first-class field on `WorkItem`, the entire reason the Time Sheet exists, and the report is silent on it. **The single biggest gap.** |
| **Timesheet code** | `TimesheetCodeResolver` | The number the user books hours against. Absent. |
| **Tags, aggregated** | `record.tags` | Rendered per session, never summed. |
| **People, aggregated** | `record.people` | Same — no "who I worked with" anywhere. |
| **Custom attributes, aggregated** | `record.attributeValues` | Rendered as grey 7pt text per session. The Time Sheet aggregates these into `attributeSections`; the PDF does not. |
| **Per-day shape** | derivable from records | A month-long report has no day axis at all. `isSingleDay` is computed and then barely used. |
| **Focus rhythm & insights** | `WorkPatternService` | Produces exactly the sustain/reclaim/delegate/plan findings with attached evidence that an infographic wants. Never called. |

### Defects to fix while in there

1. **Project colours are invented.** `_palette[colorIndex++]` assigns colours
   by first-seen order (`pdf_report_service.dart:88–92`) and ignores
   `project.colorHex`. A project that is blue in the app is pink in the PDF.
2. **`'Worked on today'`** is hardcoded on the ACTIVE TASKS tile
   (`:466`) regardless of range. A March report says "today".
3. **`efficiency` is 100.0 when there are no records** (`:139`). An empty
   report claims "100% focus efficiency".
4. **`Page X of Y` renders twice** on every page after the first — once in
   `_buildPageHeader` (`:246`) and again in `_buildPageFooter` (`:288`).
5. **The chip row is a `pw.Row`, not a `pw.Wrap`** (`:927`). Five tags and the
   chips run off the page edge silently.
6. **`JetBrainsMono` is bundled and unused.** Every duration and percentage is
   set in proportional Inter, so columns of numbers do not align. `Inter-Medium`
   and `Inter-SemiBold` are bundled and unused too.
7. **No document metadata.** `pw.Document()` is constructed bare, so the file
   shows as untitled in Preview, in email previews and in search results.
8. **The notes callout duplicates the timeline.** The same note text appears in
   `_buildNotesCallout` and again in the session card below it.

---

## 2. The central decision: one document, three acts

"Infographic" (visual, scannable, summarised) and "all the metadata included"
(complete, exhaustive) pull in opposite directions. Do not compromise between
them — **separate them**:

| | Length | Answers |
|---|---|---|
| **Act I — The Story** | Exactly 1 page, always | *What happened?* |
| **Act II — The Breakdown** | 1–2 pages | *How does it divide?* |
| **Act III — The Record** | Grows with the range | *Prove it.* |

Act I is **fixed size regardless of range** — a day and a quarter both produce
one story page. That is what makes it a summary. Act III carries every field
for every session, which is what makes it complete. Someone who wants the
gist reads page 1 and stops; someone reconciling a timesheet reads the
appendix.

---

## 3. Visual language

### The rule that keeps it professional

> **Colour must encode something.** No section is tinted to look lively.

Large flat fills are limited to the masthead and one hero band. Everything
else is white or near-white with coloured *marks* — dots, bars, arcs, 3pt
accent rules. That is the difference between an infographic and clip art, and
it is also what keeps the thing printable in greyscale.

### Four colour roles

1. **Ink** — the slate ramp already in the file (`_slate900` … `_slate50`).
   All structure and all text. Unchanged.
2. **Brand** — one indigo, for the masthead band and section rules only.
3. **Semantic** — fixed meanings, never decorative:
   - CapEx → indigo · OpEx → amber · Unclassified → slate 400
   - Net/focus → emerald · Idle → amber · Attention needed → rose
   Mirror the intent of `lib/core/theme/classification_style.dart` so the PDF
   and the app agree about what CapEx looks like. That extension is the app's
   single source for this; the PDF cannot import Flutter colours, so **restate
   the mapping in one place** (`pdf_theme.dart`) with a comment naming the
   extension as its counterpart.
4. **Entity** — projects and tags use **the user's own `colorHex`**, parsed to
   `PdfColor`. Fall back to `ColorUtils.paletteHex` (the app's palette, so
   fallbacks still look like the app) indexed by a stable hash of the entity
   id — not by first-seen order, so the same project is the same colour across
   two exports of different ranges.

### Print-hardening

`ColorUtils.paletteHex` is tuned for backlit screens. `#FFD60A` yellow and
`#64D2FF` teal are unreadable as text on white paper. Rule:

- An entity colour may fill a **shape** (dot, bar segment, arc) at full
  strength.
- An entity colour may **never** be a text colour. Text on a tinted chip is
  ink; the colour is carried by a 2pt leading bar or a dot.
- Add `PdfColor printSafe(PdfColor c)` in `pdf_theme.dart` that darkens toward
  black until relative luminance ≤ 0.62, for the few places a colour does
  carry a thin stroke.

### Typography

- Load `Inter-Regular`, `Inter-Medium`, `Inter-SemiBold`, `Inter-Bold` into
  `pw.ThemeData` (all four are already in `assets/fonts/` and three are
  unused).
- **Set every duration, percentage, count and time-of-day in
  `JetBrainsMono`.** It is bundled and unused. A theme has no "mono" slot, so
  hold the loaded `pw.Font` instances in a small `PdfTypography` value object
  and pass the mono face explicitly to numeric `TextStyle`s. This one change
  does more for "professional" than any colour decision in this document —
  columns of durations finally align.
- Keep the existing `try/catch` font fallback to `pw.ThemeData.base()`, and
  make the mono load **independently** optional: a missing mono font must
  degrade to the base font, not fail the export.
- Type scale, fixed: 22 / 15 / 11 / 9 / 8 / 7. Six sizes, no more. The current
  file uses 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 15, 17, 18 — ten sizes, which is why
  it reads as unsettled.

### Document metadata

Set it on `pw.Document(...)`: `title` = `'$workspaceName — Work Report,
$dateSubtitle'`, `author` = the user's name, `creator`/`producer` =
`'WorkPulse'`, `subject` = the range. Free, and it is what shows in Preview's
title bar and in an email attachment preview.

---

## 4. Act I — The Story (one page)

```
┌──────────────────────────────────────────────────────────────────┐
│  ███ indigo band ███                                             │
│  WORK REPORT                                    ┌──────────────┐ │
│  Mon 3 – Sun 9 March 2026                       │  42h 10m     │ │
│  Acme Workspace · Kishore Kumar Hemraj          │  TOTAL NET   │ │
└──────────────────────────────────────────────────────────────────┘

┌ 42h 10m ┐┌ 38h 05m ┐┌ 4h 05m  ┐┌   18    ┐┌    6    ┐
│ TRACKED ││  FOCUS  ││  IDLE   ││  TASKS  ││PROJECTS │      5 stat tiles
│ 6 days  ││   90%   ││ 10% ded ││ 41 sess ││ 4 categ │

┌ WHERE THE TIME WENT ──────────────┐┌ HOW IT CLASSIFIES ────────┐
│ ████████████░░░░░░░░░░░░░░  stacked││        ◜◝                 │
│ ● Payments      18h 20m    43%    ││      ◜ 61% ◝   donut      │
│ ● Platform      11h 05m    26%    ││      ◟     ◞             │
│ ● Onboarding     7h 40m    18%    ││  ● CapEx 25h 40m  61%     │
│ ● No project     5h 05m    12%    ││  ● OpEx  14h 20m  34%     │
└───────────────────────────────────┘│  ● Unclass 2h 05m  5%     │
                                     └───────────────────────────┘
┌ DAILY RHYTHM ────────────────────────────────────────────────────┐
│  ▄▄  ███  ████  ██  █████  ▃  ·      per-day bars, CapEx/OpEx    │
│  Sun Mon  Tue   Wed Thu    Fri Sat   stacked, idle hatched       │
└──────────────────────────────────────────────────────────────────┘

┌ WHAT THIS PERIOD LOOKED LIKE ────────────────────────────────────┐
│ 42h 10m across 18 tasks in 6 projects. 61% capitalizable.        │
│ Busiest day Thursday (9h 15m). Longest unbroken block 2h 40m.    │
│ Peak focus 09:00–11:00.                                          │
└──────────────────────────────────────────────────────────────────┘

┌ CONTINUE ─────────┐┌ RECLAIM ──────────┐┌ PLAN ─────────────────┐
│ Deep work held at ││ 11 switches/day   ││ 2h 05m unclassified   │
│ 46% of tracked    ││ on Payments       ││ across 4 sessions     │
│ time              ││ ─ 3h 20m lost     ││ ─ blocks the timesheet│
└───────────────────┘└───────────────────┘└───────────────────────┘
```

### Rules

- **Exactly one page, always.** If the insight cards would push to a second
  page, drop to two cards, then one, then none. Never let Act I spill.
- **Stat tiles: five, not four.** Add PROJECTS; move SESSIONS into the TASKS
  tile's subtitle. Fix the two defects: the subtitle must say `'6 days'` /
  `'41 sessions'` computed from the range, never `'Worked on today'`; and
  efficiency must render `'—'`, not `100%`, when nothing is tracked.
- **Stacked bar for projects**, using each project's own colour. Cap at the
  top 6 projects and roll the rest into a slate `Other (n)` segment — a
  20-segment bar is noise.
- **Donut for classification.** `pw.Chart` with `PieGrid` + `PieDataSet`.
  Three slices, fixed semantic colours, hole ~55%, with the CapEx share in the
  centre. **Give it a bounded `SizedBox` height** — `pw.Chart` inside a
  `MultiPage` without a height constraint will not lay out.
- **Daily rhythm** is the section that currently does not exist and is most of
  what "tell me what happened" means:
  - Multi-day range → one bar per calendar day across the whole range,
    including **zero days** (a gap is information). Split each bar
    CapEx/OpEx/unclassified. Label weekday initials; label the busiest bar
    with its total.
  - Single-day range → switch the axis to **hour of day**, 06:00–22:00, one
    bar per hour. Same widget, different bucketing. The existing `isSingleDay`
    flag finally earns its keep.
  - Cap at 62 bars. Beyond that (a quarter), bucket by week and say so in the
    axis label.
- **Headline sentence** is generated prose, assembled from the same numbers
  shown above it — never a separate calculation. If a figure is unavailable
  (no comparison window), the clause is omitted rather than hedged.
- **Insight cards**: at most three, taken from `WorkPatternReport.insights`,
  one per lane, highest severity first. Lane colours: `sustain` emerald,
  `reclaim` amber, `plan` indigo, `delegate` sky. Each card shows the lane
  label, the finding, and **the evidence figure it was derived from** —
  `InsightEvidence` already carries it, and AGENTS.md is explicit that a
  finding with no evidence is a bug. If no `WorkPatternReport` is supplied the
  row is omitted entirely; the page must not depend on it.

---

## 5. Act II — The Breakdown (1–2 pages)

Every breakdown is the same widget: a **bar-in-cell table**, where each row
carries a thin horizontal bar sized to its share. That is what makes a table
read as a chart without becoming one.

```
Payments platform      ████████████████░░░░░   18h 20m   43%   12 sess
Internal tooling       ████████░░░░░░░░░░░░░   11h 05m   26%    8 sess
```

Blocks, in order:

1. **By project** — entity colour bars.
2. **By category** — the session's own category, never the task's (AGENTS.md
   rule 7). Uncategorised sorts **last** regardless of size, matching
   `TimesheetService._sorted`.
3. **By classification** — three rows, semantic colours, plus the CapEx ratio
   taken over *classified* time only. Unclassified is reported in its own row,
   never folded into OpEx. This mirrors `ClassificationSplit` exactly; restate
   nothing.
4. **By timesheet code** — code, contributing projects, hours. Rows whose
   resolution `needsAttention` get a rose dot and a footnote. Omit the whole
   block when no resolver was supplied.
5. **By each reportable attribute** — one block per
   `AttributeDefinition` where `reportable && enabled && !isArchived`, same
   filter and same ordering as `TimesheetService`. A multi-select value stays
   whole (`"Backend; Platform"` is one row) so the block still sums to the
   total — the reason is spelled out in AGENTS.md and must not be re-litigated
   here.
6. **Top tasks** — top 12 by duration, with project, category set,
   classification, session count, total and share bar. `+ n more tasks` line
   when truncated.
7. **People & tags strip** — two compact chip rows: who time was logged with
   (name + total), and which tags carried the most time. Small, but it is the
   only place either is ever aggregated.

Every block is **omitted, not rendered empty**, when it has no rows. A report
from a workspace with no attributes configured should not show an empty
attributes heading.

**Invariant, and it must be asserted in tests:** every breakdown block sums to
the same range total. The project table, the category table, the
classification table and each attribute table are four views of one set of
hours. This is the same rule the Time Sheet already lives by.

---

## 6. Act III — The Record (appendix)

### 6a. Notes, grouped by task

Reuse the shape that just landed on the Time Notes screen (`TimeNotesService`,
commit `79f67ae`): group notes by day, then by task, and apply the
**promotion rule** — metadata identical across every session in a task group
is printed once in the task header; metadata that varies is printed per row.

```
Thursday 6 March                                    5h 10m · 9 notes

  Payments migration                       3 sessions · 2h 40m
  ● Platform   ▲ CapEx   PRJ-4471   Alice
  ─────────────────────────────────────────────────────────────
  09:15–10:30  1h 15m   Development
      Traced the double-charge to the retry wrapper. Wrote a
      failing test first.
  13:00–14:10  1h 10m   Meeting · Bob
      Walked Bob through the fix. He'll own the rollout.
```

Do not re-implement the grouping. If `TimeNotesService` can be called with
`SessionExportRecord`s and a resolver — it can — call it and render its
`TimeNotesReport`. That is a genuine reuse and it keeps the PDF and the Time
Notes screen from telling different stories about the same day.

Notes are **never truncated here**. This is the record.

### 6b. Full session table

Replace the per-session cards entirely with a dense `TableHelper` table:

`Date · Start–End · Task · Project · Category · Class · Code · Tags · People · Attributes · Idle · Net`

- Zebra striping at 4% slate, a 2pt project-coloured leading rule per row.
- Notes are **not** in this table (they are in 6a); a `•` marker in a narrow
  column indicates the row has one.
- Attributes collapse to `Key: Value · Key: Value` in one ellipsised cell.
- Day subtotal rows in slate 100, and a bold range total at the end.

This is the change that takes a 40-session week from ten pages to two, and it
is the reason the appendix can afford to carry every field.

---

## 7. The two copy removals (the explicit ask)

| File:line | Delete | Replace with |
|---|---|---|
| `pdf_report_service.dart:378` | `'Team Member: $userName \| Prepared for Manager / Standup Review \| $sessionCount sessions recorded'` | A neutral fact line: `'$sessionCount sessions · $taskCount tasks · $projectCount projects'` |
| `pdf_report_service.dart:281` | `'Generated locally for $userName with WorkPulse - Privacy-First & Offline-First'` | `'$workspaceName · $dateSubtitle'` on the left, `Page X of Y` on the right |
| `pdf_report_service.dart:796` | `'STANDUP / PROGRESS HIGHLIGHTS & NOTES'` | `'Notes & Highlights'` — the heading carries the same standup framing the request is removing |

Also delete the duplicated `Page X of Y` from `_buildPageHeader` (`:246`); the
running header becomes `workspace · range` alone.

**One open question, needs a word from the user.** `userName` also appears in
the masthead as a `'Report for $userName'` chip (`:340`) and in the running
header (`:243`). The recommendation is to **keep the name once**, as a byline
in the masthead, and remove it from the running header — a report that gets
emailed with no author on it is odd, and the request targets the *audience
framing* ("prepared for managers/standup", "generated locally with WorkPulse"),
not the authorship. If the user wants the name gone entirely it is three more
deletions plus dropping the `userName` parameter; do not do that unprompted.
Keep `UserInfoService.getCurrentUserFullName()` in `ExportService.generatePdf`
either way — it feeds the document `author` metadata.

---

## 8. Architecture — split arithmetic from layout

The file is 1094 lines of aggregation and `pw.Widget` construction
interleaved, with private `_TaskSummary` / `_SessionNoteSummary` types. Its
tests (`test/unit/services/pdf_report_service_test.dart`) assert only that the
bytes start with `%PDF-`. **Nothing about the report's correctness is
currently testable.**

Follow the pattern the codebase already uses three times over
(`TimesheetService`, `WorkPatternService`, `TimeNotesService`): pure service,
data in, model out.

```
lib/domain/models/work_report_model.dart      NEW   the report as data
lib/domain/services/report_builder_service.dart NEW pure: records → WorkReport
lib/domain/services/pdf/pdf_theme.dart        NEW   palette, fonts, printSafe
lib/domain/services/pdf/pdf_primitives.dart   NEW   chip, tile, bar, donut, legend
lib/domain/services/pdf_report_service.dart   THIN  WorkReport → bytes
```

### The model

```dart
/// Everything the PDF renders, computed once and independent of how it is
/// drawn.
///
/// Pure data by design, like TimesheetData: the arithmetic that decides what
/// the report says is unit-testable without generating a single byte, and the
/// layout code cannot quietly recompute a figure a second way.
class WorkReport {
  final ReportIdentity identity;      // workspace, author, range, single-day
  final ReportHeadline headline;      // the five stat tiles + the prose line
  final ClassificationSplit classification;
  final List<ReportSlice> projects;   // label, duration, share, colorHex, count
  final List<ReportSlice> categories;
  final List<ReportSlice> tags;
  final List<ReportSlice> people;
  final List<ReportCodeRow> codes;
  final List<ReportBreakdown> attributes;
  final List<ReportBucket> rhythm;    // per-day, or per-hour when single-day
  final RhythmAxis rhythmAxis;        // day | hour | week
  final List<ReportTaskLine> topTasks;
  final TimeNotesReport notes;        // reused wholesale, see §6a
  final List<ReportSessionLine> sessions;
  final List<ReportInsight> insights; // empty when no WorkPatternReport given

  bool get isEmpty => headline.sessionCount == 0;
}
```

### The builder

```dart
class ReportBuilderService {
  const ReportBuilderService();

  WorkReport build({
    required String workspaceName,
    required String? authorName,
    required DateRange range,
    required List<SessionExportRecord> records,
    List<AttributeDefinition> definitions = const [],
    TimesheetCodeResolver codes = const TimesheetCodeResolver(),
    WorkPatternReport? patterns,
  });
}
```

Pure — no repositories, no clock, no `DateTime.now()`. Every figure derives
from the records it was handed. Same contract as `TimesheetService`, and the
same reason: it is the only way the numbers become testable.

### Data plumbing

`generatePdf` needs two things it does not currently receive. Both are I/O and
both already have an owner, so **do not** grow a second assembly path inside
`ExportService`:

- **`TimesheetCodeResolver`** — `timesheetCodeResolverProvider` already builds
  it (extracted in the Session Context work). `PdfReportExport.run` reads it
  and passes it down.
- **`WorkPatternReport`** — `AnalyticsService` owns that I/O. Same route.

So `ExportService.generatePdf` gains two **optional** parameters, both
defaulting to absent, and `PdfReportExport.run` supplies them. Optional
matters: `pdf_report_service_test.dart` calls the service directly, and the
sections must **degrade gracefully** — no resolver means no code block, no
pattern report means no insight cards, and in both cases a valid report.

---

## 9. Edge cases — specify these or they will ship broken

| Case | Required behaviour |
|---|---|
| **Zero records** | One page: masthead, "No time tracked in this period", the range. Not four stat tiles reading `00:00` and `100% efficiency`. |
| **One session** | Donut with one slice; rhythm with one bar. No division by zero anywhere — every share calculation guards a zero denominator, as `ClassificationSplit._share` already does. |
| **Single-day range** | Rhythm switches to hour-of-day. Act I otherwise identical. |
| **Range > 62 days** | Rhythm buckets by week; the axis label says so. |
| **Session crossing midnight** | The rhythm must attribute it to both days by overlap, not bucket it by start time. `overlapOnDay` in `timesheet_grid_math.dart` already does exactly this — **use it, do not write a second one.** |
| **Daylight saving** | Never advance a day with `.add(Duration(days: 1))`. Use `DateTime(y, m, d + 1)`. Same rule as the timesheet grid. |
| **Running session** | `endTime` is null. Render `'09:15 – in progress'` and use `netActiveDuration` as-is. Never print a duration that changes between the PDF and the screen. |
| **200+ sessions** | The appendix table must page cleanly. `MultiPage` + `TableHelper` does; a `Column` of `Container` cards does not — this is the current failure mode. |
| **Long names** | Ellipsise in one line. Never wrap inside a table cell. |
| **No projects / categories / attributes configured** | Omit the block. No empty headings. |
| **Very long note** | Full text in Act III. Two lines maximum in any Act I or Act II highlight. |
| **Font load failure** | Falls back to `ThemeData.base()`. The mono font falls back independently. |

---

## 10. Testing

The current tests assert `%PDF-` and a byte count. That is a smoke test and it
should stay one — but it must stop being the *only* test.

### `test/unit/services/report_builder_service_test.dart` — NEW, the real tests

- Project, category, classification and attribute breakdowns each sum to the
  same range total (§5's invariant).
- Shares sum to 100 ± one rounding step.
- Classification comes only from `SessionExportRecord.classification`; a
  session whose task is CapEx and which overrides to OpEx lands in OpEx.
  **Never re-derive the fallback** — AGENTS.md says this is resolved in exactly
  one place.
- Rhythm buckets cover every day in range **including zero days**, and a
  session crossing midnight contributes to both days by overlap.
- Single-day input selects the hour axis; 90-day input selects the week axis.
- Empty records produce `WorkReport.isEmpty` with no NaN, no `Infinity`, and no
  `100%` efficiency.
- Uncategorised sorts last regardless of size.
- Top-tasks truncation reports the correct remainder count.

### `test/unit/services/pdf_report_service_test.dart` — extend

Keep the existing four smoke tests. Add:

- An empty range produces a valid single-page PDF.
- 200 sessions generate without throwing, within a generous time budget.
- **The removed copy is actually gone.** Generate with
  `pw.Document(compress: false)` behind a `@visibleForTesting` flag and assert
  the raw bytes contain neither `'Prepared for Manager'` nor `'Generated
  locally for'` nor `'STANDUP'`. Without `compress: false` the text is
  deflated and string-searching the bytes silently passes on anything — a test
  that cannot fail is worse than no test.

---

## 11. Build order

1. **Copy removals + the six defects in §1.** Small, self-contained, immediately
   valuable, and it lands the explicit ask before any refactor risk. Commit
   alone.
2. **`pdf_theme.dart` + `pdf_primitives.dart`.** Fonts (including mono),
   palette, `printSafe`, document metadata, and the shared chip / stat tile /
   bar / donut / legend widgets. No page changes yet.
3. **`WorkReport` + `ReportBuilderService` + its tests.** Pure, green before
   any layout consumes it. The existing PDF still renders from the old path at
   this point.
4. **Act I.** Rewrite the first page against `WorkReport`.
5. **Act II.** The bar-in-cell breakdown blocks.
6. **Act III.** Notes via `TimeNotesService`, then the dense session table —
   deleting `_buildSessionTimeline`, `_buildNotesCallout`, `_TaskSummary` and
   `_SessionNoteSummary`.
7. **Plumbing.** Optional resolver and pattern report through
   `ExportService.generatePdf` and `PdfReportExport.run`, with graceful
   degradation verified by the direct-call tests.

Bump `pubspec.yaml` to `4.2.0`.

---

## 12. Out of scope — say no to these

- **A report-style or section picker in the export dialog.** The request asked
  for a better report, not a configurable one. `ExportFormat` stays as it is.
- **Charts beyond the donut and the bars.** No line charts, no radar, no
  sparkline grid. Each of the three visual forms here earns its place; a
  fourth would be decoration.
- **Logos, cover pages, or watermarks.**
- **Localisation of the generated prose.** The app is English-only today.
- **Changing what `getExportRecords` returns.** The PDF is a consumer; if a
  field is missing the fix is upstream and is a separate change.
- **Re-deriving any financial classification.**
  `SessionExportRecord.classification` is the only source.
- **A second timesheet-code assembly path inside `ExportService`.** Pass the
  resolver in (§8).
- **Making the report pretty in greyscale by adding patterns/hatching**, beyond
  the single hatched idle segment already specified. Colour plus label is
  enough; the labels carry the meaning on their own.

---

## 13. Invariants to assert

- Act I is exactly one page for every input, including a 90-day range with 500
  sessions.
- Every breakdown block sums to the range total.
- No figure on the PDF is computed twice by two different code paths — the
  headline prose reads the same fields the tiles do.
- The report's colour for a project equals the colour the app shows for that
  project.
- Generating the same range twice produces the same colours, the same ordering
  and the same page count.
