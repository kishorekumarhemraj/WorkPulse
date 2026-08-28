# Delegation prompt — PDF Report redesign

Copy everything below the line into the implementing agent.

---

You are working on **WorkPulse**, an offline-first Flutter/Riverpod/SQLite
desktop time tracker at the repo root. Read `AGENTS.md` first and follow its 10
architectural rules. Rules 1, 2, 6, 7 and 8 constrain this task, and the
**Financial Classification** section of `AGENTS.md` is required reading — the
report is about to surface CapEx/OpEx for the first time and there is exactly
one legal way to read it.

## Your task

Implement the design in **`docs/PDF_REPORT_DESIGN.md`**. Read it in full before
writing any code. It carries the page-by-page layout, the colour and type
rules, the new model and service, the edge cases and the test plan. **Follow
the build order in §11** — step 1 lands the user's explicit ask on its own, and
step 3 must be green before any layout depends on it.

The file you are rewriting is
`lib/domain/services/pdf_report_service.dart` (1094 lines). It is reached
through `ExportService.generatePdf` and run from three call sites via
`PdfReportExport.run`.

## Why this exists

The current export is not ugly, it is the **wrong shape**: it emits a bordered
card per session, so a one-week range is roughly ten pages of near-identical
cards. It is a transcript, not a summary. Separately it is silent on the
metadata that matters most — the word "classification" does not appear once in
the file, and CapEx/OpEx is the reason half this app exists. You are turning it
into an infographic that summarises the period on one fixed page, breaks it
down on the next, and carries the complete record in an appendix.

## Decisions already made — do not relitigate these

1. **Three acts: Story (exactly 1 page, always) → Breakdown (1–2) → Record
   (grows).** "Summarised" and "all the metadata" are not compromised between,
   they are separated. If Act I would spill to a second page, drop insight
   cards until it does not.
2. **Colour must encode something.** Large fills only in the masthead and hero
   band; everything else is white with coloured marks. Entity colours come from
   the user's own `colorHex`, never from a rotating palette.
3. **An entity colour may fill a shape, never colour text.** Screen-tuned
   colours like `#FFD60A` are unreadable on paper.
4. **All numbers set in JetBrainsMono.** It is already bundled and unused.
5. **Arithmetic moves into a pure `ReportBuilderService`**, matching
   `TimesheetService` / `WorkPatternService` / `TimeNotesService`. The PDF
   service becomes layout only.
6. **The notes appendix calls `TimeNotesService`**, it does not re-implement
   grouping. That service and its promotion rule landed in `79f67ae`.
7. **The resolver and the work-pattern report are passed in**, as optional
   parameters, from `PdfReportExport.run`. `ExportService` does not grow a
   second assembly path.

## The explicit ask, exactly

Three strings come out, listed with line numbers in §7 of the design:

- `:378` — `'Team Member: … | Prepared for Manager / Standup Review | …'`
- `:281` — `'Generated locally for $userName with WorkPulse - Privacy-First & Offline-First'`
- `:796` — `'STANDUP / PROGRESS HIGHLIGHTS & NOTES'` (same framing, same removal)

Also delete the duplicated `Page X of Y` from the running header at `:246`.

Do **this step first and commit it alone**, before any refactor.

## Seven things that will bite you if you skip them

- **Never re-derive the CapEx/OpEx fallback.**
  `SessionExportRecord.classification` is the single place inheritance is
  resolved. Writing `session.financialClassification ?? workItem.…` anywhere in
  this change is a bug, and `AGENTS.md` says so explicitly.
- **Unclassified time is its own bucket**, never folded into OpEx, and the
  CapEx ratio is taken over *classified* time only. `ClassificationSplit`
  already encodes this — read it, restate nothing.
- **A session can cross midnight.** The daily-rhythm chart must attribute it to
  both days by overlap, not bucket it by start time. `overlapOnDay` in
  `timesheet_grid_math.dart` already does this correctly. Use it. Do not write
  a second one.
- **Never advance a day with `.add(Duration(days: 1))`.** A day is 23 or 25
  hours twice a year. Build the next local midnight with `DateTime(y, m, d + 1)`.
- **`pw.Chart` will not lay out inside a `MultiPage` without a bounded
  height.** Wrap the donut in a `SizedBox`.
- **The appendix must be a `TableHelper` table, not a `Column` of cards.**
  Cards are the current bug: they do not page cleanly and they are why a week
  is ten pages.
- **The chip row at `:927` is a `pw.Row`.** Five tags and it silently runs off
  the page edge. Every chip container in the new code is a `pw.Wrap`.

## Three defects to fix in passing (step 1)

- `:88–92` — project colours are assigned by first-seen order and ignore
  `project.colorHex`. A project that is blue in the app is pink in the PDF.
  Use the user's colour, with a fallback keyed on a stable hash of the entity
  id so two exports of different ranges agree.
- `:466` — `'Worked on today'` is hardcoded on the ACTIVE TASKS tile. A March
  report says "today".
- `:139` — `efficiency` is `100.0` when there are no records, so an empty
  report claims "100% focus efficiency". Render `'—'`.

## Testing — the current tests cannot fail

`test/unit/services/pdf_report_service_test.dart` asserts only that the bytes
start with `%PDF-`. Keep those smoke tests, and add the real ones:

- **`test/unit/services/report_builder_service_test.dart`** (new) — the
  breakdown-sums-to-total invariant, share arithmetic, classification
  sourcing, rhythm bucketing including zero days and midnight-crossing
  sessions, axis selection, and the empty-input case producing no `NaN`, no
  `Infinity` and no `100%`.
- **The copy removals must be verified by a test that can actually fail.**
  PDF text is deflated, so string-searching normal output silently passes on
  anything. Generate with `pw.Document(compress: false)` behind a
  `@visibleForTesting` flag and assert the bytes contain neither
  `'Prepared for Manager'`, nor `'Generated locally for'`, nor `'STANDUP'`.

## Definition of done

- `flutter analyze` clean, `flutter test` green.
- Act I is one page for every input, including a 90-day range with 500
  sessions. Verify with a real generated file, not by reasoning.
- Every breakdown block sums to the range total.
- A 40-session week is at most ~4 pages total, against roughly ten today.
- `_buildSessionTimeline`, `_buildNotesCallout`, `_TaskSummary` and
  `_SessionNoteSummary` are deleted, not left orphaned.
- `pw.Document` carries `title`, `author`, `creator` and `subject`.
- Font loading still degrades: no Inter → base theme; no JetBrainsMono → base
  font for numerals. Neither failure aborts the export.
- `pubspec.yaml` bumped to `4.2.0`, commits following the build order with the
  Claude co-author trailer from `AGENTS.md`.

## One thing to ask before starting

§7 flags an open question. The user asked to remove the *audience framing*
("prepared for managers/standup", "generated locally … with WorkPulse"), but
`userName` also appears as a `'Report for $userName'` chip in the masthead
(`:340`) and in the running header (`:243`). The design recommends **keeping
the name once as a masthead byline** and dropping it from the running header —
a report that gets emailed with no author on it is odd. Implement it that way
unless the user says otherwise, and say which you did in your summary.
