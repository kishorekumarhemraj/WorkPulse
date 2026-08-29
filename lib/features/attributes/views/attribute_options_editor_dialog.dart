import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/design_tokens.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/widgets/app_snack_bar.dart';
import 'package:workpulse/core/widgets/error_state.dart';
import 'package:workpulse/core/widgets/app_dialog.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';

class AttributeOptionsEditorDialog extends ConsumerStatefulWidget {
  final AttributeDefinition definition;

  const AttributeOptionsEditorDialog({super.key, required this.definition});

  static Future<void> show(BuildContext context,
      {required AttributeDefinition definition}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          AttributeOptionsEditorDialog(definition: definition),
    );
  }

  @override
  ConsumerState<AttributeOptionsEditorDialog> createState() =>
      _AttributeOptionsEditorDialogState();
}

class _AttributeOptionsEditorDialogState
    extends ConsumerState<AttributeOptionsEditorDialog> {
  final _labelController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedColor = ColorUtils.paletteHex.first;
  bool _isAdding = false;

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _addOption() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;

    final val = _valueController.text.trim().isEmpty
        ? label.toLowerCase().replaceAll(RegExp(r'\s+'), '_')
        : _valueController.text.trim();

    setState(() => _isAdding = true);
    try {
      await ref.read(attributeOptionsControllerProvider).createOption(
            definitionId: widget.definition.id,
            value: val,
            label: label,
            colorHex: _selectedColor,
          );
      _labelController.clear();
      _valueController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          AppSnackBar.failure(message: 'Error creating option: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync =
        ref.watch(attributeOptionsFamilyProvider(widget.definition.id));

    return AppDialog(
      title: 'Options for "${widget.definition.name}"',
      subtitle: widget.definition.type == AttributeType.singleSelect
          ? 'Single Select Options'
          : 'Multi Select Options',
      icon: Icons.list_alt,
      iconColor: context.colors.info,
      width: DialogWidth.large,
      // The options list scrolls itself and should fill the height available
      // rather than sit inside an outer scroll view at a fixed size.
      scrollableBody: false,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            // Options list
            Expanded(
              child: optionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(
                  title: 'Could not load options',
                  error: e,
                  compact: true,
                  onRetry: () => ref.invalidate(
                    attributeOptionsFamilyProvider(widget.definition.id),
                  ),
                ),
                data: (options) {
                  if (options.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.format_list_bulleted,
                              size: 36, color: context.colors.textTertiary),
                          const SizedBox(height: 8),
                          Text('No options defined yet',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Add options using the input below',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: context.colors.divider, height: 1),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final col = ColorUtils.parseHex(opt.colorHex);

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration:
                              BoxDecoration(color: col, shape: BoxShape.circle),
                        ),
                        title: Text(opt.label,
                            style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(opt.value,
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Courier',
                                color: context.colors.textSecondary)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 16, color: context.colors.danger),
                          tooltip: 'Delete option',
                          onPressed: () async {
                            await ref
                                .read(attributeOptionsControllerProvider)
                                .deleteOption(widget.definition.id, opt.id);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Divider(color: context.colors.divider, height: 1),
            const SizedBox(height: 12),

            // Add Option Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: Radii.mdAll,
                border: Border.all(color: context.colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _labelController,
                          style: TextStyle(
                              fontSize: 13, color: context.colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Option Label (e.g. High)',
                            hintStyle: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            if (_valueController.text.isEmpty) {
                              _valueController.text = val
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'\s+'), '_');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _valueController,
                          style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Courier',
                              color: context.colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Value (e.g. high)',
                            hintStyle: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Color: ',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary)),
                      const SizedBox(width: 6),
                      Wrap(
                        spacing: 6,
                        children: ColorUtils.paletteHex.take(6).map((String c) {
                          final col = ColorUtils.parseHex(c);
                          final isSel = _selectedColor == c;
                          return InkWell(
                            onTap: () => setState(() => _selectedColor = c),
                            borderRadius: Radii.lgAll,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: isSel
                                    ? Border.all(
                                        color: context.colors.onAccent,
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isAdding ? null : _addOption,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Option',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
