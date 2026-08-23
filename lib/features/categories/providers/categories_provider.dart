import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final categoriesProvider = AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    final categoryRepo = ref.watch(categoryRepositoryProvider);
    return categoryRepo.getAll(workspaceId: workspace.id, includeArchived: false);
  }

  Future<Category> createCategory({
    required String name,
    String? description,
    String? iconName,
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final categoryRepo = ref.read(categoryRepositoryProvider);

    final now = DateTime.now().toUtc();
    final newCategory = Category(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      name: name.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      iconName: iconName ?? 'folder',
      createdAt: now,
      updatedAt: now,
    );

    final created = await categoryRepo.create(newCategory);
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<Category> updateCategory(Category category) async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final updated = await categoryRepo.update(category);
    ref.invalidateSelf();
    await future;
    return updated;
  }

  Future<void> archiveCategory(String id) async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    await categoryRepo.archive(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> unarchiveCategory(String id) async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    await categoryRepo.unarchive(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteCategory(String id) async {
    final categoryRepo = ref.read(categoryRepositoryProvider);
    await categoryRepo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
