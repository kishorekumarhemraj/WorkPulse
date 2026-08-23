import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/core/extensions/datetime_extensions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/domain/repositories/person_repository.dart';

class SqlitePersonRepository implements PersonRepository {
  final DatabaseService _dbService;

  SqlitePersonRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  @override
  Future<Person?> getById(String id) async {
    final results = await _db.query(
      Tables.people,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _fromMap(results.first);
  }

  @override
  Future<List<Person>> getAll({String? workspaceId}) async {
    final results = await _db.query(
      Tables.people,
      where: workspaceId != null ? 'workspace_id = ?' : null,
      whereArgs: workspaceId != null ? [workspaceId] : null,
      orderBy: 'name ASC',
    );
    return results.map(_fromMap).toList();
  }

  @override
  Future<Person> create(Person person) async {
    try {
      await _db.insert(
        Tables.people,
        _toMap(person),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return person;
    } catch (e) {
      throw AppDatabaseException('Failed to create person: $e');
    }
  }

  @override
  Future<Person> update(Person person) async {
    final count = await _db.update(
      Tables.people,
      _toMap(person),
      where: 'id = ?',
      whereArgs: [person.id],
    );

    if (count == 0) {
      throw NotFoundException('Person with id ${person.id} not found');
    }
    return person;
  }

  @override
  Future<void> delete(String id) async {
    final count = await _db.delete(
      Tables.people,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Person with id $id not found');
    }
  }

  Map<String, dynamic> _toMap(Person person) {
    return {
      'id': person.id,
      'workspace_id': person.workspaceId,
      'name': person.name,
      'email': person.email,
      'created_at': person.createdAt.toStorageString(),
    };
  }

  Person _fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
