import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/date_range.dart';
import 'package:workpulse/domain/services/export_service.dart';
import 'package:workpulse/domain/services/timer_service.dart';

class PdfReportService {
  // Brand & Modern Report Color Palette
  static const _indigo = PdfColor.fromInt(0xFF4F46E5);
  static const _indigoLight = PdfColor.fromInt(0xFFEEF2FF);
  static const _indigoDark = PdfColor.fromInt(0xFF3730A3);

  static const _emerald = PdfColor.fromInt(0xFF059669);
  static const _emeraldLight = PdfColor.fromInt(0xFFECFDF5);

  static const _amber = PdfColor.fromInt(0xFFD97706);
  static const _amberLight = PdfColor.fromInt(0xFFFFFBEB);

  static const _blue = PdfColor.fromInt(0xFF2563EB);
  static const _blueLight = PdfColor.fromInt(0xFFEFF6FF);

  static const _slate900 = PdfColor.fromInt(0xFF0F172A);
  static const _slate800 = PdfColor.fromInt(0xFF1E293B);
  static const _slate700 = PdfColor.fromInt(0xFF334155);
  static const _slate500 = PdfColor.fromInt(0xFF64748B);
  static const _slate400 = PdfColor.fromInt(0xFF94A3B8);
  static const _slate200 = PdfColor.fromInt(0xFFE2E8F0);
  static const _slate100 = PdfColor.fromInt(0xFFF1F5F9);
  static const _slate50 = PdfColor.fromInt(0xFFF8FAFC);

  static const _palette = [
    PdfColor.fromInt(0xFF6366F1), // Indigo
    PdfColor.fromInt(0xFF0EA5E9), // Sky
    PdfColor.fromInt(0xFF10B981), // Emerald
    PdfColor.fromInt(0xFFF59E0B), // Amber
    PdfColor.fromInt(0xFFEC4899), // Pink
    PdfColor.fromInt(0xFF8B5CF6), // Purple
    PdfColor.fromInt(0xFF14B8A6), // Teal
    PdfColor.fromInt(0xFFF97316), // Orange
  ];

