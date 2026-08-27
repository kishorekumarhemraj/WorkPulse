# Timesheet Code Resolution — Design & Delegation Brief

Status: design only, not implemented.
Target branch: a fresh branch off `develop`.
Database version at time of writing: **7** (`AppConstants.dbVersion`). This work
introduces **v8**.

---

## 1. The problem

A timesheet code is not a property of a project. It is a property of
**(project, release)**.

The product *L-Waste* has three releases running in parallel. Each release has
its own code. Today `projects.timesheet_code` is a single `TEXT` column, so
every L-Waste hour reports the same code no matter which release it belonged
to. The Time Sheet screen is therefore giving a confidently wrong answer.

The release is already recorded — it is a custom attribute on the work item.
The missing piece is a mapping from *the release value* to *the code*, owned by
the project.

### What the attributes are for (and what they are not for)

| Attribute | Scope | Role in this design |
|---|---|---|
| **Release** | task | *Candidate discriminator.* Selects which of a project's codes applies. |
| **Component** | task | Reporting breakdown only. Never affects the code. |
| **Jira** | task | Reporting breakdown only. Never affects the code. |
| **RITM** | session | Reporting breakdown only. Never affects the code. |

Only **one** attribute per project drives the code. The rest stay exactly as
they are — they already produce their own tables on the Time Sheet and their own
CSV columns.

### What must not be built

AGENTS.md rules 1 and 2 forbid naming an organisation-specific concept in the
domain model. There must be **no `release` field, no `Release` constant, no
`isReleaseAttribute` check** anywhere in `lib/domain/` or the schema. A project
points at *an attribute definition, by id*. That it happens to be called
"Release" is the user's data, not the app's model.

---

## 2. Review of the current implementation

Findings are ordered by how much they matter. File references are against
`develop` at the time of writing.

### F1 — Code is 1:1 with project (the headline defect)

`lib/domain/models/project_model.dart:18` — `final String? timesheetCode;`
`lib/data/migrations/migration_v6.dart` — `ALTER TABLE projects ADD COLUMN timesheet_code TEXT`

One scalar per project. Three parallel releases cannot be represented.

### F2 — Task rows borrow the project's code

`lib/domain/services/timesheet_service.dart:66–89` — both the project row and
the task row are built with `code: record.project?.timesheetCode`. Once codes
vary within a project, a task row's code must come from *resolution*, not from
the project record. The task row is exactly where a wrong code will be noticed,
so this is the line that must change.

### F3 — Attribute values reach the Time Sheet as display labels, not ids

**This is the most important structural finding, and it blocks everything else.**

`lib/domain/services/export_service.dart:27–62` —
`final Map<String, String> attributeValues; // definitionId -> formatted string`

`lib/domain/services/export_service.dart:466–500` — `_formatAttributeValue`
returns `options[optionId]?.label` for a single-select, and for a multi-select
splits the comma-joined ids out of `text_value` and joins their **labels** with
`'; '`.

Consequences, all of which land on this feature:

- A mapping keyed on the label breaks silently the day the user renames
  `R24.3` to `Release 24.3`. Hours then book to the wrong code with no error.
- Two options that happen to share a label collide into one row.
- The multi-select value cannot be decomposed once joined.

**Any code-resolution rule must key on `attribute_options.id`.** Option ids are
already available in both storage paths (`option_id` for single-select, a
comma-joined list in `text_value` for multi-select), so this is a matter of
carrying them through, not of changing storage.

### F4 — Attribute breakdown rows are keyed by label

`lib/domain/services/timesheet_service.dart:112–114` —
`.putIfAbsent(label, () => _RowBuilder(id: label, label: label))`

Same root cause as F3. Worth fixing in the same pass: key select-typed
attributes by option id and carry the label for display.

### F5 — Archived options must still resolve

A finished release gets archived. Last quarter's hours still have to report its
code. Wherever the resolver loads options it must pass
`includeArchived: true` (`AttributeRepository.getOptions`,
`lib/domain/repositories/attribute_repository.dart:19`). Getting this wrong
produces a bug that only appears a quarter later, which is the worst kind.

### F6 — Nothing surfaces an unmapped combination

`Project.hasTimesheetCode` exists (`project_model.dart:39`) but the Time Sheet
never says "this project has no code". Once codes are per-release the number of
ways to forget a mapping goes up by the number of releases. The screen has to
report its own gaps.

