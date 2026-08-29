import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:workpulse/domain/models/work_report_model.dart';
import 'package:workpulse/domain/services/pdf/pdf_theme.dart';
import 'package:workpulse/domain/services/timer_service.dart';

/// Reusable layout components and drawing primitives for the 3-act PDF report.
class PdfPrimitives {
  /// Masthead header banner for Act I (The Story).
  static pw.Widget masthead({
    required String workspaceName,
    required String? authorName,
    required String dateSubtitle,
    required Duration totalNet,
    required PdfTypography typo,
  }) {
    final byline = [
      workspaceName,
      if (authorName != null && authorName.trim().isNotEmpty) authorName.trim(),
    ].join(' · ');

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const pw.BoxDecoration(
        color: PdfThemeColors.indigoDark,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'WORK REPORT',
                  style: typo.h1.copyWith(
                    color: PdfThemeColors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  dateSubtitle,
                  style: typo.bodyMedium.copyWith(
                    color: PdfThemeColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  byline,
                  style: typo.caption.copyWith(
                    color: PdfThemeColors.indigoLight,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfThemeColors.white,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TOTAL NET',
                  style: typo.microBold.copyWith(
                    color: PdfThemeColors.slate500,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  TimerService.formatDuration(totalNet, includeSeconds: false),
                  style: typo.monoHero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 5 Stat Tiles row for Act I.
  static pw.Widget statTilesRow({
    required ReportHeadline headline,
    required PdfTypography typo,
  }) {
    final focusSub = headline.totalGross > Duration.zero
        ? '${(headline.focusEfficiency).toStringAsFixed(0)}%'
        : '—';

    final idleSub = headline.totalIdle > Duration.zero
        ? '${(headline.idlePercent).toStringAsFixed(0)}% ded'
        : '0%';

    final taskSub = '${headline.sessionCount} sess';
    final projSub = '${headline.categoryCount} categ';

    return pw.Row(
      children: [
        pw.Expanded(
          child: statTile(
            title: 'TRACKED',
            value: TimerService.formatDuration(headline.totalGross,
                includeSeconds: false),
            subtitle: '${headline.activeDays} days',
            typo: typo,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: statTile(
            title: 'FOCUS',
            value: TimerService.formatDuration(headline.totalNet,
                includeSeconds: false),
            subtitle: focusSub,
            typo: typo,
            valueColor: PdfThemeColors.netFocus,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: statTile(
            title: 'IDLE',
            value: TimerService.formatDuration(headline.totalIdle,
                includeSeconds: false),
            subtitle: idleSub,
            typo: typo,
            valueColor: headline.totalIdle > Duration.zero
                ? PdfThemeColors.idle
                : PdfThemeColors.slate500,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: statTile(
            title: 'TASKS',
            value: '${headline.taskCount}',
            subtitle: taskSub,
            typo: typo,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: statTile(
            title: 'PROJECTS',
            value: '${headline.projectCount}',
            subtitle: projSub,
            typo: typo,
          ),
        ),
      ],
    );
  }

  /// Individual stat tile widget.
  static pw.Widget statTile({
    required String title,
    required String value,
    required String subtitle,
    required PdfTypography typo,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfThemeColors.slate50,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.fromBorderSide(
          pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: typo.microBold.copyWith(
              color: PdfThemeColors.slate500,
              letterSpacing: 0.3,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: typo.monoStat.copyWith(
              color: valueColor ?? PdfThemeColors.slate900,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            subtitle,
            style: typo.micro.copyWith(
              color: PdfThemeColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  /// Section heading with an optional subtitle and an accent line.
  static pw.Widget sectionHeader(
    String title, {
    String? subtitle,
    required PdfTypography typo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title.toUpperCase(),
              style: typo.captionBold.copyWith(
                color: PdfThemeColors.slate900,
                letterSpacing: 0.5,
              ),
            ),
            if (subtitle != null)
              pw.Text(
                subtitle,
                style: typo.micro.copyWith(
                  color: PdfThemeColors.slate500,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Container(
          height: 1.5,
          color: PdfThemeColors.indigo,
        ),
      ],
    );
  }

  /// Stacked horizontal bar chart segmenting time by project or classification.
  static pw.Widget stackedBar({
    required List<ReportSlice> slices,
    required Duration totalDuration,
    required PdfTypography typo,
    double height = 12,
  }) {
    if (slices.isEmpty || totalDuration <= Duration.zero) {
      return pw.Container(
        height: height,
        decoration: const pw.BoxDecoration(
          color: PdfThemeColors.slate200,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
      );
    }

    return pw.ClipRRect(
      horizontalRadius: 3,
      verticalRadius: 3,
      child: pw.Container(
        height: height,
        child: pw.Row(
          children: [
            for (final slice in slices)
              if (slice.duration.inSeconds > 0)
                pw.Expanded(
                  flex: (slice.share * 1000).round().clamp(1, 1000000),
                  child: pw.Container(
                    color: slice.color,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// Donut breakdown chart for classification (bounded in a SizedBox).
  static pw.Widget donutChart({
    required double capexShare,
    required double opexShare,
    required double unclassifiedShare,
    required String centerLabel,
    required String centerSub,
    required PdfTypography typo,
    double size = 90,
  }) {
    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.Chart(
        grid: pw.PieGrid(),
        datasets: [
          if (capexShare > 0)
            pw.PieDataSet(
              value: capexShare,
              color: PdfThemeColors.capex,
              innerRadius: 0.55,
            ),
          if (opexShare > 0)
            pw.PieDataSet(
              value: opexShare,
              color: PdfThemeColors.opex,
              innerRadius: 0.55,
            ),
          if (unclassifiedShare > 0)
            pw.PieDataSet(
              value: unclassifiedShare,
              color: PdfThemeColors.unclassified,
              innerRadius: 0.55,
            ),
          if (capexShare == 0 && opexShare == 0 && unclassifiedShare == 0)
            pw.PieDataSet(
              value: 1.0,
              color: PdfThemeColors.slate200,
              innerRadius: 0.55,
            ),
        ],
      ),
    );
  }

  /// Compact chip wrapped in pw.Wrap, never using screen-bright text colors.
  static pw.Widget chip({
    required String text,
    PdfColor? dotColor,
    PdfColor? barColor,
    required PdfTypography typo,
    bool dense = false,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: dense ? 4 : 6,
        vertical: dense ? 1.5 : 2.5,
      ),
      margin: const pw.EdgeInsets.only(right: 4, bottom: 3),
      decoration: const pw.BoxDecoration(
        color: PdfThemeColors.slate100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            pw.Container(
              width: dense ? 4 : 5,
              height: dense ? 4 : 5,
              decoration: pw.BoxDecoration(
                color: dotColor,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 3),
          ] else if (barColor != null) ...[
            pw.Container(
              width: 2,
              height: dense ? 6 : 8,
              color: barColor,
            ),
            pw.SizedBox(width: 3),
          ],
          pw.Text(
            text,
            style: dense
                ? typo.microMedium.copyWith(color: PdfThemeColors.slate800)
                : typo.captionMedium.copyWith(color: PdfThemeColors.slate800),
          ),
        ],
      ),
    );
  }

  /// Bar-in-cell table row for Act II breakdowns.
  static pw.Widget barInCellRow({
    required String label,
    required Duration duration,
    required double share,
    required PdfColor color,
    required PdfTypography typo,
    String? subtitle,
    int? sessionCount,
    bool isUncategorized = false,
    bool isAttention = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // 1. Dot & Label
          pw.Container(
            width: 5,
            height: 5,
            decoration: pw.BoxDecoration(
              color: isAttention ? PdfThemeColors.attention : color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 5),
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: isUncategorized
                  ? typo.body.copyWith(
                      color: PdfThemeColors.slate500,
                      fontStyle: pw.FontStyle.italic,
                    )
                  : typo.bodyMedium,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          pw.SizedBox(width: 8),

          // 2. Embedded Proportional Progress Bar
          pw.Expanded(
            child: pw.Stack(
              alignment: pw.Alignment.centerLeft,
              children: [
                pw.Container(
                  height: 6,
                  decoration: const pw.BoxDecoration(
                    color: PdfThemeColors.slate100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                ),
                if (share > 0)
                  pw.LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints?.maxWidth ?? 100.0;
                      final barWidth = (maxWidth * share.clamp(0.0, 1.0))
                          .clamp(2.0, maxWidth);
                      return pw.Container(
                        width: barWidth,
                        height: 6,
                        decoration: pw.BoxDecoration(
                          color: isAttention ? PdfThemeColors.attention : color,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(2)),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),

          // 3. Duration in Mono
          pw.SizedBox(
            width: 52,
            child: pw.Text(
              TimerService.formatDuration(duration, includeSeconds: false),
              textAlign: pw.TextAlign.right,
              style: typo.monoBodyBold,
            ),
          ),
          pw.SizedBox(width: 8),

          // 4. Share Percentage in Mono
          pw.SizedBox(
            width: 34,
            child: pw.Text(
              '${(share * 100).toStringAsFixed(0)}%',
              textAlign: pw.TextAlign.right,
              style: typo.monoCaption,
            ),
          ),

          // 5. Session Count
          if (sessionCount != null) ...[
            pw.SizedBox(width: 8),
            pw.SizedBox(
              width: 44,
              child: pw.Text(
                '$sessionCount sess',
                textAlign: pw.TextAlign.right,
                style: typo.micro,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Insight finding card for Act I (Sustain, Reclaim, Plan, Delegate).
  static pw.Widget insightCard({
    required ReportInsight insight,
    required PdfTypography typo,
  }) {
    PdfColor laneColor;

    switch (insight.lane.toLowerCase()) {
      case 'sustain':
        laneColor = PdfThemeColors.netFocus;
        break;
      case 'reclaim':
        laneColor = PdfThemeColors.opex;
        break;
      case 'plan':
        laneColor = PdfThemeColors.indigo;
        break;
      case 'delegate':
      default:
        laneColor = PdfThemeColors.sky;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfThemeColors.slate50,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.fromBorderSide(
          pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 9,
                color: laneColor,
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                insight.lane.toUpperCase(),
                style: typo.microBold.copyWith(
                  color: laneColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            insight.finding,
            style: typo.captionMedium.copyWith(
              color: PdfThemeColors.slate900,
            ),
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
          ),
          if (insight.evidence.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              '— ${insight.evidence}',
              style: typo.micro.copyWith(
                color: PdfThemeColors.slate500,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ],
        ],
      ),
    );
  }
}
