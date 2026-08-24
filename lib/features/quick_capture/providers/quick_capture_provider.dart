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

final quickCaptureProvider =
    NotifierProvider.autoDispose<QuickCaptureNotifier, QuickCaptureState>(
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

  void setTagIds(List<String> ids) =>
      state = state.copyWith(selectedTagIds: ids);

  void setPeopleIds(List<String> ids) =>
      state = state.copyWith(selectedPeopleIds: ids);

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
    final sessionCatId = state.selectedCategoryId ?? task.categoryId;
    await ref.read(timerProvider.notifier).startTimer(
          task,
          categoryId: sessionCatId,
          peopleIds: state.selectedPeopleIds.isNotEmpty
              ? state.selectedPeopleIds
              : const [],
        );
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

    final projectId = state.selectedProjectId ??
        (projects.isNotEmpty ? projects.first.id : null);
    final categoryId = state.selectedCategoryId ??
        (categories.isNotEmpty ? categories.first.id : null);

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
      final taskDefs = definitions
          .where((d) =>
              d.scope == AttributeScope.task && d.enabled && !d.isArchived)
          .toList();
      final valuesToSave = <WorkItemAttributeValue>[];
      final now = DateTime.now().toUtc();

      for (final entry in attributeValues.entries) {
        final def = taskDefs.where((d) => d.id == entry.key).firstOrNull;
        if (def == null || entry.value == null) continue;

        switch (def.type) {
          case AttributeType.text:
            valuesToSave.add(
              _attributeValue(
                workItemId: created.id,
                definitionId: def.id,
                textValue: entry.value.toString(),
                now: now,
              ),
            );
            break;
          case AttributeType.number:
            valuesToSave.add(
              _attributeValue(
                workItemId: created.id,
                definitionId: def.id,
                numberValue: entry.value is num
                    ? (entry.value as num).toDouble()
                    : double.tryParse(entry.value.toString()),
                now: now,
              ),
            );
            break;
          case AttributeType.boolean:
            valuesToSave.add(
              _attributeValue(
                workItemId: created.id,
                definitionId: def.id,
                booleanValue: entry.value == true,
                now: now,
              ),
            );
            break;
          case AttributeType.singleSelect:
            valuesToSave.add(
              _attributeValue(
                workItemId: created.id,
                definitionId: def.id,
                optionId: entry.value.toString(),
                now: now,
              ),
            );
            break;
          case AttributeType.multiSelect:
            final selectedOptionIds = entry.value is Iterable
                ? (entry.value as Iterable)
                    .where((v) => v != null)
                    .map((v) => v.toString())
                : [entry.value.toString()];
            for (final optionId in selectedOptionIds) {
              valuesToSave.add(
                _attributeValue(
                  workItemId: created.id,
                  definitionId: def.id,
                  optionId: optionId,
                  now: now,
                ),
              );
            }
            break;
          case AttributeType.date:
            valuesToSave.add(
              _attributeValue(
                workItemId: created.id,
                definitionId: def.id,
                dateValue: entry.value is DateTime
                    ? entry.value as DateTime
                    : DateTime.tryParse(entry.value.toString()),
                now: now,
              ),
            );
            break;
        }
      }

      if (valuesToSave.isNotEmpty) {
        await ref
            .read(workItemAttributeValuesControllerProvider)
            .saveValues(created.id, valuesToSave);
      }
    }

    await ref.read(timerProvider.notifier).startTimer(
          created,
          categoryId: categoryId,
          peopleIds: state.selectedPeopleIds,
        );
    reset();
    return created;
  }

  WorkItemAttributeValue _attributeValue({
    required String workItemId,
    required String definitionId,
    required DateTime now,
    String? textValue,
    double? numberValue,
    bool? booleanValue,
    DateTime? dateValue,
    String? optionId,
  }) {
    return WorkItemAttributeValue(
      id: _uuid.v4(),
      workItemId: workItemId,
      attributeDefinitionId: definitionId,
      optionId: optionId,
      textValue: textValue,
      numberValue: numberValue,
      booleanValue: booleanValue,
      dateValue: dateValue,
      createdAt: now,
      updatedAt: now,
    );
  }
}
