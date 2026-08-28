# Session Context — Design & Delegation Brief

Five requested changes across four screens plus the timer. They look unrelated
in the request but share one spine: **a session is shown almost everywhere in
WorkPulse without the metadata that makes it meaningful**, and in one case is
created without it too. This document designs the shared machinery once and
then applies it per screen.

Companion prompt: `docs/SESSION_CONTEXT_PROMPT.md`.

---

## 0. Requests, verified against the tree

| # | Request | Status after inspection |
|---|---|---|
| 1 | Session category inherited from the previous session of the same task | **Reverses a documented rule.** See §1 — needs AGENTS.md rewritten and three tests replaced. |
| 2 | Time Notes: tell the day/range story, group by task, show metadata | Real work. Currently a flat time-ordered list. §3 |
| 3a | Time Sheet "Week of" card must start Sunday | One-line default change + doc/test updates. §4a |
| 3b | Merge "CapEx by category" / "OpEx by category" into one "By category" | **Already done** in `9c86d1d`. `TimesheetData.categoryRows` is a single list and `timesheet_view.dart:151` renders one panel. Nothing to do. §4b |
| 3c | All Time Sheet titles in title case | Pure string sweep, one open decision. §4c |
| 4 | Work Items → Sessions rows need Category, Timesheet code, People, Tags, Custom Attributes | Blocked on data: the inspector only receives raw `Session` objects. §5 |
| 5 | Time Log → Sessions show all metadata, Notes on a new line | Pure UI: the data is already in `SessionExportRecord`. §6 |

---

## 1. Session category inheritance — the one change that costs a rule

### What is being asked

Today (`timer_service.dart:55–77`): a work item seeds **only its first**
session with `categoryId` / `tagIds` / `peopleIds`. Every session after that
starts unclassified.

Requested: the category comes from the **previous session of the same task**.

### This contradicts AGENTS.md rule 7 on purpose

Rule 7 currently reads, in part:

> A WorkItem's `categoryId`, `tagIds` and `peopleIds` seed its **first**
> session only. Every session after that starts unclassified and is the
> user's to set — the second hour on a task is often not the same kind of
> work as the first.

That rationale is a real one and it was written deliberately: the same task
can be reading, then a call about it, then the change itself, and copying the
classification forward makes all three look identical in reporting.

The counter-argument, which is the user's, is stronger in practice: **the
common case is that the second hour on a task is the same kind of work as the
first**, and a session that starts blank stays blank, because nobody goes back
to classify. Unclassified time is a bigger reporting defect than
over-inherited time, and inheritance is trivially correctable at the session
editor while a blank is invisible.

**Decision: implement as asked, and rewrite rule 7 to match.** Leaving the
code and the rule contradicting each other is the worst of the three options.

### Scope: category only

The request names Category. **Tags and people keep their current behaviour**
(seeded on the first session from the work item, blank thereafter).

Rationale for the asymmetry, and why it is defensible rather than an
oversight: a category is a *kind of work* and is stable across a task's
sessions; people and tags are *who was in this particular hour* and *what this
particular hour was about*, which genuinely vary. Carrying people forward
would put a colleague on a solo session and, worse, would feed back into
`WorkItem.peopleIds` through the additive merge in
`SessionEditorController.updateSession` — one meeting would permanently attach
its attendees to every subsequent session of the task.

If the user wants tags and people to carry too, it is the same code path with
two more lines; the design notes it as a switch rather than a rewrite.

### The new precedence

In `TimerService.startSession`, for `categoryId`:

1. **Explicit argument wins**, on any session. Unchanged, and stays unchanged
   — Quick Capture lets the user classify as they start and that must never be
   second-guessed.
2. **Otherwise, the previous session's `categoryId`**, where the task has one.
   Previous = highest `start_time` for that work item, which is the session
   just closed when the user is resuming the same task.
3. **Otherwise, the work item's `categoryId`** — only reachable when the task
   has no sessions at all, i.e. the existing first-session seed.
4. **Otherwise null.**

For `tagIds` / `peopleIds`, unchanged: explicit → work item on first session →
empty.

### Implementation

Add to `SessionRepository`:

```dart
/// The most recently started session for a work item, or null when it has
/// none.
///
/// Exists so "what was I last doing on this task?" costs one indexed row
/// rather than hydrating the task's whole history. Ordered by start_time,
/// not created_at: a session backdated in the editor is genuinely the later
/// one, and the classification should follow the clock the user sees.
Future<Session?> getLatestByWorkItemId(String workItemId);
```

SQLite implementation mirrors `getByWorkItemId` with `limit: 1`. The existing
`idx_sessions_work_item_id` index covers the filter; the residual sort is over
one task's sessions and is not worth a composite index (noted in §9 as an
optional follow-up if a task ever accumulates thousands of sessions).

`startSession` then becomes, replacing lines 55–77:

```dart
var effectiveCategoryId = categoryId;
var effectiveTagIds = tagIds;
var effectivePeopleIds = peopleIds;

// One row rather than a count: this answers both questions the seeding
// rules ask — "has this task been tracked before?" and "what was it
// classified as last time?" — and it is still the Quick Capture hot path.
final previous = await _sessionRepository.getLatestByWorkItemId(workItemId);

if (previous == null) {
  // First session on this task: the work item's own classification is the
  // only thing there is to start from.
  final workItem = await _workItemRepository.getById(workItemId);
  if (workItem != null) {
    effectiveCategoryId ??= workItem.categoryId;
    if (effectiveTagIds.isEmpty) effectiveTagIds = workItem.tagIds;
    if (effectivePeopleIds.isEmpty) effectivePeopleIds = workItem.peopleIds;
  }
} else {
  // Continuing a task: the kind of work it was last time is the best
  // available guess at the kind of work it is now, and a session that
  // starts blank tends to stay blank. Tags and people are not carried —
  // see AGENTS.md rule 7.
  effectiveCategoryId ??= previous.categoryId;
}
```

### Ordering matters, and happens to be already correct

`startSession` closes the active session *before* this block runs. Closing
sets `end_time` and does not touch `start_time`, so the just-closed session is
still the `start_time DESC` winner. That is the behaviour we want: stop task A,
start task A again → the new session inherits from the one just stopped.

### Callers — nothing else changes

| Caller | Passes | Effect |
|---|---|---|
| `timer_provider.dart:110` (start timer) | `categoryId` possibly null | Inherits when null. Intended. |
| `timer_provider.dart:297` (switch, no notes path) | `targetCategoryId` possibly null | Inherits when null. Intended. |
| `task_switch_service.dart:93` | `targetCategoryId` possibly null | Inherits when null. Intended. |
| `idle_service.dart:98` | `categoryId: session.categoryId` **explicit** | Unaffected — explicit already wins, and the idle-split continuation rule in AGENTS.md rule 7 stays exactly as written. |

### Accepted cost: a dangling category id propagates

`sessions.category_id` has **no foreign key** (`migration_v1.dart:121–128`).
A hard-deleted category leaves dangling ids that already render as
`Uncategorized` everywhere (`export_service.dart:157` resolves through
`categoryMap` and gets null). Inheritance will now carry a dangling id forward
to new sessions rather than letting them start blank.

**Decision: accept, do not validate.** Validating would mean injecting a
`CategoryRepository` into `TimerService`, changing its constructor and every
test that builds one, to defend against a rare event (rule 6 prefers archiving
over deletion) whose symptom is already indistinguishable from "not
classified". The condition self-heals the moment the user classifies one
session. Do not add a repository for this.

### AGENTS.md rule 7 — replacement text

Replace the second bullet of rule 7 with:

> - A WorkItem's `tagIds` and `peopleIds` seed its **first** session only.
>   Every session after that starts with none, and they are the user's to set
>   — who was in an hour and what that hour was about genuinely vary session
>   to session.
> - **`categoryId` is inherited from the task's previous session**, falling
>   back to the WorkItem's own category when there is no previous session. A
>   category names the *kind* of work, which is usually stable across a task's
>   life, and an unclassified session stays unclassified because nobody
>   revisits it — a wrong inherited category is visible and one click to fix,
>   a blank one is invisible. This is inheritance at **write** time and is
>   copied onto the row, unlike the financial classification below, which is
>   resolved at read time.
> - Nothing borrows the WorkItem's classification at **read time**. …

Keep the remaining bullets (read-time rule, idle-split continuation, financial
classification exception, "explicit always wins") unchanged. Also update the
doc comment above `startSession` (`timer_service.dart:31–41`), which states
the old rule in prose.

### Tests to replace

`test/unit/services/timer_service_test.dart:227–320`, group
`'a work item seeds only its first session'`. Rename to
`'category is inherited forward; tags and people are not'` and replace:

- `the first session inherits category, tags and people` — **keep as is**,
  still true.
- `every session after the first starts unclassified` — **replace** with
  `a later session inherits the previous session's category, not the task's`:
  start session 1 (inherits `defaultCategory`), edit it to a *different*
  category, start session 2, assert session 2 carries the edited category —
  this is the test that proves it reads the previous session and not the work
  item. Assert `tagIds` and `peopleIds` are still empty on session 2.
- Add `a later session on a task whose sessions are all unclassified stays
  unclassified` — a task with no category, two sessions, both null.
- Add `an explicit null-category task with a classified previous session
  inherits it` — guards the fallback order.
- `an explicit choice always wins, on any session` — **keep**.
- `each work item is judged on its own session history` — **keep**.
- `countByWorkItemId counts only that work item` — **keep**; the repository
  method stays (it is part of the public interface and cheap), it is just no
  longer called from `startSession`.