### F7 — The headline table is "by Project"

`lib/features/timesheet/views/timesheet_view.dart` renders projects first. The
artefact the user actually produces is a list of *(code, hours)*. The screen
should match the form being filled in.

### F8 — `TimesheetService` is pure and must stay pure

`lib/domain/services/timesheet_service.dart:23` — "It owns no repositories and
no clock". Correct, and worth preserving. The resolver is therefore built by the
provider layer and **passed in** as a plain value object, exactly as
`definitions` already is.

### F9 — `timesheetDataProvider` must not start re-querying

`lib/features/timesheet/providers/timesheet_provider.dart:34–45` deliberately
builds on `sessionHistoryProvider` rather than issuing its own queries. Adding
the resolver means awaiting two more providers (projects, code mappings). It
must not reintroduce a session query.

### F10 — Multi-select as discriminator is ambiguous

If a task's discriminator attribute holds two options, there is no correct
single code, and splitting the hours across two codes would double-count. The
project form must offer **single-select task-scoped attributes only**.

---

## 3. The model

### 3.1 Schema (migration v8)

```sql
-- Which attribute, if any, selects this project's code.
-- NULL means "this project has one code" — today's behaviour, exactly.
ALTER TABLE projects ADD COLUMN code_attribute_definition_id TEXT;

CREATE TABLE project_timesheet_codes (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  attribute_option_id TEXT NOT NULL,
  code TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
  FOREIGN KEY (attribute_option_id) REFERENCES attribute_options(id) ON DELETE CASCADE,
  UNIQUE (project_id, attribute_option_id)
);

CREATE INDEX idx_project_timesheet_codes_project
  ON project_timesheet_codes(project_id);
```

`projects.timesheet_code` **stays** and becomes the project's *default* code —
what applies when the discriminator has no value. Do not drop it, do not rename
the column.

Note on `ON DELETE CASCADE` for `attribute_option_id`: archiving an option does
not delete the row, so archived releases keep their mapping (see F5). The
cascade only fires on a genuine `deleteOption`, where keeping an orphan mapping
would be worse.

### 3.2 Dart models

New — `lib/domain/models/project_timesheet_code.dart`:

```dart
class ProjectTimesheetCode extends Equatable {
  final String id;
  final String projectId;
  final String attributeOptionId;
  final String code;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Changed — `lib/domain/models/project_model.dart`:

```dart
/// The attribute whose value selects which of this project's codes applies.
///
/// Null means the project books everything to [timesheetCode]. Held as an id
/// rather than a name because the concept it represents — a release train, a
/// workstream — is the user's, not the app's (AGENTS.md rules 1 and 2).
final String? codeAttributeDefinitionId;
```

Changed — `lib/domain/services/export_service.dart`, on `SessionExportRecord`:

```dart
/// Option ids behind [attributeValues], for select-typed definitions.
///
/// Ids, not labels: a code mapping keyed on a label books hours to the wrong
/// code the moment the user renames an option, and says nothing when it does.
/// A single-select yields one id; a multi-select yields the ids it holds.
final Map<String, List<String>> attributeOptionIds;
```

Populate it in `getExportRecords` alongside `attrMap` (around
`export_service.dart:166–210`), from `optionId` for single-selects and from the
comma-split of `textValue` for multi-selects. Do not change how values are
stored.

---

## 4. Resolution

New — `lib/domain/services/timesheet_code_resolver.dart`. Pure. No
repositories, no clock, no Flutter import.

```dart
enum TimesheetCodeSource {
  /// Matched a (project, option) mapping. The normal, correct case.
  optionMapping,

  /// The project varies its code but this task has no value for the
  /// discriminator, so the project's default applies.
  projectDefault,

  /// The task named an option the project has no mapping for. The default
  /// still applies, but this is a configuration gap and is reported as one.
  unmappedOption,

  /// Nothing to book against: no mapping and no default.
  missingCode,

  /// The record has no project at all.
  unknownProject,
}

class TimesheetCodeResolution extends Equatable {
  final String? code;
  final TimesheetCodeSource source;
  final String? optionId;
  final String? optionLabel;

  bool get isBookable => code != null && code!.trim().isNotEmpty;

