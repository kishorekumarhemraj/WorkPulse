import 'package:flutter/material.dart';
import 'package:workpulse/core/theme/app_colors.dart';
import 'package:workpulse/core/theme/color_utils.dart';
import 'package:workpulse/core/theme/design_tokens.dart';

/// Picks an entity colour from the app palette.
///
/// The selected swatch previously showed a white ring, which vanished against
/// white surfaces in light mode. It now uses a contrasting outline plus a
/// tick, and each swatch is labelled for assistive tech — colour alone never
/// carries the selection.
class ColorSwatchPicker extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onChanged;

  const ColorSwatchPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
  });

  /// Human-readable names, in the same order as [ColorUtils.paletteHex].
  static const _names = [
    'Blue',
    'Green',
    'Orange',
    'Purple',
    'Red',
    'Teal',
    'Yellow',
    'Indigo',
    'Pink',
    'Gray',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Wrap(
      spacing: Spacing.sm + 2,
      runSpacing: Spacing.sm + 2,
      children: [
        for (var i = 0; i < ColorUtils.paletteHex.length; i++)
          () {
            final hex = ColorUtils.paletteHex[i];
            final color = ColorUtils.parseHex(hex);
            final isSelected = hex.toUpperCase() == selectedHex.toUpperCase();
            final name = i < _names.length ? _names[i] : hex;

            return Semantics(
              label: name,
              selected: isSelected,
              inMutuallyExclusiveGroup: true,
              button: true,
              child: Tooltip(
                message: name,
                child: InkWell(
                  onTap: () => onChanged(hex),
                  borderRadius: Radii.pillAll,
                  child: Container(
                    width: 30,
                    height: 30,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colors.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: IconSizes.sm,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
