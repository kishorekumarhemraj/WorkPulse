import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/platform/idle_detector_service.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/session_model.dart';
import 'package:workpulse/domain/models/work_item_model.dart';
import 'package:workpulse/features/idle/providers/idle_provider.dart';
import 'package:workpulse/features/idle/views/idle_prompt_dialog.dart';

class _FakeIdleNotifier extends IdleNotifier {
  final IdleState _initial;
  bool keepTrackingCalled = false;
  bool markIdleCalled = false;
  bool stopSessionCalled = false;

  _FakeIdleNotifier(this._initial);

  @override
  IdleState build() => _initial;

  @override
  Future<void> keepTracking() async {
    keepTrackingCalled = true;
    state = const IdleState(isPromptVisible: false);
  }

  @override
  Future<void> markIdle() async {
    markIdleCalled = true;
    state = const IdleState(isPromptVisible: false);
  }

  @override
  Future<void> stopSession() async {
    stopSessionCalled = true;
    state = const IdleState(isPromptVisible: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().toUtc();
  final testTask = WorkItem(
    id: 'task-1',
    workspaceId: 'ws-1',
    projectId: 'proj-1',
    categoryId: 'cat-1',
    name: 'Build Core Engine',
    createdAt: now,
    updatedAt: now,
  );

  final testSession = Session(
    id: 'sess-1',
    workItemId: testTask.id,
    startTime: now.subtract(const Duration(minutes: 40)),
    createdAt: now,
  );

  final testEvent = IdleDetectionEvent(
    idleDuration: const Duration(minutes: 15, seconds: 30),
    idleStartTime: now.subtract(const Duration(minutes: 15, seconds: 30)),
    idleEndTime: now,
  );

  final testIdleState = IdleState(
    isPromptVisible: true,
    currentEvent: testEvent,
    activeWorkItem: testTask,
    activeSession: testSession,
  );

  group('IdlePromptDialog UI Widget Tests', () {
    testWidgets('renders duration, active task name, and all 3 resolution choices', (tester) async {
      final fakeNotifier = _FakeIdleNotifier(testIdleState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            idleNotifierProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: IdlePromptDialog(
                idleDuration: testEvent.idleDuration,
                idleStartTime: testEvent.idleStartTime,
                activeWorkItem: testTask,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Inactivity Detected'), findsOneWidget);
      expect(find.text('15m 30s'), findsOneWidget);
      expect(find.text('Build Core Engine'), findsOneWidget);
      expect(find.text('Keep Tracking'), findsOneWidget);
      expect(find.text('Mark as Idle & Resume'), findsOneWidget);
      expect(find.text('Stop Timer at Inactivity'), findsOneWidget);
    });

    testWidgets('tapping Keep Tracking triggers keepTracking on notifier', (tester) async {
      final fakeNotifier = _FakeIdleNotifier(testIdleState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            idleNotifierProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: IdlePromptDialog(
                idleDuration: testEvent.idleDuration,
                idleStartTime: testEvent.idleStartTime,
                activeWorkItem: testTask,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Tracking'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.keepTrackingCalled, isTrue);
    });

    testWidgets('tapping Mark as Idle & Resume triggers markIdle on notifier', (tester) async {
      final fakeNotifier = _FakeIdleNotifier(testIdleState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            idleNotifierProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: IdlePromptDialog(
                idleDuration: testEvent.idleDuration,
                idleStartTime: testEvent.idleStartTime,
                activeWorkItem: testTask,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark as Idle & Resume'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.markIdleCalled, isTrue);
    });

    testWidgets('tapping Stop Timer at Inactivity triggers stopSession on notifier', (tester) async {
      final fakeNotifier = _FakeIdleNotifier(testIdleState);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            idleNotifierProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: IdlePromptDialog(
                idleDuration: testEvent.idleDuration,
                idleStartTime: testEvent.idleStartTime,
                activeWorkItem: testTask,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop Timer at Inactivity'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.stopSessionCalled, isTrue);
    });
  });
}