  /// Whether this resolution is something the user should go and fix.
  bool get needsAttention =>
      source == TimesheetCodeSource.unmappedOption ||
      source == TimesheetCodeSource.missingCode ||
      source == TimesheetCodeSource.unknownProject;
}

class TimesheetCodeResolver {
  /// projectId -> (attributeOptionId -> code)
  final Map<String, Map<String, String>> _codesByProject;

  /// optionId -> option, including archived ones (see F5).
  final Map<String, AttributeOption> _optionsById;

  const TimesheetCodeResolver({ ... });

  TimesheetCodeResolution resolveFor({
    required Project? project,
    required Map<String, List<String>> attributeOptionIds,
  });
}
```

### Algorithm

```
1. project == null                      -> unknownProject, code = null
2. discriminator = project.codeAttributeDefinitionId
   discriminator == null                -> default code
                                           (projectDefault, or missingCode if blank)
3. ids = attributeOptionIds[discriminator] ?? []
   ids.length != 1                      -> ids.isEmpty
                                             ? default code (projectDefault)
                                             : default code (unmappedOption)
4. code = _codesByProject[project.id]?[ids.single]
   code != null && code.isNotBlank      -> optionMapping
   otherwise                            -> default code (unmappedOption)
5. If the code selected in 2 or 4 is null or blank -> missingCode
```

Step 3's `length != 1` branch is why a multi-select discriminator is flagged
rather than guessed at (F10). Never split hours across codes.

### Why keyed on option id

Renaming an option changes `attribute_options.label`, not `.id`. Resolution is
therefore stable across renames, and a mapping survives the user tidying up
release names mid-quarter. This is the whole reason F3 has to be fixed first.

---

## 5. Reporting

### 5.1 New rows on `TimesheetData`

`lib/domain/models/timesheet_model.dart`:

```dart
/// One line of the sheet the user actually fills in.
class TimesheetCodeRow extends Equatable {
  /// The code, or '' for the row holding time that could not be coded.
  final String code;
  final String label;              // code, or 'No timesheet code'
  final ClassificationSplit net;
  final ClassificationSplit gross;
  final int sessionCount;

  /// Where this row's hours came from — a code can be fed by more than one
  /// project, and by more than one release within a project.
  final List<TimesheetCodeContribution> contributions;

  bool get needsAttention =>
      contributions.any((c) => c.source.needsAttention);
}

