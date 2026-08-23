import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/task_model.dart';
import 'package:workpulse/domain/repositories/task_repository.dart';

class SqliteTaskRepository implements TaskRepository {
  final DatabaseService _dbService;

  SqliteTaskRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<List<Task>> getAllTasks() async {
    final rows = await _db.query(
      Tables.tasks,
      orderBy: 'COALESCE(last_worked_at, updated_at) DESC',
    );
    return _populateTasks(rows);
  }

  @override
  Future<Task?> getTaskById(String id) async {
    final rows = await _db.query(
      Tables.tasks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final tasks = await _populateTasks(rows);
    return tasks.first;
  }

  @override
  Future<List<Task>> getTasksByProject(String projectId) async {
    final rows = await _db.query(
      Tables.tasks,
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'COALESCE(last_worked_at, updated_at) DESC',
    );
    return _populateTasks(rows);
  }

  @override
  Future<List<Task>> getTasksByCategory(String categoryId) async {
    final rows = await _db.query(
      Tables.tasks,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'COALESCE(last_worked_at, updated_at) DESC',
    );
    return _populateTasks(rows);
  }

  @override
  Future<List<Task>> searchTasks(String query) async {
    final sanitizedQuery = '%${query.trim()}%';
    final rows = await _db.rawQuery('''
      SELECT DISTINCT t.* FROM ${Tables.tasks} t
      LEFT JOIN ${Tables.projects} p ON t.project_id = p.id
      LEFT JOIN ${Tables.categories} c ON t.category_id = c.id
      LEFT JOIN ${Tables.taskTags} tt ON t.id = tt.task_id
      LEFT JOIN ${Tables.tags} tg ON tt.tag_id = tg.id
      LEFT JOIN ${Tables.taskPeople} tp ON t.id = tp.task_id
      LEFT JOIN ${Tables.people} pp ON tp.person_id = pp.id
      WHERE t.name LIKE ? ESCAPE '\\'
         OR t.jira_id LIKE ? ESCAPE '\\'
         OR t.notes LIKE ? ESCAPE '\\'
         OR p.name LIKE ? ESCAPE '\\'
         OR c.name LIKE ? ESCAPE '\\'
         OR tg.name LIKE ? ESCAPE '\\'
         OR pp.name LIKE ? ESCAPE '\\'
      ORDER BY COALESCE(t.last_worked_at, t.updated_at) DESC
    ''', [
      sanitizedQuery,
      sanitizedQuery,
      sanitizedQuery,
      sanitizedQuery,
      sanitizedQuery,
      sanitizedQuery,
      sanitizedQuery,
    ]);
    return _populateTasks(rows);
  }

  @override
  Future<List<Task>> getRecentTasks({int limit = 5}) async {
    final rows = await _db.query(
      Tables.tasks,
      orderBy: 'COALESCE(last_worked_at, updated_at) DESC',
      limit: limit,
    );
    return _populateTasks(rows);
  }

  @override
  Future<void> createTask(Task task) async {
    await _db.transaction((txn) async {
      await txn.insert(
        Tables.tasks,
        _toMap(task),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      for (final tagId in task.tagIds) {
        await txn.insert(
          Tables.taskTags,
          {'task_id': task.id, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final personId in task.peopleIds) {
        await txn.insert(
          Tables.taskPeople,
          {'task_id': task.id, 'person_id': personId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    await _db.transaction((txn) async {
      await txn.update(
        Tables.tasks,
        _toMap(task),
        where: 'id = ?',
        whereArgs: [task.id],
      );

      // Re-sync tags
      await txn.delete(
        Tables.taskTags,
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (final tagId in task.tagIds) {
        await txn.insert(
          Tables.taskTags,
          {'task_id': task.id, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Re-sync people
      await txn.delete(
        Tables.taskPeople,
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (final personId in task.peopleIds) {
        await txn.insert(
          Tables.taskPeople,
          {'task_id': task.id, 'person_id': personId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  @override
  Future<void> updateLastWorkedAt(String taskId, DateTime lastWorkedAt) async {
    await _db.update(
      Tables.tasks,
      {
        'last_worked_at': lastWorkedAt.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  @override
  Future<void> deleteTask(String id) async {
    await _db.delete(
      Tables.tasks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Task>> _populateTasks(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return [];

    final tasks = <Task>[];
    for (final row in rows) {
      final taskId = row['id'] as String;

      final tagRows = await _db.query(
        Tables.taskTags,
        columns: ['tag_id'],
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      final tagIds = tagRows.map((r) => r['tag_id'] as String).toList();

      final peopleRows = await _db.query(
        Tables.taskPeople,
        columns: ['person_id'],
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
      final peopleIds = peopleRows.map((r) => r['person_id'] as String).toList();

      tasks.add(Task(
        id: taskId,
        name: row['name'] as String,
        projectId: row['project_id'] as String,
        categoryId: row['category_id'] as String,
        jiraId: row['jira_id'] as String?,
        notes: row['notes'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        lastWorkedAt: row['last_worked_at'] != null
            ? DateTime.parse(row['last_worked_at'] as String)
            : null,
        tagIds: tagIds,
        peopleIds: peopleIds,
      ));
    }
    return tasks;
  }

  Map<String, Object?> _toMap(Task task) {
    return {
      'id': task.id,
      'name': task.name,
      'project_id': task.projectId,
      'category_id': task.categoryId,
      'jira_id': task.jiraId,
      'notes': task.notes,
      'created_at': task.createdAt.toIso8601String(),
      'updated_at': task.updatedAt.toIso8601String(),
      'last_worked_at': task.lastWorkedAt?.toIso8601String(),
    };
  }
}
