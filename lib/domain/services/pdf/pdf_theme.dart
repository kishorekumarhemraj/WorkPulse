import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:workpulse/core/theme/color_utils.dart';

/// Semantic, brand, and layout palette for PDF document generation.
///
/// Restates the intent of `lib/core/theme/classification_style.dart` and the
/// app's visual hierarchy in pure PDF primitives so that screen and paper
/// agree on meaning without sharing Flutter UI dependencies.
class PdfThemeColors {
  // Ink
  static const slate900 = PdfColor.fromInt(0xFF0F172A);
  static const slate800 = PdfColor.fromInt(0xFF1E293B);
  static const slate700 = PdfColor.fromInt(0xFF334155);
  static const slate500 = PdfColor.fromInt(0xFF64748B);
  static const slate400 = PdfColor.fromInt(0xFF94A3B8);
  static const slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const slate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const slate50 = PdfColor.fromInt(0xFFF8FAFC);
  static const white = PdfColors.white;

  // Brand
  static const indigo = PdfColor.fromInt(0xFF4F46E5);
  static const indigoLight = PdfColor.fromInt(0xFFEEF2FF);
  static const indigoDark = PdfColor.fromInt(0xFF3730A3);

  // Semantic (mirrors ClassificationStyle / app semantics)
  static const capex = PdfColor.fromInt(0xFF4F46E5); // Indigo
  static const capexLight = PdfColor.fromInt(0xFFEEF2FF);

  static const opex = PdfColor.fromInt(0xFFD97706); // Amber
  static const opexLight = PdfColor.fromInt(0xFFFFFBEB);

  static const unclassified = PdfColor.fromInt(0xFF94A3B8); // Slate 400
  static const unclassifiedLight = PdfColor.fromInt(0xFFF1F5F9);

  static const netFocus = PdfColor.fromInt(0xFF059669); // Emerald
  static const netFocusLight = PdfColor.fromInt(0xFFECFDF5);

  static const idle = PdfColor.fromInt(0xFFD97706); // Amber
  static const idleLight = PdfColor.fromInt(0xFFFFFBEB);

  static const attention = PdfColor.fromInt(0xFFE11D48); // Rose
  static const attentionLight = PdfColor.fromInt(0xFFFFF1F2);

  static const sky = PdfColor.fromInt(0xFF0284C7); // Sky (delegate lane)
  static const skyLight = PdfColor.fromInt(0xFFF0F9FF);

  /// Resolves an entity's color from its hex string or a stable hash fallback.
  static PdfColor entityColor(String? colorHex, String fallbackSeed) {
    if (colorHex != null && colorHex.trim().isNotEmpty) {
      final color = ColorUtils.parseHex(colorHex.trim());
      return PdfColor.fromInt(color.toARGB32());
    }
    final hash = fallbackSeed.hashCode.abs();
    final fallbackHex =
        ColorUtils.paletteHex[hash % ColorUtils.paletteHex.length];
    final color = ColorUtils.parseHex(fallbackHex);
    return PdfColor.fromInt(color.toARGB32());
  }

  /// Darkens bright screen-tuned colors toward black until relative luminance
  /// is <= 0.62, ensuring thin strokes and fine rules remain legible on white paper.
  static PdfColor printSafe(PdfColor color) {
    var r = color.red;
    var g = color.green;
    var b = color.blue;

    double luminance(double red, double green, double blue) =>
        0.2126 * red + 0.7152 * green + 0.0722 * blue;

    var lum = luminance(r, g, b);
    while (lum > 0.62 && (r > 0 || g > 0 || b > 0)) {
      r = (r * 0.9).clamp(0.0, 1.0);
      g = (g * 0.9).clamp(0.0, 1.0);
      b = (b * 0.9).clamp(0.0, 1.0);
      lum = luminance(r, g, b);
    }
    return PdfColor(r, g, b, color.alpha);
  }
}

/// Loaded fonts and fixed 6-tier type scale for PDF report generation.
///
/// Scale: 22 (h1), 15 (h2), 11 (h3), 9 (body), 8 (caption), 7 (micro).
/// All numeric durations, counts, percentages, and times use JetBrainsMono.
class PdfTypography {
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font bold;

  final pw.Font monoRegular;
  final pw.Font monoMedium;
  final pw.Font monoBold;

  const PdfTypography({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.bold,
    required this.monoRegular,
    required this.monoMedium,
    required this.monoBold,
  });

