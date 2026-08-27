# Delegation prompt

Copy everything below the line into the other agent.

---

You are working on **WorkPulse**, an offline-first Flutter/Riverpod/SQLite
desktop time tracker at the repo root. Read `AGENTS.md` first and follow its 10
architectural rules — rules 1, 2, 6, 8 and 10 all constrain this task directly.

## Your task

Implement the design in **`docs/TIMESHEET_CODE_DESIGN.md`**. Read it in full
before writing any code. It contains the schema, the resolution algorithm, the
model changes with exact file paths and line references, the UI changes, the
migration plan, the test plan, and a build order. Follow the build order — each
step leaves the app working.

## The problem in one paragraph

A timesheet code belongs to a *(project, release)* pair, not to a project. The
product L-Waste runs three releases in parallel and each has its own code, but
`projects.timesheet_code` is a single column, so the Time Sheet screen reports
one code for all three. The release is already captured as a custom attribute on
the work item. You are adding the mapping from that attribute's value to the
code, owned by the project, and making the Time Sheet report by code.

## Decisions already made — do not relitigate these

1. **One discriminator attribute per project.** A project declares which
   attribute selects its code (`projects.code_attribute_definition_id`, an id).
   Not a global setting, not a precedence chain of several attributes.
2. **Fall back to the project's default code** when a task has no value for the
   discriminator. `projects.timesheet_code` stays and becomes that default.
   Never drop hours, never invent a code.
3. **"By timesheet code" becomes the headline table** on the Time Sheet, above
   the existing by-project table, which stays as a secondary breakdown.
4. **Single-select discriminators only.** A multi-select value has no single
   correct code and hours must never be split across codes.

## Three things that will bite you if you skip them

- **Key everything on `attribute_options.id`, never on the option's label.**
  `SessionExportRecord.attributeValues` currently carries *formatted display
  strings* (`export_service.dart:466–500`), so a mapping built on it breaks
  silently when the user renames a release. Adding `attributeOptionIds` to that
  record is step 1 of the build order for exactly this reason.
- **Load options with `includeArchived: true`.** A finished release is archived
  but last quarter's hours still need its code. Miss this and the bug surfaces a
  quarter later.
- **No `release` anywhere in `lib/domain/` or the schema.** AGENTS.md rules 1
  and 2. A project points at an attribute definition by id; that it is called
  "Release" is the user's data. The same design must work for a project that
  codes by Component instead.

## Verify before you push

There is a Flutter SDK available to you — use it. CI runs all three and fails on
any of them:

```
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The lints in `analysis_options.yaml` are stricter than default: `strict-casts`,
`strict-inference`, `strict-raw-types`, plus `prefer_single_quotes`,
`prefer_final_locals`, `prefer_const_constructors`,
`always_declare_return_types`.

## Scope discipline

Build what section 3–7 of the design specifies. Section 8 lists explicit
non-goals — date-effective codes in particular. If you find something else wrong
along the way, note it in your summary rather than fixing it in this change.

Work on a branch off `develop`. Do not open a pull request unless asked.
