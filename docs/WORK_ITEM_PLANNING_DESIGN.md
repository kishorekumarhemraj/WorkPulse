# Work Item Planning & Reminders — Design & Delegation Brief

Status: design only, not implemented.
Target branch: `claude/work-items-planning-notifications-yrhaz3`.
Database version at time of writing: **9** (`AppConstants.dbVersion`). This work
introduces **v10**.

---

## 1. The problem

WorkPulse answers *"where did my time go"* with real rigour. It cannot answer
*"what am I supposed to be doing today"*, and it never speaks first.

A `WorkItem` today carries `createdAt`, `updatedAt`, `lastWorkedAt` and
`archivedAt` — four timestamps, all of them records of things that already
happened. There is nowhere to write down an intention. So the user keeps their
commitments somewhere else (a Jira board, a notebook, their memory) and
WorkPulse, the app that is open all day and knows exactly what they are working
on, is the one tool that cannot remind them that the thing they promised for
Thursday is due Thursday.

This design adds three dates to a work item and a reminder engine that acts on
them:

| Field | Meaning | Kind |
|---|---|---|
| **Planned start** | The day I intend to begin. | Calendar date |
| **Due** | The day I have committed to deliver. | Calendar date |
| **Completed** | The moment I actually finished. | Instant |

And it makes the app speak: a reminder on the day something is planned to
start, a reminder ahead of a due date, a reminder on the due date, and — the
part the user asked for explicitly — **a reminder that keeps arriving every
working day until an overdue item is either done or rescheduled**.

### The shape of the feature in one sentence

*Three dates on a work item, one pure function that turns them into a status,
one pure function that turns them into reminder occurrences, a delivery ledger
that makes "at most once" a database invariant, and a platform bridge that
raises the notification.*

### What must not be built

- **No status column.** A work item does not get a `status` field with
  `TODO / IN_PROGRESS / DONE`. WorkPulse is a time tracker, not an issue
  tracker, and a workflow state machine is precisely the organisation-specific
  metadata AGENTS.md rule 2 says belongs in the configurable attribute system.
  What this design adds is a *plan*, and the plan's status is **derived**, never
  stored (§4).
- **No priority, no assignee, no estimate, no sub-tasks, no dependencies.**
  Every one of those is a step toward reimplementing Jira inside the domain
  model that rule 1 exists to keep Jira out of.
- **No network.** Rule 8 stands. Reminders are local notifications raised by
  the OS on this machine, from data in this machine's SQLite file. Nothing is
  fetched, nothing is sent, no push service is involved.
- **No plan inheritance into sessions.** Rule 7. A session does not acquire its
  work item's due date at read time or write time. Financial classification
  remains the *single* deliberate exception to the read-time rule, and this
  design does not add a second one. Plans describe intent; sessions describe
  what happened.

---

## 2. Review of the current implementation

Findings are ordered by how much they matter to this work. File references are
against the branch at the time of writing.

### F1 — `WorkItem` has no forward-looking field at all

`lib/domain/models/work_item_model.dart:21–25` — `createdAt`, `updatedAt`,
`lastWorkedAt`, `archivedAt`. All backward-looking. There is no column to
extend and no adjacent concept to piggyback on; this is genuinely new state.

### F2 — The existing date attribute stores a calendar date as a UTC instant

**This is the defect this design must not repeat, and the reason for the
`CalendarDate` type in §3.2.**

`lib/data/repositories/sqlite_attribute_repository.dart:396` —
`'date_value': val.dateValue?.toStorageString()`
`lib/core/extensions/datetime_extensions.dart:7` —
`String toStorageString() => toUtc().toIso8601String();`

A user in UTC+05:30 who picks "3 September" gets `2026-09-02T18:30:00.000Z`
written to disk. Read back and formatted in local time it round-trips correctly
*on that machine, in that zone, that half of the year*. Compare it against
another date, or read it after a timezone change, and it is off by a day.

A due date is not an instant. "Due Thursday" does not mean "due at 00:00 UTC on
Thursday" — it does not become due earlier for a colleague in Sydney. It is a
calendar fact, and it must be stored as `'YYYY-MM-DD'` text, compared as text or
as (y, m, d), and never passed through `toStorageString()`.

Fixing the existing `date_value` columns is **out of scope** here (§11) — it is a
data migration with its own risk profile. But the new columns must not join
them, and the new `CalendarDate` type exists so that the compiler stops the next
person from making the same mistake.

### F3 — `WorkItemRepository.update` rewrites the tag and people join tables

`lib/data/repositories/sqlite_work_item_repository.dart:220–245` — every
`update` deletes all rows from `work_item_tags` and `work_item_people` for the
item and re-inserts them.

That is correct for the form dialog, which owns the whole item. It is wrong for
a checkbox in a list row that means "mark this done": ticking it would rewrite
two join tables to their current contents on every click. §6.3 adds a targeted
`updatePlan` for exactly this reason.

### F4 — Filtering is entirely client-side and has no sort

`lib/features/tasks/providers/work_items_provider.dart:149–168` — the notifier
fetches with `getAll` / `search` and then filters project, category, tag and
person in Dart. Order comes from the repository's `ORDER BY updated_at DESC`
and is not user-controllable.

For planning this is not good enough: "everything overdue, oldest deadline
first" is *the* question a planning view asks, and it is an ordering question.
§7.1 adds a `WorkItemSort` to the filter provider and sorts in Dart alongside
the existing filters — consistent with what is already there, and correct at
this data scale (a personal tracker, hundreds of items, not millions). The
`(workspace_id, due_date)` index in §3.1 exists for the Planner's own query,
which does go to SQL.

