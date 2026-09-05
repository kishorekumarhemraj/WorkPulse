import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/repositories/session_repository.dart';

class SqliteSessionRepository implements SessionRepository {
  final DatabaseService _dbService;

  SqliteSessionRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Session?> getById(String id) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final sessionMap = results.first;
    final peopleIds = await _getPeopleIds(id);
    final tagIds = await _getTagIds(id);
    return _fromMap(sessionMap, peopleIds, tagIds);
  }

  @override
  Future<List<Session>> getByWorkItemId(String workItemId) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
      orderBy: 'start_time DESC',
    );

    return _hydrate(results);
  }

  @override
  Future<Session?> getLatestByWorkItemId(String workItemId) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final sessionMap = results.first;
    final id = sessionMap['id'] as String;
    final peopleIds = await _getPeopleIds(id);
    final tagIds = await _getTagIds(id);
    return _fromMap(sessionMap, peopleIds, tagIds);
  }

  @override
  Future<int> countByWorkItemId(String workItemId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${Tables.sessions} WHERE work_item_id = ?',
      [workItemId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['count'] as int?) ?? 0;
  }

  @override
  Future<List<Session>> getByDateRange(DateTime start, DateTime end) async {
    final results = await _db.query(
      Tables.sessions,
      where: 'start_time <= ? AND (end_time IS NULL OR end_time >= ?)',
      whereArgs: [
        end.toUtc().toIso8601String(),
        start.toUtc().toIso8601String(),
      ],
      orderBy: 'start_time DESC',
    );

    return _hydrate(results);
  }

  @override
  Future<Session?> getActiveSession() async {
    final results = await _db.query(
      Tables.sessions,
      where: 'end_time IS NULL',
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;

    final sessionMap = results.first;
    final id = sessionMap['id'] as String;
    final peopleIds = await _getPeopleIds(id);
    final tagIds = await _getTagIds(id);
    return _fromMap(sessionMap, peopleIds, tagIds);
  }

  @override
  Future<Session> create(Session session) async {
    try {
      await _db.transaction((txn) async {
        await txn.insert(
          Tables.sessions,
          _toMap(session),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        for (final personId in session.peopleIds) {
          await txn.insert(Tables.sessionPeople, {
            'session_id': session.id,
            'person_id': personId,
          });
        }

        for (final tagId in session.tagIds) {
          await txn.insert(Tables.sessionTags, {
            'session_id': session.id,
            'tag_id': tagId,
          });
        }
      });
      return session;
    } catch (e) {
      throw AppDatabaseException('Failed to create session: $e');
    }
  }

  @override
  Future<Session> update(Session session) async {
    try {
      await _db.transaction((txn) async {
        final count = await txn.update(
          Tables.sessions,
          _toMap(session),
          where: 'id = ?',
          whereArgs: [session.id],
        );

        if (count == 0) {
          throw NotFoundException('Session with id ${session.id} not found');
        }

        // Sync people
        await txn.delete(
          Tables.sessionPeople,
          where: 'session_id = ?',
          whereArgs: [session.id],
        );
        for (final personId in session.peopleIds) {
          await txn.insert(Tables.sessionPeople, {
            'session_id': session.id,
            'person_id': personId,
          });
        }

        // Sync tags
        await txn.delete(
          Tables.sessionTags,
          where: 'session_id = ?',
          whereArgs: [session.id],
        );
        for (final tagId in session.tagIds) {
          await txn.insert(Tables.sessionTags, {
            'session_id': session.id,
            'tag_id': tagId,
          });
        }
      });
      return session;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw AppDatabaseException('Failed to update session: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.sessions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Session with id $id not found');
    }
  }

  Future<List<String>> _getPeopleIds(String sessionId) async {
    final results = await _db.query(
      Tables.sessionPeople,
      columns: ['person_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return results.map((row) => row['person_id'] as String).toList();
  }

  Future<List<String>> _getTagIds(String sessionId) async {
    final results = await _db.query(
      Tables.sessionTags,
      columns: ['tag_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return results.map((row) => row['tag_id'] as String).toList();
  }

  /// Attaches people and tags to a page of session rows in three queries
  /// rather than `2n + 1`.
  ///
  /// The dashboard and every export read a whole date range through here; a
  /// month of tracking is hundreds of sessions, and the per-row lookups it
  /// used to do dominated the load time.
  Future<List<Session>> _hydrate(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return const [];

    final ids = rows.map((row) => row['id'] as String).toList();
    final peopleBySession = await _idsBySession(
      table: Tables.sessionPeople,
      column: 'person_id',
      sessionIds: ids,
    );
    final tagsBySession = await _idsBySession(
      table: Tables.sessionTags,
      column: 'tag_id',
      sessionIds: ids,
    );

    return [
      for (final row in rows)
        _fromMap(
          row,
          peopleBySession[row['id'] as String] ?? const [],
          tagsBySession[row['id'] as String] ?? const [],
        ),
    ];
  }

  /// One `IN (...)` query per join table, grouped back by session.
  ///
  /// Chunked because SQLite's default `SQLITE_MAX_VARIABLE_NUMBER` caps how
  /// many placeholders a statement may carry, and a wide date range can hold
  /// more sessions than that.
  Future<Map<String, List<String>>> _idsBySession({
    required String table,
    required String column,
    required List<String> sessionIds,
  }) async {
    const chunkSize = 500;
    final grouped = <String, List<String>>{};

    for (var start = 0; start < sessionIds.length; start += chunkSize) {
      final end = start + chunkSize < sessionIds.length
          ? start + chunkSize
          : sessionIds.length;
      final chunk = sessionIds.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');

      final rows = await _db.query(
        table,
        columns: ['session_id', column],
        where: 'session_id IN ($placeholders)',
        whereArgs: chunk,
      );

      for (final row in rows) {
        grouped
            .putIfAbsent(row['session_id'] as String, () => <String>[])
            .add(row[column] as String);
      }
    }

    return grouped;
  }

  Map<String, dynamic> _toMap(Session session) {
    return {
      'id': session.id,
      'work_item_id': session.workItemId,
      'category_id': session.categoryId,
      // Null is meaningful here: it is "inherit from the task", not "unset".
      'financial_classification': session.financialClassification?.value,
      'start_time': session.startTime.toStorageString(),
      'end_time': session.endTime?.toStorageString(),
      'notes': session.notes,
      'created_at': session.createdAt.toStorageString(),
    };
  }

  Session _fromMap(
    Map<String, dynamic> map,
    List<String> peopleIds,
    List<String> tagIds,
  ) {
    return Session(
      id: map['id'] as String,
      workItemId: map['work_item_id'] as String,
      categoryId: map['category_id'] as String?,
      financialClassification: map['financial_classification'] == null
          ? null
          : FinancialClassification.fromString(
              map['financial_classification'] as String?,
            ),
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      tagIds: tagIds,
      peopleIds: peopleIds,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
