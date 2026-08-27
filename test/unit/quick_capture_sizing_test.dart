import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/features/quick_capture/views/quick_capture_body.dart';

/// The configuration bar used to be pinned at 220pt whatever it held, so a
/// workspace with more than a couple of quick-capture attributes hid the rest
/// inside a scroll view with nothing to say so. These pin the arithmetic that
/// replaced the constant.
void main() {
  final now = DateTime.now().toUtc();

  AttributeDefinition def(
    String id, {
    bool enabled = true,
    bool showInQuickCapture = true,
    bool archived = false,
    AttributeScope scope = AttributeScope.task,
    int displayOrder = 0,
  }) {
    return AttributeDefinition(
      id: id,
      workspaceId: 'ws-1',
      key: id,
      name: id,
      type: AttributeType.text,
      scope: scope,
      enabled: enabled,
      showInQuickCapture: showInQuickCapture,
      displayOrder: displayOrder,
      createdAt: now,
      updatedAt: now,
      archivedAt: archived ? now : null,
    );
  }

  group('configuration bar height', () {
    test('grows once the first attribute appears', () {
      expect(
        QuickCaptureBody.configurationBarHeight(1),
        greaterThan(QuickCaptureBody.configurationBarHeight(0)),
      );
    });

    test('pairs attributes two to a row', () {
      expect(
        QuickCaptureBody.configurationBarHeight(1),
        QuickCaptureBody.configurationBarHeight(2),
      );
      expect(
        QuickCaptureBody.configurationBarHeight(3),
        QuickCaptureBody.configurationBarHeight(4),
      );
    });

    test('adds the same height for every row after the first', () {
      final second = QuickCaptureBody.configurationBarHeight(4) -
          QuickCaptureBody.configurationBarHeight(2);
      final third = QuickCaptureBody.configurationBarHeight(6) -
          QuickCaptureBody.configurationBarHeight(4);
      expect(second, third);
      expect(second, greaterThan(0));
    });
  });

  group('HUD height', () {
    test('never opens shorter than the window always was', () {
      expect(QuickCaptureBody.hudHeightFor(0), 580);
    });

    test('grows with the fields it has to show', () {
      expect(
        QuickCaptureBody.hudHeightFor(8),
        greaterThan(QuickCaptureBody.hudHeightFor(0)),
      );
    });

    test('stops growing before it takes over the screen', () {
      expect(QuickCaptureBody.hudHeightFor(100), 860);
    });
  });

  group('captureFields', () {
    test('keeps only live task attributes marked for quick capture', () {
      final fields = QuickCaptureBody.captureFields([
        def('kept'),
        def('disabled', enabled: false),
        def('archived', archived: true),
        def('hidden', showInQuickCapture: false),
        def('session-scoped', scope: AttributeScope.session),
      ]);

      expect(fields.map((d) => d.id), ['kept']);
    });

    test('orders by displayOrder, the order the user arranged them in', () {
      final fields = QuickCaptureBody.captureFields([
        def('third', displayOrder: 3),
        def('first', displayOrder: 1),
        def('second', displayOrder: 2),
      ]);

      expect(fields.map((d) => d.id), ['first', 'second', 'third']);
    });
  });
}
