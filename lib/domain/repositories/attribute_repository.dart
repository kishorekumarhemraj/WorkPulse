import 'package:workpulse/domain/models/attribute_model.dart';

abstract class AttributeRepository {
  // Attribute Definitions
  Future<AttributeDefinition?> getDefinitionById(String id);
  Future<AttributeDefinition?> getDefinitionByKey(
      String workspaceId, String key);
  Future<List<AttributeDefinition>> getDefinitions({
    String? workspaceId,
    AttributeScope? scope,
    bool includeArchived = false,
  });
  Future<AttributeDefinition> createDefinition(AttributeDefinition definition);
  Future<AttributeDefinition> updateDefinition(AttributeDefinition definition);
  Future<void> archiveDefinition(String id);
  Future<void> deleteDefinition(String id);

  // Attribute Options
  Future<List<AttributeOption>> getOptions(String definitionId,
      {bool includeArchived = false});
  Future<AttributeOption> createOption(AttributeOption option);
  Future<AttributeOption> updateOption(AttributeOption option);
  Future<void> archiveOption(String id);
  Future<void> deleteOption(String id);

  // WorkItem Attribute Values
  Future<List<WorkItemAttributeValue>> getWorkItemValues(String workItemId);
  Future<void> setWorkItemValue(WorkItemAttributeValue value);
  Future<void> deleteWorkItemValue(String valueId);
  Future<void> deleteWorkItemValuesByWorkItemId(String workItemId);

  // Session Attribute Values
  Future<List<SessionAttributeValue>> getSessionValues(String sessionId);
  Future<void> setSessionValue(SessionAttributeValue value);
  Future<void> deleteSessionValue(String valueId);
  Future<void> deleteSessionValuesBySessionId(String sessionId);
}
