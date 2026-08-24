import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/migrations/migration_v2.dart';
import 'package:workpulse/data/migrations/migration_v3.dart';
import 'package:workpulse/data/migrations/migration_v4.dart';

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

    test('All 17 SQLite tables are created with proper schema', () async {
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
        Tables.sessionTags,
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

    test(
        'sessions table has a notes and category_id column on a fresh database',
        () async {
      final db = dbService.database;
      final columns =
          await db.rawQuery('PRAGMA table_info(${Tables.sessions});');
      final columnNames = columns.map((c) => c['name'] as String).toSet();
      expect(columnNames, contains('notes'));
      expect(columnNames, contains('category_id'));
    });

    test('people table has a team column on a fresh database', () async {
      final db = dbService.database;
      final columns = await db.rawQuery('PRAGMA table_info(${Tables.people});');
      final columnNames = columns.map((c) => c['name'] as String).toSet();
      expect(columnNames, contains('team'));
    });
  });

  group('Migration v1 -> v2 upgrade path', () {
    test('adds sessions.notes and preserves existing rows on a real upgrade',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('workpulse_migration_test');
      final dbPath = p.join(tempDir.path, 'upgrade_test.db');

      try {
        // 1. Create a v1-only database, as if from a pre-2.0 shipped install.
        final v1Db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
            onCreate: (db, version) => MigrationV1.execute(db),
          ),
        );
        final now = DateTime.now().toUtc().toIso8601String();
        await v1Db.insert(Tables.projects, {
          'id': 'proj-pre-upgrade',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Pre-upgrade Project',
          'created_at': now,
          'updated_at': now,
        });
        await v1Db.insert(Tables.categories, {
          'id': 'cat-pre-upgrade',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Pre-upgrade Category',
          'created_at': now,
          'updated_at': now,
        });
        await v1Db.insert(Tables.tags, {
          'id': 'tag-pre-upgrade',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Pre-upgrade Tag',
          'created_at': now,
        });
        await v1Db.insert(Tables.people, {
          'id': 'person-pre-upgrade',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Pre-upgrade Person',
          'created_at': now,
        });
        await v1Db.insert(Tables.workItems, {
          'id': 'wi-pre-upgrade',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Pre-upgrade Task',
          'project_id': 'proj-pre-upgrade',
          'category_id': 'cat-pre-upgrade',
          'created_at': now,
          'updated_at': now,
        });
        await v1Db.insert(Tables.workItemTags, {
          'work_item_id': 'wi-pre-upgrade',
          'tag_id': 'tag-pre-upgrade',
        });
        await v1Db.insert(Tables.workItemPeople, {
          'work_item_id': 'wi-pre-upgrade',
          'person_id': 'person-pre-upgrade',
        });
        await v1Db.insert(Tables.sessions, {
          'id': 'session-pre-upgrade',
          'work_item_id': 'wi-pre-upgrade',
          'start_time': now,
          'end_time': now,
          'created_at': now,
        });
        await v1Db.close();

        // 2. Re-open the same file through DatabaseService, which now
        // targets AppConstants.dbVersion (4) - this exercises the real
        // onUpgrade(db, 1, 4) path, not onCreate.
        final upgraded = DatabaseService();
        await upgraded.initialize(customPath: dbPath);
        final db = upgraded.database;

        final columns =
            await db.rawQuery('PRAGMA table_info(${Tables.sessions});');
        final columnNames = columns.map((c) => c['name'] as String).toSet();
        expect(columnNames, contains('notes'));
        expect(columnNames, contains('category_id'));

        final peopleCols =
            await db.rawQuery('PRAGMA table_info(${Tables.people});');
        final peopleColNames =
            peopleCols.map((c) => c['name'] as String).toSet();
        expect(peopleColNames, contains('team'));

        final sessionTagsTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
          [Tables.sessionTags],
        );
        expect(sessionTagsTable, isNotEmpty);

        final rows = await db.query(
          Tables.sessions,
          where: 'id = ?',
          whereArgs: ['session-pre-upgrade'],
        );
        expect(rows, hasLength(1));
        expect(rows.first['notes'], isNull);
        // Backfilled from parent work item:
        expect(rows.first['category_id'], equals('cat-pre-upgrade'));

        final backfilledTags = await db.query(
          Tables.sessionTags,
          where: 'session_id = ?',
          whereArgs: ['session-pre-upgrade'],
        );
        expect(backfilledTags, hasLength(1));
        expect(backfilledTags.first['tag_id'], equals('tag-pre-upgrade'));

        final backfilledPeople = await db.query(
          Tables.sessionPeople,
          where: 'session_id = ?',
          whereArgs: ['session-pre-upgrade'],
        );
        expect(backfilledPeople, hasLength(1));
        expect(
            backfilledPeople.first['person_id'], equals('person-pre-upgrade'));

        await upgraded.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('MigrationV2, MigrationV3 and MigrationV4 are idempotent', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('workpulse_idempotency_test');
      final dbPath = p.join(tempDir.path, 'idempotent_test.db');

      try {
        final db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) => MigrationV1.execute(db),
          ),
        );

        // Run MigrationV2, MigrationV3, and MigrationV4 once
        await MigrationV2.execute(db);
        await MigrationV3.execute(db);
        await MigrationV4.execute(db);
        // Run a second time - should not throw duplicate column/table error
        await expectLater(MigrationV2.execute(db), completes);
        await expectLater(MigrationV3.execute(db), completes);
        await expectLater(MigrationV4.execute(db), completes);

        await db.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
