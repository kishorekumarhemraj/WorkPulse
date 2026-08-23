import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/models/quick_capture_state.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

final quickCaptureProvider = NotifierProvider<QuickCaptureNotifier, QuickCaptureState>(
  QuickCaptureNotifier.new,
);

class QuickCaptureNotifier extends Notifier<QuickCaptureState> {
  @override
  QuickCaptureState build() {
    final projects = ref.watch(projectsProvider).value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];

    final defaultProjId = projects.isNotEmpty ? projects.first.id : null;
    final defaultCatId = categories.isNotEmpty ? categories.first.id : null;

    return QuickCaptureState(
      selectedProjectId: defaultProjId,
      selectedCategoryId: defaultCatId,
    );
  }

  void setQuery(String query) {
    state = state.copyWith(query: query, selectedIndex: 0);
  }

  void setSelectedIndex(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void selectPrevious() {
    if (state.selectedIndex > 0) {
      state = state.copyWith(selectedIndex: state.selectedIndex - 1);
    }
  }

  void selectNext(int maxCount) {
    if (maxCount > 0 && state.selectedIndex < maxCount - 1) {
      state = state.copyWith(selectedIndex: state.selectedIndex + 1);
    }
  }

  void setProject(String? projectId) {
    state = state.copyWith(selectedProjectId: projectId);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void toggleTag(String tagId) {
    final updated = List<String>.from(state.selectedTagIds);
    if (updated.contains(tagId)) {
      updated.remove(tagId);
    } else {
      updated.add(tagId);
    }
    state = state.copyWith(selectedTagIds: updated);
  }

  void togglePerson(String personId) {
    final updated = List<String>.from(state.selectedPeopleIds);
    if (updated.contains(personId)) {
      updated.remove(personId);
    } else {
      updated.add(personId);
    }
    state = state.copyWith(selectedPeopleIds: updated);
  }

  void reset() {
    final projects = ref.read(projectsProvider).value ?? [];
    final categories = ref.read(categoriesProvider).value ?? [];

    state = QuickCaptureState(
      selectedProjectId: projects.isNotEmpty ? projects.first.id : null,
      selectedCategoryId: categories.isNotEmpty ? categories.first.id : null,
    );
  }

  /// Starts tracking an existing work item.
  Future<void> startExistingTask(WorkItem task) async {
    await ref.read(timerProvider.notifier).startTimer(task);
    reset();
  }

  /// Creates a new work item and immediately begins time tracking.
  Future<WorkItem?> createAndStartTask({
    required String name,
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null || name.trim().isEmpty) return null;

    final projectId = state.selectedProjectId;
    final categoryId = state.selectedCategoryId;

    if (projectId == null || categoryId == null) return null;

    final created = await ref.read(workItemsProvider.notifier).createWorkItem(
          workspaceId: workspace.id,
          projectId: projectId,
          categoryId: categoryId,
          name: name.trim(),
          tagIds: state.selectedTagIds,
          peopleIds: state.selectedPeopleIds,
        );

    await ref.read(timerProvider.notifier).startTimer(created);
    reset();
    return created;
  }
}
