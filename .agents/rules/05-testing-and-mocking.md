# Rule: Testing Strategy & Mocking Guidelines

WorkPulse enforces rigorous testing across domain services, SQLite repositories, Riverpod providers, and presentation widgets.

## 1. Test Layer Breakdown

```text
test/
├── data/          # SQLite schema, migrations, and repository tests
├── domain/        # Pure Dart domain logic, entities, services
├── integration/   # Multi-service user workflow integration tests
├── mocks/         # Reusable mocks & fakes for platform channels and services
├── unit/          # StateNotifier/Provider unit tests and domain tests
└── widget/        # Flutter UI component and dialog widget tests
```

## 2. In-Memory SQLite Testing

- Always use `sqflite_common_ffi` with `inMemoryDatabasePath` for database and repository tests.
- Each test suite should initialize a fresh in-memory database using `DatabaseService` or `MigrationV1.execute(db)` to guarantee test isolation.
- Always verify that `PRAGMA foreign_keys = ON;` is enforced in test databases.

```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
});

setUp(() async {
  db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await db.execute('PRAGMA foreign_keys = ON;');
  await MigrationV1.execute(db);
});
```

## 3. Deterministic Time & Fixtures

- Never use raw `DateTime.now()` in assertions where elapsed time is measured.
- Inject a fixed reference time or time provider when testing session durations, timer calculations, and idle periods.
- Store test fixtures with explicit UTC timestamps (`2026-08-23T10:00:00.000Z`).

## 4. Mocking Native macOS Platform Plugins

- Native desktop plugins (`hotkey_manager`, `tray_manager`, `window_manager`, `screen_retriever`) will fail in headless CI or CLI test environments.
- In unit and widget tests:
  - Inject fake/mock platform service interfaces (e.g. `MockHotKeyService`, `FakeTrayService`) via Riverpod overrides.
  - Never allow tests to trigger real platform method channels.
  - Use `mocktail` for creating readable, type-safe mocks.

## 5. Widget Test Best Practices

- Wrap test widgets with `ProviderScope` containing appropriate repository or service overrides.
- Use `tester.pumpAndSettle()` when awaiting state transitions or animations.
- For keyboard interactions, simulate key events using `tester.sendKeyEvent(LogicalKeyboardKey.escape)` or `LogicalKeyboardKey.enter`.