### F5 — There is no notification capability of any kind

`lib/core/platform/` contains `hotkey_service`, `idle_detector_service`,
`pdf_export_handler`, `system_idle_source`, `tray_service`, `user_info_service`,
`window_service`. No notification bridge, and no notification package in
`pubspec.yaml`.

`docs/WORKPULSE_SPEC.md:1391` and `:1736` both list "Notifications" as a
platform capability under Phase 8. It was specified and never built. This design
builds it.

### F6 — The tray is the only existing way the app speaks unprompted

`lib/features/tray/providers/tray_provider.dart:143–175` — title, tooltip and a
context menu, driven by timer state. It is a genuine, always-visible surface and
it costs no new dependency, which is why §8.3 makes it the **fallback delivery
channel** rather than a decoration. A macOS build that is unsigned, or a user
who denies notification permission, still gets a visible overdue count.

### F7 — `IdleNotifier` is the working precedent for a background loop

`lib/features/idle/providers/idle_provider.dart` — a `Notifier` holding a
subscription, with `_closedIdleStart` guarding against re-prompting for a
stretch the user has already answered for, and `_hasCheckedForUnaccountedGap`
guarding a once-per-launch job against the shell being rebuilt when Quick
Capture takes over.

Both guards exist because **the shell is torn down and rebuilt every time the
Quick Capture window opens**. The reminder scheduler lives in the same shell and
will be rebuilt just as often. Its equivalent guard is not an in-memory flag —
it is the `UNIQUE` constraint in §5.4, which survives a rebuild, a restart and a
crash.

### F8 — `WorkPatternService` is the purity precedent

`AGENTS.md`, Pattern Insights: *"`WorkPatternService` is pure — sessions in,
insights out, no repositories and no clock of its own. All I/O belongs to
`AnalyticsService`."*

`ReminderService` (§5.5) follows it exactly: work items in, plus `now`, plus
settings, plus the set of occurrence keys already delivered — occurrences out.
No repository, no `DateTime.now()`. A reminder engine you cannot put on an
arbitrary clock is a reminder engine you cannot test, and every interesting case
here is a clock case.

### F9 — `ShellNavTab.shortcutDigit` is `index + 1`

`lib/features/shell/models/shell_nav_tab.dart:91` — `int get shortcutDigit =>
index + 1;`

Inserting a `planner` tab mid-enum renumbers every shortcut after it.
`test/unit/shell_nav_tab_test.dart` asserts against these. This is expected and
intended (§7.4), not an accident to be worked around by appending the new tab at
the end — sidebar order is meaningful and documented in that file's own comment.

### F10 — Settings already have the fallback pattern this needs

`lib/features/settings/providers/app_settings_provider.dart:224–232` —
`_idleThresholdFromMinutes` returns the default for anything unparseable or
non-positive, *"so a corrupted row can never disable idle detection outright."*

Every new reminder setting in §9 parses the same way. A corrupt row must never
be able to silently switch reminders off — that is a failure the user only
notices by missing a deadline.

---

## 3. The model

### 3.1 Schema (migration v10)

```sql
-- Three new columns on work_items.
ALTER TABLE work_items ADD COLUMN planned_start_date TEXT;  -- 'YYYY-MM-DD', local calendar date
ALTER TABLE work_items ADD COLUMN due_date TEXT;            -- 'YYYY-MM-DD', local calendar date
ALTER TABLE work_items ADD COLUMN completed_at TEXT;        -- UTC ISO-8601 instant

CREATE INDEX IF NOT EXISTS idx_work_items_due
  ON work_items(workspace_id, due_date);

-- The reminder ledger. Also the notification centre's store (§8.2).
CREATE TABLE IF NOT EXISTS work_item_reminders (
  id              TEXT PRIMARY KEY,
  work_item_id    TEXT NOT NULL,
  rule            TEXT NOT NULL,   -- 'planned_start' | 'due_ahead' | 'due_today' | 'overdue'
  occurrence_key  TEXT NOT NULL,   -- the local date this reminder was FOR: 'YYYY-MM-DD'
  anchor_date     TEXT NOT NULL,   -- the planned_start/due date it was derived from
  delivered_at    TEXT NOT NULL,   -- UTC instant it was actually raised
  read_at         TEXT,            -- UTC instant the user acknowledged it
  snoozed_until   TEXT,            -- UTC instant; suppresses re-raise until then
  FOREIGN KEY (work_item_id) REFERENCES work_items(id) ON DELETE CASCADE,
  UNIQUE (work_item_id, rule, occurrence_key)
);

CREATE INDEX IF NOT EXISTS idx_work_item_reminders_delivered
  ON work_item_reminders(delivered_at DESC);
```

Three things about this schema carry the whole design:

**Why two of the columns are dates and one is an instant.** A planned start and
a due date are commitments expressed in calendar terms — "Friday" — and they
mean the same Friday in every timezone (F2). A completion is an event: it
happened at a moment, and that moment is what makes "was it late?" answerable
against the due date. So the first two are `'YYYY-MM-DD'` text and the third
goes through `toStorageString()` like every other instant in the app.

