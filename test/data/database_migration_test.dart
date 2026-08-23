import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';

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

    test('All 16 SQLite tables are created with proper schema', () async {
      final db = dbService.database;

      final tables = [
        Tables.workspaces,
        Tables.projects,
        Tables.categories,
        Tables.tags,
        Tables.people,
        Tables.workItems,
        Tables.workItemTags,
        Tables.workItemPeople,
        Tables.sessions,
        Tables.sessionPeople,
        Tables.idlePeriods,
        Tables.attributeDefinitions,
        Tables.attributeOptions,
        Tables.workItemAttributeValues,
        Tables.sessionAttributeValues,
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

    test('Default workspace is seeded during migration', () async {
      final db = dbService.database;
      final result = await db.query(
        Tables.workspaces,
        where: 'id = ?',
        whereArgs: [MigrationV1.defaultWorkspaceId],
      );

      expect(result.isNotEmpty, isTrue);
      expect(result.first['name'], equals('Default'));
    });

    test('Foreign key constraints are enforced on work_items', () async {
      final db = dbService.database;

      // Inserting a work item with non-existent project_id should fail because foreign_keys = ON
      expect(
        () async => await db.insert(Tables.workItems, {
          'id': 'wi-invalid',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Invalid FK WorkItem',
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
