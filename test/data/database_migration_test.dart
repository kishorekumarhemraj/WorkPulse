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
import 'package:workpulse/data/migrations/migration_v5.dart';
import 'package:workpulse/data/migrations/migration_v6.dart';
import 'package:workpulse/data/migrations/migration_v8.dart';
import 'package:workpulse/data/migrations/migration_v9.dart';
import 'package:workpulse/data/migrations/migration_v10.dart';

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

    test('All 19 SQLite tables are created with proper schema', () async {
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
        Tables.projectTimesheetCodes,
        Tables.workItemReminders,
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

    test('the financial classification lives on tasks, not categories',
        () async {
      final db = dbService.database;

      final categoryColumns =
          await db.rawQuery('PRAGMA table_info(${Tables.categories});');
      final categoryNames =
          categoryColumns.map((c) => c['name'] as String).toSet();
      // A category names the kind of work and makes no financial claim.
      expect(categoryNames, isNot(contains('type')));

      final workItemColumns =
          await db.rawQuery('PRAGMA table_info(${Tables.workItems});');
      final classificationColumn = workItemColumns.firstWhere(
        (c) => c['name'] == 'financial_classification',
        orElse: () => {},
      );
      expect(classificationColumn, isNotEmpty);
      expect(classificationColumn['notnull'], 1);

      final sessionColumns =
          await db.rawQuery('PRAGMA table_info(${Tables.sessions});');
      final overrideColumn = sessionColumns.firstWhere(
        (c) => c['name'] == 'financial_classification',
        orElse: () => {},
      );
      expect(overrideColumn, isNotEmpty);
      // Nullable on purpose: null means "inherit from the task".
      expect(overrideColumn['notnull'], 0);
    });

    test('a task defaults to NONE rather than inventing a finance decision',
        () async {
      final db = dbService.database;
      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert(Tables.projects, {
        'id': 'proj-default',
        'workspace_id': MigrationV1.defaultWorkspaceId,
        'name': 'Defaulting Project',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert(Tables.categories, {
        'id': 'cat-default',
        'workspace_id': MigrationV1.defaultWorkspaceId,
        'name': 'Defaulting Category',
        'created_at': now,
        'updated_at': now,
      });
      await db.insert(Tables.workItems, {
        'id': 'wi-default',
        'workspace_id': MigrationV1.defaultWorkspaceId,
        'name': 'Defaulting Task',
        'project_id': 'proj-default',
        'category_id': 'cat-default',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query(
        Tables.workItems,
        where: 'id = ?',
        whereArgs: ['wi-default'],
      );
      expect(rows.first['financial_classification'], equals('NONE'));
    });

    test(
        'projects table has timesheet_code and code_attribute_definition_id columns on a fresh database',
        () async {
      final db = dbService.database;
      final columns =
          await db.rawQuery('PRAGMA table_info(${Tables.projects});');
      final columnNames = columns.map((c) => c['name'] as String).toSet();
      expect(columnNames, contains('timesheet_code'));
      expect(columnNames, contains('code_attribute_definition_id'));
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
        // targets AppConstants.dbVersion (7) - this exercises the real
        // onUpgrade(db, 1, 7) path, not onCreate.
        final upgraded = DatabaseService();
        await upgraded.initialize(customPath: dbPath);
        final db = upgraded.database;

        final columns =
            await db.rawQuery('PRAGMA table_info(${Tables.sessions});');
        final columnNames = columns.map((c) => c['name'] as String).toSet();
        expect(columnNames, contains('notes'));
        expect(columnNames, contains('category_id'));

        final projectCols =
            await db.rawQuery('PRAGMA table_info(${Tables.projects});');
        final projectColNames =
            projectCols.map((c) => c['name'] as String).toSet();
        expect(projectColNames, contains('timesheet_code'));
        expect(projectColNames, contains('code_attribute_definition_id'));

        final projectCodesTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
          [Tables.projectTimesheetCodes],
        );
        expect(projectCodesTable, isNotEmpty);

        final upgradedProject = await db.query(
          Tables.projects,
          where: 'id = ?',
          whereArgs: ['proj-pre-upgrade'],
        );
        // Deliberately not backfilled: a cost code is an external identifier
        // the app cannot invent, and a made-up one would be booked against
        // real hours.
        expect(upgradedProject.first['timesheet_code'], isNull);
        expect(upgradedProject.first['code_attribute_definition_id'], isNull);

        final categoryCols =
            await db.rawQuery('PRAGMA table_info(${Tables.categories});');
        final categoryColNames =
            categoryCols.map((c) => c['name'] as String).toSet();
        expect(categoryColNames, isNot(contains('type')));

        final upgradedTask = await db.query(
          Tables.workItems,
          where: 'id = ?',
          whereArgs: ['wi-pre-upgrade'],
        );
        // A v1 database has no category type to carry over, so the task
        // arrives unclassified rather than guessed at.
        expect(
          upgradedTask.first['financial_classification'],
          equals('NONE'),
        );

        final upgradedSession = await db.query(
          Tables.sessions,
          where: 'id = ?',
          whereArgs: ['session-pre-upgrade'],
        );
        // Null is "inherit from the task", which is what every historical
        // session should do.
        expect(
          upgradedSession.first['financial_classification'],
          isNull,
        );

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

    test('carries a category-level CAPEX/OPEX value onto its tasks', () async {
      // Reproduces a database that ran the *earlier* cut of v5, where the
      // classification hung off the category. The rewritten v5 has to lift
      // those values onto the tasks and then drop the column, or a user who
      // classified their categories loses that work on upgrade.
      final tempDir =
          await Directory.systemTemp.createTemp('workpulse_classify_test');
      final dbPath = p.join(tempDir.path, 'classify_test.db');

      try {
        final db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) => MigrationV1.execute(db),
          ),
        );
        await MigrationV2.execute(db);
        await MigrationV3.execute(db);
        await MigrationV4.execute(db);

        // The old v5's column, recreated by hand.
        await db.execute(
          'ALTER TABLE ${Tables.categories} '
          "ADD COLUMN type TEXT NOT NULL DEFAULT 'OPEX';",
        );

        final now = DateTime.now().toUtc().toIso8601String();
        await db.insert(Tables.projects, {
          'id': 'proj-1',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Apollo',
          'created_at': now,
          'updated_at': now,
        });
        for (final (id, name, type) in [
          ('cat-build', 'Feature Work', 'CAPEX'),
          ('cat-run', 'Production Support', 'OPEX'),
        ]) {
          await db.insert(Tables.categories, {
            'id': id,
            'workspace_id': MigrationV1.defaultWorkspaceId,
            'name': name,
            'type': type,
            'created_at': now,
            'updated_at': now,
          });
        }
        for (final (id, categoryId) in [
          ('wi-build', 'cat-build'),
          ('wi-run', 'cat-run'),
        ]) {
          await db.insert(Tables.workItems, {
            'id': id,
            'workspace_id': MigrationV1.defaultWorkspaceId,
            'name': 'Task for $categoryId',
            'project_id': 'proj-1',
            'category_id': categoryId,
            'created_at': now,
            'updated_at': now,
          });
        }

        await MigrationV5.execute(db);

        Future<Object?> classificationOf(String id) async {
          final rows = await db.query(
            Tables.workItems,
            where: 'id = ?',
            whereArgs: [id],
          );
          return rows.first['financial_classification'];
        }

        expect(await classificationOf('wi-build'), equals('CAPEX'));
        expect(await classificationOf('wi-run'), equals('OPEX'));

        final categoryCols =
            await db.rawQuery('PRAGMA table_info(${Tables.categories});');
        final categoryNames =
            categoryCols.map((c) => c['name'] as String).toSet();
        expect(categoryNames, isNot(contains('type')));

        // Re-runnable: the replay on the way to v7 must not throw or undo
        // the values it just wrote.
        await expectLater(MigrationV5.execute(db), completes);
        expect(await classificationOf('wi-build'), equals('CAPEX'));

        await db.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('MigrationV2 through MigrationV8 are idempotent', () async {
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

        // Run each migration once
        await MigrationV2.execute(db);
        await MigrationV3.execute(db);
        await MigrationV4.execute(db);
        await MigrationV5.execute(db);
        await MigrationV6.execute(db);
        await MigrationV8.execute(db);
        // Run a second time - should not throw duplicate column/table error
        await expectLater(MigrationV2.execute(db), completes);
        await expectLater(MigrationV3.execute(db), completes);
        await expectLater(MigrationV4.execute(db), completes);
        await expectLater(MigrationV5.execute(db), completes);
        await expectLater(MigrationV6.execute(db), completes);
        await expectLater(MigrationV8.execute(db), completes);

        await db.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'v7 -> v8 upgrade adds column and table, preserving existing project codes',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('workpulse_v8_upgrade_test');
      final dbPath = p.join(tempDir.path, 'v8_test.db');

      try {
        // 1. Create a v7 database (v1 through v6)
        final db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 7,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
            onCreate: (db, version) async {
              await MigrationV1.execute(db);
              await MigrationV2.execute(db);
              await MigrationV3.execute(db);
              await MigrationV4.execute(db);
              await MigrationV5.execute(db);
              await MigrationV6.execute(db);
            },
          ),
        );

        final now = DateTime.now().toUtc().toIso8601String();
        await db.insert(Tables.projects, {
          'id': 'proj-v7',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Existing Project',
          'timesheet_code': 'PRJ-V7-CODE',
          'created_at': now,
          'updated_at': now,
        });
        await db.close();

        // 2. Upgrade to v8 via DatabaseService
        final dbService = DatabaseService();
        await dbService.initialize(customPath: dbPath);
        final upgradedDb = dbService.database;

        final projectCols =
            await upgradedDb.rawQuery('PRAGMA table_info(${Tables.projects});');
        final projectColNames =
            projectCols.map((c) => c['name'] as String).toSet();
        expect(projectColNames, contains('code_attribute_definition_id'));

        final projectCodesTable = await upgradedDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
          [Tables.projectTimesheetCodes],
        );
        expect(projectCodesTable, isNotEmpty);

        final project = await upgradedDb.query(
          Tables.projects,
          where: 'id = ?',
          whereArgs: ['proj-v7'],
        );
        expect(project.first['timesheet_code'], equals('PRJ-V7-CODE'));
        expect(project.first['code_attribute_definition_id'], isNull);

        // 3. Test running MigrationV8 a second time is a no-op
        await expectLater(MigrationV8.execute(upgradedDb), completes);

        await dbService.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'v8 -> v9 upgrade adds category colour and backfills every existing row',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('workpulse_v9_upgrade_test');
      final dbPath = p.join(tempDir.path, 'v9_test.db');

      try {
        // 1. A v8 database, with categories that predate the colour column.
        final db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 8,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
            onCreate: (db, version) async {
              await MigrationV1.execute(db);
              await MigrationV2.execute(db);
              await MigrationV3.execute(db);
              await MigrationV4.execute(db);
              await MigrationV5.execute(db);
              await MigrationV6.execute(db);
              await MigrationV8.execute(db);
            },
          ),
        );

        final base = DateTime.utc(2026, 1, 1);
        for (var i = 0; i < 3; i++) {
          await db.insert(Tables.categories, {
            'id': 'cat-v8-$i',
            'workspace_id': MigrationV1.defaultWorkspaceId,
            'name': 'Legacy $i',
            'created_at': base.add(Duration(minutes: i)).toIso8601String(),
            'updated_at': base.add(Duration(minutes: i)).toIso8601String(),
          });
        }
        await db.close();

        // 2. Upgrade.
        final dbService = DatabaseService();
        await dbService.initialize(customPath: dbPath);
        final upgraded = dbService.database;

        final cols =
            await upgraded.rawQuery('PRAGMA table_info(${Tables.categories});');
        expect(cols.map((c) => c['name'] as String).toSet(),
            contains('color_hex'));

        // Every pre-existing category is coloured. A nullable column with no
        // backfill would leave the app looking exactly as it did before until
        // the user hand-edited each one.
        final rows = await upgraded.query(Tables.categories,
            orderBy: 'created_at ASC, id ASC');
        expect(rows, hasLength(3));
        for (final row in rows) {
          final hex = row['color_hex'] as String?;
          expect(hex, isNotNull);
          expect(hex, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
        }

        // Distinct colours, so a list of categories does not read as one hue.
        expect(rows.map((r) => r['color_hex']).toSet(), hasLength(3));

        // 3. Re-running must not recolour a category the user has since set.
        await upgraded.update(Tables.categories, {'color_hex': '#123456'},
            where: 'id = ?', whereArgs: ['cat-v8-0']);
        await expectLater(MigrationV9.execute(upgraded), completes);
        final kept = await upgraded
            .query(Tables.categories, where: 'id = ?', whereArgs: ['cat-v8-0']);
        expect(kept.first['color_hex'], equals('#123456'));

        await dbService.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'v9 -> v10 upgrade adds columns and reminder table, is idempotent, enforces UNIQUE and cascade',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('workpulse_v10_upgrade_test');
      final dbPath = p.join(tempDir.path, 'v10_test.db');

      try {
        // 1. A v9 database
        final db = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: 9,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
            onCreate: (db, version) async {
              await MigrationV1.execute(db);
              await MigrationV2.execute(db);
              await MigrationV3.execute(db);
              await MigrationV4.execute(db);
              await MigrationV5.execute(db);
              await MigrationV6.execute(db);
              await MigrationV8.execute(db);
              await MigrationV9.execute(db);
            },
          ),
        );

        final now = DateTime.now().toUtc().toIso8601String();
        await db.insert(Tables.projects, {
          'id': 'proj-v9',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Existing Project',
          'created_at': now,
          'updated_at': now,
        });
        await db.insert(Tables.categories, {
          'id': 'cat-v9',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Existing Category',
          'color_hex': '#0A84FF',
          'created_at': now,
          'updated_at': now,
        });
        await db.insert(Tables.workItems, {
          'id': 'wi-v9',
          'workspace_id': MigrationV1.defaultWorkspaceId,
          'name': 'Existing Task',
          'project_id': 'proj-v9',
          'category_id': 'cat-v9',
          'created_at': now,
          'updated_at': now,
        });
        await db.close();

        // 2. Upgrade to v10
        final dbService = DatabaseService();
        await dbService.initialize(customPath: dbPath);
        final upgraded = dbService.database;

        final wiCols =
            await upgraded.rawQuery('PRAGMA table_info(${Tables.workItems});');
        final wiColNames = wiCols.map((c) => c['name'] as String).toSet();
        expect(wiColNames, contains('planned_start_date'));
        expect(wiColNames, contains('due_date'));
        expect(wiColNames, contains('completed_at'));

        // Existing row has NULLs
        final existingWi = await upgraded.query(
          Tables.workItems,
          where: 'id = ?',
          whereArgs: ['wi-v9'],
        );
        expect(existingWi.first['planned_start_date'], isNull);
        expect(existingWi.first['due_date'], isNull);
        expect(existingWi.first['completed_at'], isNull);

        // Reminders table exists
        final reminderCols = await upgraded
            .rawQuery('PRAGMA table_info(${Tables.workItemReminders});');
        final reminderColNames =
            reminderCols.map((c) => c['name'] as String).toSet();
        expect(reminderColNames, contains('rule'));
        expect(reminderColNames, contains('occurrence_key'));
        expect(reminderColNames, contains('anchor_date'));
        expect(reminderColNames, contains('delivered_at'));

        // Test UNIQUE constraint on (work_item_id, rule, occurrence_key)
        await upgraded.insert(Tables.workItemReminders, {
          'id': 'rem-1',
          'work_item_id': 'wi-v9',
          'rule': 'due_today',
          'occurrence_key': '2026-09-03',
          'anchor_date': '2026-09-03',
          'delivered_at': now,
        });

        expect(
          () async => await upgraded.insert(Tables.workItemReminders, {
            'id': 'rem-2',
            'work_item_id': 'wi-v9',
            'rule': 'due_today',
            'occurrence_key': '2026-09-03',
            'anchor_date': '2026-09-03',
            'delivered_at': now,
          }),
          throwsA(isA<DatabaseException>()),
        );

        // Test ON DELETE CASCADE
        await upgraded.delete(
          Tables.workItems,
          where: 'id = ?',
          whereArgs: ['wi-v9'],
        );
        final remainingReminders = await upgraded.query(
          Tables.workItemReminders,
          where: 'work_item_id = ?',
          whereArgs: ['wi-v9'],
        );
        expect(remainingReminders, isEmpty);

        // 3. Re-run idempotency
        await expectLater(MigrationV10.execute(upgraded), completes);

        await dbService.close();
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