**Why `UNIQUE (work_item_id, rule, occurrence_key)`.** This is the only thing
standing between the user and a reminder that fires four times because the poll
ran twice, the shell was rebuilt, or the app restarted at 09:01. Making
"at most once per occurrence" a *database invariant* rather than a scheduler
promise means no in-memory guard can be lost (F7), and the correct scheduler
implementation is the obvious one: insert, and treat a constraint violation as
"already handled".

**Why `anchor_date` is stored even though it is derivable.** If the user moves a
due date from the 3rd to the 10th, the occurrence key changes and the new date
correctly gets its own reminders. But the *old* reminder is still sitting in the
notification centre saying "due today", and by tomorrow that is a lie.
`anchor_date` lets the list render it as superseded — "was due 3 Sep, now 10 Sep"
— rather than quietly deleting the history (rule 6) or displaying a stale claim.

**No backfill.** Existing work items get three NULLs. There is no conservative
default for a due date: inventing one would be inventing a commitment the user
never made, exactly as `Project.timesheetCode` refuses to invent a cost code.
`archived_at IS NOT NULL` does not imply completion either — an archived item is
hidden, which is not the same as delivered.

### 3.2 `CalendarDate`

New file: `lib/domain/models/calendar_date.dart`.

```dart
/// A day on the wall calendar — not an instant.
///
/// A due date of 3 September is 3 September in every timezone and on both
/// sides of a DST boundary. Storing it as a `DateTime` means storing an
/// instant, and an instant converted to UTC for storage lands on the previous
/// day for anyone east of Greenwich — which is exactly what
/// `attribute_values.date_value` does today (see docs, F2).
///
/// This type exists so that mistake cannot be made twice: there is no
/// implicit conversion to `DateTime`, and the only ways in are
/// [CalendarDate.fromLocal], [CalendarDate.parse] and the constructor.
class CalendarDate extends Equatable implements Comparable<CalendarDate> {
  final int year;
  final int month;
  final int day;

  const CalendarDate(this.year, this.month, this.day);

  /// The calendar day [instant] falls on *in the machine's local zone*.
  factory CalendarDate.fromLocal(DateTime instant) { ... }

  /// 'YYYY-MM-DD'. Returns null for anything malformed rather than throwing:
  /// a corrupt row must not crash the Work Items screen.
  static CalendarDate? tryParse(String? value) { ... }

  /// 'YYYY-MM-DD' — zero-padded, so text ordering equals date ordering and
  /// SQLite can sort and range-filter on the column directly.
  String toStorageString() { ... }

  /// Midday local, never midnight. Midnight does not exist on spring-forward
  /// days in some zones; midday always does. Used only at the UI boundary,
  /// for `showDatePicker` and `DateFormat`.
  DateTime toLocalDateTime() { ... }

  int compareTo(CalendarDate other);
  int differenceInDays(CalendarDate other);
  CalendarDate addDays(int days);
  bool get isWeekend;
  int get weekday;                       // DateTime.monday..DateTime.sunday
}
```

`toLocalDateTime()` returning midday rather than midnight is not fussiness. In
zones that spring forward at 00:00, midnight on that date does not exist, and
`DateTime(y, m, d)` silently yields 01:00 — which then formats and compares
differently from every other day of the year. Midday is safe in every zone.

### 3.3 `WorkItemPlan`

New file: `lib/domain/models/work_item_plan.dart`.

```dart
class WorkItemPlan extends Equatable {
  final CalendarDate? plannedStart;
  final CalendarDate? due;
  final DateTime? completedAt;          // UTC instant

  const WorkItemPlan({this.plannedStart, this.due, this.completedAt});
  const WorkItemPlan.unplanned() : plannedStart = null, due = null, completedAt = null;

  bool get isPlanned => plannedStart != null || due != null;
  bool get isComplete => completedAt != null;

  /// The plan's position in its own lifecycle, as of [today]. Never stored.
  PlanStatus statusOn(CalendarDate today);

  /// Whether the work was delivered after the day it was due. Null when the
  /// item is not complete, or was complete with no due date to be late against.
  bool? get wasLate;

  /// Negative when overdue. Null with no due date.
  int? daysUntilDue(CalendarDate today);

  /// A start after its own due date. The form prevents it (§7.2); this exists
  /// so a hand-edited database renders as an anomaly instead of crashing.
  bool get isInverted;
}
```

Grouping the three fields into a value object rather than hanging them loose on
`WorkItem` does three things: it keeps `WorkItem.props` from growing another
three entries, it gives the derivation logic (§4) one obvious home that needs no
repository and no Flutter import to test, and it makes `plan: const
WorkItemPlan.unplanned()` the readable default. `WorkItem.plan` is
**non-nullable** — "no plan" is a plan object that says so, not a null that
every call site has to remember to check.

### 3.4 `WorkItem` changes

`lib/domain/models/work_item_model.dart` — one new field, threaded through the
constructor, `copyWith` and `props`:

```dart
/// What the user intends for this item, as opposed to what has happened to
/// it. Never inherited by sessions: a session records what happened, and a
/// plan is a statement about what has not happened yet (AGENTS.md rule 7).
final WorkItemPlan plan;
```

Serialisation, in `_toMap` / `_fromMap` of
`lib/data/repositories/sqlite_work_item_repository.dart`, stays flat across the
three columns. Nothing else in the repository changes shape.

---

## 4. Status is derived, never stored

```dart
enum PlanStatus {
  unplanned,    // no dates at all
  scheduled,    // planned start is in the future
  startsToday,  // planned start is today
  open,         // started, or due in the future with no start date
  dueToday,
  overdue,
  completed,
}
```

### Why derived

