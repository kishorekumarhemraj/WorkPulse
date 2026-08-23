import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workpulse/core/database/database_service.dart';
import 'package:workpulse/core/errors/app_exceptions.dart';
import 'package:workpulse/data/database/tables.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/repositories/attribute_repository.dart';

class SqliteAttributeRepository implements AttributeRepository {
  final DatabaseService _dbService;

  SqliteAttributeRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService();

  Database get _db => _dbService.database;

  // --- Attribute Definitions ---

  @override
  Future<AttributeDefinition?> getDefinitionById(String id) async {
    final results = await _db.query(
      Tables.attributeDefinitions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return _defFromMap(results.first);
  }

  @override
  Future<AttributeDefinition?> getDefinitionByKey(String workspaceId, String key) async {
    final results = await _db.query(
      Tables.attributeDefinitions,
      where: 'workspace_id = ? AND key = ?',
      whereArgs: [workspaceId, key],
    );

    if (results.isEmpty) return null;
    return _defFromMap(results.first);
  }

  @override
  Future<List<AttributeDefinition>> getDefinitions({
    String? workspaceId,
    AttributeScope? scope,
    bool includeArchived = false,
  }) async {
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (workspaceId != null) {
      whereClauses.add('workspace_id = ?');
      whereArgs.add(workspaceId);
    }
    if (scope != null) {
      whereClauses.add('scope = ?');
      whereArgs.add(scope.value);
    }
    if (!includeArchived) {
      whereClauses.add('archived_at IS NULL');
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await _db.query(
      Tables.attributeDefinitions,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'display_order ASC, name ASC',
    );
    return results.map(_defFromMap).toList();
  }

  @override
  Future<AttributeDefinition> createDefinition(AttributeDefinition definition) async {
    try {
      await _db.insert(
        Tables.attributeDefinitions,
        _defToMap(definition),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return definition;
    } catch (e) {
      throw AppDatabaseException('Failed to create attribute definition: $e');
    }
  }

  @override
  Future<AttributeDefinition> updateDefinition(AttributeDefinition definition) async {
    final updated = definition.copyWith(updatedAt: DateTime.now().toUtc());
    final count = await _db.update(
      Tables.attributeDefinitions,
      _defToMap(updated),
      where: 'id = ?',
      whereArgs: [definition.id],
    );

    if (count == 0) {
      throw NotFoundException('Attribute definition with id ${definition.id} not found');
    }
    return updated;
  }

  @override
  Future<void> archiveDefinition(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await _db.update(
      Tables.attributeDefinitions,
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Attribute definition with id $id not found');
    }
  }

  @override
  Future<void> deleteDefinition(String id) async {
    final count = await _db.delete(
      Tables.attributeDefinitions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Attribute definition with id $id not found');
    }
  }

  // --- Attribute Options ---

  @override
  Future<List<AttributeOption>> getOptions(String definitionId, {bool includeArchived = false}) async {
    final where = includeArchived
        ? 'attribute_definition_id = ?'
        : 'attribute_definition_id = ? AND archived_at IS NULL';
    final results = await _db.query(
      Tables.attributeOptions,
      where: where,
      whereArgs: [definitionId],
      orderBy: 'display_order ASC, label ASC',
    );
    return results.map(_optFromMap).toList();
  }

  @override
  Future<AttributeOption> createOption(AttributeOption option) async {
    try {
      await _db.insert(
        Tables.attributeOptions,
        _optToMap(option),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return option;
    } catch (e) {
      throw AppDatabaseException('Failed to create attribute option: $e');
    }
  }

  @override
  Future<AttributeOption> updateOption(AttributeOption option) async {
    final count = await _db.update(
      Tables.attributeOptions,
      _optToMap(option),
      where: 'id = ?',
      whereArgs: [option.id],
    );

    if (count == 0) {
      throw NotFoundException('Attribute option with id ${option.id} not found');
    }
    return option;
  }

  @override
  Future<void> archiveOption(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final count = await _db.update(
      Tables.attributeOptions,
      {'archived_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Attribute option with id $id not found');
    }
  }

  @override
  Future<void> deleteOption(String id) async {
    final count = await _db.delete(
      Tables.attributeOptions,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw NotFoundException('Attribute option with id $id not found');
    }
  }

  // --- WorkItem Attribute Values ---

  @override
  Future<List<WorkItemAttributeValue>> getWorkItemValues(String workItemId) async {
    final results = await _db.query(
      Tables.workItemAttributeValues,
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
    );
    return results.map(_wiValFromMap).toList();
  }

  @override
  Future<void> setWorkItemValue(WorkItemAttributeValue value) async {
    try {
      await _db.insert(
        Tables.workItemAttributeValues,
        _wiValToMap(value),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to set work item attribute value: $e');
    }
  }

  @override
  Future<void> deleteWorkItemValue(String valueId) async {
    final count = await _db.delete(
      Tables.workItemAttributeValues,
      where: 'id = ?',
      whereArgs: [valueId],
    );

    if (count == 0) {
      throw NotFoundException('WorkItem attribute value with id $valueId not found');
    }
  }

  @override
  Future<void> deleteWorkItemValuesByWorkItemId(String workItemId) async {
    await _db.delete(
      Tables.workItemAttributeValues,
      where: 'work_item_id = ?',
      whereArgs: [workItemId],
    );
  }

  // --- Session Attribute Values ---

  @override
  Future<List<SessionAttributeValue>> getSessionValues(String sessionId) async {
    final results = await _db.query(
      Tables.sessionAttributeValues,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return results.map(_sessValFromMap).toList();
  }

  @override
  Future<void> setSessionValue(SessionAttributeValue value) async {
    try {
      await _db.insert(
        Tables.sessionAttributeValues,
        _sessValToMap(value),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw AppDatabaseException('Failed to set session attribute value: $e');
    }
  }

  @override
  Future<void> deleteSessionValue(String valueId) async {
    final count = await _db.delete(
      Tables.sessionAttributeValues,
      where: 'id = ?',
      whereArgs: [valueId],
    );

    if (count == 0) {
      throw NotFoundException('Session attribute value with id $valueId not found');
    }
  }

  @override
  Future<void> deleteSessionValuesBySessionId(String sessionId) async {
    await _db.delete(
      Tables.sessionAttributeValues,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // --- Helpers ---

  Map<String, dynamic> _defToMap(AttributeDefinition def) {
    return {
      'id': def.id,
      'workspace_id': def.workspaceId,
      'key': def.key,
      'name': def.name,
      'description': def.description,
      'type': def.type.value,
      'scope': def.scope.value,
      'required': def.required ? 1 : 0,
      'enabled': def.enabled ? 1 : 0,
      'searchable': def.searchable ? 1 : 0,
      'reportable': def.reportable ? 1 : 0,
      'show_in_quick_capture': def.showInQuickCapture ? 1 : 0,
      'show_in_task_details': def.showInTaskDetails ? 1 : 0,
      'display_order': def.displayOrder,
      'created_at': def.createdAt.toIso8601String(),
      'updated_at': def.updatedAt.toIso8601String(),
      'archived_at': def.archivedAt?.toIso8601String(),
    };
  }

  AttributeDefinition _defFromMap(Map<String, dynamic> map) {
    return AttributeDefinition(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      key: map['key'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      type: AttributeType.fromString(map['type'] as String),
      scope: AttributeScope.fromString(map['scope'] as String),
      required: (map['required'] as int) == 1,
      enabled: (map['enabled'] as int) == 1,
      searchable: (map['searchable'] as int) == 1,
      reportable: (map['reportable'] as int) == 1,
      showInQuickCapture: (map['show_in_quick_capture'] as int) == 1,
      showInTaskDetails: (map['show_in_task_details'] as int) == 1,
      displayOrder: map['display_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _optToMap(AttributeOption opt) {
    return {
      'id': opt.id,
      'attribute_definition_id': opt.attributeDefinitionId,
      'value': opt.value,
      'label': opt.label,
      'color_hex': opt.colorHex,
      'display_order': opt.displayOrder,
      'is_default': opt.isDefault ? 1 : 0,
      'created_at': opt.createdAt.toIso8601String(),
      'archived_at': opt.archivedAt?.toIso8601String(),
    };
  }

  AttributeOption _optFromMap(Map<String, dynamic> map) {
    return AttributeOption(
      id: map['id'] as String,
      attributeDefinitionId: map['attribute_definition_id'] as String,
      value: map['value'] as String,
      label: map['label'] as String,
      colorHex: map['color_hex'] as String?,
      displayOrder: map['display_order'] as int,
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> _wiValToMap(WorkItemAttributeValue val) {
    return {
      'id': val.id,
      'work_item_id': val.workItemId,
      'attribute_definition_id': val.attributeDefinitionId,
      'text_value': val.textValue,
      'number_value': val.numberValue,
      'boolean_value': val.booleanValue != null ? (val.booleanValue! ? 1 : 0) : null,
      'date_value': val.dateValue?.toIso8601String(),
      'option_id': val.optionId,
      'created_at': val.createdAt.toIso8601String(),
      'updated_at': val.updatedAt.toIso8601String(),
    };
  }

  WorkItemAttributeValue _wiValFromMap(Map<String, dynamic> map) {
    return WorkItemAttributeValue(
      id: map['id'] as String,
      workItemId: map['work_item_id'] as String,
      attributeDefinitionId: map['attribute_definition_id'] as String,
      textValue: map['text_value'] as String?,
      numberValue: (map['number_value'] as num?)?.toDouble(),
      booleanValue: map['boolean_value'] != null ? (map['boolean_value'] as int) == 1 : null,
      dateValue: map['date_value'] != null ? DateTime.parse(map['date_value'] as String) : null,
      optionId: map['option_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> _sessValToMap(SessionAttributeValue val) {
    return {
      'id': val.id,
      'session_id': val.sessionId,
      'attribute_definition_id': val.attributeDefinitionId,
      'text_value': val.textValue,
      'number_value': val.numberValue,
      'boolean_value': val.booleanValue != null ? (val.booleanValue! ? 1 : 0) : null,
      'date_value': val.dateValue?.toIso8601String(),
      'option_id': val.optionId,
      'created_at': val.createdAt.toIso8601String(),
      'updated_at': val.updatedAt.toIso8601String(),
    };
  }

  SessionAttributeValue _sessValFromMap(Map<String, dynamic> map) {
    return SessionAttributeValue(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      attributeDefinitionId: map['attribute_definition_id'] as String,
      textValue: map['text_value'] as String?,
      numberValue: (map['number_value'] as num?)?.toDouble(),
      booleanValue: map['boolean_value'] != null ? (map['boolean_value'] as int) == 1 : null,
      dateValue: map['date_value'] != null ? DateTime.parse(map['date_value'] as String) : null,
      optionId: map['option_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
