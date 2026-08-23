import 'package:flutter/material.dart';

/// Rebuilds [builder] as the pointer enters and leaves.
///
/// Desktop UIs lean on hover to keep rows quiet until the user reaches for
/// them — secondary actions stay hidden, backgrounds lift slightly. Flutter
/// has no built-in equivalent that also exposes the state to a subtree, so
/// this small wrapper is used throughout the app instead of each widget
/// carrying its own StatefulWidget + MouseRegion.
class Hoverable extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;
  final MouseCursor cursor;
  final ValueChanged<bool>? onHoverChanged;

  const Hoverable({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.basic,
    this.onHoverChanged,
  });

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _isHovered = false;

  void _set(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
    widget.onHoverChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: widget.builder(context, _isHovered),
    );
  }
}
