import 'package:workpulse/domain/models/person_model.dart';

abstract class PersonRepository {
  Future<List<Person>> getAllPeople();
  Future<Person?> getPersonById(String id);
  Future<Person?> getPersonByName(String name);
  Future<List<Person>> getPeopleForTask(String taskId);
  Future<List<Person>> getPeopleForSession(String sessionId);
  Future<void> createPerson(Person person);
  Future<void> updatePerson(Person person);
  Future<void> deletePerson(String id);
}
