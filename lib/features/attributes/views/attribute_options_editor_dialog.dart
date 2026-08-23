import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';

class AttributeOptionsEditorDialog extends ConsumerStatefulWidget {
  final AttributeDefinition definition;

  const AttributeOptionsEditorDialog({super.key, required this.definition});

  static Future<void> show(BuildContext context, {required AttributeDefinition definition}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AttributeOptionsEditorDialog(definition: definition),
    );
  }

  @override
  ConsumerState<AttributeOptionsEditorDialog> createState() => _AttributeOptionsEditorDialogState();
}

class _AttributeOptionsEditorDialogState extends ConsumerState<AttributeOptionsEditorDialog> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating option: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(attributeOptionsFamilyProvider(widget.definition.id));

    return AlertDialog(
      backgroundColor: AppTheme.getColors(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.getColors(context).divider, width: 1),
      ),
      titlePadding: EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.list_alt, color: AppTheme.accentPurple, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Options for "${widget.definition.name}"',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.getColors(context).textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  widget.definition.type == AttributeType.singleSelect ? 'Single Select Options' : 'Multi Select Options',
                  style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 380,
        child: Column(
          children: [
            // Options list
            Expanded(
              child: optionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: AppTheme.accentRed))),
                data: (options) {
                  if (options.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.format_list_bulleted, size: 36, color: AppTheme.getColors(context).textSecondary.withValues(alpha: 0.3)),
                          SizedBox(height: 8),
                          Text('No options defined yet', style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textSecondary)),
                          SizedBox(height: 4),
                          Text('Add options using the input below', style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(color: AppTheme.getColors(context).divider, height: 1),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final col = ColorUtils.parseHex(opt.colorHex);

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                        ),
                        title: Text(opt.label, style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textPrimary, fontWeight: FontWeight.w500)),
                        subtitle: Text(opt.value, style: TextStyle(fontSize: 11, fontFamily: 'Courier', color: AppTheme.getColors(context).textSecondary)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, size: 16, color: AppTheme.accentRed),
                          tooltip: 'Delete option',
                          onPressed: () async {
                            await ref.read(attributeOptionsControllerProvider).deleteOption(widget.definition.id, opt.id);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Divider(color: AppTheme.getColors(context).divider, height: 1),
            SizedBox(height: 12),

            // Add Option Box
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.getColors(context).card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.getColors(context).divider),
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
                          style: TextStyle(fontSize: 13, color: AppTheme.getColors(context).textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Option Label (e.g. High)',
                            hintStyle: TextStyle(fontSize: 12, color: AppTheme.getColors(context).textSecondary),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            if (_valueController.text.isEmpty) {
                              _valueController.text = val.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _valueController,
                          style: TextStyle(fontSize: 12, fontFamily: 'Courier', color: AppTheme.getColors(context).textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Value (e.g. high)',
                            hintStyle: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Color: ', style: TextStyle(fontSize: 11, color: AppTheme.getColors(context).textSecondary)),
                      SizedBox(width: 6),
                      Wrap(
                        spacing: 6,
                        children: ColorUtils.paletteHex.take(6).map((String c) {
                          final col = ColorUtils.parseHex(c);
                          final isSel = _selectedColor == c;
                          return InkWell(
                            onTap: () => setState(() => _selectedColor = c),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: isSel ? Border.all(color: Colors.white, width: 2) : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isAdding ? null : _addOption,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Option', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