- Add a repository test in `test/data/sqlite_repositories_test.dart` for
  `getLatestByWorkItemId`: null for an untracked item, the highest
  `start_time` for a tracked one, and unaffected by other work items.

Check `test/integration/task_switching_integration_test.dart` and
`test/unit/services/idle_service_test.dart` for assertions that a switched-to
or resumed session has a null category — they will now fail and their
expectations need updating rather than the code.

---

## 2. The shared spine

Requests 2, 4 and 5 all end at the same sentence: *show this session's
metadata*. Build it once.

### 2a. `timesheetCodeResolverProvider` — extracted

The `TimesheetCodeResolver` is currently assembled inline inside
`timesheetDataProvider` (`timesheet_provider.dart:52–73`). Three more screens
now need a code per session. Extract verbatim into its own provider in the
same file:

```dart
/// The project → option → code map, built once and shared.
///
/// Lifted out of [timesheetDataProvider] because the Time Log, the Work Items
/// inspector and Time Notes all now show a session's timesheet code, and four
/// screens resolving codes four ways is how they drift.
final timesheetCodeResolverProvider =
    FutureProvider<TimesheetCodeResolver>((ref) async { … });
```

`timesheetDataProvider` then `await ref.watch(timesheetCodeResolverProvider.future)`.
No behaviour change; assert this by running the existing timesheet tests
untouched.

### 2b. `ExportService` gains a work-item-scoped builder

`getExportRecords` (`export_service.dart:106`) resolves a list of sessions to
fully-hydrated records. The Work Items inspector needs exactly that, for one
task, ignoring the date range.

Refactor: extract everything after the session query into

```dart
Future<List<SessionExportRecord>> _hydrate(
  List<Session> sessions, {
  required String workspaceId,
}) async { … }
```

and add:

```dart
/// Every session logged against one work item, fully hydrated.
///
/// Shares [_hydrate] with the range query rather than resolving a second
/// way — the classification fallback, the idle netting and the attribute
/// formatting all live in one place, which is the same reason
/// [SessionExportRecord.classification] exists at all.
Future<List<SessionExportRecord>> getExportRecordsForWorkItem({
  required String workspaceId,
  required String workItemId,
}) async { … }
```

`getExportRecords` keeps its exact current signature and behaviour. Existing
`export_service_test.dart` must pass unchanged — that is the refactor's proof.

**Performance note.** `_hydrate` is N+1 by session (idle periods, task
attribute values, session attribute values). That is pre-existing and
acceptable for a range query; for a single work item it is bounded by that
task's session count. Do not optimise it in this change. Do note that
`getWorkItemValues(workItem.id)` is re-fetched per session inside the loop —
for the work-item-scoped call every session shares one work item, so hoist
that one lookup into a memo (`Map<String, List<WorkItemAttributeValue>>`)
inside `_hydrate`. That is a strict improvement for the range query too.

### 2c. `SessionMetadataChips` — one widget, three screens

New: `lib/features/reports/widgets/session_metadata.dart`.

```dart
/// The chip row that says what a session *was* — the same set, in the same
/// order, wherever a session is listed.
///
/// Three screens grew their own subsets of this (Time Log had project and
/// category, the Work Items inspector had people, Time Notes had project,
/// category and tags), which is why the same session read differently
/// depending on where you looked at it.
class SessionMetadataChips extends StatelessWidget {
  final SessionExportRecord record;
  final TimesheetCodeResolution? code;

  /// Fields already stated by the surrounding container, so they are not
  /// repeated on every row inside it. See §3's promotion rule.
  final Set<SessionMetadataField> omit;

  /// Renders an explicit muted "Uncategorized" chip when the session has no
  /// category. On by default: an unclassified session is the thing the user
  /// is looking for.
  final bool showUnclassified;

  final bool dense;
}

enum SessionMetadataField {
  project, category, classification, timesheetCode, tags, people, attributes,
}
```

Fixed render order — **project, category, classification, timesheet code,
tags, people, attributes** — inside a `Wrap` with `Spacing.sm - 2` /
`Spacing.xs`. Rules:

- Project → `EntityChip` with the project colour dot.
- Category → `EntityChip` with `IconUtils.getIcon(category.iconName)`. When
  null and `showUnclassified`, a plain `EntityChip(label: 'Uncategorized',
  icon: Icons.help_outline)` in `colors.textTertiary`.
- Classification → `StatusBadge` using `FinancialClassificationStyle.icon` /
  `.colorOf(context)` from `core/theme/classification_style.dart`. **Never
  invent a second styling** — that extension exists precisely to stop this.
  Show `record.classificationIsOverride` as a trailing `*` with a tooltip
  ("Set on this session, not inherited from the work item"). Skip the chip
  entirely for `FinancialClassification.none` unless `showUnclassified`.
