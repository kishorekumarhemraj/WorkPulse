import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/domain/repositories/tag_repository.dart';

class SqliteTagRepository implements TagRepository {
  final DatabaseService _dbService;

  SqliteTagRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<List<Tag>> getAllTags() async {
    final rows = await _db.query(Tables.tags, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Tag?> getTagById(String id) async {
    final rows = await _db.query(
      Tables.tags,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Tag?> getTagByName(String name) async {
    final rows = await _db.query(
      Tables.tags,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<Tag>> getTagsForTask(String taskId) async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM ${Tables.tags} t
      INNER JOIN ${Tables.taskTags} tt ON t.id = tt.tag_id
      WHERE tt.task_id = ?
      ORDER BY t.name COLLATE NOCASE ASC
    ''', [taskId]);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> createTag(Tag tag) async {
    await _db.insert(
      Tables.tags,
      _toMap(tag),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateTag(Tag tag) async {
    await _db.update(
      Tables.tags,
      _toMap(tag),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  @override
  Future<void> deleteTag(String id) async {
    await _db.delete(
      Tables.tags,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Tag _fromRow(Map<String, Object?> row) {
    return Tag(
      id: row['id'] as String,
      name: row['name'] as String,
      colorHex: row['color_hex'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, Object?> _toMap(Tag tag) {
    return {
      'id': tag.id,
      'name': tag.name,
      'color_hex': tag.colorHex,
      'created_at': tag.createdAt.toIso8601String(),
    };
  }
}
