import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/repositories/work_item_repository.dart';

class SqliteWorkItemRepository implements WorkItemRepository {
  final DatabaseService _dbService;

  SqliteWorkItemRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<WorkItem?> getById(String id) async {
    final results = await _db.query(
      Tables.workItems,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final itemMap = results.first;
    final tagIds = await _getTagIds(id);
    final peopleIds = await _getPeopleIds(id);

    return _fromMap(itemMap, tagIds, peopleIds);
  }

  @override
  Future<List<WorkItem>> getAll(
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
      Tables.workItems,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
    );

    final workItems = <WorkItem>[];
    for (final map in results) {
      final id = map['id'] as String;
      final tagIds = await _getTagIds(id);
      final peopleIds = await _getPeopleIds(id);
      workItems.add(_fromMap(map, tagIds, peopleIds));
    }
    return workItems;
  }

  @override
  Future<List<WorkItem>> getByProjectId(String projectId,
      {bool includeArchived = false}) async {
    final where = includeArchived
        ? 'project_id = ?'
        : 'project_id = ? AND archived_at IS NULL';
    final results = await _db.query(
      Tables.workItems,
      where: where,
      whereArgs: [projectId],
      orderBy: 'updated_at DESC',
    );

    final workItems = <WorkItem>[];
    for (final map in results) {
      final id = map['id'] as String;
      final tagIds = await _getTagIds(id);
      final peopleIds = await _getPeopleIds(id);
      workItems.add(_fromMap(map, tagIds, peopleIds));
    }
    return workItems;
  }

  @override
  Future<List<WorkItem>> getByCategoryId(String categoryId,
      {bool includeArchived = false}) async {
    final where = includeArchived
        ? 'category_id = ?'
        : 'category_id = ? AND archived_at IS NULL';
    final results = await _db.query(
      Tables.workItems,
      where: where,
      whereArgs: [categoryId],
      orderBy: 'updated_at DESC',
    );

    final workItems = <WorkItem>[];
    for (final map in results) {
      final id = map['id'] as String;
      final tagIds = await _getTagIds(id);
      final peopleIds = await _getPeopleIds(id);
      workItems.add(_fromMap(map, tagIds, peopleIds));
    }
    return workItems;
  }

  @override
  Future<List<WorkItem>> search(String query,
      {String? workspaceId, int limit = 20}) async {
    final sanitizedQuery = '%${query.trim()}%';
    final whereClauses = ['name LIKE ?', 'archived_at IS NULL'];
    final whereArgs = <dynamic>[sanitizedQuery];

    if (workspaceId != null) {
      whereClauses.add('workspace_id = ?');
      whereArgs.add(workspaceId);
    }

    final results = await _db.query(
      Tables.workItems,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'COALESCE(last_worked_at, updated_at) DESC',
      limit: limit,
    );

    final workItems = <WorkItem>[];
    for (final map in results) {
      final id = map['id'] as String;
      final tagIds = await _getTagIds(id);
      final peopleIds = await _getPeopleIds(id);
      workItems.add(_fromMap(map, tagIds, peopleIds));
    }
    return workItems;
  }

  @override
  Future<List<WorkItem>> getRecent(
      {String? workspaceId, int limit = 10}) async {
    final whereClauses = ['archived_at IS NULL'];
    final whereArgs = <dynamic>[];

    if (workspaceId != null) {
      whereClauses.add('workspace_id = ?');
      whereArgs.add(workspaceId);
    }

    final results = await _db.query(
      Tables.workItems,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'COALESCE(last_worked_at, updated_at) DESC',
      limit: limit,
    );

    final workItems = <WorkItem>[];
    for (final map in results) {
      final id = map['id'] as String;
      final tagIds = await _getTagIds(id);
      final peopleIds = await _getPeopleIds(id);
      workItems.add(_fromMap(map, tagIds, peopleIds));
    }
    return workItems;
  }