- Timesheet code → `EntityChip(icon: Icons.receipt_long_outlined)` with the
  code. When `resolution.needsAttention`, tint `colors.warning` and tooltip
  the reason. When no resolver is supplied, omit the chip — do not render
  "No timesheet code" in a dense row; that message belongs on the Time Sheet's
  attention card.
- Tags → `EntityChip(label: '#${tag.name}', color: …)`.
- People → `EntityChip(label: person.name, icon: Icons.person, plain: true)`.
- Attributes → one chip per entry in `record.attributeValues`, labelled
  `Name: Value`, ordered by the definition's `displayOrder` then name. Use
  **all** enabled non-archived definitions with a value — not just
  `reportable` ones. `reportable` gates what the Time Sheet *aggregates*;
  these rows are saying what a session was, and a field the user filled in is
  worth showing. `attributeValues` is already filtered to enabled and
  non-archived by `export_service.dart:186`.
- Every chip gets `ConstrainedBox(maxWidth: 220)` and ellipsises. The Work
  Items inspector is two fifths of a window and will otherwise overflow.
- `dense: true` drops fills (`plain: true`) and one point of font size.

Also extract `SessionNoteBlock` into the same file — the "notes on their own
line" treatment shared by requests 2 and 5:

```dart
/// A session's note, on its own line, never as a chip.
///
/// A note is prose and is the reason most sessions get read at all; squeezing
/// it into a chip row truncated it at the first clause.
class SessionNoteBlock extends StatelessWidget {
  final String note;
  final int maxLines;        // 3 in dense lists, unbounded in Time Notes
  final bool callout;        // sunken container (Time Notes) vs inline (logs)
}
```

Leading `Icons.notes` at `IconSizes.xs` in `colors.textTertiary`, body text
italic, `Tooltip` carrying the full note whenever it is truncated.

---

## 3. Time Notes — from a list of notes to a day's story

### The problem

`time_notes_view.dart` renders `Map<DateTime, List<TimeNoteEntry>>` as a flat
time-ordered list of cards. Four sessions on the same task across a day
produce four disconnected cards. There is no way to read "what happened on
PROJ-123 today", which is the question the screen exists to answer.

### New shape

```
┌ Range summary ────────────────────────────────────────────────┐
│ 6h 20m noted · 14 notes · 5 tasks · 3 days · 72% of tracked   │
│ time carries a note        Busiest: Payments migration 2h 40m │
└───────────────────────────────────────────────────────────────┘

┌ Today · Thursday, 28 Aug ─────── 4 tasks · 9 notes · 5h 10m ──┐
│ ┌ Payments migration ─────────────────── 3 sessions · 2h 40m ┐│
│ │ ● Platform  ▲ CapEx  #PRJ-4471  @Alice                     ││   ← promoted
│ │ ─────────────────────────────────────────────────────────  ││
│ │ 09:15 – 10:30  1h 15m   ⟨Development⟩                      ││   ← varies
│ │   Traced the double-charge to the retry wrapper.           ││
│ │   Wrote a failing test first.                              ││
│ │ ─────────────────────────────────────────────────────────  ││
│ │ 13:00 – 14:10  1h 10m   ⟨Meeting⟩ @Bob                     ││
│ │   Walked Bob through the fix. He'll own the rollout.       ││
│ └────────────────────────────────────────────────────────────┘│
│ ┌ Onboarding docs ───────────────────────── 1 session · 45m ─┐│
│ …
```

### The promotion rule — the thing that makes this "collate"

Inside a task group, compute each metadata field across its entries:

- **Identical on every entry** → render once in the task card header, and pass
  that field in `SessionMetadataChips.omit` for every row inside.
- **Varies** → render per row, and omit from the header.

Project, timesheet code and classification are almost always constant and will
promote; category, people and tags usually vary and will not. Without this
rule, grouping by task just stacks four identical chip rows and reads worse
than what exists today.

### Model — move to `domain/`, make the grouping pure

Delete `lib/features/notes/models/time_note_entry.dart`. New
`lib/domain/models/time_note_model.dart`:

