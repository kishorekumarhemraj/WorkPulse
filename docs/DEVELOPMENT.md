# WorkPulse — Developer Guide

**Document:** `docs/DEVELOPMENT.md`  
**Platforms:** macOS 12+ (Apple Silicon & Intel), Windows 10 1809+ (x64)  
**SDK Requirements:** Flutter >= 3.38.4, Dart >= 3.12.0 (see `pubspec.lock`)  

---

## 1. Getting Started

### Prerequisites
- Flutter SDK and Dart at the versions above
- **macOS**: Apple Silicon (arm64) or Intel (x86_64), with Xcode & Command Line Tools
- **Windows**: Visual Studio 2022 with the "Desktop development with C++" workload

Both platforms are first-class: CI compiles and tests each one on every pull
request (`.github/workflows/ci.yml`). Linux is not a supported target — the app
runs there for development, but idle detection is unavailable and packaging is
not configured.

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/kishorekumarhemraj/WorkPulse.git
cd WorkPulse

# Install dependencies
flutter pub get
```

WorkPulse uses no code generation — providers are written by hand with
`NotifierProvider`/`FutureProvider`, and models are plain Dart. There is no
`build_runner` step.

---

## 2. Running the Application

### Running the app
```bash
flutter run -d macos     # macOS
flutter run -d windows   # Windows
```

### Hotkey Access & Focus Isolation
- Press `⌥ + Space` on macOS or `Alt + Space` on Windows from any screen or application to open the Quick Capture floating HUD. The shortcut is re-bindable from the sidebar footer, and every hint in the UI is spelled for the host platform (see `lib/core/keyboard/shortcut_labels.dart`).
- Quick Capture opens as a standalone floating panel over your current active application without bringing the full WorkPulse dashboard into focus.
- Press `Enter` to start/switch tasks, or press `Esc` / click outside to close Quick Capture and return focus seamlessly to your previous application.

### Menu Bar / System Tray & Top Header
- When an active timer is running, the macOS status bar displays the live ticker and active task title: `⏱ 00:14:22  Task Name`. Windows has no equivalent to a titled tray item, so the same information is carried by the tray tooltip and context menu.
- Inside the WorkPulse app, the top header bar prominently displays the active timer, project indicator, and quick `Switch` / `Stop` buttons.

---

## 3. Running Automated Tests

WorkPulse maintains a comprehensive test suite across database, domain, provider, and widget layers.

```bash
# What CI runs, in order
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

# Focused runs
flutter test test/data/database_migration_test.dart        # schema & migrations v1 -> v4
flutter test test/data/sqlite_repositories_test.dart       # repository CRUD
flutter test test/unit/services/                           # domain services
flutter test test/unit/providers/                          # Riverpod notifiers
flutter test test/widget/                                  # widget & UI
flutter test test/widget/keyboard_navigation_test.dart     # focus & search shortcut
flutter test test/integration/                             # end-to-end task switching
```

`dart format` is enforced by CI, so run it before pushing.

---

## 4. Development Invariants & Guidelines

1. **Zero External Tool Hardcoding**:
   - Never introduce `jiraId`, `azureId`, or external tool columns into core models or database tables.
   - Use configurable attributes via `AttributeDefinition` and `WorkItemAttributeValue`.

2. **Domain Layer Independence**:
   - Files in `lib/domain/` must never import Flutter packages (`package:flutter/material.dart`) or SQLite drivers (`sqflite_common_ffi`).
   - Use `Equatable` and immutable `final` fields on all models.

3. **Platform Mocking in Tests**:
   - In unit and widget tests, always provide fake platform services (`NoOpHotKeyService`, `NoOpTrayService`, `NoOpWindowService`) to prevent desktop plugin crashes in headless environments.
   - Idle detection takes a `SystemIdleSource`; tests inject `FakeIdleSource` rather than depending on the host machine's real input state.

4. **Keyboard Navigation is a Requirement, Not a Polish Item**:
   - Every mouse-driven workflow needs a keyboard equivalent, and every focusable control must show where focus is. `AppCard`, `SidebarNavItem` and `AppSelect` draw the palette's `focusRing`; everything else inherits `ThemeData.focusColor`.
   - Never write a shortcut hint with a literal `⌘` or `⌥`. Use `ShortcutLabels`, which resolves per platform, and bind both the `meta:` and `control:` activator.
   - A screen with a search field gets it for free: `SearchField` registers with the enclosing `SearchFocusScope`, which is what `⌘F` / `Ctrl+F` focuses.

5. **Platform-Specific Code Stays Behind an Interface**:
   - Native calls live in `lib/core/platform/` behind an abstract service, with a no-op or "cannot answer" fallback for platforms that lack the capability. Degrade loudly (a `debugPrint`), never silently.

6. **Timestamp-Based Session Truth**:
   - Always calculate elapsed durations from wall-clock timestamps (`endTime - startTime`).
   - Store all database timestamps as ISO-8601 UTC strings.

---

## 5. Project Structure Reference

```text
lib/
├── core/                  # Foundation: database, theme, widgets, platform bridges
│   ├── keyboard/          # SearchFocusScope registry, platform shortcut labels
│   ├── platform/          # WindowService, TrayService, HotKeyService,
│   │                      #   IdleDetectorService, SystemIdleSource (dart:ffi)
│   ├── theme/             # WorkPulseColors extension, design tokens, typography
│   └── widgets/           # AppCard, AppDialog, AppSelect, AppSnackBar, SearchField
├── domain/                # Pure models, repository interfaces, services
│   ├── models/            # WorkItem, Session, Project, Category, Tag, Person, Attribute, IdlePeriod
│   ├── repositories/      # Abstract repository interfaces
│   └── services/          # Pure business logic services (TimerService, TaskSwitchService, IdleService)
├── data/                  # SQLite schema, migrations, concrete repositories
│   ├── database/          # Tables definition
│   ├── migrations/        # Versioned migrations (MigrationV1, MigrationV2)
│   ├── providers/         # Riverpod repository providers
│   └── repositories/      # SqliteWorkItemRepository, SqliteSessionRepository, etc.
└── features/              # Feature UI, Notifiers, and dialogs
    ├── attributes/        # Configurable attributes & options editor
    ├── categories/        # Category management
    ├── dashboard/         # Today/Week/Custom range analytics
    ├── idle/              # Inactivity detection & prompt dialog
    ├── people/            # People management
    ├── projects/          # Project management
    ├── quick_capture/     # Standalone floating HUD & dialog UI
    ├── reports/           # Analytics, grouping & CSV/JSON export
    ├── shell/             # Main desktop shell window & navigation
    ├── tags/              # Tag management
    ├── tasks/             # Work item management views
    └── timer/             # Active timer bar & task switcher dialog

macos/                     # macOS runner, entitlements, app icons
windows/                   # Windows runner (CMake, Win32 host, resources)
docs/adr/                  # Architecture Decision Records
```
