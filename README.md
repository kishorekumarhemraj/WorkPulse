# ⏱️ WorkPulse

<p align="center">
  <strong>Understand your work. Improve your flow.</strong><br>
  <em>A privacy-first, offline-first macOS work-awareness and time-tracking application designed for engineers, creators, and focused professionals.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%20(Apple%20Silicon%20%26%20Intel)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/Flutter-Desktop%203.16+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Storage-SQLite%20(100%25%20Offline)-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/Privacy-Zero%20Telemetry-2ea44f?style=for-the-badge&logo=shield&logoColor=white" alt="Privacy First" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
</p>

---

## 💡 Why WorkPulse?

Most time trackers fall into two frustrating extremes:
1. **Creepy surveillance tools** that capture random screenshots, log keystrokes, and monitor background apps.
2. **Clunky corporate portals** with bloated forms, rigid Jira-locked fields, and slow web interfaces that interrupt your flow every time you switch tasks.

**WorkPulse changes that.**

WorkPulse is built from the ground up as a **personal productivity companion**, not a surveillance dashboard. It gives you deep, honest visibility into how your time is allocated—across projects, meetings, deep engineering, code reviews, and unplanned interruptions—with **zero tracking friction** and **absolute privacy**.

```text
    ┌─────────────────────────────────────────────────────────────┐
    │  ⌥ + Space  ──►  Instant Quick Capture (<300ms)             │
    │  Type / Search Task  ──►  Press Enter                       │
    │  Switches cleanly, tracks wall-clock time, stays out of way │
    └─────────────────────────────────────────────────────────────┘
```

---

## ✨ Features & User Value

### ⚡ Instant Quick Capture (`⌥ + Space`)
- **Sub-300ms Response Time**: A lightweight floating palette appears instantly anywhere on macOS via global hotkey (`⌥ + Space`).
- **Keyboard-First Workflow**: Fuzzy search existing tasks, select categories and tags, or type a new work item and hit `Enter`—without your hands leaving the keyboard.
- **Zero Interruption to Flow**: Context switching overhead drops to seconds, keeping your cognitive energy focused on real work.

---

### 🔒 100% Offline & Absolute Privacy
- **Zero Telemetry, Zero Surveillance**: No screen captures, no keystroke recording, no browser snooping, and zero network calls.
- **Local SQLite Engine**: All data lives solely on your machine in a robust local SQLite database (`sqflite_common_ffi`).
- **Enterprise & Client Safe**: Track work freely on confidential codebases, proprietary client accounts, and secure environments without privacy risks.

---

### ⏱️ Timestamp-Based Session Integrity
- **Wall-Clock Accuracy**: Session durations are computed mathematically from immutable start/end timestamps (`duration = endTime - startTime`), never fragile in-memory ticker loops.
- **Resilient to Sleep & Restarts**: Close your laptop lid, reboot your Mac, or recover from unexpected crashes—your active session seamlessly resumes with 100% accurate time.
- **Strict Single-Active Session Invariant**: Exactly one session is active at any time. Starting a new task cleanly closes and commits the previous session automatically.

---

### 🏷️ Dynamic Configurable Attribute Engine
- **No Hardcoded SaaS Schemas**: Jira, Azure DevOps, ServiceNow, or client billing codes are never hardcoded into the core database.
- **6 Typed Attribute Categories**: Create custom attributes typed as `Text`, `Number`, `Boolean`, `Single Select`, `Multi-Select`, or `Date`.
- **Task & Session Scopes**: Attach attributes at the WorkItem level (e.g. *Ticket Key*, *Client Code*, *Priority*) or individual Session level (e.g. *Focus Rating*, *Location*).
- **Non-Destructive Archiving**: Deleting an attribute soft-archives it (`archived_at`), ensuring your historical logs and reporting never break.

---

### 💤 Smart Inactivity & Idle Management
- **Automatic Away-State Detection**: Detects when you step away from your Mac during an active tracking session.
- **Survives Quits and Shutdowns**: If WorkPulse was closed — or the Mac was switched off — with a timer running, the next launch reconstructs exactly how long it was gone and asks before that time is counted as work.
- **User-Controlled Resolution**: When you return, choose how to handle the idle gap:
  - ✅ **Keep as Work**: Attribute the duration to offline discussions, sketching, or reading.
  - ⏸️ **Mark as Idle**: Keep the record tagged as inactive.
  - ✂️ **Discard & Stop**: Trim the idle block and record your actual active stopping point.

---

### 📊 Rich Dashboards & Deep Work Analytics
- **Visual Time Breakdowns**: Group time by **Project**, **Category**, **Tag**, **Person**, or any **Custom Attribute**.
- **Context-Switching Insights**: Identify days with excessive context fragmentation versus uninterrupted deep work blocks.
- **Collaborator Tracking**: Associate team members with work items to see how much time is spent on paired sessions, reviews, and syncs.

---

### 📤 Frictionless Data Portability & Export
- **One-Click Export**: Export your entire work history to standard **CSV** or **JSON** anytime.
- **Effortless Timesheets & Billing**: Easily transfer your tracked hours to company billing software, client invoices, or weekly standup recaps with zero vendor lock-in.

---

## 🔄 How It Works