```dart
/// One note, with the session it was written on.
class TimeNoteEntry {
  final SessionExportRecord record;   // replaces the seven unpacked fields
  final String note;
  final TimeNoteSource source;        // session vs workItem — see below
  final TimesheetCodeResolution? code;

  Session get session => record.session;
  DateTime get startTime => record.session.startTime;
  DateTime? get endTime => record.session.endTime;
  Duration get duration => record.netActiveDuration;
}

/// Where the note text came from. The current provider silently falls back to
/// the work item's notes when a session has none, so the same paragraph is
/// repeated under every session of that task and looks like it was written
/// four times.
enum TimeNoteSource { session, workItem }

/// Every note for one work item within one day (or the whole range, when the
/// range is a single day).
class TaskNoteGroup {
  final WorkItem workItem;
  final Project? project;
  final List<TimeNoteEntry> entries;   // ascending by start time
  final Duration total;                // sum of entry durations
  final int sessionCount;
  final DateTime firstStart;
  final DateTime? lastEnd;
  final Set<SessionMetadataField> promoted;  // fields constant across entries
  final TimeNoteEntry representative;        // the entry the header reads from
}

class NotesDayGroup {
  final DateTime day;
  final List<TaskNoteGroup> tasks;     // by total desc, ties by firstStart
  final Duration total;
  final int noteCount;
}

class TimeNotesReport {
  final DateRange range;
  final List<NotesDayGroup> days;      // newest first
  final Duration notedDuration;        // tracked time that carries a note
  final Duration trackedDuration;      // all tracked time in range
  final int noteCount;
  final int taskCount;                 // distinct across the range
  final TaskNoteGroup? busiest;        // by total across the range
  final bool isFiltered;

  /// Share of tracked time that carries a note, 0–100. The single number
  /// that says whether this screen can be trusted as a record of the range.
  double get coverage => …;            // 0 when trackedDuration is zero
}
```

### Pure service

New `lib/domain/services/time_notes_service.dart`, modelled on
`TimesheetService` — records in, report out, no repositories and no clock:

```dart
class TimeNotesService {
  const TimeNotesService();

  TimeNotesReport build({
    required DateRange range,
    required List<SessionExportRecord> records,
    TimesheetCodeResolver codes = const TimesheetCodeResolver(),
    String query = '',
    bool includeWorkItemFallbackNotes = true,
  });
}
```

Rules it must implement:

1. **Note extraction.** Session note if non-empty. Otherwise the work item's
   note, tagged `TimeNoteSource.workItem`, and **only once per task per day** —
   repeating a task-level note under each of its four sessions is the current
   behaviour and it is noise. Attach it to the task group header instead of to
   a row. `includeWorkItemFallbackNotes: false` drops it entirely; wire this
   to a small toggle in the toolbar so the user can see session notes alone.
2. **`trackedDuration` counts every record in range**, noted or not — that is
   what makes `coverage` meaningful. Sessions with no note contribute to it
   and to nothing else.
3. **Search filters entries first, then groups are built from survivors.**
   Empty task groups and empty days drop out. Every count in every header is a
   post-filter count. A group whose *header* matches (task name, project) but
   whose notes do not must still appear, with its matching-only entries — match
   on the same field set the current provider uses (note, task, project,
   category, person, tag), plus timesheet code and attribute values.
4. **Ordering.** Days descending (newest first, unchanged). Tasks within a day
   by total duration descending, ties by `firstStart` ascending. **Entries
   within a task ascending by start time** — this is a deliberate flip from
   today's global descending order: within one task you are reading a
   narrative, and a narrative reads forwards.
5. **Promotion** as described above, computed per task group.

### Provider

`timeNotesProvider` returns `TimeNotesReport` instead of the raw map. It now
watches `sessionHistoryProvider`-style records for the notes range plus
`timesheetCodeResolverProvider`. Keep `timeNotesRangeProvider`,
`timeNotesDateProvider` and `timeNotesSearchProvider` exactly as they are —
the range controls are not part of this change.

Note the range duplication: `time_notes_provider.dart:63–95` recomputes a
`DateRange` from the same two knobs that `reportsDateRangeProvider` already
resolves. Lift it the same way `reportsDateRangeProvider` was lifted —
`timeNotesDateRangeProvider` — so the subtitle, the query and the report can
never disagree. Do not merge it with the reports range; the two screens have
independent pickers by design.

### View

- `TimeNotesSummary` card at the top, always visible (including when filtered,
  where it reports the filtered figures and says so). Metrics: noted duration,
  note count, task count, day count, coverage %, busiest task. Reuse
  `features/dashboard/widgets/metric_card.dart` if its API fits; otherwise
  match `TimesheetSummary`'s visual weight.
- Day sections **only when the report spans more than one day**. For a
  single-day range, render the task cards directly — a day card wrapping task
  cards wrapping note rows is three nested borders and reads as a maze.
- `TaskNoteCard`: header row = task name (titleSmall, w600) · duration ·
  "N sessions" · promoted `SessionMetadataChips`. Tapping the header opens the
  task in Work Items is *out of scope*; keep the existing behaviour where
  tapping a **note row** opens `SessionEditDialog` for that session.
- Note rows: time range + duration in `AppTypography.numeric`, then the
  non-promoted `SessionMetadataChips(omit: group.promoted, dense: true)`, then
  `SessionNoteBlock(callout: true, maxLines: 8)` on its own line. Multi-line
  notes must render their line breaks — they already do; preserve that.
- The task-level fallback note (source `workItem`) renders once under the
  header, in a muted callout labelled "Task note".
