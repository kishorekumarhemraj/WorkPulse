import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/repositories/project_repository.dart';

import 'package:workpulse/domain/models/project_timesheet_code.dart';

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

  @override
  Future<List<ProjectTimesheetCode>> getTimesheetCodes(String projectId) async {
    final results = await _db.query(
      Tables.projectTimesheetCodes,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );
    return results.map(_codeFromMap).toList();
  }

  @override
  Future<List<ProjectTimesheetCode>> getAllTimesheetCodes(
      {String? workspaceId}) async {
    if (workspaceId != null) {
      final results = await _db.rawQuery('''
        SELECT ptc.* FROM ${Tables.projectTimesheetCodes} ptc
        INNER JOIN ${Tables.projects} p ON ptc.project_id = p.id
        WHERE p.workspace_id = ?
        ORDER BY ptc.created_at ASC
      ''', [workspaceId]);
      return results.map(_codeFromMap).toList();
    }
    final results = await _db.query(
      Tables.projectTimesheetCodes,
      orderBy: 'created_at ASC',
    );
    return results.map(_codeFromMap).toList();
  }

  @override
  Future<void> setTimesheetCodes(
      String projectId, List<ProjectTimesheetCode> codes) async {
    await _db.transaction((txn) async {
      await txn.delete(
        Tables.projectTimesheetCodes,
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      for (final code in codes) {
        await txn.insert(
          Tables.projectTimesheetCodes,
          _codeToMap(code),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Map<String, dynamic> _toMap(Project project) {
    return {
      'id': project.id,
      'workspace_id': project.workspaceId,
      'name': project.name,
      'description': project.description,
      'color_hex': project.colorHex,
      'timesheet_code': project.timesheetCode,
      'code_attribute_definition_id': project.codeAttributeDefinitionId,
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
      timesheetCode: map['timesheet_code'] as String?,
      codeAttributeDefinitionId: map['code_attribute_definition_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _codeToMap(ProjectTimesheetCode code) {
    return {
      'id': code.id,
      'project_id': code.projectId,
      'attribute_option_id': code.attributeOptionId,
      'code': code.code,
      'created_at': code.createdAt.toStorageString(),
      'updated_at': code.updatedAt.toStorageString(),
    };
  }

  ProjectTimesheetCode _codeFromMap(Map<String, dynamic> map) {
    return ProjectTimesheetCode(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      attributeOptionId: map['attribute_option_id'] as String,
      code: map['code'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
