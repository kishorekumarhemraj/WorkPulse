import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/repositories/category_repository.dart';

class SqliteCategoryRepository implements CategoryRepository {
  final DatabaseService _dbService;

  SqliteCategoryRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Category?> getById(String id) async {
    final results = await _db.query(
      Tables.categories,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<Category>> getAll({String? workspaceId, bool includeArchived = false}) async {
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
      Tables.categories,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<Category> create(Category category) async {
    try {
      await _db.insert(
        Tables.categories,
        _toMap(category),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return category;
    } catch (e) {
      throw DatabaseException('Failed to create category: $e');
    }
  }

  @override
  Future<Category> update(Category category) async {
    final updated = category.copyWith(updatedAt: DateTime.now().toUtc());
    final count = await _db.update(
      Tables.categories,
      _toMap(updated),
      where: 'id = ?',
      whereArgs: [category.id],
    );

    if (count == 0) {
      throw NotFoundException('Category with id ${category.id} not found');
    }
    return updated;
  }

  @override
  Future<void> archive(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await _db.update(
      Tables.categories,
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Category with id $id not found');
    }
  }

  @override
  Future<void> unarchive(String id) async {
    final count = await _db.update(
      Tables.categories,
      {'archived_at': null, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Category with id $id not found');
    }
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.categories,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Category with id $id not found');
    }
  }

  Map<String, dynamic> _toMap(Category category) {
    return {
      'id': category.id,
      'workspace_id': category.workspaceId,
      'name': category.name,
      'description': category.description,
      'icon_name': category.iconName,
      'created_at': category.createdAt.toIso8601String(),
      'updated_at': category.updatedAt.toIso8601String(),
      'archived_at': category.archivedAt?.toIso8601String(),
    };
  }

  Category _fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      iconName: map['icon_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }
}
