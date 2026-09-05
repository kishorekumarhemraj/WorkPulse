import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/reminder_rule.dart';
import 'package:workpulse/domain/models/work_item_reminder_record.dart';
import 'package:workpulse/domain/repositories/reminder_repository.dart';

class SqliteReminderRepository implements ReminderRepository {
  final DatabaseService _dbService;

  SqliteReminderRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<void> recordDelivery(WorkItemReminderRecord record) async {
    await _db.insert(
      Tables.workItemReminders,
      _toMap(record),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<WorkItemReminderRecord>> getForWorkItem(String workItemId) async {
    final results = await _db.query(
      Tables.workItemReminders,
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
      orderBy: 'delivered_at DESC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<List<WorkItemReminderRecord>> getAll({int? limit}) async {
    final results = await _db.query(
      Tables.workItemReminders,
      orderBy: 'delivered_at DESC',
      limit: limit,
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<Set<String>> getDeliveredKeys() async {
    final results = await _db.rawQuery('''
      SELECT work_item_id, rule, occurrence_key
      FROM ${Tables.workItemReminders}
    ''');
    final keys = <String>{};
    for (final row in results) {
      final workItemId = row['work_item_id'] as String;
      final rule = row['rule'] as String;
      final occurrenceKey = row['occurrence_key'] as String;
      keys.add('$workItemId:$rule:$occurrenceKey');
    }
    return keys;
  }

  @override
  Future<void> markRead(String id, DateTime readAt) async {
    await _db.update(
      Tables.workItemReminders,
      {'read_at': readAt.toStorageString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markAllRead(DateTime readAt) async {
    await _db.update(
      Tables.workItemReminders,
      {'read_at': readAt.toStorageString()},
      where: 'read_at IS NULL',
    );
  }

  @override
  Future<void> snooze(String id, DateTime snoozedUntil) async {
    await _db.update(
      Tables.workItemReminders,
      {'snoozed_until': snoozedUntil.toStorageString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> pruneOld(Duration olderThan) async {
    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    await _db.delete(
      Tables.workItemReminders,
      where: 'delivered_at < ?',
      whereArgs: [cutoff.toStorageString()],
    );
  }

  Map<String, dynamic> _toMap(WorkItemReminderRecord record) {
    return {
      'id': record.id,
      'work_item_id': record.workItemId,
      'rule': record.rule.name,
      'occurrence_key': record.occurrenceKey,
      'anchor_date': record.anchorDate.toStorageString(),
      'delivered_at': record.deliveredAt.toStorageString(),
      'read_at': record.readAt?.toStorageString(),
      'snoozed_until': record.snoozedUntil?.toStorageString(),
    };
  }

  WorkItemReminderRecord _fromMap(Map<String, dynamic> map) {
    return WorkItemReminderRecord(
      id: map['id'] as String,
      workItemId: map['work_item_id'] as String,
      rule: ReminderRule.values.firstWhere(
        (r) => r.name == map['rule'],
        orElse: () => ReminderRule.dueMorning,
      ),
      occurrenceKey: map['occurrence_key'] as String,
      anchorDate: CalendarDate.parse(map['anchor_date'] as String),
      deliveredAt: DateTime.parse(map['delivered_at'] as String),
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      snoozedUntil: map['snoozed_until'] != null
          ? DateTime.parse(map['snoozed_until'] as String)
          : null,
    );
  }
}
