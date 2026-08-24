import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workpulse/core/keyboard/search_focus.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// The standard search input.
///
/// Consolidates five differently-sized, differently-padded search fields, and
/// adds three things none of them had: a clear button once text is present,
/// Escape-to-clear, and reachability from the keyboard — it registers itself
/// with [SearchFocusRegistry] so the app-wide "focus search" shortcut can jump
/// straight here.
class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final double width;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final String? initialValue;

  const SearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search…',
    this.width = 260,
    this.focusNode,
    this.controller,
    this.initialValue,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  /// Resolved once and held, because [dispose] must not walk the element tree.
  /// Null when the field is hosted outside a [SearchFocusScope] — a widget
  /// test, or a screen that does not participate in the shortcut.
  SearchFocusRegistry? _registry;

  @override
  void initState() {
    super.initState();
    _registry = SearchFocusScope.maybeOf(context);
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_onControllerChanged);

    // A node is created when the caller does not supply one, so every search
    // field is focusable by shortcut rather than only the ones whose screen
    // happened to pass a node down.
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'SearchField');

    // Deferred: registering during initState would run while the previous
    // screen's field is still mounted and about to unregister.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _registry?.register(_focusNode);
    });
  }

  void _onControllerChanged() {
    // Drives the clear button's visibility.
    setState(() {});
  }

  @override
  void dispose() {
    _registry?.unregister(_focusNode);
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasText = _controller.text.isNotEmpty;

    return SizedBox(
      width: widget.width,
      height: ControlSizes.toolbar,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _ClearIntent(),
        },
        child: Actions(
          actions: {
            _ClearIntent: CallbackAction<_ClearIntent>(
              onInvoke: (_) {
                if (hasText) _clear();
                return null;
              },
            ),
          },
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(
                Icons.search,
                size: IconSizes.md,
                color: colors.textTertiary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 34,
                minHeight: ControlSizes.toolbar,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close, size: IconSizes.sm),
                      onPressed: _clear,
                      splashRadius: 14,
                      tooltip: 'Clear search',
                      color: colors.textTertiary,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: ControlSizes.toolbar,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}
