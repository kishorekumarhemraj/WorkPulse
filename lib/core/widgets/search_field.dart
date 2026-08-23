import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// The standard search input.
///
/// Consolidates five differently-sized, differently-padded search fields, and
/// adds two things none of them had: a clear button once text is present, and
/// Escape-to-clear.
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

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    // Drives the clear button's visibility.
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
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
            focusNode: widget.focusNode,
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
