# WorkPulse

> **Understand your work. Improve your flow.**

WorkPulse is a privacy-first, offline-first macOS time-tracking and work-awareness application built with **Flutter**, **Riverpod**, and **SQLite**.

---

## Key Features

- ⚡ **Instant Quick Capture (<300ms)**: Global hotkey (`⌥ + Space`) opens a floating command palette to search, switch, or create work items with full keyboard navigation.
- 🔒 **Zero Telemetry & 100% Offline**: All data stays on your Mac in a local SQLite database. Zero network calls, zero screen recording, zero surveillance.
- ⏱️ **Timestamp-Based Truth**: Accurate wall-clock tracking that seamlessly survives reboots, app restarts, and Mac sleep/wake cycles.
- 🏷️ **Configurable Attributes**: Zero hardcoded external tool schemas. Configure custom attributes (Text, Number, Boolean, Single/Multi-Select, Date) tailored to your workflow.
- 💤 **Smart Inactivity Detection**: Detects idle periods and gives you full control to keep time, mark as idle, or stop the session.
- 📊 **Local Analytics & Export**: Group time by Project, Category, WorkItem, Person, Tag, or Custom Attribute; export to CSV and JSON anytime.

---

## 10 Critical Architectural Invariants

1. **Jira Must Not Appear Anywhere in Core Domain Model**: All external tool metadata is user-configured.
2. **Organisation Metadata Is Configurable**: Powered by `AttributeDefinition`, `AttributeOption`, and typed values.
3. **Quick Capture Response Under 300ms**: High-performance keyboard-first interface.
4. **One and Only One Active Session**: Switching tasks cleanly commits the active session before opening the next.
5. **Timestamp-Based Session Truth**: Durations derived from `endTime - startTime`, never in-memory counters.
6. **Historical Data Never Silently Destroyed**: Deletions use soft-archiving (`archived_at`).
7. **Stopping a Session Does Not Complete the Task**: Session lifecycle is distinct from WorkItem lifecycle.
8. **Offline-First & Zero Network (V1)**: Pure local SQLite persistence (`sqflite_common_ffi`).
9. **Platform-Specific Code Is Isolated**: Native macOS plugins are isolated behind testable service interfaces.
10. **Migration-Based Database with Stable UUIDs**: Versioned migrations via `PRAGMA user_version`.

---

## Quick Start

### Prerequisites
- macOS (Apple Silicon or Intel)
- Flutter SDK `>= 3.16.0` & Dart `>= 3.2.0`

### Setup & Run
```bash
# Clone the repository
git clone https://github.com/kishorekumarhemraj/WorkPulse.git
cd WorkPulse

# Install packages
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run macOS app
flutter run -d macos
```

### Running Tests
```bash
flutter test
```

---

## Project Documentation

- 📖 [Product & Technical Specification](file:///Users/kkh/Code/WorkPulse/docs/WORKPULSE_SPEC.md) (`docs/WORKPULSE_SPEC.md`)
- 🏗️ [Architecture & Technical Design](file:///Users/kkh/Code/WorkPulse/docs/DESIGN.md) (`docs/DESIGN.md`)
- 🛠️ [Developer Guide](file:///Users/kkh/Code/WorkPulse/docs/DEVELOPMENT.md) (`docs/DEVELOPMENT.md`)
- 🤖 [Agent Guidelines](file:///Users/kkh/Code/WorkPulse/AGENTS.md) (`AGENTS.md`)
- 📋 [Sprint Implementation Guide](file:///Users/kkh/Code/WorkPulse/.agents/skills/workpulse-sprint-guide/SKILL.md) (`.agents/skills/workpulse-sprint-guide/SKILL.md`)
- 🧭 [Domain & State Machine Reference](file:///Users/kkh/Code/WorkPulse/.agents/skills/workpulse-domain/SKILL.md) (`.agents/skills/workpulse-domain/SKILL.md`)

---

## License

This project is licensed under the MIT License - see the [LICENSE](file:///Users/kkh/Code/WorkPulse/LICENSE) file for details.
