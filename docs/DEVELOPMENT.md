# WorkPulse — Developer Guide

**Document:** `docs/DEVELOPMENT.md`  
**Platform:** macOS 12+ (Apple Silicon & Intel)  
**SDK Requirements:** Flutter >= 3.16.0, Dart >= 3.2.0  

---

## 1. Getting Started

### Prerequisites
- macOS running on Apple Silicon (arm64) or Intel (x86_64)
- Flutter SDK (3.16+) and Dart (3.2+) installed
- Xcode & Command Line Tools installed

### Initial Setup
```bash
# Clone the repository
git clone https://github.com/kishorekumarhemraj/WorkPulse.git
cd WorkPulse

# Install dependencies
flutter pub get

# Run code generator (for Riverpod and models)
dart run build_runner build --delete-conflicting-outputs
```

---

## 2. Running the Application

### Running on macOS Desktop
```bash
flutter run -d macos
```

### Hotkey Access & Focus Isolation
- Press `⌥ + Space` (Option + Space) from any screen or application to open the Quick Capture floating HUD.
- Quick Capture opens as a standalone floating panel over your current active application without bringing the full WorkPulse dashboard into focus.
- Press `Enter` to start/switch tasks, or press `Esc` / click outside to close Quick Capture and return focus seamlessly to your previous application.

### Menu Bar & Top Header
- When an active timer is running, the macOS status bar (top menu bar) displays the live ticker and active task title: `⏱ 00:14:22  Task Name`.
- Inside the WorkPulse app, the top header bar prominently displays the active timer, project indicator, and quick `Switch` / `Stop` buttons.

---

## 3. Running Automated Tests

WorkPulse maintains a comprehensive test suite across database, domain, provider, and widget layers.

```bash
# Run the entire test suite
flutter test

# Run database schema & migration tests (V1 and V2)
flutter test test/data/database_migration_test.dart

# Run SQLite repository CRUD tests
flutter test test/data/sqlite_repositories_test.dart

# Run domain service tests (Timer, Task Switcher, Idle)
flutter test test/unit/services/timer_service_test.dart
flutter test test/unit/services/idle_service_test.dart
flutter test test/unit/services/window_service_test.dart

# Run provider & state notifier unit tests
flutter test test/unit/providers/

# Run widget and UI tests
flutter test test/widget/
```

---

## 4. Code Generation & Riverpod Watcher

When modifying `@riverpod` annotations or Riverpod models, keep the build runner active in watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## 5. Development Invariants & Guidelines

1. **Zero External Tool Hardcoding**:
   - Never introduce `jiraId`, `azureId`, or external tool columns into core models or database tables.
   - Use configurable attributes via `AttributeDefinition` and `WorkItemAttributeValue`.

2. **Domain Layer Independence**:
   - Files in `lib/domain/` must never import Flutter packages (`package:flutter/material.dart`) or SQLite drivers (`sqflite_common_ffi`).
   - Use `Equatable` and immutable `final` fields on all models.

3. **Platform Mocking in Tests**:
   - In unit and widget tests, always provide mock platform services (`MockHotKeyService`, `MockTrayService`, `NoOpWindowService`) to prevent desktop plugin crashes in headless environments.

4. **Timestamp-Based Session Truth**:
   - Always calculate elapsed durations from wall-clock timestamps (`endTime - startTime`).
   - Store all database timestamps as ISO-8601 UTC strings.

---

## 6. Project Structure Reference

```text
lib/
├── core/                  # Database manager, theme, exceptions, platform bridges (WindowService, TrayService, HotKeyService)
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
```
