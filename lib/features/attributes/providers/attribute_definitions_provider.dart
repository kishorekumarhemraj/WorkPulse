import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workpulse/data/providers/repository_providers.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

const _uuid = Uuid();

final attributeDefinitionsProvider = AsyncNotifierProvider<AttributeDefinitionsNotifier, List<AttributeDefinition>>(
  AttributeDefinitionsNotifier.new,
);

class AttributeDefinitionsNotifier extends AsyncNotifier<List<AttributeDefinition>> {
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
      description: description?.trim().isEmpty == true ? null : description?.trim(),
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

  Future<AttributeDefinition> updateDefinition(AttributeDefinition definition) async {
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

final attributeOptionsFamilyProvider = AsyncNotifierProvider.family<AttributeOptionsNotifier, List<AttributeOption>, String>(
  AttributeOptionsNotifier.new,
);

class AttributeOptionsNotifier extends FamilyAsyncNotifier<List<AttributeOption>, String> {
  AttributeRepository get _repo => ref.read(attributeRepositoryProvider);

  @override
  Future<List<AttributeOption>> build(String arg) async {
    return _repo.getOptions(arg, includeArchived: false);
  }

  Future<AttributeOption> createOption({
    required String value,
    required String label,
    String? colorHex,
    int displayOrder = 0,
    bool isDefault = false,
  }) async {
    final now = DateTime.now().toUtc();
    final option = AttributeOption(
      id: _uuid.v4(),
      attributeDefinitionId: arg,
      value: value.trim(),
      label: label.trim(),
      colorHex: colorHex,
      displayOrder: displayOrder,
      isDefault: isDefault,
      createdAt: now,
    );

    final created = await _repo.createOption(option);
    ref.invalidateSelf();
    return created;
  }

  Future<AttributeOption> updateOption(AttributeOption option) async {
    final updated = await _repo.updateOption(option);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> archiveOption(String optionId) async {
    await _repo.archiveOption(optionId);
    ref.invalidateSelf();
  }

  Future<void> deleteOption(String optionId) async {
    await _repo.deleteOption(optionId);
    ref.invalidateSelf();
  }
}

final workItemAttributeValuesFamilyProvider = AsyncNotifierProvider.family<WorkItemAttributeValuesNotifier, List<WorkItemAttributeValue>, String>(
  WorkItemAttributeValuesNotifier.new,
);

class WorkItemAttributeValuesNotifier extends FamilyAsyncNotifier<List<WorkItemAttributeValue>, String> {
  AttributeRepository get _repo => ref.read(attributeRepositoryProvider);

  @override
  Future<List<WorkItemAttributeValue>> build(String arg) async {
    return _repo.getWorkItemValues(arg);
  }

  Future<void> setValue(WorkItemAttributeValue value) async {
    await _repo.setWorkItemValue(value);
    ref.invalidateSelf();
  }

  Future<void> saveValues(List<WorkItemAttributeValue> values) async {
    for (final v in values) {
      await _repo.setWorkItemValue(v);
    }
    ref.invalidateSelf();
  }
}
