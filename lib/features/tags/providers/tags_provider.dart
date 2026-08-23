import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/tag_model.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final tagsProvider = AsyncNotifierProvider<TagsNotifier, List<Tag>>(
  TagsNotifier.new,
);

class TagsNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    final tagRepo = ref.watch(tagRepositoryProvider);
    return tagRepo.getAll(workspaceId: workspace.id);
  }

  Future<Tag> createTag({
    required String name,
    String? colorHex,
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final tagRepo = ref.read(tagRepositoryProvider);

    final now = DateTime.now().toUtc();
    final newTag = Tag(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      name: name.trim(),
      colorHex: colorHex ?? '#30D158',
      createdAt: now,
    );

    final created = await tagRepo.create(newTag);
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<Tag> updateTag(Tag tag) async {
    final tagRepo = ref.read(tagRepositoryProvider);
    final updated = await tagRepo.update(tag);
    ref.invalidateSelf();
    await future;
    return updated;
  }

  Future<void> deleteTag(String id) async {
    final tagRepo = ref.read(tagRepositoryProvider);
    await tagRepo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
