import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/date_range.dart';

/// How far back a pattern scan looks.
///
/// Patterns are, by definition, things that happened more than once, so the
/// insights panel deliberately does not follow the dashboard's Today / This
/// Week selector. A single day cannot tell you that a task keeps coming back,
/// or that a commitment has gone quiet.
enum PatternWindow {
  twoWeeks('Last 14 days', 14),
  oneMonth('Last 30 days', 30),
  oneQuarter('Last 90 days', 90);

  const PatternWindow(this.label, this.days);

  final String label;
  final int days;
}

/// What the user is meant to *do* about a detected pattern.
///
/// Every insight belongs to exactly one of these, because an observation the
/// reader cannot act on is just another number on a dashboard that already
/// has plenty.
enum InsightAction {
  /// What is already working, and is worth defending.
  ///
  /// First on purpose. A page that only ever lists faults trains the reader to
  /// stop opening it, and a habit nobody notices is the easiest one to lose.
  /// `sustain` rather than `continue` because `continue` is a Dart keyword.
  sustain('Continue', 'What is working — protect it'),

  /// Time leaving the day without anyone deciding it should.
  reclaim('Reclaim', 'Time going somewhere you did not choose to send it'),

  /// Repetitive work that would survive being handed to someone else.
  delegate('Delegate', 'Recurring work that hands over cleanly'),

  /// Commitments and scheduling worth protecting before the week fills up.
  plan('Plan', 'What next week needs room for');

  const InsightAction(this.label, this.description);

  final String label;
  final String description;
}

/// How loudly an insight should present itself, derived from how much time it
/// accounts for rather than from how interesting the detector found it.
enum InsightSeverity { informational, notable, high }

/// The dimension a pattern was detected on.
enum PatternSubject { workItem, project, category, person, schedule }

/// One supporting figure shown under an insight.
///
/// Insights make claims about the user's own week, so each one carries the
/// numbers it was derived from. Without them the panel is asking to be
/// trusted rather than read.
class InsightEvidence extends Equatable {
  final String label;
  final String value;

  const InsightEvidence(this.label, this.value);

  @override
  List<Object?> get props => [label, value];
}

/// A single detected pattern, with the finding and what to do about it.
class WorkPatternInsight extends Equatable {
  /// Stable across recomputations of the same window, so the UI can keep a
  /// card's expansion state while the timer ticks underneath it.
  final String id;

  final InsightAction action;
  final InsightSeverity severity;
  final PatternSubject subject;

  /// The entity this is about, when there is one — a work item, project,
  /// category or person id. Null for whole-schedule observations.
  final String? subjectId;

  final String title;

  /// What the data says, in the user's own numbers.
  final String finding;

  /// What to do about it.
  final String recommendation;

  /// How much tracked time the pattern accounts for. Zero where the pattern
  /// is about shape rather than volume.
  final Duration timeInvolved;

  final List<InsightEvidence> evidence;

  /// The subject's own colour, where it has one (project, tag).
  final String? colorHex;

  const WorkPatternInsight({
    required this.id,
    required this.action,
    required this.severity,
    required this.subject,
    this.subjectId,
    required this.title,
    required this.finding,
    required this.recommendation,
    this.timeInvolved = Duration.zero,
    this.evidence = const [],
    this.colorHex,
  });

  @override
  List<Object?> get props => [
        id,
        action,
        severity,
        subject,
        subjectId,
        title,
        finding,
        recommendation,
        timeInvolved,
        evidence,
        colorHex,
      ];
}

/// The shape of the user's working day, independent of any single finding.
///
/// This is the context the insights are read against: an hour of fragmentation
/// means something different to someone who never gets an unbroken hour than
/// to someone who gets four.
class FocusRhythm extends Equatable {
  /// The local hours where the longest unbroken blocks actually happen,
  /// ascending. Empty when there is not enough deep work to name a band.
  final List<int> peakFocusHours;

  /// The longest single unbroken stretch of active work in the window.
  final Duration longestUnbrokenBlock;

  final Duration medianSessionLength;

  /// Active time spent in sessions long enough to count as a deep block.
  final Duration deepWorkTotal;

  /// [deepWorkTotal] as a fraction of all active time, 0.0–1.0.
  final double deepWorkShare;

  /// Sessions started per day on which anything was tracked.
  final double switchesPerTrackedDay;

  /// Days in the window on which anything was tracked at all.
  final int trackedDayCount;

  const FocusRhythm({
    this.peakFocusHours = const [],
    this.longestUnbrokenBlock = Duration.zero,
    this.medianSessionLength = Duration.zero,
    this.deepWorkTotal = Duration.zero,
    this.deepWorkShare = 0,
    this.switchesPerTrackedDay = 0,
    this.trackedDayCount = 0,
  });

  bool get hasData => trackedDayCount > 0;

  @override
  List<Object?> get props => [
        peakFocusHours,
        longestUnbrokenBlock,
        medianSessionLength,
        deepWorkTotal,
        deepWorkShare,
        switchesPerTrackedDay,
        trackedDayCount,
      ];
}

/// Everything the insights panel renders for one scan.
class WorkPatternReport extends Equatable {
  final DateRange window;
  final PatternWindow lookback;

  /// Active (idle-deducted) time across the whole window.
  final Duration totalActive;

  /// Completed sessions considered. A running session is excluded — its
  /// duration is still moving, and a pattern scan should not change its mind
  /// every second.
  final int sessionCount;

  final FocusRhythm rhythm;
  final List<WorkPatternInsight> insights;

  /// Whether the window before this one held enough tracked work to compare
  /// against. Findings phrased as "up from" only exist when this is true.
  final bool hasComparison;

  const WorkPatternReport({
    required this.window,
    required this.lookback,
    this.totalActive = Duration.zero,
    this.sessionCount = 0,
    this.rhythm = const FocusRhythm(),
    this.insights = const [],
    this.hasComparison = false,
  });

  List<WorkPatternInsight> forAction(InsightAction action) =>
      insights.where((i) => i.action == action).toList(growable: false);

  bool get hasInsights => insights.isNotEmpty;

  /// Whether there is enough history to say anything at all.
  bool get hasData => sessionCount > 0;

  @override
  List<Object?> get props => [
        window,
        lookback,
        totalActive,
        sessionCount,
        rhythm,
        insights,
        hasComparison,
      ];
}
