import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/repositories/project_repository.dart';

class SqliteProjectRepository implements ProjectRepository {
  final DatabaseService _dbService;

  SqliteProjectRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Project?> getById(String id) async {
    final results = await _db.query(
      Tables.projects,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<Project>> getAll(
      {String? workspaceId, bool includeArchived = false}) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (workspaceId != null) {
      whereClauses.add('workspace_id = ?');
      whereArgs.add(workspaceId);
    }
    if (!includeArchived) {
      whereClauses.add('archived_at IS NULL');
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await _db.query(
      Tables.projects,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<Project> create(Project project) async {
    try {
      await _db.insert(
        Tables.projects,
        _toMap(project),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return project;
    } catch (e) {
      throw AppDatabaseException('Failed to create project: $e');
    }
  }

  @override
  Future<Project> update(Project project) async {
    final updated = project.copyWith(updatedAt: DateTime.now().toUtc());
    final count = await _db.update(
      Tables.projects,
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [project.id],
    );

    if (count == 0) {
      throw NotFoundException('Project with id ${project.id} not found');
    }
    return updated;
  }

  @override
  Future<void> archive(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await _db.update(
      Tables.projects,
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Project with id $id not found');
    }
  }

  @override
  Future<void> unarchive(String id) async {
    final count = await _db.update(
      Tables.projects,
      {
        'archived_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Project with id $id not found');
    }
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.projects,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Project with id $id not found');
    }
  }

  Map<String, dynamic> _toMap(Project project) {
    return {
      'id': project.id,
      'workspace_id': project.workspaceId,
      'name': project.name,
      'description': project.description,
      'color_hex': project.colorHex,
      'created_at': project.createdAt.toStorageString(),
      'updated_at': project.updatedAt.toStorageString(),
      'archived_at': project.archivedAt?.toStorageString(),
    };
  }

  Project _fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      colorHex: map['color_hex'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }
}