A stored status is wrong at midnight. The user closes the laptop on Tuesday with
an item marked "due tomorrow"; they open it on Thursday and a stored status still
says "due tomorrow" until some job runs and rewrites it. Every such job is a
chance to be wrong, and none of them can run while the app is closed.

This is the same reasoning as AGENTS.md rule 5 — timers compute duration from
wall-clock timestamps rather than trusting a ticker. A plan's status is computed
from its dates and today's date, on every read. There is nothing to migrate,
nothing to repair, and nothing that can drift.

### Precedence

Evaluated in this order; the first match wins:

1. `completedAt != null` → **completed**. A finished item is never overdue.
   Whether it was finished late is `wasLate`, an attribute of the completion,
   not a status of its own — a late-but-delivered thing and an
   on-time-but-delivered thing are in the same place in the lifecycle, and the
   UI shows lateness as a badge on a completed row.
2. `due != null && due < today` → **overdue**.
3. `due == today` → **dueToday**. A deadline outranks a start: if something is
   planned to start today and also due today, the user needs to hear the
   deadline.
4. `plannedStart == today` → **startsToday**.
5. `plannedStart != null && plannedStart > today` → **scheduled**.
6. `plannedStart != null || due != null` → **open**. Started, or due later with
   no start date.
7. otherwise → **unplanned**.

### Tone mapping

`PlanStatus` maps to the existing `BadgeTone` (`lib/core/widgets/status_badge.dart`)
so planning uses the app's semantic palette rather than inventing colours:

| Status | Tone | Label |
|---|---|---|
| overdue | `danger` | `OVERDUE` / `3 DAYS LATE` |
| dueToday | `warning` | `DUE TODAY` |
| startsToday | `accent` | `STARTS TODAY` |
| scheduled | `info` | `3 SEP` |
| open | `neutral` | `DUE 10 SEP` |
| completed | `success` | `DONE` (+ `LATE` when `wasLate`) |
| unplanned | — | no badge at all |

`StatusBadge` always pairs colour with a label, so status is never communicated
by colour alone — that property is inherited for free and must not be broken by
rendering a bare coloured dot for a due date.

### Completion does not touch the timer, and the timer does not touch completion

Marking an item complete does **not** stop a running session, and starting a
session on a completed item does **not** clear `completedAt`.

Clearing it would destroy the record of when the work was delivered, which rule 6
forbids, and it would do so silently from inside Quick Capture — where rule 3
forbids the confirmation dialog that would make it non-silent. So the plan is
never mutated as a side effect of tracking time. An item that is complete and
still accruing time is a real situation (a late fix, a follow-up question), and
the Planner surfaces it as an anomaly with a one-click **Reopen** rather than
guessing. Reopening clears `completedAt` and is always explicit.

---

## 5. Reminders

### 5.1 The rules

| Rule | Fires | Default | Setting |
|---|---|---|---|
| `plannedStart` | On the planned start date | on | `remindOnPlannedStart` |
| `dueAhead` | *N* days before the due date | on, N = 1 | `dueAheadLeadDays` (0 = off) |
| `dueToday` | On the due date | on | always on when reminders are on |
| `overdue` | Every reminder day after the due date, until complete, rescheduled or archived | on | `overdueRepeat`: `weekdays` / `daily` / `off` |

`overdue` is the rule the user actually asked for — *"it will keep reminding me"*.
It is the only rule that repeats, and it is the reason the rest of the machinery
can stay simple (§5.3).

### 5.2 When they fire

One **briefing time** per day, default **09:00 local**, configurable. All four
rules fire at that time.

Reminders fire only on configured **reminder days**, default Mon–Fri.

An occurrence whose fire time has already passed *today* fires on the next pass.
This matters more than it looks: if the user sets a due date of "today" at 16:00,
the 09:00 briefing time is long gone, and the reminder they just created should
reach them now, not tomorrow morning. The condition is
`occurrence date == today && now >= briefing time`, so it does.

A due date landing on a weekend produces no `dueToday` reminder — Saturday is not
a reminder day — but the `dueAhead` reminder on Friday covers the run-up, and
Monday's `overdue` reminder covers the aftermath. That is the intended behaviour,
not a gap: the app does not interrupt the user's Saturday about a deadline it
already warned them about on Friday.

### 5.3 Missed days need no backfill

If the app was closed for three days, three days of occurrences were never
raised. WorkPulse does **not** fire them on launch.

The scheduler only ever evaluates occurrences dated **today**. Past occurrences
are never computed and never written. This is not a compromise — it is correct,
and it falls out of the `overdue` rule:

- A missed `dueToday` from Monday is, by Thursday, an item that is three days
  overdue. Thursday's `overdue` occurrence says so, once, with the right
  severity.
- A missed `plannedStart` from Monday is an intention the user has already lived
  through. Firing it on Thursday tells them nothing they can act on.
- A missed `dueAhead` is, by definition, superseded by the due date itself.

So the app that has been closed for a week opens with **one** notification —
"4 work items overdue" — not thirty. And the scheduler needs no catch-up path,
no horizon parameter and no stale-marker rows: the code that handles a week
away is the same code that handles a normal Tuesday.

### 5.4 The ledger

Every reminder actually raised writes one row to `work_item_reminders` (§3.1).
The row is both the idempotency record and the notification centre's content
(§8.2) — the same fact, not two copies of it.

`UNIQUE (work_item_id, rule, occurrence_key)` makes the guarantee structural.
The scheduler's write path is:

