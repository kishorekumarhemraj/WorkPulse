import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/timer/providers/task_duration_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('taskTotalDurationProvider Unit Tests', () {
    late DatabaseService dbService;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;

    const wsId = MigrationV1.defaultWorkspaceId;
    final now = DateTime.utc(2026, 8, 24, 10, 0, 0);

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);

      // Seed project and category for foreign key references
      await dbService.database.insert('projects', {
        'id': 'proj-1',
        'workspace_id': wsId,
        'name': 'Test Project',
        'color_hex': '#0A84FF',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await dbService.database.insert('categories', {
        'id': 'cat-1',
        'workspace_id': wsId,
        'name': 'Test Category',
        'icon_name': 'code',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });

    tearDown(() async {
      await dbService.close();
    });

    test('taskTotalDurationProvider calculates accumulated duration from completed sessions', () async {
      final task = await workItemRepo.create(
        WorkItem(
          id: 'task-dur-1',
          workspaceId: wsId,
          projectId: 'proj-1',
          categoryId: 'cat-1',
          name: 'Duration Test Task',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Add two historical completed sessions (30 mins and 45 mins)
      await sessionRepo.create(
        Session(
          id: 'sess-dur-1',
          workItemId: task.id,
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.subtract(const Duration(hours: 2)).add(const Duration(minutes: 30)),
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      );

      await sessionRepo.create(
        Session(
          id: 'sess-dur-2',
          workItemId: task.id,
          startTime: now.subtract(const Duration(hours: 1)),
          endTime: now.subtract(const Duration(hours: 1)).add(const Duration(minutes: 45)),
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
        ],
      );
      addTearDown(container.dispose);

      final duration = await container.read(taskTotalDurationProvider(task.id).future);
      expect(duration, const Duration(minutes: 75));
    });
  });
}
