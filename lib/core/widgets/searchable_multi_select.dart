import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_theme.dart';

/// One selectable option for [SearchableMultiSelect].
class SearchableMultiSelectItem {
  final String id;
  final String label;
  final Color? color;
  final IconData? icon;

  const SearchableMultiSelectItem({
    required this.id,
    required this.label,
    this.color,
    this.icon,
  });
}

/// A search-as-you-type multi-select: selected items render as compact
/// removable chips, and a search field filters the remaining options into
/// a dropdown list. Replaces rendering every option as an always-visible
/// FilterChip, which doesn't scale once a workspace has many tags/people.
class SearchableMultiSelect extends StatefulWidget {
  final List<SearchableMultiSelectItem> allItems;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final String emptyStateText;

  /// Reserved for a future "create on no match" affordance - unused for now.
  final VoidCallback? onCreateNew;
  final String Function(String query)? createLabelBuilder;

  const SearchableMultiSelect({
    super.key,
    required this.allItems,
    required this.selectedIds,
    required this.onChanged,
    required this.hintText,
    required this.emptyStateText,
    this.onCreateNew,
    this.createLabelBuilder,
  });

  @override
  State<SearchableMultiSelect> createState() => _SearchableMultiSelectState();
}

class _SearchableMultiSelectState extends State<SearchableMultiSelect> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _select(String id) {
    widget.onChanged([...widget.selectedIds, id]);
    _searchController.clear();
  }

  void _remove(String id) {
    widget.onChanged(widget.selectedIds.where((i) => i != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.getColors(context);

    final selectedItems = widget.selectedIds
        .map((id) => widget.allItems.where((i) => i.id == id).firstOrNull)
        .whereType<SearchableMultiSelectItem>()
        .toList();

    final unselected = widget.allItems
        .where((i) => !widget.selectedIds.contains(i.id))
        .where((i) => _query.isEmpty || i.label.toLowerCase().contains(_query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedItems.map((item) {
                return Container(
                  padding: const EdgeInsets.only(
                      left: 8, right: 4, top: 3, bottom: 3),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: item.color ?? colors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.color != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: item.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                      ] else if (item.icon != null) ...[
                        Icon(item.icon, size: 13, color: colors.textSecondary),
                        const SizedBox(width: 6),
                      ],
                      Text(item.label,
                          style: TextStyle(
                              fontSize: 12, color: colors.textPrimary)),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => _remove(item.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.close,
                              size: 13, color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: TextStyle(fontSize: 12, color: colors.textSecondary),
              prefixIcon:
                  Icon(Icons.search, size: 16, color: colors.textSecondary),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        if (_focusNode.hasFocus)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.divider),
            ),
            child: unselected.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.allItems.isEmpty
                          ? widget.emptyStateText
                          : 'No matches',
                      style:
                          TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: unselected.length,
                    itemBuilder: (context, index) {
                      final item = unselected[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _select(item.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                if (item.color != null) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: item.color,
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                ] else if (item.icon != null) ...[
                                  Icon(item.icon,
                                      size: 14, color: colors.textSecondary),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(item.label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: colors.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
