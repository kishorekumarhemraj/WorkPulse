import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workpulse/core/keyboard/list_cursor.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

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
/// removable chips, and a search field filters the remaining options into a
/// dropdown list.
///
/// Fully operable from the keyboard, which it was not: Up/Down move a
/// highlight through the matches, Enter takes the highlighted one, Backspace
/// on an empty query removes the last chip, and Escape closes the list.
///
/// Escape closing the *list* rather than the screen is the point of handling
/// it here at all. Every form this control appears in pops itself on Escape,
/// so the natural gesture for dismissing an open dropdown used to discard the
/// whole half-filled form with it.
class SearchableMultiSelect extends StatefulWidget {
  final List<SearchableMultiSelectItem> allItems;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final String hintText;
  final String emptyStateText;

  /// Offers a `create <query>` row when the query matches no existing item.
  ///
  /// Receives the typed query. Callers that create the entity and want it
  /// selected should add its id to [selectedIds] themselves — this control
  /// never assumes the creation succeeded.
  final ValueChanged<String>? onCreateNew;

  /// Overrides the create row's wording, e.g. `(q) => 'Add person "$q"'`.
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
  /// Matches the dense menu rows [AppSelect] uses, and gives [ListCursor] a
  /// fixed extent to scroll against.
  static const double _rowHeight = 32;
  static const double _listMaxHeight = 176;

  final _searchController = TextEditingController();
  final _fieldFocusNode = FocusNode(debugLabel: 'SearchableMultiSelect');
  final _scrollController = ScrollController();

  late final ListCursor _cursor = ListCursor(
    rowExtent: _rowHeight,
    scrollController: _scrollController,
  );

