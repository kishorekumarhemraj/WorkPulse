import 'package:equatable/equatable.dart';

enum AttributeType {
  text('TEXT'),
  number('NUMBER'),
  boolean('BOOLEAN'),
  singleSelect('SINGLE_SELECT'),
  multiSelect('MULTI_SELECT'),
  date('DATE');

  final String value;
  const AttributeType(this.value);

  static AttributeType fromString(String value) {
    return AttributeType.values.firstWhere(
      (e) => e.value.toUpperCase() == value.toUpperCase(),
      orElse: () => AttributeType.text,
    );
  }
}

enum AttributeScope {
  task('TASK'),
  session('SESSION');

  final String value;
  const AttributeScope(this.value);

  static AttributeScope fromString(String value) {
    return AttributeScope.values.firstWhere(
      (e) => e.value.toUpperCase() == value.toUpperCase(),
      orElse: () => AttributeScope.task,
    );
  }
}

class AttributeDefinition extends Equatable {
  final String id;
  final String workspaceId;
  final String key;
  final String name;
  final String? description;
  final AttributeType type;
  final AttributeScope scope;
  final bool required;
  final bool enabled;
  final bool searchable;
  final bool reportable;
  final bool showInQuickCapture;
  final bool showInTaskDetails;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const AttributeDefinition({
    required this.id,
    required this.workspaceId,
    required this.key,
    required this.name,
    this.description,
    required this.type,
    this.scope = AttributeScope.task,
    this.required = false,
    this.enabled = true,
    this.searchable = true,
    this.reportable = true,
    this.showInQuickCapture = true,
    this.showInTaskDetails = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  AttributeDefinition copyWith({
    String? id,
    String? workspaceId,
    String? key,
    String? name,
    String? description,
    AttributeType? type,
    AttributeScope? scope,
    bool? required,
    bool? enabled,
    bool? searchable,
    bool? reportable,
    bool? showInQuickCapture,
    bool? showInTaskDetails,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return AttributeDefinition(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      key: key ?? this.key,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      scope: scope ?? this.scope,
      required: required ?? this.required,
      enabled: enabled ?? this.enabled,
      searchable: searchable ?? this.searchable,
      reportable: reportable ?? this.reportable,
      showInQuickCapture: showInQuickCapture ?? this.showInQuickCapture,
      showInTaskDetails: showInTaskDetails ?? this.showInTaskDetails,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workspaceId,
        key,
        name,
        description,
        type,
        scope,
        required,
        enabled,
        searchable,
        reportable,
        showInQuickCapture,
        showInTaskDetails,
        displayOrder,
        createdAt,
        updatedAt,
        archivedAt,
      ];
}

class AttributeOption extends Equatable {
  final String id;
  final String attributeDefinitionId;
  final String value;
  final String label;
  final String? colorHex;
  final int displayOrder;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? archivedAt;

  const AttributeOption({
    required this.id,
    required this.attributeDefinitionId,
    required this.value,
    required this.label,
    this.colorHex,
    this.displayOrder = 0,
    this.isDefault = false,
    required this.createdAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  AttributeOption copyWith({
    String? id,
    String? attributeDefinitionId,
    String? value,
    String? label,
    String? colorHex,
    int? displayOrder,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? archivedAt,
  }) {
    return AttributeOption(
      id: id ?? this.id,
      attributeDefinitionId: attributeDefinitionId ?? this.attributeDefinitionId,
      value: value ?? this.value,
      label: label ?? this.label,
      colorHex: colorHex ?? this.colorHex,
      displayOrder: displayOrder ?? this.displayOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        attributeDefinitionId,
        value,
        label,
        colorHex,
        displayOrder,
        isDefault,
        createdAt,
        archivedAt,
      ];
}

class WorkItemAttributeValue extends Equatable {
  final String id;
  final String workItemId;
  final String attributeDefinitionId;
  final String? textValue;
  final double? numberValue;
  final bool? booleanValue;
  final DateTime? dateValue;
  final String? optionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkItemAttributeValue({
    required this.id,
    required this.workItemId,
    required this.attributeDefinitionId,
    this.textValue,
    this.numberValue,
    this.booleanValue,
    this.dateValue,
    this.optionId,
    required this.createdAt,
    required this.updatedAt,
  });

  WorkItemAttributeValue copyWith({
    String? id,
    String? workItemId,
    String? attributeDefinitionId,
    String? textValue,
    double? numberValue,
    bool? booleanValue,
    DateTime? dateValue,
    String? optionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkItemAttributeValue(
      id: id ?? this.id,
      workItemId: workItemId ?? this.workItemId,
      attributeDefinitionId: attributeDefinitionId ?? this.attributeDefinitionId,
      textValue: textValue ?? this.textValue,
      numberValue: numberValue ?? this.numberValue,
      booleanValue: booleanValue ?? this.booleanValue,
      dateValue: dateValue ?? this.dateValue,
      optionId: optionId ?? this.optionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workItemId,
        attributeDefinitionId,
        textValue,
        numberValue,
        booleanValue,
        dateValue,
        optionId,
        createdAt,
        updatedAt,
      ];
}

class SessionAttributeValue extends Equatable {
  final String id;
  final String sessionId;
  final String attributeDefinitionId;
  final String? textValue;
  final double? numberValue;
  final bool? booleanValue;
  final DateTime? dateValue;
  final String? optionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionAttributeValue({
    required this.id,
    required this.sessionId,
    required this.attributeDefinitionId,
    this.textValue,
    this.numberValue,
    this.booleanValue,
    this.dateValue,
    this.optionId,
    required this.createdAt,
    required this.updatedAt,
  });

  SessionAttributeValue copyWith({
    String? id,
    String? sessionId,
    String? attributeDefinitionId,
    String? textValue,
    double? numberValue,
    bool? booleanValue,
    DateTime? dateValue,
    String? optionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionAttributeValue(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      attributeDefinitionId: attributeDefinitionId ?? this.attributeDefinitionId,
      textValue: textValue ?? this.textValue,
      numberValue: numberValue ?? this.numberValue,
      booleanValue: booleanValue ?? this.booleanValue,
      dateValue: dateValue ?? this.dateValue,
      optionId: optionId ?? this.optionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sessionId,
        attributeDefinitionId,
        textValue,
        numberValue,
        booleanValue,
        dateValue,
        optionId,
        createdAt,
        updatedAt,
      ];
}