1. Compute today's due occurrences (pure, §5.5).
2. `INSERT` each one. A `UNIQUE` violation means another pass already handled
   it — swallow it and drop that occurrence from the batch.
3. Raise a notification for what actually inserted.

Two passes racing, a shell rebuilt by Quick Capture, a restart at 09:01 — all of
them converge on exactly one delivery. No in-memory flag is load-bearing (F7).

**Snooze.** A row with `snoozed_until` in the future is treated as delivered and
suppresses re-raising. When that instant passes, the *same row* is re-raised
(`delivered_at` updated, `snoozed_until` cleared) rather than a new row being
created — the user is being reminded again about the same occurrence, and the
notification centre should say so once. Offered durations: 1 hour, and until
tomorrow's briefing.

**Retention.** Reminder rows are history. Prune rows with
`delivered_at` older than 90 days **and** `read_at IS NOT NULL` on startup.
Unread rows are never pruned — an unread reminder is the one piece of state the
user has not yet seen.

### 5.5 `ReminderService` — pure

New file: `lib/domain/services/reminder_service.dart`. Pure, following
`WorkPatternService` (F8): no repositories, no clock of its own.

```dart
class ReminderOccurrence {
  final WorkItem workItem;
  final ReminderRule rule;
  final CalendarDate occurrence;   // always today, in practice
  final CalendarDate anchor;       // the plannedStart/due it came from
  final int daysOverdue;           // 0 unless rule == overdue
}

class ReminderService {
  /// Every reminder that is due as of [now] and has not already been
  /// delivered. Deterministic: the same inputs always give the same output.
  List<ReminderOccurrence> occurrencesDue({
    required List<WorkItem> items,
    required DateTime now,                    // local
    required ReminderSettings settings,
    required Set<String> alreadyDelivered,    // '<workItemId>|<rule>|<key>'
  });
}
```

Rules the function enforces:

- Archived items are excluded. Archiving is how a user says "stop showing me
  this", and a reminder is the loudest possible way to show it to them.
- Completed items are excluded from every rule. Completion is the exit.
- Items whose plan `isInverted` (§3.3) are excluded from `dueAhead` only — the
  lead-day arithmetic is meaningless — but still produce `dueToday` and
  `overdue`, because the due date itself is unambiguous.
- Nothing fires when `now` is before the briefing time, on a non-reminder day,
  or when `remindersEnabled` is false.
- Results are ordered: `overdue` (most overdue first), `dueToday`,
  `plannedStart`, `dueAhead`. This ordering is what the grouped notification's
  headline reads from.

### 5.6 The scheduler — the only impure part

New file: `lib/features/planner/providers/reminder_scheduler_provider.dart`,
modelled on `idle_provider.dart` (F7).

A `Notifier` holding a `Timer.periodic` at **5 minutes**, which:

1. Reads work items for the current workspace and today's ledger rows.
2. Calls `ReminderService.occurrencesDue` with `DateTime.now()`.
3. Inserts ledger rows, dropping `UNIQUE` collisions (§5.4).
4. Groups what survived into one notification (§5.7) and hands it to
   `NotificationService`.
5. Updates the in-app notification centre state.

A pass also runs on: app start (after DB init), window focus, and **immediately
after any plan edit** — so setting a due date of "today" at 16:00 reminds the
user at 16:00, not tomorrow (§5.2).

Five minutes is chosen against sleep/wake, not against precision. The machine
sleeps at 08:30 and wakes at 09:40; a wall-clock evaluation on the next tick
finds today's occurrence undelivered and raises it. There is no timer to drift,
because nothing is scheduled in advance — every pass asks "what is due *now*",
which is the same principle as rule 5.

### 5.7 One interruption per pass

**The ledger is per item. The interruption is per pass.**

Seven items due today must not be seven banners. Within a pass, occurrences are
collapsed into a single notification:

- one occurrence → the item speaks for itself:
  *"Due today — Migrate reporting queries"*
- more than one → a count, led by the most severe rule:
  *"3 work items need attention — 1 overdue, 2 due today"*

Clicking it shows the window and switches to the Planner. Each occurrence still
gets its own ledger row and its own line in the notification centre, so the
record stays per-item while the interruption stays proportionate.

---

## 6. Data access

### 6.1 `ReminderRepository` (new)

`lib/domain/repositories/reminder_repository.dart`:

```dart
abstract class ReminderRepository {
  /// Occurrence keys already delivered for [date] — the scheduler's
  /// suppression set. Cheap: one indexed query per pass.
  Future<Set<String>> deliveredKeysOn(CalendarDate date);

  /// Inserts, or returns null when the UNIQUE constraint rejects it because
  /// another pass got there first.
  Future<ReminderRecord?> recordDelivery(ReminderRecord record);

  Future<List<ReminderRecord>> recent({int limit = 50});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> snooze(String id, DateTime until);
  Future<void> pruneReadBefore(DateTime cutoff);
}
```

Implementation `lib/data/repositories/sqlite_reminder_repository.dart`,
registered in `lib/data/providers/repository_providers.dart` alongside the rest.

### 6.2 `WorkItemRepository` additions

```dart
/// Writes only the three plan columns and `updated_at`.
///
/// Deliberately not `update(WorkItem)`: that method deletes and re-inserts
/// the tag and people join tables (see docs, F3), which is right for the form
/// dialog and wrong for a checkbox in a list row.
Future<void> updatePlan(String id, WorkItemPlan plan);

/// Items with a due date inside [from, to], plus (when [includeOverdue])
/// everything still open and past due. Ordered by due date ascending.
/// Excludes archived; includes completed only when [includeCompleted].
Future<List<WorkItem>> getByDueRange({
  required String workspaceId,
  CalendarDate? from,
  CalendarDate? to,
  bool includeOverdue = true,
  bool includeCompleted = false,
});
```

