import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/migrations/migration_v1.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/providers/quick_capture_provider.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('QuickCaptureProvider Unit Tests', () {
    late DatabaseService dbService;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteWorkItemRepository workItemRepo;
    late SqliteSessionRepository sessionRepo;

    const wsId = MigrationV1.defaultWorkspaceId;
    late Project defaultProject;
    late Category defaultCategory;
    late WorkItem existingTask;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      workItemRepo = SqliteWorkItemRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);

      final now = DateTime.now().toUtc();

      defaultProject = await projectRepo.create(
        Project(
          id: 'proj-1',
          workspaceId: wsId,
          name: 'Core System',
          createdAt: now,
          updatedAt: now,
        ),
      );

      defaultCategory = await categoryRepo.create(
        Category(
          id: 'cat-1',
          workspaceId: wsId,
          name: 'Engineering',
          createdAt: now,
          updatedAt: now,
        ),
      );

      existingTask = await workItemRepo.create(
        WorkItem(
          id: 'task-1',
          workspaceId: wsId,
          projectId: defaultProject.id,
          categoryId: defaultCategory.id,
          name: 'Fix Search Latency',
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          workItemRepositoryProvider.overrideWithValue(workItemRepo),
          projectRepositoryProvider.overrideWithValue(projectRepo),
          categoryRepositoryProvider.overrideWithValue(categoryRepo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('initializes and selects default project and category', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(projectsProvider.future);
      await container.read(categoriesProvider.future);

      final qcState = container.read(quickCaptureProvider);

      expect(qcState.query, isEmpty);
      expect(qcState.selectedIndex, 0);
      expect(qcState.selectedProjectId, isNotNull);
      expect(qcState.selectedCategoryId, isNotNull);
    });

    test('query updates and arrow navigation clamping', () async {
      final container = createContainer();
      final notifier = container.read(quickCaptureProvider.notifier);

      notifier.setQuery('Auth');
      expect(container.read(quickCaptureProvider).query, 'Auth');
      expect(container.read(quickCaptureProvider).selectedIndex, 0);

      // Navigate down
      notifier.selectNext(3);
      expect(container.read(quickCaptureProvider).selectedIndex, 1);

      notifier.selectNext(3);
      expect(container.read(quickCaptureProvider).selectedIndex, 2);

      // Cannot exceed maxCount - 1
      notifier.selectNext(3);
      expect(container.read(quickCaptureProvider).selectedIndex, 2);

      // Navigate up
      notifier.selectPrevious();
      expect(container.read(quickCaptureProvider).selectedIndex, 1);

      notifier.selectPrevious();
      expect(container.read(quickCaptureProvider).selectedIndex, 0);

      // Cannot go below 0
      notifier.selectPrevious();
      expect(container.read(quickCaptureProvider).selectedIndex, 0);
    });

    test('startExistingTask starts timer on the task', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(workItemsProvider.future);
      await container.read(timerProvider.future);

      // quickCaptureProvider is autoDispose; in the real app the
      // QuickCaptureDialog widget's ref.watch keeps it alive across the
      // await below. Simulate that here so it isn't disposed mid-flight.
      container.listen(quickCaptureProvider, (_, __) {});
      final notifier = container.read(quickCaptureProvider.notifier);
      await notifier.startExistingTask(existingTask);

      final timerState = container.read(timerProvider).value!;
      expect(timerState.isRunning, isTrue);
      expect(timerState.activeWorkItem!.id, existingTask.id);
    });

    test('createAndStartTask creates work item and starts timer', () async {
      final container = createContainer();
      await container.read(currentWorkspaceProvider.future);
      await container.read(projectsProvider.future);
      await container.read(categoriesProvider.future);
      await container.read(workItemsProvider.future);
      await container.read(timerProvider.future);

      // quickCaptureProvider is autoDispose; in the real app the
      // QuickCaptureDialog widget's ref.watch keeps it alive across the
      // awaits below. Simulate that here so it isn't disposed mid-flight.
      container.listen(quickCaptureProvider, (_, __) {});
      final notifier = container.read(quickCaptureProvider.notifier);
      notifier.setProject(defaultProject.id);
      notifier.setCategory(defaultCategory.id);

      final created =
          await notifier.createAndStartTask(name: 'New Feature Fast');
      expect(created, isNotNull);
      expect(created!.name, 'New Feature Fast');
      expect(created.projectId, defaultProject.id);
      expect(created.categoryId, defaultCategory.id);

      final timerState = container.read(timerProvider).value!;
      expect(timerState.isRunning, isTrue);
      expect(timerState.activeWorkItem!.id, created.id);
    });
  });
}