  /// Loads bundled Inter and JetBrainsMono fonts with graceful degradation.
  static Future<PdfTypography> load() async {
    pw.Font reg = pw.Font.helvetica();
    pw.Font med = pw.Font.helvetica();
    pw.Font semi = pw.Font.helveticaBold();
    pw.Font bld = pw.Font.helveticaBold();

    try {
      final regData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final medData = await rootBundle.load('assets/fonts/Inter-Medium.ttf');
      final semiData = await rootBundle.load('assets/fonts/Inter-SemiBold.ttf');
      final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');

      reg = pw.Font.ttf(regData);
      med = pw.Font.ttf(medData);
      semi = pw.Font.ttf(semiData);
      bld = pw.Font.ttf(boldData);
    } catch (_) {
      // Fall back to built-in fonts
    }

    pw.Font mReg = reg;
    pw.Font mMed = med;
    pw.Font mBld = bld;

    try {
      final mRegData =
          await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf');
      final mMedData =
          await rootBundle.load('assets/fonts/JetBrainsMono-Medium.ttf');
      final mBoldData =
          await rootBundle.load('assets/fonts/JetBrainsMono-Bold.ttf');

      mReg = pw.Font.ttf(mRegData);
      mMed = pw.Font.ttf(mMedData);
      mBld = pw.Font.ttf(mBoldData);
    } catch (_) {
      // Degrades to proportional fonts cleanly without failing the export
    }

    return PdfTypography(
      regular: reg,
      medium: med,
      semiBold: semi,
      bold: bld,
      monoRegular: mReg,
      monoMedium: mMed,
      monoBold: mBld,
    );
  }

  // --- Text Styles (Inter) ---
  pw.TextStyle get h1 => pw.TextStyle(
        font: bold,
        fontSize: 22,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get h2 => pw.TextStyle(
        font: bold,
        fontSize: 15,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get h3 => pw.TextStyle(
        font: semiBold,
        fontSize: 11,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get body => pw.TextStyle(
        font: regular,
        fontSize: 9,
        color: PdfThemeColors.slate700,
      );

  pw.TextStyle get bodyMedium => pw.TextStyle(
        font: medium,
        fontSize: 9,
        color: PdfThemeColors.slate800,
      );

  pw.TextStyle get bodyBold => pw.TextStyle(
        font: bold,
        fontSize: 9,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get caption => pw.TextStyle(
        font: regular,
        fontSize: 8,
        color: PdfThemeColors.slate500,
      );

  pw.TextStyle get captionMedium => pw.TextStyle(
        font: medium,
        fontSize: 8,
        color: PdfThemeColors.slate700,
      );

  pw.TextStyle get captionBold => pw.TextStyle(
        font: bold,
        fontSize: 8,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get micro => pw.TextStyle(
        font: regular,
        fontSize: 7,
        color: PdfThemeColors.slate500,
      );

  pw.TextStyle get microMedium => pw.TextStyle(
        font: medium,
        fontSize: 7,
        color: PdfThemeColors.slate700,
      );

  pw.TextStyle get microBold => pw.TextStyle(
        font: bold,
        fontSize: 7,
        color: PdfThemeColors.slate900,
      );

  // --- Numeric Styles (JetBrainsMono) ---
  pw.TextStyle get monoHero => pw.TextStyle(
        font: monoBold,
        fontSize: 18,
        color: PdfThemeColors.indigoDark,
      );

  pw.TextStyle get monoH2 => pw.TextStyle(
        font: monoBold,
        fontSize: 15,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get monoStat => pw.TextStyle(
        font: monoBold,
        fontSize: 12,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get monoBody => pw.TextStyle(
        font: monoRegular,
        fontSize: 9,
        color: PdfThemeColors.slate800,
      );

  pw.TextStyle get monoBodyBold => pw.TextStyle(
        font: monoBold,
        fontSize: 9,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get monoCaption => pw.TextStyle(
        font: monoRegular,
        fontSize: 8,
        color: PdfThemeColors.slate700,
      );

  pw.TextStyle get monoCaptionBold => pw.TextStyle(
        font: monoBold,
        fontSize: 8,
        color: PdfThemeColors.slate900,
      );

  pw.TextStyle get monoMicro => pw.TextStyle(
        font: monoRegular,
        fontSize: 7,
        color: PdfThemeColors.slate500,
      );
}
