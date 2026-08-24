import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/person_model.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final peopleProvider = AsyncNotifierProvider<PeopleNotifier, List<Person>>(
  PeopleNotifier.new,
);

class PeopleNotifier extends AsyncNotifier<List<Person>> {
  @override
  Future<List<Person>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    final personRepo = ref.watch(personRepositoryProvider);
    return personRepo.getAll(workspaceId: workspace.id);
  }

  Future<Person> createPerson({
    required String name,
    String? email,
    String? team,
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final personRepo = ref.read(personRepositoryProvider);

    final now = DateTime.now().toUtc();
    final newPerson = Person(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      name: name.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      team: team?.trim().isEmpty == true ? null : team?.trim(),
      createdAt: now,
    );

    final created = await personRepo.create(newPerson);
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<Person> updatePerson(Person person) async {
    final personRepo = ref.read(personRepositoryProvider);
    final updated = await personRepo.update(person);
    ref.invalidateSelf();
    await future;
    return updated;
  }

  Future<void> deletePerson(String id) async {
    final personRepo = ref.read(personRepositoryProvider);
    await personRepo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