  @override
  Future<WorkItem> create(WorkItem workItem) async {
    try {
      await _db.transaction((txn) async {
        await txn.insert(
          Tables.workItems,
          _toMap(workItem),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        for (final tagId in workItem.tagIds) {
          await txn.insert(Tables.workItemTags, {
            'work_item_id': workItem.id,
            'tag_id': tagId,
          });
        }

        for (final personId in workItem.peopleIds) {
          await txn.insert(Tables.workItemPeople, {
            'work_item_id': workItem.id,
            'person_id': personId,
          });
        }
      });
      return workItem;
    } catch (e) {
      throw AppDatabaseException('Failed to create work item: $e');
    }
  }

  @override
  Future<WorkItem> update(WorkItem workItem) async {
    final updated = workItem.copyWith(updatedAt: DateTime.now().toUtc());

    try {
      await _db.transaction((txn) async {
        final count = await txn.update(
          Tables.workItems,
          _toMap(updated),
          where: 'id = ?',
          whereArgs: [workItem.id],
        );

        if (count == 0) {
          throw NotFoundException('WorkItem with id ${workItem.id} not found');
        }

        // Sync tags
        await txn.delete(
          Tables.workItemTags,
          where: 'work_item_id = ?',
          whereArgs: [workItem.id],
        );
        for (final tagId in workItem.tagIds) {
          await txn.insert(Tables.workItemTags, {
            'work_item_id': workItem.id,
            'tag_id': tagId,
          });
        }

        // Sync people
        await txn.delete(
          Tables.workItemPeople,
          where: 'work_item_id = ?',
          whereArgs: [workItem.id],
        );
        for (final personId in workItem.peopleIds) {
          await txn.insert(Tables.workItemPeople, {
            'work_item_id': workItem.id,
            'person_id': personId,
          });
        }
      });
      return updated;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw AppDatabaseException('Failed to update work item: $e');
    }
  }

  @override
  Future<void> updateLastWorkedAt(String id, DateTime timestamp) async {
    final count = await _db.update(
      Tables.workItems,
      {
        'last_worked_at': timestamp.toStorageString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('WorkItem with id $id not found');
    }
  }

  @override
  Future<void> archive(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await _db.update(
      Tables.workItems,
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('WorkItem with id $id not found');
    }
  }

  @override
  Future<void> unarchive(String id) async {
    final count = await _db.update(
      Tables.workItems,
      {
        'archived_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('WorkItem with id $id not found');
    }
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.workItems,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('WorkItem with id $id not found');
    }
  }

  Future<List<String>> _getTagIds(String workItemId) async {
    final results = await _db.query(
      Tables.workItemTags,
      columns: ['tag_id'],
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
    );
    return results.map((row) => row['tag_id'] as String).toList();
  }

  Future<List<String>> _getPeopleIds(String workItemId) async {
    final results = await _db.query(
      Tables.workItemPeople,
      columns: ['person_id'],
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
    );
    return results.map((row) => row['person_id'] as String).toList();
  }

  Map<String, dynamic> _toMap(WorkItem item) {
    return {
      'id': item.id,
      'workspace_id': item.workspaceId,
      'name': item.name,
      'project_id': item.projectId,
      'category_id': item.categoryId,
      'notes': item.notes,
      'created_at': item.createdAt.toStorageString(),
      'updated_at': item.updatedAt.toStorageString(),
      'last_worked_at': item.lastWorkedAt?.toStorageString(),
      'archived_at': item.archivedAt?.toStorageString(),
    };
  }

  WorkItem _fromMap(
      Map<String, dynamic> map, List<String> tagIds, List<String> peopleIds) {
    return WorkItem(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      projectId: map['project_id'] as String,
      categoryId: map['category_id'] as String,
      notes: map['notes'] as String?,
      tagIds: tagIds,
      peopleIds: peopleIds,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastWorkedAt: map['last_worked_at'] != null
          ? DateTime.parse(map['last_worked_at'] as String)
          : null,
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }
}