  bool _isOpen = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    _fieldFocusNode.addListener(_onFieldFocusChanged);
    _cursor.addListener(_onCursorMoved);
  }

  @override
  void dispose() {
    _cursor.removeListener(_onCursorMoved);
    _cursor.dispose();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _fieldFocusNode.removeListener(_onFieldFocusChanged);
    _fieldFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCursorMoved() => setState(() {});

  void _onQueryChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _query) return;
    setState(() {
      _query = next;
      // The matches underneath are a different list now.
      if (next.isNotEmpty) _isOpen = true;
    });
    _cursor.reset();
  }

  void _onFieldFocusChanged() {
    if (_fieldFocusNode.hasFocus) {
      setState(() => _isOpen = true);
    } else {
      // Repaints the border, which tracks focus.
      setState(() {});
    }
  }

  // --- Options ------------------------------------------------------------

  /// The rows currently on offer, derived the same way here and in [build] —
  /// the key handler and the list must never disagree about what row 3 is.
  List<SearchableMultiSelectItem> _matches() {
    return widget.allItems
        .where((i) => !widget.selectedIds.contains(i.id))
        .where((i) => _query.isEmpty || i.label.toLowerCase().contains(_query))
        .toList();
  }

  /// Whether a "create" row is on offer. Suppressed when the query already
  /// names an item exactly, selected or not, so the user is not invited to
  /// create a duplicate of something they simply cannot see.
  bool get _canCreate {
    if (widget.onCreateNew == null || _query.isEmpty) return false;
    return !widget.allItems.any((i) => i.label.trim().toLowerCase() == _query);
  }

  int get _rowCount => _matches().length + (_canCreate ? 1 : 0);

  // --- Actions ------------------------------------------------------------

  void _select(String id) {
    widget.onChanged([...widget.selectedIds, id]);
    _searchController.clear();
    _cursor.reset();
    _fieldFocusNode.requestFocus();
  }

  void _remove(String id) {
    widget.onChanged(widget.selectedIds.where((i) => i != id).toList());
  }

  void _create() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    widget.onCreateNew!(query);
    _searchController.clear();
    _cursor.reset();
    _fieldFocusNode.requestFocus();
  }

  /// Commits whatever the cursor is sitting on.
  void _confirmCursor() {
    final matches = _matches();
    final index = _cursor.clampedIn(_rowCount);
    if (index >= matches.length) {
      if (_canCreate) _create();
      return;
    }
    _select(matches[index].id);
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _cursor.reset();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      // Only claim Escape when there is a list to close; otherwise the
      // enclosing dialog should still get it.
      if (!_isOpen) return KeyEventResult.ignored;
      _close();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      // Only with an empty query, so Backspace stays a text edit while there
      // is text to edit.
      if (_searchController.text.isNotEmpty) return KeyEventResult.ignored;
      if (widget.selectedIds.isEmpty) return KeyEventResult.ignored;
      _remove(widget.selectedIds.last);
      return KeyEventResult.handled;
    }

    if (!_isOpen) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _isOpen = true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (_cursor.handleKey(event, _rowCount)) return KeyEventResult.handled;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // With nothing to take, Enter belongs to the form's submit binding.
      if (_rowCount == 0) return KeyEventResult.ignored;
      _confirmCursor();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final selectedItems = widget.selectedIds
        .map((id) => widget.allItems.where((i) => i.id == id).firstOrNull)
        .whereType<SearchableMultiSelectItem>()
        .toList();

    return TapRegion(
      onTapOutside: (_) => _close(),
      // hasFocus covers descendants, so this fires when focus leaves the
      // field *and* the list rather than merely moving between them.
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _close();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm - 2),
                child: Wrap(
                  spacing: Spacing.sm - 2,
                  runSpacing: Spacing.sm - 2,
                  children: [
                    for (final item in selectedItems)
                      _SelectedChip(
                        item: item,
                        onRemove: () => _remove(item.id),
                      ),
                  ],
                ),
              ),
            _buildField(colors),
            if (_isOpen) _buildList(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildField(WorkPulseColors colors) {
    final theme = Theme.of(context);
    final hasFocus = _fieldFocusNode.hasFocus;

    return Container(
      decoration: BoxDecoration(
        color: colors.field,
        border: Border.all(
          color: hasFocus ? colors.focusRing : colors.divider,
          width: hasFocus ? 1.5 : 1.0,
        ),
        borderRadius: Radii.mdAll,
      ),
      child: Focus(
        onKeyEvent: _handleKey,
        // The node belongs to the TextField below; this Focus only intercepts
        // keys on the way past, because a TextField eats arrows and Enter
        // before any ancestor sees them.
        canRequestFocus: false,
        skipTraversal: true,
        child: TextField(
          controller: _searchController,
          focusNode: _fieldFocusNode,
          onTap: () => setState(() => _isOpen = true),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: widget.hintText,
            hintStyle: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.textTertiary),
            prefixIcon: Icon(
              Icons.search,
              size: IconSizes.md,
              color: colors.textTertiary,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: ControlSizes.toolbar,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm + 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(WorkPulseColors colors) {
    final theme = Theme.of(context);
    final matches = _matches();
    final rowCount = matches.length + (_canCreate ? 1 : 0);
    final cursor = _cursor.clampedIn(rowCount);

    return Container(
      margin: const EdgeInsets.only(top: Spacing.xs),
      constraints: const BoxConstraints(maxHeight: _listMaxHeight),
      decoration: BoxDecoration(
        // surfaceRaised, not the field's own fill: a popover that matches the
        // control it drops out of has no edge in light mode.
        color: colors.surfaceRaised,
        borderRadius: Radii.mdAll,
        border: Border.all(color: colors.divider),
        boxShadow: Elevation.medium(colors.shadow),
      ),
      clipBehavior: Clip.antiAlias,
      child: rowCount == 0
          ? Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Text(
                widget.allItems.isEmpty ? widget.emptyStateText : 'No matches',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: rowCount,
              itemBuilder: (context, index) {
                if (index >= matches.length) {
                  return _OptionRow(
                    height: _rowHeight,
                    isHighlighted: index == cursor,
                    icon: Icons.add,
                    label: widget.createLabelBuilder
                            ?.call(_searchController.text.trim()) ??
                        'Create "${_searchController.text.trim()}"',
                    labelColor: colors.accent,
                    onTap: _create,
                    onHover: () => _cursor.moveTo(index, rowCount),
                  );
                }
                final item = matches[index];
                return _OptionRow(
                  height: _rowHeight,
                  isHighlighted: index == cursor,
                  dotColor: item.color,
                  icon: item.icon,
                  label: item.label,
                  onTap: () => _select(item.id),
                  onHover: () => _cursor.moveTo(index, rowCount),
                );
              },
            ),
    );
  }
}

/// A chosen item, with a remove button that is reachable from the keyboard.
class _SelectedChip extends StatelessWidget {
  final SearchableMultiSelectItem item;
  final VoidCallback onRemove;

  const _SelectedChip({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(
        left: Spacing.sm,
        right: Spacing.xs,
        top: Spacing.xxs + 1,
        bottom: Spacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: Radii.smAll,
        border: Border.all(color: item.color ?? colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: item.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Spacing.sm - 2),
          ] else if (item.icon != null) ...[
            Icon(item.icon, size: IconSizes.sm, color: colors.textSecondary),
            const SizedBox(width: Spacing.sm - 2),
          ],
          Text(
            item.label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(width: Spacing.xxs),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: IconSizes.sm,
            onPressed: onRemove,
            // A chip is 24pt tall; IconButton's 48pt default target would set
            // the row height on its own.
            padding: const EdgeInsets.all(Spacing.xxs),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove ${item.label}',
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// One row of the dropdown. [isHighlighted] is the keyboard cursor, which is
/// deliberately the same treatment hover uses — they are the same idea
/// arriving by different hardware.
class _OptionRow extends StatelessWidget {
  final double height;
  final bool isHighlighted;
  final Color? dotColor;
  final IconData? icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _OptionRow({
    required this.height,
    required this.isHighlighted,
    required this.label,
    required this.onTap,
    required this.onHover,
    this.dotColor,
    this.icon,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        color: isHighlighted ? colors.selected : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // The row is driven by the cursor, not by its own focus; letting it
          // take focus would pull it out of the search field mid-type.
          canRequestFocus: false,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Row(
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                ] else if (icon != null) ...[
                  Icon(
                    icon,
                    size: IconSizes.sm,
                    color: labelColor ?? colors.textSecondary,
                  ),
                  const SizedBox(width: Spacing.sm - 2),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: labelColor ?? colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
