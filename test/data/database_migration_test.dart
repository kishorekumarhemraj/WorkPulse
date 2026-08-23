import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite Database & Migration Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('All 11 SQLite tables are created with proper schema', () async {
      final db = dbService.database;

      final tables = [
        Tables.projects,
        Tables.categories,
        Tables.tags,
        Tables.people,
        Tables.tasks,
        Tables.taskTags,
        Tables.taskPeople,
        Tables.sessions,
        Tables.sessionPeople,
        Tables.idlePeriods,
        Tables.settings,
      ];

      for (final table in tables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
          [table],
        );
        expect(result.isNotEmpty, isTrue, reason: 'Table $table must exist');
      }
    });

    test('Foreign key constraints are enforced', () async {
      final db = dbService.database;

      // Inserting a task with non-existent project_id should fail because foreign_keys = ON
      expect(
        () async => await db.insert(Tables.tasks, {
          'id': 'task-invalid',
          'name': 'Invalid FK Task',
          'project_id': 'non-existent-proj',
          'category_id': 'non-existent-cat',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