- **`_copyStandupNotes` must follow the new shape.** Day heading → task
  bullet with its promoted metadata → indented note lines per session with
  their times. This is the screen's most-used action; a copy output that still
  reads as a flat time list defeats the whole change.
- Empty states: keep both existing ones. Add a third for "notes exist but
  every one was filtered out" — already handled by `isFiltered`.

### Tests

New `test/unit/services/time_notes_service_test.dart` (pure, no widgets):
grouping by task within a day; ordering rules 4; promotion of constant fields
and non-promotion of varying ones; the work-item fallback note appearing once
per task per day, not once per session; coverage arithmetic including the
zero-tracked-time case; search filtering entries and pruning empty groups;
header counts being post-filter.

Extend `test/widget/time_notes_view_test.dart`: summary card renders; a task
with three sessions renders one card with three rows; a constant project chip
appears once, in the header; a varying category chip appears on each row.

---

## 4. Time Sheet

### 4a. Week starts Sunday

`AppSettings.defaultTimesheetWeekStartDay` (`app_settings_provider.dart:34`):
`DateTime.saturday` → `DateTime.sunday`.

That is the whole functional change. `weekStartFor` (`timesheet_grid_math.dart`)
computes `delta = (weekday - weekStartDay + 7) % 7`, which for `weekStartDay =
7` gives Sunday → 0 and Monday → 1, producing columns **Sun Mon Tue Wed Thu
Fri Sat** — exactly what was asked.

Also:

- `timesheet_settings_dialog.dart:71` helper text: "Defaults to Saturday" →
  "Defaults to Sunday."
- `test/unit/providers/app_settings_provider_test.dart:40`:
  `expect(settings.timesheetWeekStartDay, DateTime.saturday)` →
  `DateTime.sunday`.
- `docs/TIMESHEET_GRID_DESIGN.md` §7 and `docs/TIMESHEET_GRID_PROMPT.md`
  decision 2 both state "defaulting to Saturday". Correct both, and note in
  the grid design that the grid's week now aligns with
  `DashboardTimeRange.thisWeek` (`analytics_model.dart:26`), which has always
  started Sunday. The two concepts agreeing is a improvement worth recording,
  not an accident to leave undocumented.

**Migration: none needed, and none should be added.** Settings are read from
the settings table and fall back to the constant when absent
(`app_settings_provider.dart:210`). A user who never opened the settings
dialog has nothing stored and moves to Sunday on the next launch. A user who
explicitly chose Saturday has it stored and keeps it — which is correct, and
is the reason not to backfill.

**Open decision, needs one word from the user:** the request says "should
always be Sunday", which could mean *remove the setting*. The recommendation
is to **keep it configurable and change the default** — a week-start day is
exactly the organisation-specific configuration AGENTS.md rule 2 says not to
hardcode, and the request is satisfied for this user either way. If the user
does want it locked, it is a one-line change: drop the "Week start day" field
from `TimesheetSettingsDialog` and pass `DateTime.sunday` literally in
`timesheet_provider.dart:82`. Do not do this without being told to.

### 4b. Unified "By category" — already shipped

Commit `9c86d1d` merged the per-classification category tables.
`TimesheetData.categoryRows` is one `List<TimesheetRow>` and
`timesheet_view.dart:151–160` renders a single panel whose columns already
carry CapEx / OpEx / Unclassified. **No work.** Verify by opening the screen;
if a stale per-classification panel is visible, it is a build artefact.