`getByDueRange` is the Planner's query and the only place plan filtering goes to
SQL — hence `idx_work_items_due`. Because `CalendarDate.toStorageString()` is
zero-padded, `WHERE due_date BETWEEN ? AND ?` on TEXT is a correct date range
comparison.

### 6.3 Completion

`complete` and `reopen` are `updatePlan` calls, not new repository methods —
completion is a plan edit. They live on the provider (§7.1) as
`completeWorkItem(id)` / `reopenWorkItem(id)`, which set or clear `completedAt`
and re-run a scheduler pass.

---

## 7. Screens

### 7.1 Work Items — `lib/features/tasks/`

**`work_item_row.dart`** — a plan badge between the name and the existing
duration badge, using the tone table in §4. Rows with no plan show nothing:
planning is opt-in and an "UNPLANNED" badge on every row would be noise on the
majority of items. The row's overflow menu (`_MenuRow`) gains **Mark complete**
/ **Reopen**, **Set due date…** and **Snooze reminders**.

**`work_items_toolbar.dart`** — one new `AppFilterDropdown<PlanFilter>`:
*Any plan · Overdue · Due today · Due this week · Scheduled · Unplanned ·
Completed*, and an `AppSegmentedControl` for sort: *Recent · Due date · Name*.
Both feed the existing active-filter chip row, which already renders whatever
the filter carries.

**`work_items_provider.dart`** — `WorkItemFilter` gains `planFilter` and
`WorkItemSort`; both applied in the existing client-side `where` and a `sort`
after it (F4). `WorkItemsNotifier` gains `setPlan`, `completeWorkItem`,
`reopenWorkItem`, each invalidating itself as the existing mutators do.

### 7.2 Task form — `lib/features/tasks/views/task_form_dialog.dart`

A **Plan** section below the classification fields: *Planned start* and *Due
date*, each a clearable date field built on `showDatePicker` (already used in six
places, listed in `lib/features/reports/widgets/reports_range_controls.dart` and
others), plus a *Mark complete* control that records the completion instant and
allows back-dating it.

Validation: due date must not precede planned start. The message names the
conflict rather than blaming the field — *"Due date is before the planned start
(3 Sep)"* — and the fix is one tap on either field. This is the only place
`isInverted` should ever become possible.

### 7.3 Inspector — `lib/features/tasks/widgets/work_item_inspector.dart`

A `_Section` titled **Plan**: the three dates, the derived status badge, days
until/since due in words, and quick actions — **Complete**, **+1 day**,
**Next week**, **Snooze reminders**. Rescheduling from here is one click because
rescheduling is the honest answer to most overdue reminders, and a reminder
engine that makes rescheduling harder than ignoring it trains the user to ignore
it.

### 7.4 Planner — new `lib/features/planner/`

A new `ShellNavTab.planner`, inserted **immediately before `tasks`** in the
`Track` group. The enum's own comment says declaration order is sidebar order
and *"runs in the order a day does: see where you stand, read what that says
about you, pick the work, log it, write it up, then report it."* Deciding what
to work on comes immediately before picking it up. Inserting mid-enum renumbers
the shortcut digits after it and `test/unit/shell_nav_tab_test.dart` must be
updated (F9) — that is the intended cost of keeping sidebar order meaningful.

Sections, in this order, each collapsible and hidden when empty:

1. **Overdue** — most overdue first. The only section that is never collapsed by
   default.
2. **Due today**
3. **Starting today**
4. **This week**
5. **Later**
6. **Recently completed** (last 7 days, with `LATE` badges where applicable)
7. **Needs attention** — the anomalies: complete but still accruing time (§4),
   inverted dates, items overdue by more than 30 days that are probably dead.

Empty state (`lib/core/widgets/empty_state.dart`) when nothing is planned at
all: it must say what to do — *"Set a due date on a work item and it will show up
here"* — with a button that opens the Work Items screen.

### 7.5 Notification centre — `lib/features/shell/widgets/`

A bell in `sidebar_header.dart` carrying an unread count, opening a popover of
recent reminder rows (newest first), each with **Open**, **Complete**, **Snooze**
and its `anchor_date` rendered as superseded where the plan has since moved
(§3.1). **Mark all read** at the foot.

It belongs in the sidebar, not on the Planner, because the point of a reminder is
to reach the user while they are looking at something else.

### 7.6 Tray — `lib/features/tray/providers/tray_provider.dart`

When anything is overdue or due today, the tray menu gains a disabled summary
line (`⚠ 2 overdue · 3 due today`) above the existing timer items, and an
**Open Planner** entry. The tooltip carries the same summary.

This is also the fallback delivery channel (§8.3), so it must be built as part of
the reminder work and not deferred as polish.

---

## 8. Delivery

### 8.1 The platform bridge

New file: `lib/core/platform/notification_service.dart`, following the shape of
every other bridge in that directory — abstract interface, desktop
implementation, no-op for tests (rule 9):

