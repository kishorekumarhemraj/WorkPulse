import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

class WorkItemFilter extends Equatable {
  final String searchQuery;
  final String? projectId;
  final String? categoryId;
  final String? tagId;
  final String? personId;
  final bool includeArchived;

  const WorkItemFilter({
    this.searchQuery = '',
    this.projectId,
    this.categoryId,
    this.tagId,
    this.personId,
    this.includeArchived = false,
  });

  WorkItemFilter copyWith({
    String? searchQuery,
    String? projectId,
    bool clearProject = false,
    String? categoryId,
    bool clearCategory = false,
    String? tagId,
    bool clearTag = false,
    String? personId,
    bool clearPerson = false,
    bool? includeArchived,
  }) {
    return WorkItemFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      tagId: clearTag ? null : (tagId ?? this.tagId),
      personId: clearPerson ? null : (personId ?? this.personId),
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      projectId != null ||
      categoryId != null ||
      tagId != null ||
      personId != null ||
      includeArchived;

  @override
  List<Object?> get props => [
        searchQuery,
        projectId,
        categoryId,
        tagId,
        personId,
        includeArchived,
      ];
}

final workItemFilterProvider =
    NotifierProvider<WorkItemFilterNotifier, WorkItemFilter>(
  WorkItemFilterNotifier.new,
);

class WorkItemFilterNotifier extends Notifier<WorkItemFilter> {
  @override
  WorkItemFilter build() => const WorkItemFilter();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setProject(String? projectId) {
    if (projectId == null) {
      state = state.copyWith(clearProject: true);
    } else {
      state = state.copyWith(projectId: projectId);
    }
  }

  void setCategory(String? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(categoryId: categoryId);
    }
  }

  void setTag(String? tagId) {
    if (tagId == null) {
      state = state.copyWith(clearTag: true);
    } else {
      state = state.copyWith(tagId: tagId);
    }
  }

  void setPerson(String? personId) {
    if (personId == null) {
      state = state.copyWith(clearPerson: true);
    } else {
      state = state.copyWith(personId: personId);
    }
  }

  void toggleIncludeArchived() {
    state = state.copyWith(includeArchived: !state.includeArchived);
  }

  void reset() {
    state = const WorkItemFilter();
  }
}

final workItemsProvider =
    AsyncNotifierProvider<WorkItemsNotifier, List<WorkItem>>(
  WorkItemsNotifier.new,
);

class WorkItemsNotifier extends AsyncNotifier<List<WorkItem>> {
  @override
  Future<List<WorkItem>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    final filter = ref.watch(workItemFilterProvider);
    final workItemRepo = ref.watch(workItemRepositoryProvider);

    List<WorkItem> items;
    if (filter.searchQuery.trim().isNotEmpty) {
      items = await workItemRepo.search(
        filter.searchQuery,
        workspaceId: workspace.id,
        limit: 100,
      );
    } else {
      items = await workItemRepo.getAll(
        workspaceId: workspace.id,
        includeArchived: filter.includeArchived,
      );
    }

    // Apply client-side filters for project, category, tag, and person
    return items.where((item) {
      if (!filter.includeArchived && item.isArchived) {
        return false;
      }
      if (filter.projectId != null && item.projectId != filter.projectId) {
        return false;
      }
      if (filter.categoryId != null && item.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.tagId != null && !item.tagIds.contains(filter.tagId)) {
        return false;
      }
      if (filter.personId != null &&
          !item.peopleIds.contains(filter.personId)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<WorkItem> createWorkItem({
    required String name,
    required String projectId,
    required String categoryId,
    String? notes,
    List<String> tagIds = const [],
    List<String> peopleIds = const [],
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final workItemRepo = ref.read(workItemRepositoryProvider);

    final now = DateTime.now().toUtc();
    final newItem = WorkItem(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      name: name.trim(),
      projectId: projectId,
      categoryId: categoryId,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      tagIds: tagIds,
      peopleIds: peopleIds,
      createdAt: now,
      updatedAt: now,
    );

    final created = await workItemRepo.create(newItem);
    ref.invalidateSelf();
    await future;
    return created;
  }

  Future<WorkItem> updateWorkItem(WorkItem item) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    final updated = await workItemRepo.update(item);
    ref.invalidateSelf();
    await future;
    return updated;
  }

  Future<void> archiveWorkItem(String id) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    await workItemRepo.archive(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> unarchiveWorkItem(String id) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    await workItemRepo.unarchive(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteWorkItem(String id) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    await workItemRepo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}
