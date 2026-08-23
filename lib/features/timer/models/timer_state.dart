import 'package:equatable/equatable.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';

enum TimerStatus {
  idle,
  running,
  switching,
}

class TimerState extends Equatable {
  final TimerStatus status;
  final WorkItem? activeWorkItem;
  final Session? activeSession;
  final Duration elapsed;
  final WorkItem? pendingSwitchWorkItem;

  const TimerState({
    this.status = TimerStatus.idle,
    this.activeWorkItem,
    this.activeSession,
    this.elapsed = Duration.zero,
    this.pendingSwitchWorkItem,
  });

  bool get isRunning => status == TimerStatus.running && activeSession != null;
  bool get isIdle => status == TimerStatus.idle;
  bool get isSwitching => status == TimerStatus.switching;

  TimerState copyWith({
    TimerStatus? status,
    WorkItem? activeWorkItem,
    bool clearActiveWorkItem = false,
    Session? activeSession,
    bool clearActiveSession = false,
    Duration? elapsed,
    WorkItem? pendingSwitchWorkItem,
    bool clearPendingSwitchWorkItem = false,
  }) {
    return TimerState(
      status: status ?? this.status,
      activeWorkItem:
          clearActiveWorkItem ? null : (activeWorkItem ?? this.activeWorkItem),
      activeSession:
          clearActiveSession ? null : (activeSession ?? this.activeSession),
      elapsed: elapsed ?? this.elapsed,
      pendingSwitchWorkItem: clearPendingSwitchWorkItem
          ? null
          : (pendingSwitchWorkItem ?? this.pendingSwitchWorkItem),
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeWorkItem,
        activeSession,
        elapsed,
        pendingSwitchWorkItem,
      ];
}
