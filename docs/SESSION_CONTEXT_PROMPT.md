# Delegation prompt — Session Context

Copy everything below the line into the implementing agent.

---

You are working on **WorkPulse**, an offline-first Flutter/Riverpod/SQLite
desktop time tracker at the repo root. Read `AGENTS.md` first and follow its 10
architectural rules. Rules 3, 6, 7 and 10 constrain this task directly, and
**rule 7 is one you are being asked to change** — see below.

## Your task

Implement the design in **`docs/SESSION_CONTEXT_DESIGN.md`**. Read it in full
before writing any code. It carries the models, the widget API, the exact
string changes, the test plan and a build order. **Follow the build order in
§7** — steps 1 and 2 are self-contained and must land before the shared
refactor in step 3, and step 3's whole point is that it changes no behaviour.

## Why this exists

WorkPulse shows a session in four places — the Time Log, the Work Items
inspector, Time Notes, and the Time Sheet — and three of them show a different
subset of what a session actually is. The user cannot read what an hour was
without opening the edit dialog. Separately, sessions after the first on a task
start with no category and stay that way, because nobody goes back to classify
them. You are fixing both: sessions inherit their category forward, and every
list that shows a session shows what it was.

## Decisions already made — do not relitigate these

1. **Category inherits from the previous session of the same task.** This
   reverses the current documented behaviour. AGENTS.md rule 7 must be
   rewritten (replacement text is in §1 of the design) along with the doc
   comment on `TimerService.startSession`. Do not leave the rule and the code
   contradicting each other.
2. **Only the category inherits.** Tags and people keep today's behaviour —
   first session seeds from the work item, blank thereafter. §1 explains why;
   do not "improve" on it.
3. **An explicit argument to `startSession` still always wins**, on any
   session. This is untouched and is why the idle-split path needs no change.
4. **Time Sheet week start day stays a setting**; only its default moves
   Saturday → Sunday. No migration.
5. **"By category" is already merged** (commit `9c86d1d`). That request item is
   done. Do not re-implement it.
6. **Title case applies to Time Sheet panel titles only**, hardcoded as string
   literals. No `toTitleCase()` helper, and user-entered attribute names are
   rendered verbatim.
7. **One `SessionMetadataChips` widget serves three screens.** Do not let any
   screen grow its own chip row again — that divergence is the bug being fixed.

## Six things that will bite you if you skip them

- **`startSession` must stay one query, not two.** Replace the
  `countByWorkItemId` call with a single `getLatestByWorkItemId` — that one row
  answers both "is this the first session?" and "what was it last classified
  as?". Quick Capture has a <300ms budget (rule 3) and this is its hot path.
  Keep `countByWorkItemId` on the repository interface; it is just no longer
  called here.
- **Look up the previous session *after* the active one is closed**, i.e. leave
  the existing close-first ordering alone. Stopping task A and restarting it
  must inherit from the session just stopped, and `start_time DESC` gives you
  that for free.
- **The Work Items inspector has no metadata to render yet.** It receives
  `List<Session>` — raw ids. You must add
  `ExportService.getExportRecordsForWorkItem` and a new provider before any UI
  work there. Do not resolve categories or tags a second way inside the widget.
- **Do not re-derive a session's financial classification anywhere.**
  `SessionExportRecord.classification` is the single place inheritance is
  resolved (AGENTS.md, Financial Classification section). Read it; never
  recompute the `session.financialClassification ?? workItem.…` fallback.
- **Time Notes header counts must be post-filter.** Search filters entries,
  then groups are rebuilt from the survivors and empty groups are dropped. A
  header saying "3 sessions" above one visible row is the classic failure here.
- **The work item's note is not four notes.** Today's provider falls back to
  `workItem.notes` when a session has none, so the same paragraph repeats under
  every session of that task. In the new grouping it appears **once per task
  per day**, attached to the task card header, tagged
  `TimeNoteSource.workItem`.

## Two more traps

- `SessionExportRecord.netActiveDuration` for a **running** session is computed
  at hydration time and goes stale immediately. The Work Items inspector must
  keep preferring the live `liveElapsed` from `timerState.elapsed`, exactly as
  `work_item_inspector.dart` does today.
- Chips in the Work Items inspector must have a hard `maxWidth` and ellipsise.
  That pane is two fifths of the window, and the same row that fits in the Time
  Log will overflow there.

## Definition of done

- `flutter analyze` clean, `flutter test` green.
- After build-order step 3 (the shared extractions), **the entire pre-existing
  test suite passes untouched**. If you had to edit a test to make step 3 pass,
  you changed behaviour you were not supposed to change — back it out.
- Tests updated where the design says so: `timer_service_test.dart` (group
  replaced), `sqlite_repositories_test.dart` (new repository method),
  `app_settings_provider_test.dart:40`, `timesheet_view_test.dart` (title
  strings), plus the new `time_notes_service_test.dart`.
- `AGENTS.md` rule 7 rewritten; `docs/TIMESHEET_GRID_DESIGN.md` §7 and
  `docs/TIMESHEET_GRID_PROMPT.md` decision 2 corrected from Saturday to Sunday;
  the orphaned doc comment at `timesheet_model.dart:200–204` deleted.
- `pubspec.yaml` bumped to `4.1.0`.
- Commits follow the build order, one per step, with the Claude co-author
  trailer from AGENTS.md.

## One thing to ask before starting

§4a flags an open question: the request says the timesheet week "should always
be Sunday", which may mean *remove the setting* rather than *change its
default*. The design recommends changing the default and keeping the setting
(AGENTS.md rule 2 — organisation-specific configuration should not be
hardcoded). Implement it that way unless the user says otherwise, and mention
the alternative in your summary.