```dart
class AppNotification {
  final String id;          // the ledger row id, echoed back on click
  final String title;
  final String body;
  final bool urgent;        // overdue
}

abstract class NotificationService {
  /// False when the platform cannot deliver or the user has denied
  /// permission. Callers fall back (§8.3) rather than failing.
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<void> show(AppNotification notification);
  void setNotificationClickListener(void Function(String id) listener);
  Future<void> dispose();
}
```

Implementations: `DesktopNotificationService`, `TrayFallbackNotificationService`,
`NoOpNotificationService`. Every method on the desktop implementation is wrapped
in try/catch with `debugPrint`, exactly as `DesktopTrayService` does — a
notification failure must never take down the app that is tracking the user's
time.

### 8.2 The dependency decision

**Recommendation: add `flutter_local_notifications`** (confirm the current major
on pub.dev before adding; Windows support ships as the companion
`flutter_local_notifications_windows` package and must be checked against the CI
Windows build).

It is the right call despite being the only new dependency in this design:

- It is **local-only** — macOS `UNUserNotificationCenter`, Windows toast. No
  network, no push service, no account. Rule 8 holds.
- The alternative — tray title and tooltip only — is not a reminder. A reminder
  the user only sees if they happen to look at the menu bar is a status
  indicator with extra steps, and the user's request was for the app to speak
  first.

Two things about it that will bite:

- **macOS App Sandbox is fine, code signing is not optional.**
  `macos/Runner/Release.entitlements` already enables the sandbox and that is
  compatible with `UNUserNotificationCenter`. But an unsigned local debug build
  can have notifications silently fail — no error, no banner. Do not diagnose
  that as a bug in this code, and do not weaken the fallback because "it works
  on my machine".
- **Permission is asked once and can be denied forever.** Ask on the first pass
  that actually has something to deliver, not on app start — a permission prompt
  at launch, before the user has planned anything, is the prompt everyone
  denies. On denial, set `nativeNotificationsEnabled` false, fall back, and say
  so in settings with a link to system settings.

The pubspec change is the one part of this design that should be sanity-checked
by a human before merge, because it affects both platform builds in CI.

### 8.3 Fallback

If `initialize()` or `requestPermission()` returns false, the scheduler uses
`TrayFallbackNotificationService`: the tray summary of §7.6 plus the in-app
notification centre badge. Reminders still exist, still land in the ledger, and
are still visible — they simply do not raise an OS banner.

The in-app notification centre is **always** written, on every path. It is the
durable record; the OS banner is one way of pointing at it.

---

## 9. Settings

New fields on `AppSettings`
(`lib/features/settings/providers/app_settings_provider.dart`), each persisted
through the existing `settings` key/value repository:

| Field | Key | Default |
|---|---|---|
| `remindersEnabled` | `reminders_enabled` | `true` |
| `reminderTimeMinutes` | `reminder_time_minutes` | `540` (09:00) |
| `reminderDays` | `reminder_days` | `1,2,3,4,5` (Mon–Fri) |
| `dueAheadLeadDays` | `due_ahead_lead_days` | `1` |
| `overdueRepeat` | `overdue_repeat` | `weekdays` |
| `remindOnPlannedStart` | `remind_on_planned_start` | `true` |
| `nativeNotificationsEnabled` | `native_notifications_enabled` | `true` |

Every parser follows `_idleThresholdFromMinutes` (F10): unparseable, empty or
out-of-range values fall back to the default. A corrupt row must never be able
to switch reminders off silently — that is a failure whose only symptom is a
missed deadline.

UI: a **Reminders** section in the settings surface, with a plain-language
preview line that renders the current configuration as a sentence — *"Weekdays at
09:00, one day before, repeating while overdue"* — because seven independent
controls with no summary is a configuration nobody can hold in their head.

---

## 10. Migration

`lib/data/migrations/migration_v10.dart`, guarded and re-runnable in the style
of `MigrationV8` and `MigrationV9`:

- `PRAGMA table_info(work_items)` before each `ALTER TABLE ... ADD COLUMN`.
- `CREATE TABLE IF NOT EXISTS work_item_reminders` and
  `CREATE INDEX IF NOT EXISTS` for both indexes.
- **No backfill** (§3.1).

Then:

- `AppConstants.dbVersion`: `9` → `10`.
- `DatabaseService._onCreate`: `if (version >= 10) await MigrationV10.execute(db);`
- `DatabaseService._onUpgrade`: `if (oldVersion < 10) await MigrationV10.execute(db);`

Note that `_onCreate` runs the whole chain itself — sqflite never calls
`onUpgrade` for a new file — so missing the `_onCreate` line ships fresh installs
stamped v10 with a v9 schema.

---

## 11. Out of scope

- **Reminders while WorkPulse is not running.** The app is tray-resident and
  normally open all day, which covers the working day, but a closed app is
  silent. A background agent (launchd on macOS, Task Scheduler on Windows) is a
  separate piece of work with its own install, permission and update story.
  This must be stated plainly in the settings UI rather than left for the user
  to discover by missing something.
- **Fixing `attribute_values.date_value`** (F2). A real defect, a real data
  migration, its own design.
- **Recurring work items** ("every Monday"). The reminder engine repeats;
  the *item* does not.
- **Planned effort vs actual.** Tempting, because the app already knows actual
  hours to the second — and a genuinely separate feature about estimation.
- **Calendar import/export (ICS), and reading the system calendar.** Reading the
  user's calendar is a privacy posture change, not a feature addition.
- **Inline actions on the OS notification** ("Complete" from the banner). V1
  click opens the Planner.
- **Due dates on sessions or projects.** A commitment is made about a piece of
  work, which is what a work item is.
