import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// A shimmering placeholder block.
///
/// Lists previously showed a centred spinner, which gives no sense of what is
/// arriving and makes the whole viewport feel empty. A skeleton keeps the
/// layout stable so content does not jump when it lands.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 12,
    this.radius = Radii.xs,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour "Reduce motion": hold a steady tone instead of pulsing.
    if (Motion.enabled(context)) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              colors.card,
              colors.surfaceSunken,
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A stack of skeleton rows shaped like the list they stand in for.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double spacing;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
    this.spacing = Spacing.md,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Skeleton(width: 180 + (index.isEven ? 60 : 0), height: 13),
              const SizedBox(height: Spacing.sm + 2),
              const Row(
                children: [
                  Skeleton(width: 74, height: 11),
                  SizedBox(width: Spacing.sm),
                  Skeleton(width: 56, height: 11),
                  SizedBox(width: Spacing.sm),
                  Skeleton(width: 48, height: 11),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A grid of skeleton cards, for the entity views.
class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final double maxCrossAxisExtent;
  final double itemHeight;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.maxCrossAxisExtent = 360,
    this.itemHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisExtent: itemHeight,
        crossAxisSpacing: Spacing.lg,
        mainAxisSpacing: Spacing.lg,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.xlAll,
            border: Border.all(color: colors.divider),
          ),
          // Callers ask for tile heights from ~100 (tags) to ~160 (projects),
          // so the placeholder includes only the rows that actually fit
          // rather than assuming a height and overflowing the short ones.
          child: LayoutBuilder(
            builder: (context, constraints) {
              const titleHeight = 14.0;
              const lineHeight = 11.0;
              const gap = Spacing.sm;

              final available = constraints.maxHeight;
              final rows = <Widget>[
                const Skeleton(width: 150, height: titleHeight),
              ];
              var used = titleHeight;

              for (final width in <double?>[null, 200, 90]) {
                if (used + gap + lineHeight > available) break;
                rows
                  ..add(const SizedBox(height: gap))
                  ..add(Skeleton(width: width, height: lineHeight));
                used += gap + lineHeight;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: rows,
              );
            },
          ),
        );
      },
    );
  }
}
