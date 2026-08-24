import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final attributeDefinitionsProvider = AsyncNotifierProvider<
    AttributeDefinitionsNotifier, List<AttributeDefinition>>(
  AttributeDefinitionsNotifier.new,
);

class AttributeDefinitionsNotifier
    extends AsyncNotifier<List<AttributeDefinition>> {
  AttributeRepository get _repo => ref.read(attributeRepositoryProvider);

  @override
  Future<List<AttributeDefinition>> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    return _repo.getDefinitions(
      workspaceId: workspace.id,
      includeArchived: false,
    );
  }

  Future<AttributeDefinition> createDefinition({
    required String key,
    required String name,
    String? description,
    required AttributeType type,
    AttributeScope scope = AttributeScope.task,
    bool required = false,
    bool enabled = true,
    bool searchable = true,
    bool reportable = true,
    bool showInQuickCapture = true,
    bool showInTaskDetails = true,
    int displayOrder = 0,
  }) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final now = DateTime.now().toUtc();

    final definition = AttributeDefinition(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      key: key.trim().toLowerCase(),
      name: name.trim(),
      description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      type: type,
      scope: scope,
      required: required,
      enabled: enabled,
      searchable: searchable,
      reportable: reportable,
      showInQuickCapture: showInQuickCapture,
      showInTaskDetails: showInTaskDetails,
      displayOrder: displayOrder,
      createdAt: now,
      updatedAt: now,
    );

    final created = await _repo.createDefinition(definition);
    ref.invalidateSelf();
    return created;
  }

  Future<AttributeDefinition> updateDefinition(
      AttributeDefinition definition) async {
    final updated = await _repo.updateDefinition(
      definition.copyWith(updatedAt: DateTime.now().toUtc()),
    );
    ref.invalidateSelf();
    return updated;
  }

  Future<void> toggleEnabled(String id, bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final item = current.where((d) => d.id == id).firstOrNull;
    if (item == null) return;

    await _repo.updateDefinition(item.copyWith(
      enabled: enabled,
      updatedAt: DateTime.now().toUtc(),
    ));
    ref.invalidateSelf();
  }

  Future<void> archiveDefinition(String id) async {
    await _repo.archiveDefinition(id);
    ref.invalidateSelf();
  }

  Future<void> deleteDefinition(String id) async {
    await _repo.deleteDefinition(id);
    ref.invalidateSelf();
  }
}

final attributeOptionsFamilyProvider =
    FutureProvider.family<List<AttributeOption>, String>(
        (ref, definitionId) async {
  final repo = ref.watch(attributeRepositoryProvider);
  return repo.getOptions(definitionId, includeArchived: false);
});

final attributeOptionsControllerProvider =
    Provider<AttributeOptionsController>((ref) {
  return AttributeOptionsController(ref);
});

class AttributeOptionsController {
  final Ref _ref;
  AttributeOptionsController(this._ref);

  AttributeRepository get _repo => _ref.read(attributeRepositoryProvider);

  Future<AttributeOption> createOption({
    required String definitionId,
    required String value,
    required String label,
    String? colorHex,
    int displayOrder = 0,
    bool isDefault = false,
  }) async {
    final now = DateTime.now().toUtc();
    final option = AttributeOption(
      id: _uuid.v4(),
      attributeDefinitionId: definitionId,
      value: value.trim(),
      label: label.trim(),
      colorHex: colorHex,
      displayOrder: displayOrder,
      isDefault: isDefault,
      createdAt: now,
    );

    final created = await _repo.createOption(option);
    _ref.invalidate(attributeOptionsFamilyProvider(definitionId));
    return created;
  }

  Future<AttributeOption> updateOption(AttributeOption option) async {
    final updated = await _repo.updateOption(option);
    _ref.invalidate(
        attributeOptionsFamilyProvider(option.attributeDefinitionId));
    return updated;
  }

  Future<void> archiveOption(String definitionId, String optionId) async {
    await _repo.archiveOption(optionId);
    _ref.invalidate(attributeOptionsFamilyProvider(definitionId));
  }

  Future<void> deleteOption(String definitionId, String optionId) async {
    await _repo.deleteOption(optionId);
    _ref.invalidate(attributeOptionsFamilyProvider(definitionId));
  }
}

final workItemAttributeValuesFamilyProvider =
    FutureProvider.family<List<WorkItemAttributeValue>, String>(
        (ref, workItemId) async {
  final repo = ref.watch(attributeRepositoryProvider);
  return repo.getWorkItemValues(workItemId);
});

final workItemAttributeValuesControllerProvider =
    Provider<WorkItemAttributeValuesController>((ref) {
  return WorkItemAttributeValuesController(ref);
});

class WorkItemAttributeValuesController {
  final Ref _ref;
  WorkItemAttributeValuesController(this._ref);

  AttributeRepository get _repo => _ref.read(attributeRepositoryProvider);

  Future<void> setValue(WorkItemAttributeValue value) async {
    await _repo.setWorkItemValue(value);
    _ref.invalidate(workItemAttributeValuesFamilyProvider(value.workItemId));
  }

  Future<void> saveValues(
      String workItemId, List<WorkItemAttributeValue> values) async {
    for (final v in values) {
      await _repo.setWorkItemValue(v);
    }
    _ref.invalidate(workItemAttributeValuesFamilyProvider(workItemId));
  }
}

final sessionAttributeValuesFamilyProvider =
    FutureProvider.family<List<SessionAttributeValue>, String>(
        (ref, sessionId) async {
  final repo = ref.watch(attributeRepositoryProvider);
  return repo.getSessionValues(sessionId);
});
