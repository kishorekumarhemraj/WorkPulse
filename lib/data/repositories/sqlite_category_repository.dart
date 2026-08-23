import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/repositories/category_repository.dart';

class SqliteCategoryRepository implements CategoryRepository {
  final DatabaseService _dbService;

  SqliteCategoryRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<List<Category>> getAllCategories({bool includeArchived = false}) async {
    final List<Map<String, Object?>> rows;
    if (includeArchived) {
      rows = await _db.query(Tables.categories, orderBy: 'name COLLATE NOCASE ASC');
    } else {
      rows = await _db.query(
        Tables.categories,
        where: 'archived_at IS NULL',
        orderBy: 'name COLLATE NOCASE ASC',
      );
    }
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    final rows = await _db.query(
      Tables.categories,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Category?> getCategoryByName(String name) async {
    final rows = await _db.query(
      Tables.categories,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> createCategory(Category category) async {
    await _db.insert(
      Tables.categories,
      _toMap(category),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updateCategory(Category category) async {
    await _db.update(
      Tables.categories,
      _toMap(category),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _db.delete(
      Tables.categories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Category _fromRow(Map<String, Object?> row) {
    return Category(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      iconName: row['icon_name'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      archivedAt: row['archived_at'] != null ? DateTime.parse(row['archived_at'] as String) : null,
    );
  }

  Map<String, Object?> _toMap(Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'description': category.description,
      'icon_name': category.iconName,
      'created_at': category.createdAt.toIso8601String(),
      'updated_at': category.updatedAt.toIso8601String(),
      'archived_at': category.archivedAt?.toIso8601String(),
    };
  }
}