class TimesheetCodeContribution extends Equatable {
  final String projectId;
  final String projectName;
  final String? optionLabel;       // the release, where there is one
  final TimesheetCodeSource source;
  final ClassificationSplit net;
  final ClassificationSplit gross;
}
```

Add `final List<TimesheetCodeRow> codeRows;` to `TimesheetData` and build it in
`TimesheetService.build`, whose signature gains:

```dart
required TimesheetCodeResolver codes,
```

Ranking follows the existing convention in `timesheet_service.dart:150–165`:
longest first by **gross** so the Net/Gross toggle does not reshuffle rows, ties
broken by label, and the uncodeable row pinned last the way
`timesheetUnspecifiedLabel` already is.

**Invariant to assert in tests:** the sum of `codeRows` equals `total` on both
bases. A sheet whose rows do not add up to its total is worse than a coarse one
— this is already the stated principle for multi-select rows
(`timesheet_service.dart:103–107`) and it holds here too.

### 5.2 Screen changes — `lib/features/timesheet/`

1. **New headline table, "By timesheet code"**, above the existing by-project
   table. Columns: `Code | Project · Release | CapEx | OpEx | Unclassified |
   Total | split bar`. Reuse `timesheet_table.dart`'s `_HeaderRow` / `_DataRow`
   / `_TotalRow` / `SplitBar` rather than writing a second table.
2. **By-project stays**, demoted to a secondary breakdown. It still answers
   "how much on L-Waste altogether" when several codes roll up to one product.
3. **An attention card** when anything `needsAttention`: *"4h 20m in L-Waste has
   no release and booked to the default code"*, *"Release R24.4 has no code in
   L-Waste"*, each linking to the project form. This is F6.
4. Task rows (`taskRows`) take their `code` from resolution, not from
   `record.project?.timesheetCode`. This is F2.

Use `AppCard` for every surface and `colors.surface` for panel backgrounds —
`colors.card` is the inset badge/chip tint and using it as a card background is
what previously made this screen render entirely grey.

### 5.3 Project form — `lib/features/projects/views/project_form_dialog.dart`

- Relabel the existing field **"Default timesheet code"**, with helper text
  saying it applies when the discriminator has no value.
- New select **"Code varies by"**, listing single-select task-scoped attribute
  definitions, plus a null option "Doesn't vary".
- When a discriminator is chosen, show a repeating editor: one row per
  non-archived option of that attribute, each with a code text field, pre-filled
  from `project_timesheet_codes`. Archived options that already have a mapping
  appear in a collapsed "Retired" group so history stays editable (F5).
- Changing the discriminator does **not** delete existing mappings (AGENTS.md
  rule 6). Warn that they will stop applying, and leave the rows in place.

### 5.4 Export — `lib/domain/services/export_service.dart`

The CSV already has a `Timesheet Code` column (`export_service.dart:259`); it
now carries the resolved code. Add `Timesheet Code Source` next to it, mirroring
the existing `Classification Source` column, so an exported sheet can be audited
without opening the app.

---

## 6. Migration

New — `lib/data/migrations/migration_v8.dart`, following the guarded,
re-runnable style of `migration_v5.dart` and `migration_v6.dart`:

- `PRAGMA table_info(projects)` before adding `code_attribute_definition_id`.
- `CREATE TABLE IF NOT EXISTS project_timesheet_codes`.
- `CREATE INDEX IF NOT EXISTS ...`.

Wire it up:

- `AppConstants.dbVersion`: `7` -> `8`.
- `DatabaseService._onCreate`: run v1..v8.
- `DatabaseService._onUpgrade`: `if (oldVersion < 8) await MigrationV8.execute(db);`

**No backfill, and this is deliberate.** A null `code_attribute_definition_id`
means "one code, in `timesheet_code`", which is precisely how every existing
project behaves today. Every existing project therefore keeps reporting exactly
what it reports now until the user opens it and maps its releases. There is no
guessed data and no window where the sheet is wrong in a new way.

---

## 7. Tests

`test/unit/services/timesheet_code_resolver_test.dart` (new):

- each `TimesheetCodeSource`, one test apiece;
- an **archived** option still resolves to its code;
- **renaming** an option does not change resolution — the point of keying on id;
- a discriminator holding two option ids yields `unmappedOption`, not a guess;
- a project with no discriminator and no default yields `missingCode`, not `''`.

`test/unit/services/timesheet_service_test.dart` (extend):

- two releases of one project produce two code rows;
- two projects sharing one code roll into a single row with two contributions;
- **`codeRows` sum to `total`, on both net and gross**;
- the uncodeable row sorts last regardless of size.

`test/data/database_migration_test.dart` (extend):

- v7 -> v8 adds the column and the table;
- running v8 twice is a no-op;
- a project with a `timesheet_code` and no discriminator resolves to that code
  after upgrading — the "nothing changed for existing data" guarantee.

`test/widget/` — project form shows the per-option editor only once a
discriminator is chosen; the Time Sheet renders the attention card when a
mapping is missing.

---

## 8. Out of scope

State these as non-goals; do not build them.

- **Date-effective codes.** A code changing mid-quarter for the same release.
- Per-person or per-category codes.
- Editing mappings from the Time Sheet screen (project form only).
- Pushing anything to the employer's timesheet system. V1 is offline, zero
  network (AGENTS.md rule 8).
- Changing how attribute values are stored. F3 is about *carrying ids through*,
  not about re-modelling storage.

---

## 9. Build order

Each step leaves the app working and testable.

1. **F3 first.** Add `attributeOptionIds` to `SessionExportRecord` and populate
   it. Nothing consumes it yet. Ship and verify the CSV is unchanged.
2. Migration v8 + `ProjectTimesheetCode` model + repository methods. No UI.
3. `TimesheetCodeResolver` + its unit tests. Still nothing consumes it.
4. `TimesheetService` gains `codes:` and produces `codeRows`; extend its tests.
5. Time Sheet screen: code table, attention card, task rows resolved (F2).
6. Project form: discriminator select and the per-option code editor.
7. F4 (key attribute rows by option id) and the export column.

Steps 1–4 are pure and fully unit-testable without a UI. If time runs short,
stopping after 5 still delivers the whole point of the feature.
