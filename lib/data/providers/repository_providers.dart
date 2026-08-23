import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/repositories/sqlite_attribute_repository.dart';
import 'package:workpulse/data/repositories/sqlite_category_repository.dart';
import 'package:workpulse/data/repositories/sqlite_idle_period_repository.dart';
import 'package:workpulse/data/repositories/sqlite_person_repository.dart';
import 'package:workpulse/data/repositories/sqlite_project_repository.dart';
import 'package:workpulse/data/repositories/sqlite_session_repository.dart';
import 'package:workpulse/data/repositories/sqlite_settings_repository.dart';
import 'package:workpulse/data/repositories/sqlite_tag_repository.dart';
import 'package:workpulse/data/repositories/sqlite_work_item_repository.dart';
import 'package:workpulse/data/repositories/sqlite_workspace_repository.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/domain/repositories/category_repository.dart';
import 'package:workpulse/domain/repositories/idle_period_repository.dart';
import 'package:workpulse/domain/repositories/person_repository.dart';
import 'package:workpulse/domain/repositories/project_repository.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';
import 'package:workpulse/domain/repositories/settings_repository.dart';
import 'package:workpulse/domain/repositories/tag_repository.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';
import 'package:workpulse/domain/repositories/workspace_repository.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteWorkspaceRepository(dbService);
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteProjectRepository(dbService);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteCategoryRepository(dbService);
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteTagRepository(dbService);
});

final personRepositoryProvider = Provider<PersonRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqlitePersonRepository(dbService);
});

final workItemRepositoryProvider = Provider<WorkItemRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteWorkItemRepository(dbService);
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteSessionRepository(dbService);
});

final attributeRepositoryProvider = Provider<AttributeRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteAttributeRepository(dbService);
});

final idlePeriodRepositoryProvider = Provider<IdlePeriodRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteIdlePeriodRepository(dbService);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return SqliteSettingsRepository(dbService);
});
