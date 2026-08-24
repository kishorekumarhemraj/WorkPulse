import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_attribute_repository.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_idle_period_repository.dart';
import 'package:workpulse/data/repositories/sqlite_person_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_tag_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/data/repositories/sqlite_workspace_repository.dart';
import 'package:workpulse/domain/models/analytics_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/dashboard/providers/dashboard_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Dashboard Riverpod Providers Unit Tests', () {
    late DatabaseService dbService;
    late SqliteWorkspaceRepository workspaceRepo;
    late SqliteSessionRepository sessionRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteTagRepository tagRepo;
    late SqlitePersonRepository personRepo;
    late SqliteAttributeRepository attributeRepo;
    late SqliteIdlePeriodRepository idleRepo;

    const wsId = MigrationV1.defaultWorkspaceId;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      workspaceRepo = SqliteWorkspaceRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      tagRepo = SqliteTagRepository(dbService);
      personRepo = SqlitePersonRepository(dbService);
      attributeRepo = SqliteAttributeRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);

      final now = DateTime.now().toUtc();

      final proj = await projectRepo.create(
        Project(id: 'proj-1', workspaceId: wsId, name: 'Engine Dev', createdAt: now, updatedAt: now),
      );

      final cat = await categoryRepo.create(
        Category(id: 'cat-1', workspaceId: wsId, name: 'Feature', createdAt: now, updatedAt: now),
      );

      final task = await workItemRepo.create(
        WorkItem(
          id: 'task-1',
          workspaceId: wsId,
          projectId: proj.id,
          categoryId: cat.id,
          name: 'Dashboard Analytics',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await sessionRepo.create(
        Session(
          id: 'sess-1',
          workItemId: task.id,
          startTime: now.subtract(const Duration(minutes: 1)),
          endTime: now,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(workspaceRepo),
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
          projectRepositoryProvider.overrideWithValue(projectRepo),
          categoryRepositoryProvider.overrideWithValue(categoryRepo),
          tagRepositoryProvider.overrideWithValue(tagRepo),
          personRepositoryProvider.overrideWithValue(personRepo),
          attributeRepositoryProvider.overrideWithValue(attributeRepo),
          idlePeriodRepositoryProvider.overrideWithValue(idleRepo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('selectedTimeRangeProvider defaults to today and switches ranges', () {
      final container = createContainer();

      expect(
          container.read(selectedTimeRangeProvider), DashboardTimeRange.today);

      container
          .read(selectedTimeRangeProvider.notifier)
          .setRange(DashboardTimeRange.thisWeek);
      expect(container.read(selectedTimeRangeProvider),
          DashboardTimeRange.thisWeek);

      container
          .read(selectedTimeRangeProvider.notifier)
          .setRange(DashboardTimeRange.thisMonth);
      expect(container.read(selectedTimeRangeProvider),
          DashboardTimeRange.thisMonth);
    });

    test('dashboardDateProvider defaults to today and navigates days', () {
      final container = createContainer();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(container.read(dashboardDateProvider), today);

      final specific = DateTime(2026, 5, 15);
      container.read(dashboardDateProvider.notifier).setDate(specific);
      expect(container.read(dashboardDateProvider), specific);

      container.read(dashboardDateProvider.notifier).previousDay();
      expect(container.read(dashboardDateProvider), DateTime(2026, 5, 14));

      container.read(dashboardDateProvider.notifier).nextDay();
      expect(container.read(dashboardDateProvider), DateTime(2026, 5, 15));

      container.read(dashboardDateProvider.notifier).goToToday();
      expect(container.read(dashboardDateProvider), today);
    });

    test('dashboardDataProvider loads DashboardData for active workspace on selected date', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);

      final data = await container.read(dashboardDataProvider.future);

      expect(data.summary.sessionCount, 1);
      expect(data.summary.taskCount, 1);
      expect(data.summary.totalTrackedDuration, const Duration(minutes: 1));
      expect(data.projectBreakdown.length, 1);
      expect(data.projectBreakdown.first.name, 'Engine Dev');
    });
  });
}