- **Plan columns in CSV/PDF exports.** Straightforward to add later; adds
  columns to files people have built spreadsheets against, so it wants its own
  decision.

---

## 12. Tests

Following `.agents/rules/05-testing-and-mocking.md` and the existing layout.

**New — `test/unit/calendar_date_test.dart`**
Parse/format round trip; rejects malformed input by returning null rather than
throwing; ordering matches text ordering; `differenceInDays` across a DST
boundary and across a year boundary; `toLocalDateTime()` on a spring-forward
date; two `CalendarDate`s built in different zones from the same wall date are
equal.

**New — `test/unit/work_item_plan_test.dart`**
The full `statusOn` precedence table, one case per rule in §4; completed beats
overdue; dueToday beats startsToday; boundary at today ± 1 day; `wasLate` true,
false and null; `isInverted`; `daysUntilDue` sign.

**New — `test/unit/services/reminder_service_test.dart`**
The core of the feature, all on injected clocks:
- each rule fires on its day and not on the day before or after;
- `alreadyDelivered` suppresses exactly the matching occurrence and nothing else;
- nothing fires before the briefing time, on a non-reminder day, or when
  disabled;
- **due date set to today at 16:00 fires on the next pass**, not tomorrow;
- **app closed for three days produces one overdue occurrence, not three days of
  backfill**;
- archived and completed items produce nothing;
- `dueAhead` respects the lead-day setting and is skipped when 0;
- ordering: most overdue first.

**New — `test/unit/providers/reminder_scheduler_test.dart`**
With `NoOpNotificationService` and an in-memory database: a pass writes ledger
rows; a second pass in the same minute writes none and raises nothing; seven
occurrences produce seven rows and **one** notification; a plan edit triggers a
pass; snooze suppresses until its instant and then re-raises the same row.

**New — `test/unit/services/notification_service_test.dart`**
Mirrors `test/unit/services/tray_service_test.dart`: the no-op records calls, the
fallback routes to the tray, `initialize` returning false is handled by callers
without throwing.

**New — `test/widget/planner_view_test.dart`**
Sections render in order and hide when empty; the empty state appears with no
plans and its button navigates; overdue is expanded by default; complete and
reschedule actions call through.

**Extended — `test/data/database_migration_test.dart`**
v9 → v10 adds the three columns and the table; running `MigrationV10` twice is
safe; the `UNIQUE` constraint rejects a duplicate `(work_item_id, rule,
occurrence_key)`; `ON DELETE CASCADE` removes reminders with their work item.

**Extended — `test/data/sqlite_repositories_test.dart`**
Plan round-trips through `_toMap`/`_fromMap`; a null plan reads back as
`WorkItemPlan.unplanned()`; **`updatePlan` leaves `work_item_tags` and
`work_item_people` untouched** (F3); `getByDueRange` boundaries are inclusive and
`includeOverdue` behaves.

**Extended — `test/unit/providers/work_items_provider_test.dart`**
Each `PlanFilter` value; each sort order, including where nulls land (unplanned
items sort last under "Due date", never first).

**Extended — `test/unit/shell_nav_tab_test.dart`**
Renumbered shortcut digits and the new tab's group, label and keywords (F9).

**Extended — `test/widget/work_management_ui_test.dart`**
The plan badge appears with the right tone and label; no badge for unplanned
items; the form rejects a due date before the planned start with a message
naming both dates.

---

## 13. Build order

Each step leaves the app compiling, tested and shippable. Steps 1–5 deliver
usable planning with **no new dependency and no platform risk**; the only risky
step is last, and everything before it works without it.

**1. `CalendarDate` + `WorkItemPlan` + status derivation.**
Pure Dart, no schema, no UI. `test/unit/calendar_date_test.dart` and
`test/unit/work_item_plan_test.dart` pass. Nothing else in the app knows these
types exist yet.

**2. Migration v10 + persistence.**
`MigrationV10`, `AppConstants.dbVersion` → 10, both `DatabaseService` call sites,
`WorkItem.plan` threaded through the model and the repository's `_toMap` /
`_fromMap`, `updatePlan` and `getByDueRange`. Migration and repository tests
pass. The app runs unchanged — the plan is stored and read but nothing displays
it.

**3. Editing a plan.**
Task form Plan section with validation, inspector Plan section with quick
actions, row badge, provider mutators. **Planning is now usable end to end.**

**4. Finding planned work.**
Toolbar plan filter and sort, then the Planner tab and view. Ship-worthy on its
own: a user can plan, see what is due, and work from it — with no reminders yet.

**5. Reminder settings.**
`AppSettings` fields, parsers with fallbacks, the settings section with its
plain-language preview. Nothing reads them yet, which makes them easy to verify
in isolation.

**6. `ReminderService`.**
Pure, and the largest test file in the feature. No wiring. Every clock case in
§12 passes before anything can fire at a user.

**7. Scheduler + in-app delivery.**
`ReminderRepository`, `SqliteReminderRepository`, the scheduler provider, the
notification centre bell, the tray summary — all with
`NoOpNotificationService`. **Reminders work end to end at this point**, visible
in-app and in the tray, with zero new dependencies. If step 8 were cancelled
tomorrow, this would still be a complete feature.

**8. OS notifications.**
`NotificationService`, `flutter_local_notifications`, the permission flow, the
fallback wiring. Verify on both macOS and Windows CI. This step touches
`pubspec.yaml` and both platform builds, which is exactly why it is last.
