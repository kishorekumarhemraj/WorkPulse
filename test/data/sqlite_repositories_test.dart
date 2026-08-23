import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_idle_period_repository.dart';
import 'package:workpulse/data/repositories/sqlite_person_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/data/repositories/sqlite_tag_repository.dart';
import 'package:workpulse/data/repositories/sqlite_task_repository.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/idle_period_model.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/models/task_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite Repositories End-to-End Tests', () {
    late DatabaseService dbService;
    late SqliteProjectRepository projectRepo;
    late SqliteCategoryRepository categoryRepo;
    late SqliteTagRepository tagRepo;
    late SqlitePersonRepository personRepo;
    late SqliteTaskRepository taskRepo;
    late SqliteSessionRepository sessionRepo;
    late SqliteIdlePeriodRepository idleRepo;
    late SqliteSettingsRepository settingsRepo;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initialize(inMemory: true);

      projectRepo = SqliteProjectRepository(dbService);
      categoryRepo = SqliteCategoryRepository(dbService);
      tagRepo = SqliteTagRepository(dbService);
      personRepo = SqlitePersonRepository(dbService);
      taskRepo = SqliteTaskRepository(dbService);
      sessionRepo = SqliteSessionRepository(dbService);
      idleRepo = SqliteIdlePeriodRepository(dbService);
      settingsRepo = SqliteSettingsRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Project & Category CRUD operations', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final project = Project(
        id: 'proj-1',
        name: 'OpenText Platform',
        description: 'Core backend platform',
        colorHex: '#0A84FF',
        createdAt: now,
        updatedAt: now,
      );
      await projectRepo.createProject(project);

      final fetchedProj = await projectRepo.getProjectById('proj-1');
      expect(fetchedProj, isNotNull);
      expect(fetchedProj!.name, equals('OpenText Platform'));

      final category = Category(
        id: 'cat-1',
        name: 'Engineering',
        description: 'Software development',
        iconName: 'code',
        createdAt: now,
        updatedAt: now,
      );
      await categoryRepo.createCategory(category);

      final fetchedCat = await categoryRepo.getCategoryByName('engineering');
      expect(fetchedCat, isNotNull);
      expect(fetchedCat!.id, equals('cat-1'));
    });

    test('Tags & People relations and CRUD', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      final tag1 = Tag(id: 'tag-1', name: 'Architecture', createdAt: now);
      final tag2 = Tag(id: 'tag-2', name: 'Deep Work', createdAt: now);
      await tagRepo.createTag(tag1);
      await tagRepo.createTag(tag2);

      final allTags = await tagRepo.getAllTags();
      expect(allTags.length, equals(2));

      final person = Person(id: 'per-1', name: 'Richard', email: 'r@example.com', createdAt: now);
      await personRepo.createPerson(person);

      final fetchedPerson = await personRepo.getPersonById('per-1');
      expect(fetchedPerson?.name, equals('Richard'));
    });

    test('Task creation, search, and relations', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // Seed project, category, tag, person
      await projectRepo.createProject(Project(
        id: 'p-1',
        name: 'OpenText Platform',
        createdAt: now,
        updatedAt: now,
      ));
      await categoryRepo.createCategory(Category(
        id: 'c-1',
        name: 'Engineering',
        createdAt: now,
        updatedAt: now,
      ));
      await tagRepo.createTag(Tag(id: 't-1', name: 'Deep Work', createdAt: now));
      await personRepo.createPerson(Person(id: 'per-1', name: 'Richard', createdAt: now));

      // Create task
      final task = Task(
        id: 'task-1',
        name: 'Prepare Q3 architecture proposal',
        projectId: 'p-1',
        categoryId: 'c-1',
        jiraId: 'PLAT-1234',
        tagIds: const ['t-1'],
        peopleIds: const ['per-1'],
        createdAt: now,
        updatedAt: now,
      );
      await taskRepo.createTask(task);

      // Verify task retrieval with populated relations
      final retrieved = await taskRepo.getTaskById('task-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Prepare Q3 architecture proposal'));
      expect(retrieved.tagIds, contains('t-1'));
      expect(retrieved.peopleIds, contains('per-1'));

      // Verify search by Jira ID
      final searchJira = await taskRepo.searchTasks('PLAT-1234');
      expect(searchJira.length, equals(1));
      expect(searchJira.first.id, equals('task-1'));

      // Verify search by Person name
      final searchPerson = await taskRepo.searchTasks('Richard');
      expect(searchPerson.length, equals(1));

      // Verify search by Tag name
      final searchTag = await taskRepo.searchTasks('Deep Work');
      expect(searchTag.length, equals(1));
    });

    test('Session lifecycle, active session recovery, and multi-session resume', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // Setup task
      await projectRepo.createProject(Project(id: 'p-1', name: 'OpenText', createdAt: now, updatedAt: now));
      await categoryRepo.createCategory(Category(id: 'c-1', name: 'Dev', createdAt: now, updatedAt: now));
      await taskRepo.createTask(Task(
        id: 'task-1',
        name: 'API Redesign',
        projectId: 'p-1',
        categoryId: 'c-1',
        createdAt: now,
        updatedAt: now,
      ));

      // Session 1: completed
      final session1 = Session(
        id: 'sess-1',
        taskId: 'task-1',
        startTime: DateTime.utc(2026, 8, 23, 10, 0),
        endTime: DateTime.utc(2026, 8, 23, 11, 15),
        createdAt: now,
      );
      await sessionRepo.createSession(session1);

      // No active session yet
      var active = await sessionRepo.getActiveSession();
      expect(active, isNull);

      // Session 2: active (ongoing)
      final session2 = Session(
        id: 'sess-2',
        taskId: 'task-1',
        startTime: DateTime.utc(2026, 8, 23, 14, 0),
        endTime: null,
        createdAt: DateTime.utc(2026, 8, 23, 14, 0),
      );
      await sessionRepo.createSession(session2);

      // Active session recovery check
      active = await sessionRepo.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, equals('sess-2'));
      expect(active.isActive, isTrue);

      // End active session
      await sessionRepo.endSession('sess-2', DateTime.utc(2026, 8, 23, 15, 0));
      active = await sessionRepo.getActiveSession();
      expect(active, isNull);

      // Verify all sessions for task
      final taskSessions = await sessionRepo.getSessionsForTask('task-1');
      expect(taskSessions.length, equals(2));
      final totalMinutes = taskSessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
      expect(totalMinutes, equals(75 + 60)); // 135 mins = 2h 15m
    });

    test('Idle period recording and settings persistence', () async {
      final now = DateTime.utc(2026, 8, 23, 10, 0);

      // Setup task & session
      await projectRepo.createProject(Project(id: 'p-1', name: 'P', createdAt: now, updatedAt: now));
      await categoryRepo.createCategory(Category(id: 'c-1', name: 'C', createdAt: now, updatedAt: now));
      await taskRepo.createTask(Task(id: 't-1', name: 'T', projectId: 'p-1', categoryId: 'c-1', createdAt: now, updatedAt: now));
      await sessionRepo.createSession(Session(id: 's-1', taskId: 't-1', startTime: now, createdAt: now));

      // Add idle period
      final idle = IdlePeriod(
        id: 'idle-1',
        sessionId: 's-1',
        startTime: DateTime.utc(2026, 8, 23, 10, 15),
        endTime: DateTime.utc(2026, 8, 23, 10, 45),
        resolution: IdleResolution.markIdle,
        createdAt: now,
      );
      await idleRepo.createIdlePeriod(idle);

      final idles = await idleRepo.getIdlePeriodsForSession('s-1');
      expect(idles.length, equals(1));
      expect(idles.first.resolution, equals(IdleResolution.markIdle));

      // Settings
      await settingsRepo.setSetting('global_hotkey', 'Option + Space');
      final hotkey = await settingsRepo.getSetting('global_hotkey');
      expect(hotkey, equals('Option + Space'));
    });
  });
}
