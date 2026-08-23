import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/domain/repositories/workspace_repository.dart';

class SqliteWorkspaceRepository implements WorkspaceRepository {
  final DatabaseService _dbService;

  SqliteWorkspaceRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Workspace?> getById(String id) async {
    final results = await _db.query(
      Tables.workspaces,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<Workspace>> getAll() async {
    final results = await _db.query(
      Tables.workspaces,
      orderBy: 'name ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<Workspace> create(Workspace workspace) async {
    try {
      await _db.insert(
        Tables.workspaces,
        _toMap(workspace),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return workspace;
    } catch (e) {
      throw AppDatabaseException('Failed to create workspace: $e');
    }
  }

  @override
  Future<Workspace> update(Workspace workspace) async {
    final updated = workspace.copyWith(updatedAt: DateTime.now().toUtc());
    final count = await _db.update(
      Tables.workspaces,
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [workspace.id],
    );

    if (count == 0) {
      throw NotFoundException('Workspace with id ${workspace.id} not found');
    }
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.workspaces,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Workspace with id $id not found');
    }
  }

  Map<String, dynamic> _toMap(Workspace workspace) {
    return {
      'id': workspace.id,
      'name': workspace.name,
      'created_at': workspace.createdAt.toIso8601String(),
      'updated_at': workspace.updatedAt.toIso8601String(),
    };
  }

  Workspace _fromMap(Map<String, dynamic> map) {
    return Workspace(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