The one leftover is a stale doc comment: `timesheet_model.dart:200–204`
("One classification's worth of category rows … the breakdown that the old
category-level model could not express") is orphaned above `TimesheetGridRow`
and describes a class that no longer exists. Delete it.

### 4c. Title case

Apply to **panel and card titles on the Time Sheet screen only**. Do not touch
subtitles, body copy, table cells, or other screens — this is the scope the
request drew, and a half-swept app is worse than a consistently sentence-cased
one.

Convention: capitalise the first and last word and everything else except
articles and short prepositions/conjunctions (*a, an, the, and, but, or, nor,
for, of, on, at, to, in, by, with, as*).

| File:line | Now | Becomes |
|---|---|---|
| `timesheet_code_table.dart:71` | By timesheet code | **By Timesheet Code** |
| `timesheet_view.dart:131` | By project | **By Project** |
| `timesheet_view.dart:141` | By work item | **By Work Item** |
| `timesheet_view.dart:151` | By category | **By Category** |
| `timesheet_entry_grid.dart:203` | Week of Sat 1 Mar – Fri 7 Mar | **Week of Sun 1 Mar – Sat 7 Mar** (`of` stays lowercase; only the day names change, and those change from §4a, not from this) |

Also sweep, in the same pass, the titles inside `timesheet_summary.dart`,
`timesheet_attention_card.dart`, `timesheet_entry_grid.dart` and
`_NoAttributesHint` (`timesheet_view.dart:230`). Read each and apply the same
rule; they are static string literals, so **hardcode the corrected strings**.
Do **not** add a `toTitleCase()` helper — it would mangle proper nouns and
acronyms, and there is nothing dynamic to justify it.

**Attribute sections** (`timesheet_view.dart:163`, `'By ${section.definition.name}'`):
capitalise the literal `By` and render the user's attribute name **verbatim**.
A name the user typed as "cost centre" stays "cost centre"; re-casing
user-entered data is how "iOS" becomes "Ios". The result is
`By cost centre`, which is slightly inconsistent and is the correct trade.

Update `test/widget/timesheet_view_test.dart:273, 275, 283, 285, 307, 309, 412`
to the new strings.

---

## 5. Work Items — session rows carry their metadata

### The blocker

`WorkItemInspector` receives `List<Session>` from
`sessionsForWorkItemProvider` — raw rows holding `categoryId`, `tagIds` and
`peopleIds` as **ids**. It renders people only because `peopleMap` is passed
down separately from `tasks_view.dart`. There is no category, no tag, no
classification, no timesheet code and no attribute value anywhere in reach.

### Data

New in `lib/features/tasks/providers/task_sessions_provider.dart`:

```dart
/// Every session on one work item, fully hydrated — the same records the
/// Time Log renders, scoped to one task.
///
/// [sessionsForWorkItemProvider] stays for TaskFormDialog, which only needs
/// ids and must not pay for attribute hydration on every keystroke.
final workItemSessionRecordsProvider =
    FutureProvider.family<List<SessionExportRecord>, String>((ref, id) async {
  ref.watch(timerProvider.select((s) => s.value?.activeSession?.id));
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  return ref
      .watch(exportServiceProvider)
      .getExportRecordsForWorkItem(workspaceId: workspace.id, workItemId: id);
});
```

Invalidate it everywhere `sessionsForWorkItemProvider` is invalidated:
`SessionEditorController.updateSession` and `.deleteSession`
(`reports_provider.dart`), and the inspector's own `onEdited`.

### UI

`_InspectorSessionRow` (`work_item_inspector.dart:378–500`) takes a
`SessionExportRecord` plus an optional `TimesheetCodeResolution` and becomes
three stacked lines:

1. Leading state icon · `MMM d • HH:mm – HH:mm` · duration (right-aligned,
   `AppTypography.numeric`) · hover edit affordance. Unchanged.
2. `SessionMetadataChips(record: record, code: code, dense: true,
   omit: {SessionMetadataField.project})` — project is the task's and is
   already stated in the inspector's Classification section, so repeating it
   on every row is pure noise.
3. `SessionNoteBlock(note: …, maxLines: 3)` on its own line when present.

Delete the bespoke people `Wrap` at `work_item_inspector.dart:465–479`; the
shared widget renders people now.

**Height.** Rows grow from ~44px to ~90px with metadata and a note. The narrow
layout constrains the inspector to `SizedBox(height: 320)`
(`tasks_view.dart:250`) — three rows and the whole thing is scrolled. Raise it
to 420 and let the inner `ListView` scroll; do not make the sessions list
non-scrollable.

**Live session.** The running session's row must keep its live ticker
(`liveElapsed`). `SessionExportRecord.netActiveDuration` for an open session is
computed from `DateTime.now()` at hydration time and will be stale; keep
passing `liveElapsed` from `timerState.elapsed` and prefer it, exactly as the
current code does.

**Keep the `Sessions (N)` header count** and add the task's total next to it —
the inspector already fetches `taskTotalDurationProvider`.

Tests: extend `test/widget/tasks_inspector_timer_test.dart` — a session with a
category, two tags, one person and one attribute renders all four; a session
with none of them renders the muted "Uncategorized" chip and nothing else; the
live ticker still updates.

---

## 6. Time Log — metadata and notes on their own line

Purely presentational. `SessionRow` already holds the full
`SessionExportRecord`; it just chooses to render two chips and a truncated
note.

`session_row.dart:127–147` becomes:

```
[gutter dot] [09:15 – 10:30]  Task name                    [Active]
                              ⟨project⟩ ⟨category⟩ ⟨CapEx⟩ ⟨#PRJ-4471⟩
                              ⟨#urgent⟩ ⟨Alice⟩ ⟨Release: 24.3⟩
                              📝 Traced the double-charge to the retry…
                                                    −0:12  01:15:00  ✎ 🗑
```

- Line 1: task name + `Active` badge. Unchanged.
- Line 2: `SessionMetadataChips(record: record, code: resolution)` — full set,
  nothing omitted, since the Time Log spans projects and tasks and every field
  is genuinely varying here.
- Line 3: `SessionNoteBlock(note: …, maxLines: 3)`. **Delete `_NoteChip`**
  (`session_row.dart:217–248`) — it is the thing the request is asking to
  remove, and nothing else uses it.
- Idle chip, duration and hover actions stay in the trailing column,
  `crossAxisAlignment: CrossAxisAlignment.start` so they align to the first
  line rather than floating to the middle of a now-tall row.

Timesheet code: `SessionHistoryView` watches `timesheetCodeResolverProvider`
and passes the resolver down through `SessionDayGroup` to `SessionRow`, which
calls `codes.resolveFor(project: record.project, attributeOptionIds:
record.attributeOptionIds)` per row. That is a map lookup, safe to do in
`build`. Default the parameter to `const TimesheetCodeResolver()` so existing
widget tests constructing a `SessionRow` keep compiling — with an empty
resolver the code chip is simply absent.

Bump the loading skeleton `itemHeight` from 96 to ~140
(`session_history_view.dart`) so the skeleton is not visibly shorter than the
content it stands in for.

Density: a 60-row day becomes long. **Do not** add a density toggle in this
change — it is scope the request did not ask for. If it becomes a problem, the
existing `density` pattern in `tasks_view.dart` is the precedent to follow
later.

Tests: extend `test/widget/export_ui_test.dart` or add
`test/widget/session_row_test.dart` — all metadata renders; the note is on its
own line and is not a chip; a session with no metadata renders one
"Uncategorized" chip and no empty `Wrap`.

---

## 7. Build order

Each step is green before the next starts.

1. **Timer inheritance** (§1). `getLatestByWorkItemId` + repository test →
   `startSession` → replace the timer service tests → fix fallout in the idle
   and task-switch tests → rewrite AGENTS.md rule 7 and the `startSession` doc
   comment. Self-contained; commit alone.
2. **Time Sheet week start + title case** (§4a, §4c). Two independent string
   and constant changes plus doc/test updates. No new code. Commit alone —
   this is the change most likely to be wanted immediately.
3. **Shared spine** (§2). `timesheetCodeResolverProvider` extraction →
   `ExportService._hydrate` + `getExportRecordsForWorkItem` →
   `SessionMetadataChips` and `SessionNoteBlock`. **The whole existing test
   suite must pass untouched after this step** — that is the proof the
   extractions changed nothing.
4. **Time Log** (§6). The smallest consumer of the spine, so it shakes out the
   widget's API before two more screens depend on it.
5. **Work Items inspector** (§5). Adds the second consumer plus its provider.
6. **Time Notes** (§3). Largest, and last, because it consumes everything
   above and its own pure service is the only genuinely new logic left.

Bump `pubspec.yaml` to `4.1.0` at the end.

---

## 8. Out of scope — say no to these

- **Editing metadata inline** from any list row. Every row still opens
  `SessionEditDialog`; that dialog is the one place a session is edited.
- **Tags and people inheriting forward** (§1). Category only, unless the user
  says otherwise.
- **Removing the week-start setting** (§4a). Default change only.
- **Title-casing outside the Time Sheet screen.**
- **A density toggle on the Time Log** (§6).
- **Fixing the N+1 in `_hydrate`** beyond the single work-item-values hoist in
  §2b. It is pre-existing and this change does not make it worse.
- **A new migration.** Nothing here needs a schema change; the composite
  `(work_item_id, start_time)` index in §9 is explicitly deferred.
- **Grouping the Time Log by task.** The request asked for that on Time Notes
  only, and the Time Log's value is precisely that it is chronological.

---

## 9. Deferred, with reasons

- **Composite index `(work_item_id, start_time DESC)` on sessions.**
  `getLatestByWorkItemId` filters on the existing `idx_sessions_work_item_id`
  and sorts one task's rows. Worth a v9 migration only if a task ever holds
  thousands of sessions. Measure before adding.
- **Moving Time Notes' range logic into a shared range abstraction.** The two
  screens duplicate a five-case switch. Lifting `timeNotesDateRangeProvider`
  (§3) removes the intra-screen drift; unifying it with
  `reportsDateRangeProvider` would couple two independently-driven pickers.
- **Note coverage as a Work Pattern insight.** `TimeNotesReport.coverage` is
  exactly the shape `WorkPatternService` findings take (`plan` lane, evidence
  attached). Natural follow-up, not this change.

---

## 10. Invariants to assert

- After §1, `startSession` issues **one** query to answer the seeding question,
  not two. The Quick Capture budget (AGENTS.md rule 3, <300ms) is the reason.
- After §2b, the range export and the work-item export produce **identical
  records** for a session that appears in both. Assert it directly in
  `export_service_test.dart`.
- After §3, every count rendered in a Time Notes header equals the number of
  things rendered under it, filtered or not.
- After §4a, the Time Sheet grid's week and `DashboardTimeRange.thisWeek` start
  on the same weekday for a default-configured user.
- Nothing in §5 or §6 re-derives a session's financial classification.
  `SessionExportRecord.classification` is the only source, as AGENTS.md
  already requires.
