import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/widgets/app_select.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';

class DynamicAttributeFields extends ConsumerWidget {
  final List<AttributeDefinition> definitions;
  final Map<String, dynamic> values;
  final void Function(String definitionId, dynamic value) onValueChanged;

  const DynamicAttributeFields({
    super.key,
    required this.definitions,
    required this.values,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (definitions.isEmpty) return const SizedBox.shrink();

    final activeDefs =
        definitions.where((d) => d.enabled && !d.isArchived).toList();
    if (activeDefs.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < activeDefs.length; i += 2) {
      final def1 = activeDefs[i];
      final hasSecond = i + 1 < activeDefs.length;
      final def2 = hasSecond ? activeDefs[i + 1] : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFieldForDefinition(context, ref, def1),
              ),
              if (def2 != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFieldForDefinition(context, ref, def2),
                ),
              ] else ...[
                const SizedBox(width: 12),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Attributes',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary),
        ),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }

  Widget _buildFieldForDefinition(
      BuildContext context, WidgetRef ref, AttributeDefinition def) {
    final currentValue = values[def.id];

    switch (def.type) {
      case AttributeType.text:
        return TextFormField(
          initialValue: currentValue as String?,
          style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
          decoration: InputDecoration(
            labelText: '${def.name}${def.required ? ' *' : ''}',
            hintText: def.description ?? 'Enter ${def.name}',
          ),
          validator: def.required
              ? (v) => (v == null || v.trim().isEmpty)
                  ? '${def.name} is required'
                  : null
              : null,
          onChanged: (val) => onValueChanged(def.id, val.trim()),
        );

      case AttributeType.number:
        return TextFormField(
          initialValue: currentValue?.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
          decoration: InputDecoration(
            labelText: '${def.name}${def.required ? ' *' : ''}',
            hintText: def.description ?? 'Enter number',
          ),
          validator: (v) {
            if (def.required && (v == null || v.trim().isEmpty)) {
              return '${def.name} is required';
            }
            if (v != null &&
                v.trim().isNotEmpty &&
                double.tryParse(v.trim()) == null) {
              return 'Must be a valid number';
            }
            return null;
          },
          onChanged: (val) {
            final parsed = double.tryParse(val.trim());
            onValueChanged(def.id, parsed);
          },
        );

      case AttributeType.boolean:
        final boolVal = currentValue == true;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: Radii.mdAll,
            border: Border.all(color: context.colors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${def.name}${def.required ? ' *' : ''}',
                      style: TextStyle(
                          fontSize: 13, color: context.colors.textPrimary),
                    ),
                    if (def.description != null) ...[
                      const SizedBox(height: 2),
                      Text(def.description!,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary)),
                    ],
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: boolVal,
                  onChanged: (val) => onValueChanged(def.id, val),
                  activeTrackColor: context.colors.accent,
                ),
              ),
            ],
          ),
        );

      case AttributeType.singleSelect:
        final optionsAsync = ref.watch(attributeOptionsFamilyProvider(def.id));
        return optionsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
          data: (options) {
            return AppSelect<String>(
              label: def.name,
              isRequired: def.required,
              placeholder: 'Select ${def.name}',
              maxTriggerWidth: double.infinity,
              value: options.any((o) => o.id == currentValue)
                  ? currentValue as String?
                  : null,
              options: options
                  .map((opt) => SelectOption(
                        value: opt.id,
                        label: opt.label,
                        color: ColorUtils.parseHex(opt.colorHex),
                      ))
                  .toList(),
              validator: def.required
                  ? (v) => v == null ? 'Please select ${def.name}' : null
                  : null,
              onChanged: (val) => onValueChanged(def.id, val),
            );
          },
        );

      case AttributeType.multiSelect:
        final optionsAsync = ref.watch(attributeOptionsFamilyProvider(def.id));
        final selectedIds = (currentValue is List
            ? List<String>.from(currentValue)
            : <String>[]);

        return optionsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
          data: (options) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${def.name}${def.required ? ' *' : ''}',
                  style: TextStyle(
                      fontSize: 12, color: context.colors.textSecondary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: options.map((opt) {
                    final isSel = selectedIds.contains(opt.id);
                    final col = ColorUtils.parseHex(opt.colorHex);

                    return FilterChip(
                      label: Text(opt.label),
                      selected: isSel,
                      selectedColor: col.withValues(alpha: 0.3),
                      checkmarkColor: col,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color:
                            isSel ? Colors.white : context.colors.textSecondary,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: context.colors.card,
                      side: BorderSide(
                          color: isSel ? col : context.colors.divider),
                      onSelected: (selected) {
                        final updated = List<String>.from(selectedIds);
                        if (selected) {
                          updated.add(opt.id);
                        } else {
                          updated.remove(opt.id);
                        }
                        onValueChanged(def.id, updated);
                      },
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );

      case AttributeType.date:
        final dateVal = currentValue is DateTime
            ? currentValue
            : (currentValue is String ? DateTime.tryParse(currentValue) : null);
        final formattedDate = dateVal != null
            ? DateFormat.yMMMd().format(dateVal)
            : 'Select date';

        return Container(
          decoration: BoxDecoration(
            borderRadius: Radii.mdAll,
            border: Border.all(color: context.colors.divider),
          ),
          child: Material(
            color: context.colors.card,
            borderRadius: Radii.mdAll,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dateVal ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  onValueChanged(def.id, picked);
                }
              },
              borderRadius: Radii.mdAll,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: context.colors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${def.name}${def.required ? ' *' : ''}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: dateVal != null
                                  ? context.colors.textPrimary
                                  : context.colors.textSecondary,
                              fontWeight: dateVal != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dateVal != null)
                      IconButton(
                        tooltip: 'Clear date',
                        icon: Icon(Icons.close,
                            size: 14, color: context.colors.textSecondary),
                        onPressed: () => onValueChanged(def.id, null),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}
