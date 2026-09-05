import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/calendar_date.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/domain/models/work_item_plan.dart';
import 'package:workpulse/features/reminders/providers/reminder_scheduler_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

enum PlanFilter {
  all,
  overdue,
  dueToday,
  dueThisWeek,
  scheduled,
  unplanned,
  completed,
}

enum WorkItemSort {
  recent,
  dueDate,
  name,
}

class WorkItemFilter extends Equatable {
  final String searchQuery;
  final String? projectId;
  final String? categoryId;
  final String? tagId;
  final String? personId;
  final PlanFilter planFilter;
  final WorkItemSort sort;
  final bool includeArchived;

  const WorkItemFilter({
    this.searchQuery = '',
    this.projectId,
    this.categoryId,
    this.tagId,
    this.personId,
    this.planFilter = PlanFilter.all,
    this.sort = WorkItemSort.recent,
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
    PlanFilter? planFilter,
    WorkItemSort? sort,
    bool? includeArchived,
  }) {
    return WorkItemFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      tagId: clearTag ? null : (tagId ?? this.tagId),
      personId: clearPerson ? null : (personId ?? this.personId),
      planFilter: planFilter ?? this.planFilter,
      sort: sort ?? this.sort,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      projectId != null ||
      categoryId != null ||
      tagId != null ||
      personId != null ||
      planFilter != PlanFilter.all ||
      includeArchived;

  List<WorkItem> filter(List<WorkItem> items, {CalendarDate? today}) {
    final curToday = today ?? CalendarDate.fromLocal(DateTime.now());
    final filtered = items.where((item) {
      if (!includeArchived && item.isArchived) {
        return false;
      }
      if (searchQuery.isNotEmpty &&
          !item.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
          !(item.notes?.toLowerCase().contains(searchQuery.toLowerCase()) ??
              false)) {
        return false;
      }
      if (projectId != null && item.projectId != projectId) {
        return false;
      }
      if (categoryId != null && item.categoryId != categoryId) {
        return false;
      }
      if (tagId != null && !item.tagIds.contains(tagId)) {
        return false;
      }
      if (personId != null && !item.peopleIds.contains(personId)) {
        return false;
      }

      switch (planFilter) {
        case PlanFilter.all:
          return true;
        case PlanFilter.overdue:
          return item.plan.statusOn(curToday) == PlanStatus.overdue;
        case PlanFilter.dueToday:
          return item.plan.statusOn(curToday) == PlanStatus.dueToday;
        case PlanFilter.dueThisWeek:
          if (item.plan.isComplete || item.plan.due == null) return false;
          final diff = item.plan.due!.differenceInDays(curToday);
          return diff >= 0 && diff <= 7;
        case PlanFilter.scheduled:
          return item.plan.statusOn(curToday) == PlanStatus.scheduled;
        case PlanFilter.unplanned:
          return item.plan.statusOn(curToday) == PlanStatus.unplanned;
        case PlanFilter.completed:
          return item.plan.statusOn(curToday) == PlanStatus.completed;
      }
    }).toList();

    // Apply client-side sorting
    filtered.sort((a, b) {
      switch (sort) {
        case WorkItemSort.recent:
          final aTime = a.lastWorkedAt ?? a.updatedAt;
          final bTime = b.lastWorkedAt ?? b.updatedAt;
          return bTime.compareTo(aTime);
        case WorkItemSort.dueDate:
          final aDue = a.plan.due;
          final bDue = b.plan.due;
          if (aDue != null && bDue != null) {
            final cmp = aDue.compareTo(bDue);
            if (cmp != 0) return cmp;
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (aDue != null && bDue == null) return -1;
          if (aDue == null && bDue != null) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        case WorkItemSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return filtered;
  }

  @override
  List<Object?> get props => [
        searchQuery,
        projectId,
        categoryId,
        tagId,
        personId,
        planFilter,
        sort,
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

  void setPlanFilter(PlanFilter planFilter) {
    state = state.copyWith(planFilter: planFilter);
  }

  void setSort(WorkItemSort sort) {
    state = state.copyWith(sort: sort);
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

/// Returns all unarchived work items for the active workspace without the toolbar
/// search/filter state. Used by the Planner view.
final unfilteredWorkItemsProvider = FutureProvider<List<WorkItem>>((ref) async {
  ref.watch(workItemsProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final workItemRepo = ref.watch(workItemRepositoryProvider);
  return workItemRepo.getAll(
    workspaceId: workspace.id,
    includeArchived: false,
  );
});

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

    final today = CalendarDate.fromLocal(DateTime.now());
    return filter.filter(items, today: today);
  }

  Future<WorkItem> createWorkItem({
    required String name,
    required String projectId,
    required String categoryId,
    FinancialClassification classification = FinancialClassification.none,
    WorkItemPlan plan = const WorkItemPlan.unplanned(),
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
      financialClassification: classification,
      plan: plan,
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

  Future<void> setPlan(String id, WorkItemPlan plan) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    await workItemRepo.updatePlan(id, plan);
    ref.invalidateSelf();
    await future;
    try {
      await ref.read(reminderSchedulerProvider).checkReminders();
    } catch (_) {}
  }

  Future<void> completeWorkItem(String id, [DateTime? completedAt]) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    final existing = await workItemRepo.getById(id);
    if (existing == null) return;
    final updatedPlan = existing.plan.copyWith(
      completedAt: (completedAt ?? DateTime.now()).toUtc(),
    );
    await workItemRepo.updatePlan(id, updatedPlan);
    ref.invalidateSelf();
    await future;
    try {
      await ref.read(reminderSchedulerProvider).checkReminders();
    } catch (_) {}
  }

  Future<void> reopenWorkItem(String id) async {
    final workItemRepo = ref.read(workItemRepositoryProvider);
    final existing = await workItemRepo.getById(id);
    if (existing == null) return;
    final updatedPlan = existing.plan.copyWith(clearCompletedAt: true);
    await workItemRepo.updatePlan(id, updatedPlan);
    ref.invalidateSelf();
    await future;
    try {
      await ref.read(reminderSchedulerProvider).checkReminders();
    } catch (_) {}
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