```mermaid
graph TD
    A[Global Hotkey: ⌥ + Space] --> B[Quick Capture Dialog]
    B -->|Search / Create Task| C{Active Session Running?}
    C -->|Yes| D[Cleanly Stop & Commit Previous Session]
    C -->|No| E[Start New Session]
    D --> E
    E --> F[Background Wall-Clock Timer]
    F -->|Inactivity Detected| G[Smart Idle Resolution Prompt]
    F -->|Manual Stop / Switch| H[Commit Session to Local SQLite]
    G --> H
    H --> I[Instant Local Analytics & CSV/JSON Export]
```

---

## 🎯 Who is WorkPulse For?

| Role | How WorkPulse Adds Value |
| :--- | :--- |
| 💻 **Software Engineers & Architects** | Effortlessly track time across code reviews, architecture spikes, meetings, and feature development without leaving the keyboard or wrestling with web timesheets. |
| 🎨 **Designers & Creators** | Gain clarity on deep creative focus versus client revisions and sync meetings with zero distraction. |
| 💼 **Consultants & Freelancers** | Categorize work by client, project, and custom billing codes; export spotless CSV reports for invoicing in seconds. |
| 🚀 **Product & Engineering Leaders** | Understand personal bandwidth, spot meeting fatigue, and protect focus time without invasive corporate surveillance tools. |

---

## 🏛️ Architecture & Principles

WorkPulse is built following clean, domain-driven architecture and strict modular boundaries:

```text
lib/
├── core/         # Theme, database setup, utilities, platform bridges
├── domain/       # Pure Dart business models, state machines, repository contracts (Zero Flutter/SQLite dependencies)
├── data/         # SQLite tables, versioned migrations, repository implementations
└── features/     # Feature vertical slices (UI, Riverpod state notifiers, widgets)
```

### The 10 Invariant Architectural Rules
1. **Zero External Tool Hardcoding**: External tool fields (Jira, ServiceNow, etc.) are purely user-configurable attributes.
2. **Configurable Metadata**: Powered by `AttributeDefinition`, `AttributeOption`, and typed value models.
3. **Sub-300ms Quick Capture**: Floating, ultra-fast keyboard-first palette.
4. **Single Active Session**: Exactly one work session active at any given moment.
5. **Timestamp-Based Session Truth**: Elapsed durations calculated exclusively via `endTime - startTime`.
6. **No Silent Data Loss**: Deletions use soft-archiving (`archived_at`) to preserve historical accuracy.
7. **Session Independence**: Stopping a timer closes the session, but leaves the work item open to resume later.
8. **Offline-First & Zero Telemetry**: 100% local persistence via SQLite (`sqflite_common_ffi`).
9. **Isolated Platform Bridges**: Native macOS integrations (Hotkeys, Tray, Window management) live behind abstract interfaces.
10. **Strict Database Versioning**: All schema modifications are version-controlled with `PRAGMA user_version` migrations.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| <kbd>⌥ Option</kbd> + <kbd>Space</kbd> | Toggle Quick Capture floating dialog from anywhere |
| <kbd>Enter</kbd> | Confirm and start/switch tracking session |
| <kbd>Esc</kbd> | Dismiss Quick Capture / close active modal dialog |
| <kbd>Tab</kbd> / <kbd>Shift + Tab</kbd> | Cycle through inputs (WorkItem, Project, Category, Tags, Attributes) |
| <kbd>↑</kbd> / <kbd>↓</kbd> | Navigate search suggestions and dropdown options |

---

## 🚀 Getting Started

### Prerequisites
- **macOS**: 12.0+ (Monterey or newer), supporting both Apple Silicon (M1/M2/M3/M4) and Intel (x86_64).
- **Flutter SDK**: `>= 3.16.0`
- **Dart SDK**: `>= 3.2.0`
- **Xcode**: Command Line Tools installed (`xcode-select --install`)

### Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/kishorekumarhemraj/WorkPulse.git
   cd WorkPulse
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate code (Riverpod & Models):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Launch WorkPulse on macOS:**
   ```bash
   flutter run -d macos
   ```

---

## 🧪 Testing

WorkPulse includes a comprehensive automated test suite spanning unit tests, database migrations, repository contracts, and widget tests.

```bash
# Run the complete test suite
flutter test

# Run database schema & migration tests
flutter test test/data/database_migration_test.dart

# Run SQLite repository CRUD tests
flutter test test/data/sqlite_repositories_test.dart

# Run domain service tests (Timer, Task Switcher, Idle)
flutter test test/unit/services/timer_service_test.dart
flutter test test/unit/services/idle_service_test.dart

# Run Riverpod state notifier tests
flutter test test/unit/providers/

# Run widget and UI tests
flutter test test/widget/
```

---

## 📦 Building for Release

To package a standalone, optimized macOS application:

```bash
flutter build macos --release
```

The resulting application bundle will be located at:
`build/macos/Build/Products/Release/workpulse.app`

---

## 📚 Project Documentation

- 📖 [Product & Technical Specification](docs/WORKPULSE_SPEC.md) (`docs/WORKPULSE_SPEC.md`)
- 🏗️ [Architecture & Technical Design](docs/DESIGN.md) (`docs/DESIGN.md`)
- 🛠️ [Developer Guide](docs/DEVELOPMENT.md) (`docs/DEVELOPMENT.md`)
- 🤖 [Agent Guidelines](AGENTS.md) (`AGENTS.md`)
- 📋 [Sprint Roadmap Guide](.agents/skills/workpulse-sprint-guide/SKILL.md) (`.agents/skills/workpulse-sprint-guide/SKILL.md`)
- 🧭 [Domain Model & State Machines](.agents/skills/workpulse-domain/SKILL.md) (`.agents/skills/workpulse-domain/SKILL.md`)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
