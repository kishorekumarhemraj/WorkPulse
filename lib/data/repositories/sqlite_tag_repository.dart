import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/repositories/tag_repository.dart';

class SqliteTagRepository implements TagRepository {
  final DatabaseService _dbService;

  SqliteTagRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Tag?> getById(String id) async {
    final results = await _db.query(
      Tables.tags,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<Tag>> getAll({String? workspaceId}) async {
    final results = await _db.query(
      Tables.tags,
      where: workspaceId != null ? 'workspace_id = ?' : null,
      whereArgs: workspaceId != null ? [workspaceId] : null,
      orderBy: 'name ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<Tag> create(Tag tag) async {
    try {
      await _db.insert(
        Tables.tags,
        _toMap(tag),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return tag;
    } catch (e) {
      throw DatabaseException('Failed to create tag: $e');
    }
  }

  @override
  Future<Tag> update(Tag tag) async {
    final count = await _db.update(
      Tables.tags,
      _toMap(tag),
      where: 'id = ?',
      whereArgs: [tag.id],
    );

    if (count == 0) {
      throw NotFoundException('Tag with id ${tag.id} not found');
    }
    return tag;
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.tags,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Tag with id $id not found');
    }
  }

  Map<String, dynamic> _toMap(Tag tag) {
    return {
      'id': tag.id,
      'workspace_id': tag.workspaceId,
      'name': tag.name,
      'color_hex': tag.colorHex,
      'created_at': tag.createdAt.toIso8601String(),
    };
  }

  Tag _fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
