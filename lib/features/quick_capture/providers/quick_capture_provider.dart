import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/category_model.dart';
import 'package:workpulse/domain/models/project_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/categories/providers/categories_provider.dart';
import 'package:workpulse/features/projects/providers/projects_provider.dart';
import 'package:workpulse/features/quick_capture/models/quick_capture_state.dart';
import 'package:workpulse/features/tasks/providers/work_items_provider.dart';
import 'package:workpulse/features/timer/providers/timer_provider.dart';

const _uuid = Uuid();

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
    Map<String, dynamic> attributeValues = const {},
  }) async {
    if (name.trim().isEmpty) return null;

    List<Project> projects;
    final cachedProjects = ref.read(projectsProvider).value;
    if (cachedProjects != null && cachedProjects.isNotEmpty) {
      projects = cachedProjects;
    } else {
      projects = await ref.read(projectsProvider.future);
    }

    List<Category> categories;
    final cachedCategories = ref.read(categoriesProvider).value;
    if (cachedCategories != null && cachedCategories.isNotEmpty) {
      categories = cachedCategories;
    } else {
      categories = await ref.read(categoriesProvider.future);
    }

    final projectId = state.selectedProjectId ?? (projects.isNotEmpty ? projects.first.id : null);
    final categoryId = state.selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : null);

    if (projectId == null || categoryId == null) return null;

    final created = await ref.read(workItemsProvider.notifier).createWorkItem(
          projectId: projectId,
          categoryId: categoryId,
          name: name.trim(),
          tagIds: state.selectedTagIds,
          peopleIds: state.selectedPeopleIds,
        );

    // Save custom attribute values if provided
    if (attributeValues.isNotEmpty) {
      final definitions = ref.read(attributeDefinitionsProvider).value ?? [];
      final taskDefs = definitions.where((d) => d.scope == AttributeScope.task && d.enabled && !d.isArchived).toList();
      final valuesToSave = <WorkItemAttributeValue>[];
      final now = DateTime.now().toUtc();

      for (final entry in attributeValues.entries) {
        final def = taskDefs.where((d) => d.id == entry.key).firstOrNull;
        if (def == null || entry.value == null) continue;

        String? textVal;
        double? numVal;
        bool? boolVal;
        DateTime? dateVal;
        String? optId;

        switch (def.type) {
          case AttributeType.text:
            textVal = entry.value.toString();
            break;
          case AttributeType.number:
            numVal = entry.value is num ? (entry.value as num).toDouble() : double.tryParse(entry.value.toString());
            break;
          case AttributeType.boolean:
            boolVal = entry.value == true;
            break;
          case AttributeType.singleSelect:
            optId = entry.value.toString();
            break;
          case AttributeType.multiSelect:
            textVal = (entry.value as List).join(',');
            break;
          case AttributeType.date:
            dateVal = entry.value is DateTime ? entry.value as DateTime : DateTime.tryParse(entry.value.toString());
            break;
        }

        valuesToSave.add(
          WorkItemAttributeValue(
            id: _uuid.v4(),
            workItemId: created.id,
            attributeDefinitionId: def.id,
            optionId: optId,
            textValue: textVal,
            numberValue: numVal,
            booleanValue: boolVal,
            dateValue: dateVal,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (valuesToSave.isNotEmpty) {
        await ref.read(workItemAttributeValuesControllerProvider).saveValues(created.id, valuesToSave);
      }
    }

    await ref.read(timerProvider.notifier).startTimer(created);
    reset();
    return created;
  }
}
