# Delegation prompt

Copy everything below the line into the other agent.

---

You are working on **WorkPulse**, an offline-first Flutter/Riverpod/SQLite
desktop time tracker at the repo root. Read `AGENTS.md` first and follow its 10
architectural rules — rules 1, 2, 3, 5, 6, 7, 8, 9 and 10 all constrain this
task directly.

## Your task

Implement the design in **`docs/WORK_ITEM_PLANNING_DESIGN.md`**. Read it in full
before writing any code. It contains the schema, the model, the status
derivation table, the reminder rules, the delivery design with exact file paths
and line references, the migration plan, the test plan, and a build order.
Follow the build order — each of its eight steps leaves the app compiling,
tested and shippable.

## The problem in one paragraph

A `WorkItem` carries four timestamps and every one of them records something
that already happened, so there is nowhere to write down an intention. The user
keeps their commitments in another tool and the app that is open all day, and
knows exactly what they are working on, is the one tool that cannot remind them
that the thing they promised for Thursday is due Thursday. You are adding a
planned start date, a due date and a completion instant to a work item, a
derived status, a screen that answers "what should I do today", and a reminder
engine that speaks on the planned start day, ahead of the deadline, on the
deadline, and then **every working day until an overdue item is done or
rescheduled**.

## Decisions already made — do not relitigate these

1. **No `status` column.** A work item does not get `TODO / IN_PROGRESS / DONE`.
   Status is *derived* from three dates and today's date, on every read, by a
   pure function. A stored status is wrong at midnight and there is no job that
   can fix it while the app is closed. This is the same reasoning as rule 5.
2. **Planned start and due are calendar dates; completion is an instant.**
   Dates are stored as `'YYYY-MM-DD'` TEXT via the new `CalendarDate` type, never
   as a `DateTime` and never through `toStorageString()`.
3. **Reminders never backfill.** The scheduler only ever evaluates occurrences
   dated *today*. An app closed for a week opens with one "4 work items overdue"
   notification, not thirty. This is correct, not a compromise — the daily
   `overdue` rule already covers everything a missed day would have said.
4. **The ledger is per item; the interruption is per pass.** Seven items due
   today write seven ledger rows and raise **one** notification.
5. **Completion and the timer never touch each other.** Marking complete does
   not stop a running session; starting a session on a completed item does not
   clear `completedAt`. Clearing it would destroy the delivery record (rule 6)
   silently from inside Quick Capture, where a confirmation dialog is forbidden
   (rule 3). Reopening is always explicit.
6. **`flutter_local_notifications` is the recommended dependency**, added in the
   final build step, behind a `NotificationService` bridge with a tray fallback.
   Confirm the current major on pub.dev before adding it, and check the Windows
   companion package against the CI Windows build.
7. **The Planner tab goes immediately before `tasks`** in `ShellNavTab`, which
   renumbers the shortcut digits after it. That is intended — sidebar order is
   meaningful and documented in that file's own comment. Update
   `test/unit/shell_nav_tab_test.dart`; do not dodge it by appending the tab at
   the end.

## Four things that will bite you if you skip them

- **Do not store a calendar date as a `DateTime`.**
  `lib/data/repositories/sqlite_attribute_repository.dart:396` already makes
  this mistake with `date_value`: `toStorageString()` converts to UTC, so a user
  east of Greenwich who picks 3 September gets 2 September on disk. The
  `CalendarDate` type in §3.2 exists specifically so the compiler stops you.
  Fixing the existing `date_value` columns is **out of scope** — do not widen
  the change.
- **Do not use `WorkItemRepository.update` for a completion checkbox.** It
  deletes and re-inserts `work_item_tags` and `work_item_people` on every call
  (`sqlite_work_item_repository.dart:220–245`). Use the new `updatePlan`, and
  keep the test that proves the join tables are untouched.
- **Make "at most once" a database invariant, not a scheduler promise.** The
  `UNIQUE (work_item_id, rule, occurrence_key)` constraint is what stops a
  double-fire — insert and swallow the violation. An in-memory flag will not
  survive: the shell is torn down and rebuilt every time Quick Capture opens,
  which is why `IdleNotifier` needs the guards it has.
- **`ReminderService` must be pure.** Work items in, plus `now`, plus settings,
  plus the delivered-key set — occurrences out. No repository, no
  `DateTime.now()` inside it, mirroring `WorkPatternService`. Every interesting
  case in this feature is a clock case, and you cannot test any of them against
  a service that reads its own clock.

## Definition of done

- All eight build-order steps complete, or a clean stop at the end of any one of
  them with the app compiling and green.
- `flutter analyze` clean; `flutter test` green, including every new and extended
  file listed in §12 of the design.
- The reminder tests cover, explicitly: a due date set to today at 16:00 fires on
  the next pass; an app closed for three days produces one overdue occurrence;
  a second pass in the same minute raises nothing.
- No new field, constant or comment anywhere in `lib/domain/` or the schema
  names an external tool or an organisation-specific workflow (rules 1 and 2).
- No outbound network call anywhere in the change (rule 8).
- `docs/WORKPULSE_SPEC.md` Phase 8 "Notifications" is now partly real; note what
  remains (reminders while the app is closed) rather than marking it done.