  /// Generates a comprehensive, colorful modern PDF report.
  Future<Uint8List> generateReportPdf({
    required String workspaceName,
    required DateRange range,
    required List<SessionExportRecord> records,
    List<AttributeDefinition> attributeDefinitions = const [],
    String? userName,
  }) async {
    final effectiveUserName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : 'User';
    final doc = pw.Document();

    pw.ThemeData theme;
    try {
      final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
      theme = pw.ThemeData.withFont(
        base: pw.Font.ttf(fontData),
        bold: pw.Font.ttf(boldData),
      );
    } catch (_) {
      theme = pw.ThemeData.base();
    }

    // 1. Calculate Aggregations
    Duration totalGross = Duration.zero;
    Duration totalIdle = Duration.zero;
    Duration totalNet = Duration.zero;

    final projectTotals = <String, Duration>{};
    final projectColorMap = <String, PdfColor>{};
    final categoryTotals = <String, Duration>{};
    final taskTotals = <String, _TaskSummary>{};
    final allNotes = <_SessionNoteSummary>[];

    var colorIndex = 0;

    for (final r in records) {
      totalGross += r.grossDuration;
      totalIdle += r.idleDuration;
      totalNet += r.netActiveDuration;

      // Project aggregation
      final projName = r.project?.name ?? 'No Project';
      projectTotals[projName] =
          (projectTotals[projName] ?? Duration.zero) + r.netActiveDuration;
      if (!projectColorMap.containsKey(projName)) {
        projectColorMap[projName] = _palette[colorIndex % _palette.length];
        colorIndex++;
      }

      // Category aggregation (accurately tracks each session's category override or task category)
      final sessionCatName = r.category?.name ?? 'Uncategorized';
      categoryTotals[sessionCatName] =
          (categoryTotals[sessionCatName] ?? Duration.zero) +
              r.netActiveDuration;

      // Task aggregation (collects all session categories for the same work item)
      final taskKey = r.workItem.id;
      final existingTask = taskTotals[taskKey];
      if (existingTask == null) {
        taskTotals[taskKey] = _TaskSummary(
          taskId: r.workItem.id,
          taskName: r.workItem.name,
          projectName: r.project?.name ?? '-',
          categories: {sessionCatName},
          totalDuration: r.netActiveDuration,
          sessionCount: 1,
        );
      } else {
        taskTotals[taskKey] = _TaskSummary(
          taskId: r.workItem.id,
          taskName: r.workItem.name,
          projectName: r.project?.name ?? existingTask.projectName,
          categories: {...existingTask.categories, sessionCatName},
          totalDuration: existingTask.totalDuration + r.netActiveDuration,
          sessionCount: existingTask.sessionCount + 1,
        );
      }

      // Notes
      final note = r.session.notes?.trim();
      if (note != null && note.isNotEmpty) {
        allNotes.add(_SessionNoteSummary(
          taskName: r.workItem.name,
          projectName: r.project?.name,
          note: note,
          duration: r.netActiveDuration,
          startTime: r.session.startTime,
        ));
      }
    }

    final efficiency = totalGross.inSeconds > 0
        ? (totalNet.inSeconds / totalGross.inSeconds) * 100
        : 100.0;

    final isSingleDay = _isSameCalendarDay(range.start, range.end);
    final dateSubtitle = isSingleDay
        ? DateFormat('EEEE, MMMM d, yyyy').format(range.start.toLocal())
        : '${DateFormat('MMM d, yyyy').format(range.start.toLocal())} - ${DateFormat('MMM d, yyyy').format(range.end.toLocal())}';

    // 2. Build Document Pages
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        header: (context) => _buildPageHeader(
          context: context,
          workspaceName: workspaceName,
          userName: effectiveUserName,
          dateSubtitle: dateSubtitle,
          isSingleDay: isSingleDay,
        ),
        footer: (context) => _buildPageFooter(
          context: context,
          userName: effectiveUserName,
        ),
        build: (context) {
          return [
            // Title & Workspace Banner
            _buildBanner(
              workspaceName: workspaceName,
              userName: effectiveUserName,
              dateSubtitle: dateSubtitle,
              isSingleDay: isSingleDay,
              totalNet: totalNet,
              sessionCount: records.length,
            ),
            pw.SizedBox(height: 16),

            // Executive KPI Cards
            _buildKpiSection(
              totalGross: totalGross,
              totalNet: totalNet,
              totalIdle: totalIdle,
              efficiency: efficiency,
              taskCount: taskTotals.length,
              sessionCount: records.length,
            ),
            pw.SizedBox(height: 20),

            // Visual Categorization Breakdown (Projects & Categories)
            _buildCategorizationSection(
              totalNet: totalNet,
              projectTotals: projectTotals,
              projectColorMap: projectColorMap,
              categoryTotals: categoryTotals,
            ),
            pw.SizedBox(height: 20),

            // Task Aggregation Matrix
            if (taskTotals.isNotEmpty) ...[
              _buildTaskSummaryTable(
                tasks: taskTotals.values.toList(),
                totalDayNet: totalNet,
              ),
              pw.SizedBox(height: 20),
            ],

            // Daily Standup / Accomplishments Summary
            if (allNotes.isNotEmpty) ...[
              _buildNotesCallout(allNotes),
              pw.SizedBox(height: 20),
            ],

            // Complete Chronological Session Timeline
            _buildSessionTimeline(
              records: records,
              attributeDefinitions: attributeDefinitions,
              projectColorMap: projectColorMap,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  // --- UI Components ---

  static pw.Widget _buildPageHeader({
    required pw.Context context,
    required String workspaceName,
    required String userName,
    required String dateSubtitle,
    required bool isSingleDay,
  }) {
    if (context.pageNumber == 1) {
      return pw.SizedBox.shrink();
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _slate200, width: 0.75)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'WorkPulse | $userName | $workspaceName | $dateSubtitle',
            style: const pw.TextStyle(
              fontSize: 8,
              color: _slate500,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: _slate500,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter({
    required pw.Context context,
    required String userName,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _slate200, width: 0.75)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated locally for $userName with WorkPulse - Privacy-First & Offline-First',
            style: const pw.TextStyle(fontSize: 7.5, color: _slate400),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _slate500,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBanner({
    required String workspaceName,
    required String userName,
    required String dateSubtitle,
    required bool isSingleDay,
    required Duration totalNet,
    required int sessionCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        color: _indigoDark,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const pw.BoxDecoration(
                        color: _indigo,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        isSingleDay
                            ? 'DAILY WORK REPORT'
                            : 'WORK & ACTIVITY REPORT',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const pw.BoxDecoration(
                        color: _indigoLight,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'Report for $userName',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: _indigoDark,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      workspaceName,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: _indigoLight,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  dateSubtitle,
                  style: const pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Team Member: $userName | Prepared for Manager / Standup Review | $sessionCount sessions recorded',
                  style: const pw.TextStyle(fontSize: 8.5, color: _indigoLight),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'TOTAL TIME',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _slate500,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  TimerService.formatDuration(totalNet, includeSeconds: false),
                  style: const pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _indigoDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiSection({
    required Duration totalGross,
    required Duration totalNet,
    required Duration totalIdle,
    required double efficiency,
    required int taskCount,
    required int sessionCount,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildKpiCard(
            title: 'TOTAL TRACKED',
            value:
                TimerService.formatDuration(totalGross, includeSeconds: false),
            subtitle: '$sessionCount sessions logged',
            accentColor: _blue,
            bgColor: _blueLight,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiCard(
            title: 'NET FOCUS TIME',
            value: TimerService.formatDuration(totalNet, includeSeconds: false),
            subtitle: '${efficiency.toStringAsFixed(0)}% focus efficiency',
            accentColor: _emerald,
            bgColor: _emeraldLight,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiCard(
            title: 'IDLE DEDUCTIONS',
            value:
                TimerService.formatDuration(totalIdle, includeSeconds: false),
            subtitle: totalIdle.inMinutes > 0
                ? 'Excluded inactivity'
                : 'Zero idle detected',
            accentColor: _amber,
            bgColor: _amberLight,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiCard(
            title: 'ACTIVE TASKS',
            value: '$taskCount',
            subtitle: 'Worked on today',
            accentColor: _indigo,
            bgColor: _indigoLight,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor accentColor,
    required PdfColor bgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _slate200, width: 0.75),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: _slate900,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 7.5, color: _slate500),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCategorizationSection({
    required Duration totalNet,
    required Map<String, Duration> projectTotals,
    required Map<String, PdfColor> projectColorMap,
    required Map<String, Duration> categoryTotals,
  }) {
    final sortedProjects = projectTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalSeconds = totalNet.inSeconds > 0 ? totalNet.inSeconds : 1;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _slate50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _slate200, width: 0.75),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TIME BREAKDOWN & CATEGORIZATION',
            style: const pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _slate800,
            ),
          ),
          pw.SizedBox(height: 8),

          // Visual Progress Bar for Projects
          if (sortedProjects.isNotEmpty) ...[
            pw.ClipRRect(
              horizontalRadius: 3,
              verticalRadius: 3,
              child: pw.Container(
                height: 7,
                child: pw.Row(
                  children: sortedProjects.map((entry) {
                    final flex = (entry.value.inSeconds / totalSeconds * 1000)
                        .round()
                        .clamp(1, 1000);
                    return pw.Expanded(
                      flex: flex,
                      child: pw.Container(
                        color: projectColorMap[entry.key] ?? _indigo,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            pw.SizedBox(height: 10),
          ],

          // Two Columns: Projects & Categories
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Projects Column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Time by Project',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _slate700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    ...sortedProjects.map((entry) {
                      final pct = (entry.value.inSeconds / totalSeconds) * 100;
                      final col = projectColorMap[entry.key] ?? _indigo;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 6,
                              height: 6,
                              decoration: pw.BoxDecoration(
                                color: col,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                entry.key,
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: _slate800,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            pw.Text(
                              '${TimerService.formatDuration(entry.value, compact: true)} (${pct.toStringAsFixed(0)}%)',
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: _slate700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),

              // Categories Column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Time by Category',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _slate700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    ...sortedCategories.map((entry) {
                      final pct = (entry.value.inSeconds / totalSeconds) * 100;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 4,
                              height: 4,
                              decoration: const pw.BoxDecoration(
                                color: _slate500,
                                shape: pw.BoxShape.circle,
                              ),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Expanded(
                              child: pw.Text(
                                entry.key,
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: _slate800,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            pw.Text(
                              '${TimerService.formatDuration(entry.value, compact: true)} (${pct.toStringAsFixed(0)}%)',
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: _slate700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTaskSummaryTable({
    required List<_TaskSummary> tasks,
    required Duration totalDayNet,
  }) {
    tasks.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
    final totalSeconds = totalDayNet.inSeconds > 0 ? totalDayNet.inSeconds : 1;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _slate200, width: 0.75),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: pw.Text(
              'TASKS WORKED ON SUMMARY',
              style: const pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _slate800,
              ),
            ),
          ),
          pw.TableHelper.fromTextArray(
            border: null,
            headerStyle: const pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: _slate500,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: _slate100,
            ),
            cellHeight: 20,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
            headers: [
              'Task Name',
              'Project',
              'Category / Types',
              'Sessions',
              'Total Time',
              'Share',
            ],
            data: tasks.map((t) {
              final pct = (t.totalDuration.inSeconds / totalSeconds) * 100;
              final catDisplay = t.categories.where((c) => c != '-').join(', ');
              return [
                t.taskName,
                t.projectName,
                catDisplay.isNotEmpty ? catDisplay : 'Uncategorized',
                '${t.sessionCount}',
                TimerService.formatDuration(t.totalDuration,
                    includeSeconds: false),
                '${pct.toStringAsFixed(0)}%',
              ];
            }).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8, color: _slate800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNotesCallout(List<_SessionNoteSummary> notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _indigoLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _indigo.shade(0.3), width: 0.75),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: const pw.BoxDecoration(
                  color: _indigo,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 5),
              pw.Text(
                'STANDUP / PROGRESS HIGHLIGHTS & NOTES',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _indigoDark,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          ...notes.map((n) {
            final projSuffix =
                n.projectName != null ? ' [${n.projectName}]' : '';
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '- ${n.taskName}$projSuffix (${TimerService.formatDuration(n.duration, compact: true)})',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _slate900,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, top: 1),
                    child: pw.Text(
                      n.note,
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: _slate700,
                        lineSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildSessionTimeline({
    required List<SessionExportRecord> records,
    required List<AttributeDefinition> attributeDefinitions,
    required Map<String, PdfColor> projectColorMap,
  }) {
    final timeFormat = DateFormat('HH:mm');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETAILED SESSION TIMELINE',
          style: const pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _slate800,
          ),
        ),
        pw.SizedBox(height: 8),
        ...records.map((r) {
          final s = r.session;
          final start = s.startTime.toLocal();
          final end = s.endTime?.toLocal();
          final timeRangeStr = end != null
              ? '${timeFormat.format(start)} - ${timeFormat.format(end)}'
              : '${timeFormat.format(start)} - in progress';

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _slate200, width: 0.75),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header Row: Time Badge + Task Name + Duration
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Time range pill
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const pw.BoxDecoration(
                        color: _slate100,
                        borderRadius:
                            pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        timeRangeStr,
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _slate700,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),

                    // Task Title
                    pw.Expanded(
                      child: pw.Text(
                        r.workItem.name,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: _slate900,
                        ),
                        maxLines: 1,
                      ),
                    ),

                    // Duration
                    pw.Text(
                      TimerService.formatDuration(r.netActiveDuration,
                          includeSeconds: false),
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _indigo,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),

                // Classification Pills: Project, Category, Tags, People
                pw.Row(
                  children: [
                    if (r.project != null) ...[
                      _buildChip(
                        label: r.project!.name,
                        bgColor: _indigoLight,
                        textColor: _indigoDark,
                        borderColor: _indigo.shade(0.3),
                      ),
                      pw.SizedBox(width: 4),
                    ],
                    if (r.category != null) ...[
                      _buildChip(
                        label: r.category!.name,
                        bgColor: _emeraldLight,
                        textColor: _emerald,
                        borderColor: _emerald.shade(0.3),
                      ),
                      pw.SizedBox(width: 4),
                    ],
                    ...r.tags.map((tag) => pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 4),
                          child: _buildChip(
                            label: '#${tag.name}',
                            bgColor: _slate100,
                            textColor: _slate700,
                            borderColor: _slate200,
                          ),
                        )),
                    if (r.people.isNotEmpty) ...[
                      _buildChip(
                        label: 'with ${r.people.map((p) => p.name).join(', ')}',
                        bgColor: _blueLight,
                        textColor: _blue,
                        borderColor: _blue.shade(0.3),
                      ),
                      pw.SizedBox(width: 4),
                    ],
                    if (r.idleDuration.inSeconds > 0)
                      _buildChip(
                        label:
                            '-${TimerService.formatDuration(r.idleDuration, compact: true)} idle',
                        bgColor: _amberLight,
                        textColor: _amber,
                        borderColor: _amber.shade(0.3),
                      ),
                  ],
                ),

                // Session Notes
                if ((s.notes ?? '').trim().isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(
                      color: _slate50,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      s.notes!.trim(),
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: _slate700,
                        lineSpacing: 1.2,
                      ),
                    ),
                  ),
                ],

                // Configurable Custom Attributes
                if (r.attributeValues.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: r.attributeValues.entries.map((entry) {
                      final def = attributeDefinitions
                          .where((d) => d.id == entry.key)
                          .firstOrNull;
                      final label = def?.name ?? entry.key;
                      return pw.Text(
                        '$label: ${entry.value}',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: _slate500,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildChip({
    required String label,
    required PdfColor bgColor,
    required PdfColor textColor,
    PdfColor? borderColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        border: pw.Border.all(color: borderColor ?? bgColor, width: 0.5),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

class _TaskSummary {
  final String taskId;
  final String taskName;
  final String projectName;
  final Set<String> categories;
  final Duration totalDuration;
  final int sessionCount;

  const _TaskSummary({
    required this.taskId,
    required this.taskName,
    required this.projectName,
    required this.categories,
    required this.totalDuration,
    required this.sessionCount,
  });
}

class _SessionNoteSummary {
  final String taskName;
  final String? projectName;
  final String note;
  final Duration duration;
  final DateTime startTime;

  const _SessionNoteSummary({
    required this.taskName,
    this.projectName,
    required this.note,
    required this.duration,
    required this.startTime,
  });
}
