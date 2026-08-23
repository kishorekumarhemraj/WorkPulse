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
}
