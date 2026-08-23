import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/repositories/person_repository.dart';

class SqlitePersonRepository implements PersonRepository {
  final DatabaseService _dbService;

  SqlitePersonRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<List<Person>> getAllPeople() async {
    final rows = await _db.query(Tables.people, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Person?> getPersonById(String id) async {
    final rows = await _db.query(
      Tables.people,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Person?> getPersonByName(String name) async {
    final rows = await _db.query(
      Tables.people,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<Person>> getPeopleForTask(String taskId) async {
    final rows = await _db.rawQuery('''
      SELECT p.* FROM ${Tables.people} p
      INNER JOIN ${Tables.taskPeople} tp ON p.id = tp.person_id
      WHERE tp.task_id = ?
      ORDER BY p.name COLLATE NOCASE ASC
    ''', [taskId]);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Person>> getPeopleForSession(String sessionId) async {
    final rows = await _db.rawQuery('''
      SELECT p.* FROM ${Tables.people} p
      INNER JOIN ${Tables.sessionPeople} sp ON p.id = sp.person_id
      WHERE sp.session_id = ?
      ORDER BY p.name COLLATE NOCASE ASC
    ''', [sessionId]);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> createPerson(Person person) async {
    await _db.insert(
      Tables.people,
      _toMap(person),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  @override
  Future<void> updatePerson(Person person) async {
    await _db.update(
      Tables.people,
      _toMap(person),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  @override
  Future<void> deletePerson(String id) async {
    await _db.delete(
      Tables.people,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Person _fromRow(Map<String, Object?> row) {
    return Person(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, Object?> _toMap(Person person) {
    return {
      'id': person.id,
      'name': person.name,
      'email': person.email,
      'created_at': person.createdAt.toIso8601String(),
    };
  }
}
