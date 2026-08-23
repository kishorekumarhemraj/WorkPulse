import 'package:workpulse/domain/models/person_model.dart';

abstract class PersonRepository {
  Future<Person?> getById(String id);
  Future<List<Person>> getAll({String? workspaceId});
  Future<Person> create(Person person);
  Future<Person> update(Person person);
  Future<void> delete(String id);
}
