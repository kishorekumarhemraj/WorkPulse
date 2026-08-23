import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/repositories/project_repository.dart';

class SqliteProjectRepository implements ProjectRepository {
  final DatabaseService _dbService;

  SqliteProjectRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<List<Project>> getAllProjects({bool includeArchived = false}) async {
    final List<Map<String, Object?>> rows;
    if (includeArchived) {
      rows = await _db.query(Tables.projects, orderBy: 'name COLLATE NOCASE ASC');
    } else {
      rows = await _db.query(
        Tables.projects,
        where: 'archived_at IS NULL',
        orderBy: 'name COLLATE NOCASE ASC',
      );
    }
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Project?> getProjectById(String id) async {
    final rows = await _db.query(
      Tables.projects,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Project?> getProjectByName(String name) async {
    final rows = await _db.query(
      Tables.projects,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> createProject(Project project) async {
    await _db.insert(
      Tables.projects,
      _toMap(project),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateProject(Project project) async {
    await _db.update(
      Tables.projects,
      _toMap(project),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  @override
  Future<void> deleteProject(String id) async {
    await _db.delete(
      Tables.projects,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Project _fromRow(Map<String, Object?> row) {
    return Project(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      colorHex: row['color_hex'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      archivedAt: row['archived_at'] != null ? DateTime.parse(row['archived_at'] as String) : null,
    );
  }

  Map<String, Object?> _toMap(Project project) {
    return {
      'id': project.id,
      'name': project.name,
      'description': project.description,
      'color_hex': project.colorHex,
      'created_at': project.createdAt.toIso8601String(),
      'updated_at': project.updatedAt.toIso8601String(),
      'archived_at': project.archivedAt?.toIso8601String(),
    };
  }
}
