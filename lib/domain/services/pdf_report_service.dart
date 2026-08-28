import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/models/financial_classification.dart';
import 'package:workpulse/domain/models/work_pattern_model.dart';
import 'package:workpulse/domain/models/work_report_model.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/pdf/pdf_primitives.dart';
import 'package:workpulse/domain/services/pdf/pdf_theme.dart';
import 'package:workpulse/domain/services/report_builder_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';
import 'package:workpulse/domain/services/timesheet_code_resolver.dart';

/// Generates a modern, professional, 3-act executive PDF infographic report.
///
/// Layout follows `docs/PDF_REPORT_DESIGN.md`:
/// - **Act I — The Story**: Exactly 1 page summarizing what happened.
/// - **Act II — The Breakdown**: Bar-in-cell breakdown tables.
/// - **Act III — The Record**: Task-grouped notes & dense session table.
class PdfReportService {
  final ReportBuilderService _builder;

  const PdfReportService({ReportBuilderService? builder})
      : _builder = builder ?? const ReportBuilderService();

  /// Generates the complete PDF report byte array.
  Future<Uint8List> generateReportPdf({
    required String workspaceName,
    required DateRange range,
    required List<SessionExportRecord> records,
    List<AttributeDefinition> attributeDefinitions = const [],
    String? userName,
    TimesheetCodeResolver codes = const TimesheetCodeResolver(),
    WorkPatternReport? patterns,
    @visibleForTesting bool compress = true,
  }) async {
    final report = _builder.build(
      workspaceName: workspaceName,
      authorName: userName,
      range: range,
      records: records,
      definitions: attributeDefinitions,
      codes: codes,
      patterns: patterns,
    );

    final typo = await PdfTypography.load();

    final doc = pw.Document(
      compress: compress,
      title: '$workspaceName - Work Report, ${report.identity.dateSubtitle}',
      author: userName ?? 'WorkPulse User',
      creator: 'WorkPulse',
      producer: 'WorkPulse',
      subject: report.identity.dateSubtitle,
    );

    if (report.isEmpty) {
      _buildEmptyReport(doc, report, typo);
      return doc.save();
    }

    // --- Act I: The Story (Exactly 1 page, standalone Page widget) ---
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => _buildActI(context, report, typo),
      ),
    );

    // --- Act II & III: The Breakdown & The Record (MultiPage) ---
    doc.addPage(
      pw.MultiPage(
        maxPages: 100,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildRunningHeader(context, report, typo),
        footer: (context) => _buildRunningFooter(context, report, typo, pageOffset: 1),
        build: (context) => [
          // Act II: The Breakdown
          ..._buildActII(report, typo),
          pw.SizedBox(height: 20),

          // Act III: The Record (Notes & Session Table)
          ..._buildActIII(report, typo),
        ],
      ),
    );

    return doc.save();
  }

  // ===========================================================================
  // Empty State Report (1 page)
  // ===========================================================================
  void _buildEmptyReport(
    pw.Document doc,
    WorkReport report,
    PdfTypography typo,
  ) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            PdfPrimitives.masthead(
              workspaceName: report.identity.workspaceName,
              authorName: report.identity.authorName,
              dateSubtitle: report.identity.dateSubtitle,
              totalNet: Duration.zero,
              typo: typo,
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: const pw.BoxDecoration(
                  color: PdfThemeColors.slate50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.fromBorderSide(
                    pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
                  ),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'No time tracked in this period',
                      style: typo.h2.copyWith(color: PdfThemeColors.slate700),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Sessions logged within ${report.identity.dateSubtitle} will appear here.',
                      style: typo.body.copyWith(color: PdfThemeColors.slate500),
                    ),
                  ],
                ),
              ),
            ),
            pw.Spacer(),
            _buildRunningFooter(context, report, typo),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Act I: The Story (1 Page, fixed)
  // ===========================================================================
  pw.Widget _buildActI(
    pw.Context context,
    WorkReport report,
    PdfTypography typo,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // 1. Masthead Hero Banner
        PdfPrimitives.masthead(
          workspaceName: report.identity.workspaceName,
          authorName: report.identity.authorName,
          dateSubtitle: report.identity.dateSubtitle,
          totalNet: report.headline.totalNet,
          typo: typo,
        ),
        pw.SizedBox(height: 10),

        // 2. 5 Stat Tiles
        PdfPrimitives.statTilesRow(
          headline: report.headline,
          typo: typo,
        ),
        pw.SizedBox(height: 12),

        // 3. Middle Band: "Where the Time Went" + "How it Classifies"
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Where the Time Went (Projects)
            pw.Expanded(
              flex: 11,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfThemeColors.slate50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                  border: pw.Border.fromBorderSide(
                    pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'WHERE THE TIME WENT',
                      style: typo.microBold.copyWith(
                        color: PdfThemeColors.slate900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    PdfPrimitives.stackedBar(
                      slices: report.projects,
                      totalDuration: report.headline.totalNet,
                      typo: typo,
                      height: 8,
                    ),
                    pw.SizedBox(height: 8),
                    for (final p in report.projects.take(4))
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 5,
                              height: 5,
                              decoration: pw.BoxDecoration(
                                color: p.color,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 4),
                            pw.Expanded(
                              child: pw.Text(
                                p.label,
                                style: typo.microMedium,
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                              ),
                            ),
                            pw.Text(
                              TimerService.formatDuration(p.duration, includeSeconds: false),
                              style: typo.monoMicro,
                            ),
                            pw.SizedBox(width: 6),
                            pw.SizedBox(
                              width: 24,
                              child: pw.Text(
                                '${(p.share * 100).toStringAsFixed(0)}%',
                                textAlign: pw.TextAlign.right,
                                style: typo.monoMicro.copyWith(color: PdfThemeColors.slate500),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 10),

            // Right: How It Classifies (Donut)
            pw.Expanded(
              flex: 10,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfThemeColors.slate50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                  border: pw.Border.fromBorderSide(
                    pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HOW IT CLASSIFIES',
                      style: typo.microBold.copyWith(
                        color: PdfThemeColors.slate900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        PdfPrimitives.donutChart(
                          capexShare: report.classification.capex.inSeconds.toDouble(),
                          opexShare: report.classification.opex.inSeconds.toDouble(),
                          unclassifiedShare: report.classification.none.inSeconds.toDouble(),
                          centerLabel: report.classification.classifiedTotal > Duration.zero
                              ? '${report.classification.capexShare.toStringAsFixed(0)}%'
                              : '—',
                          centerSub: 'CapEx',
                          typo: typo,
                          size: 64,
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildClassLegendRow('CapEx', report.classification.capex,
                                  report.classification.capexShare, PdfThemeColors.capex, typo),
                              pw.SizedBox(height: 3),
                              _buildClassLegendRow('OpEx', report.classification.opex,
                                  report.classification.opexShare, PdfThemeColors.opex, typo),
                              if (report.classification.hasNone) ...[
                                pw.SizedBox(height: 3),
                                _buildClassLegendRow('Unclass', report.classification.none,
                                    null, PdfThemeColors.unclassified, typo),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        // 4. Daily Rhythm Section
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: PdfThemeColors.slate50,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
            border: pw.Border.fromBorderSide(
              pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'DAILY RHYTHM',
                    style: typo.microBold.copyWith(
                      color: PdfThemeColors.slate900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.Text(
                    report.rhythmAxis == RhythmAxis.hour
                        ? 'Hour of Day (06:00 – 22:00)'
                        : (report.rhythmAxis == RhythmAxis.week ? 'Weekly Rollup' : 'Active Days'),
                    style: typo.micro.copyWith(color: PdfThemeColors.slate500),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              _buildRhythmBars(report.rhythm, typo),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // 5. Headline Prose Summary
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: PdfThemeColors.indigoLight,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'WHAT THIS PERIOD LOOKED LIKE',
                style: typo.microBold.copyWith(
                  color: PdfThemeColors.indigoDark,
                  letterSpacing: 0.3,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                report.headline.proseLine,
                style: typo.captionMedium.copyWith(color: PdfThemeColors.slate900),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),

        // 6. Insight Cards (Capped at 3, dropped if space demands)
        if (report.insights.isNotEmpty) ...[
          pw.Row(
            children: [
              for (final ins in report.insights.take(3)) ...[
                pw.Expanded(
                  child: PdfPrimitives.insightCard(insight: ins, typo: typo),
                ),
                if (ins != report.insights.take(3).last) pw.SizedBox(width: 8),
              ],
            ],
          ),
        ],

        pw.Spacer(),
        // Running footer for Page 1
        _buildRunningFooter(context, report, typo),
      ],
    );
  }

  pw.Widget _buildClassLegendRow(
    String label,
    Duration duration,
    double? share,
    PdfColor color,
    PdfTypography typo,
  ) {
    final shareStr = share != null ? ' (${share.toStringAsFixed(0)}%)' : '';
    return pw.Row(
      children: [
        pw.Container(
          width: 5,
          height: 5,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: typo.microBold.copyWith(color: PdfThemeColors.slate800)),
        pw.Spacer(),
        pw.Text(
          '${TimerService.formatDuration(duration, compact: true)}$shareStr',
          style: typo.monoMicro,
        ),
      ],
    );
  }

  pw.Widget _buildRhythmBars(List<ReportBucket> rhythm, PdfTypography typo) {
    if (rhythm.isEmpty) {
      return pw.SizedBox(height: 28);
    }

    final maxDurSeconds = rhythm.map((b) => b.totalDuration.inSeconds).fold(0, max);
    final maxSafe = maxDurSeconds > 0 ? maxDurSeconds : 1;

    return pw.Container(
      height: 38,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final b in rhythm)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    if (b.totalDuration > Duration.zero)
                      pw.Container(
                        height: (b.totalDuration.inSeconds / maxSafe * 24).clamp(3.0, 24.0),
                        decoration: pw.BoxDecoration(
                          color: b.capexDuration > b.opexDuration
                              ? PdfThemeColors.capex
                              : PdfThemeColors.opex,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
                        ),
                      )
                    else
                      pw.Container(
                        height: 2,
                        color: PdfThemeColors.slate200,
                      ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      b.label,
                      style: typo.micro.copyWith(fontSize: 5.5, color: PdfThemeColors.slate500),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Act II: The Breakdown (Bar-in-cell tables)
  // ===========================================================================
  // ===========================================================================
  // Act II: The Breakdown (Bar-in-cell tables)
  // ===========================================================================
  List<pw.Widget> _buildActII(WorkReport report, PdfTypography typo) {
    return [
      PdfPrimitives.sectionHeader('ACT II — THE BREAKDOWN', typo: typo),
      pw.SizedBox(height: 10),

      // 1. By Project
      if (report.projects.isNotEmpty) ...[
        pw.Text('By Project', style: typo.h3),
        pw.SizedBox(height: 4),
        for (final p in report.projects)
          PdfPrimitives.barInCellRow(
            label: p.label,
            duration: p.duration,
            share: p.share,
            color: p.color,
            sessionCount: p.sessionCount,
            typo: typo,
          ),
        pw.SizedBox(height: 12),
      ],

      // 2. By Category (Uncategorized sorts last)
      if (report.categories.isNotEmpty) ...[
        pw.Text('By Category', style: typo.h3),
        pw.SizedBox(height: 4),
        for (final c in report.categories)
          PdfPrimitives.barInCellRow(
            label: c.label,
            duration: c.duration,
            share: c.share,
            color: c.color,
            sessionCount: c.sessionCount,
            isUncategorized: c.isUncategorized,
            typo: typo,
          ),
        pw.SizedBox(height: 12),
      ],

      // 3. By Financial Classification
      pw.Text('By Financial Classification', style: typo.h3),
      pw.SizedBox(height: 4),
      PdfPrimitives.barInCellRow(
        label: 'CapEx (Capitalizable)',
        duration: report.classification.capex,
        share: report.headline.totalNet.inSeconds > 0
            ? report.classification.capex.inSeconds / report.headline.totalNet.inSeconds
            : 0.0,
        color: PdfThemeColors.capex,
        typo: typo,
      ),
      PdfPrimitives.barInCellRow(
        label: 'OpEx (Operational)',
        duration: report.classification.opex,
        share: report.headline.totalNet.inSeconds > 0
            ? report.classification.opex.inSeconds / report.headline.totalNet.inSeconds
            : 0.0,
        color: PdfThemeColors.opex,
        typo: typo,
      ),
      if (report.classification.hasNone)
        PdfPrimitives.barInCellRow(
          label: 'Unclassified',
          duration: report.classification.none,
          share: report.headline.totalNet.inSeconds > 0
              ? report.classification.none.inSeconds / report.headline.totalNet.inSeconds
              : 0.0,
          color: PdfThemeColors.unclassified,
          isUncategorized: true,
          typo: typo,
        ),
      pw.SizedBox(height: 12),

      // 4. By Timesheet Code
      if (report.codes.isNotEmpty) ...[
        pw.Text('By Timesheet Code', style: typo.h3),
        pw.SizedBox(height: 4),
        for (final code in report.codes)
          PdfPrimitives.barInCellRow(
            label: code.code,
            duration: code.duration,
            share: code.share,
            color: code.needsAttention ? PdfThemeColors.attention : PdfThemeColors.slate700,
            isAttention: code.needsAttention,
            typo: typo,
          ),
        pw.SizedBox(height: 12),
      ],

      // 5. Configurable Attributes Breakdown
      for (final attr in report.attributes) ...[
        pw.Text('By ${attr.definitionName}', style: typo.h3),
        pw.SizedBox(height: 4),
        for (final s in attr.slices)
          PdfPrimitives.barInCellRow(
            label: s.label,
            duration: s.duration,
            share: s.share,
            color: s.color,
            sessionCount: s.sessionCount,
            isUncategorized: s.isUncategorized,
            typo: typo,
          ),
        pw.SizedBox(height: 12),
      ],

      // 6. Top Tasks Table
      if (report.topTasks.isNotEmpty) ...[
        pw.Text('Top Work Items', style: typo.h3),
        pw.SizedBox(height: 4),
        for (final t in report.topTasks)
          PdfPrimitives.barInCellRow(
            label: t.taskName,
            duration: t.totalDuration,
            share: t.share,
            color: PdfThemeColors.entityColor(t.projectColorHex, t.taskId),
            sessionCount: t.sessionCount,
            typo: typo,
          ),
        if (report.topTasksRemainderCount > 0) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            '+ ${report.topTasksRemainderCount} more tasks',
            style: typo.micro.copyWith(color: PdfThemeColors.slate500, fontStyle: pw.FontStyle.italic),
          ),
        ],
        pw.SizedBox(height: 12),
      ],

      // 7. People & Tags summary chips
      if (report.people.isNotEmpty || report.tags.isNotEmpty) ...[
        pw.Text('Collaborators & Tags', style: typo.h3),
        pw.SizedBox(height: 4),
        pw.Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final p in report.people)
              PdfPrimitives.chip(
                text: '${p.label} (${TimerService.formatDuration(p.duration, compact: true)})',
                dotColor: p.color,
                typo: typo,
              ),
            for (final t in report.tags)
              PdfPrimitives.chip(
                text: '${t.label} (${TimerService.formatDuration(t.duration, compact: true)})',
                barColor: t.color,
                typo: typo,
              ),
          ],
        ),
      ],
    ];
  }

  // ===========================================================================
  // Act III: The Record (Notes & Detailed Session Table)
  // ===========================================================================
  List<pw.Widget> _buildActIII(WorkReport report, PdfTypography typo) {
    return [
      PdfPrimitives.sectionHeader('ACT III — THE RECORD', typo: typo),
      pw.SizedBox(height: 10),

      // 6a: Task-Grouped Notes (via TimeNotesService)
      if (report.notes.totalNotes > 0) ...[
        pw.Text('Notes & Highlights', style: typo.h2),
        pw.SizedBox(height: 6),
        for (final dayGroup in report.notes.dayGroups) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfThemeColors.slate100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(dayGroup.day),
                  style: typo.captionBold,
                ),
                pw.Text(
                  '${TimerService.formatDuration(dayGroup.totalDuration, compact: true)} · ${dayGroup.noteCount} notes',
                  style: typo.monoCaption,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          for (final taskGroup in dayGroup.taskGroups)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8, bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Task header with promoted metadata
                  pw.Row(
                    children: [
                      pw.Text(taskGroup.workItem.name, style: typo.bodyBold),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        '(${taskGroup.sessionCount} sessions · ${TimerService.formatDuration(taskGroup.totalDuration, compact: true)})',
                        style: typo.caption.copyWith(color: PdfThemeColors.slate500),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  // Promoted chips
                  pw.Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (taskGroup.project != null)
                        PdfPrimitives.chip(
                          text: taskGroup.project!.name,
                          dotColor: PdfThemeColors.entityColor(
                              taskGroup.project!.colorHex, taskGroup.project!.id),
                          dense: true,
                          typo: typo,
                        ),
                      if (taskGroup.category != null)
                        PdfPrimitives.chip(
                          text: taskGroup.category!.name,
                          dotColor: PdfThemeColors.entityColor(null, taskGroup.category!.id),
                          dense: true,
                          typo: typo,
                        ),
                      if (taskGroup.classification != FinancialClassification.none)
                        PdfPrimitives.chip(
                          text: taskGroup.classification.label,
                          dotColor: taskGroup.classification == FinancialClassification.capex
                              ? PdfThemeColors.capex
                              : PdfThemeColors.opex,
                          dense: true,
                          typo: typo,
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  // Individual notes
                  for (final entry in taskGroup.entries)
                    if (entry.note.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 6, bottom: 3),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ', style: typo.body.copyWith(color: PdfThemeColors.indigo)),
                            pw.Expanded(
                              child: pw.Text(
                                entry.note,
                                style: typo.body.copyWith(color: PdfThemeColors.slate800),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
        ],
        pw.SizedBox(height: 14),
      ],

      // 6b: Dense Session Table
      pw.Text('Session Log', style: typo.h2),
      pw.SizedBox(height: 6),
      _buildSessionTable(report.sessions, typo),
    ];
  }

  pw.Widget _buildSessionTable(List<ReportSessionLine> sessions, PdfTypography typo) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'Date',
        'Time',
        'Task',
        'Project',
        'Category',
        'Class',
        'Code',
        'Net',
      ],
      data: [
        for (final s in sessions)
          [
            DateFormat('MM/dd').format(s.session.startTime.toLocal()),
            '${DateFormat('HH:mm').format(s.session.startTime.toLocal())}–${s.session.endTime != null ? DateFormat('HH:mm').format(s.session.endTime!.toLocal()) : 'now'}',
            s.workItem.name,
            s.project?.name ?? '—',
            s.category?.name ?? 'Unclass',
            s.classification.label,
            s.code ?? '—',
            TimerService.formatDuration(s.netActiveDuration, compact: true),
          ],
      ],
      headerStyle: typo.microBold.copyWith(color: PdfThemeColors.slate900),
      headerDecoration: const pw.BoxDecoration(color: PdfThemeColors.slate100),
      cellStyle: typo.micro.copyWith(color: PdfThemeColors.slate800),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        7: pw.Alignment.centerRight,
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
        ),
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfThemeColors.slate50,
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(34),
        1: const pw.FixedColumnWidth(54),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FixedColumnWidth(36),
        6: const pw.FixedColumnWidth(44),
        7: const pw.FixedColumnWidth(36),
      },
    );
  }

  // ===========================================================================
  // Running Header & Footer
  // ===========================================================================
  pw.Widget _buildRunningHeader(
    pw.Context context,
    WorkReport report,
    PdfTypography typo,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${report.identity.workspaceName} · ${report.identity.dateSubtitle}',
            style: typo.micro.copyWith(color: PdfThemeColors.slate500),
          ),
          pw.Text(
            'WorkPulse',
            style: typo.microBold.copyWith(color: PdfThemeColors.slate500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRunningFooter(
    pw.Context context,
    WorkReport report,
    PdfTypography typo, {
    int pageOffset = 0,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfThemeColors.slate200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${report.identity.workspaceName} · ${report.identity.dateSubtitle}',
            style: typo.micro.copyWith(color: PdfThemeColors.slate400),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: typo.microBold.copyWith(color: PdfThemeColors.slate500),
          ),
        ],
      ),
    );
  }
}
