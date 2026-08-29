import 'package:flutter/material.dart';

class ColorUtils {
  static const List<String> paletteHex = [
    '#0A84FF', // macOS Blue
    '#30D158', // Green
    '#FF9F0A', // Orange
    '#BF5AF2', // Purple
    '#FF453A', // Red
    '#64D2FF', // Teal
    '#FFD60A', // Yellow
    '#5E5CE6', // Indigo
    '#FF375F', // Pink
    '#8E8E93', // Gray
  ];

  static Color parseHex(String? hexString,
      {Color defaultColor = const Color(0xFF0A84FF)}) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    final buffer = StringBuffer();
    final clean = hexString.replaceAll('#', '');
    if (clean.length == 6) {
      buffer.write('FF');
      buffer.write(clean);
    } else if (clean.length == 8) {
      buffer.write(clean);
    } else {
      return defaultColor;
    }
    return Color(
        int.tryParse(buffer.toString(), radix: 16) ?? defaultColor.toARGB32());
  }

  static String toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  /// A stable colour from [paletteHex] for an entity that carries none of its
  /// own — people, and attribute fields that are not select-typed.
  ///
  /// Categories, people and free-text attributes have no colour in the schema,
  /// so [EntityChip] fell back to a neutral fill for all three. They are also
  /// the three most frequent chip types, which is why a session row read as
  /// five grey chips to one coloured one and no amount of surface tuning
  /// changed it.
  ///
  /// Seed this with a **stable id**, never a display name: renaming a person
  /// must not recolour them, and a colour that moves between rebuilds is worse
  /// than no colour at all.
  static Color deterministicColor(String seed) =>
      parseHex(paletteHex[_stableHash(seed) % paletteHex.length]);

  /// FNV-1a. Dart's own `String.hashCode` is not contractually stable across
  /// SDK versions, and this value decides what colour a person is — it has to
  /// survive an upgrade.
  static int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
