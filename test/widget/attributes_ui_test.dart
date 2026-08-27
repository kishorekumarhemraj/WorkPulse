import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workpulse/core/theme/app_theme.dart';
import 'package:workpulse/domain/models/attribute_model.dart';
import 'package:workpulse/domain/models/workspace_model.dart';
import 'package:workpulse/features/attributes/providers/attribute_definitions_provider.dart';
import 'package:workpulse/features/attributes/views/attribute_definition_form_dialog.dart';
import 'package:workpulse/features/attributes/views/attribute_definitions_view.dart';
import 'package:workpulse/features/attributes/views/attribute_options_editor_dialog.dart';
import 'package:workpulse/features/attributes/widgets/dynamic_attribute_fields.dart';
import 'package:workpulse/features/workspace/providers/workspace_provider.dart';

class _FakeWorkspaceNotifier extends CurrentWorkspaceNotifier {
  final Workspace _ws;
  _FakeWorkspaceNotifier(this._ws);
  @override
  Future<Workspace> build() async => _ws;
}

class _FakeAttributeDefinitionsNotifier extends AttributeDefinitionsNotifier {
  final List<AttributeDefinition> _list;
  _FakeAttributeDefinitionsNotifier(this._list);

  @override
  Future<List<AttributeDefinition>> build() async => _list;

  @override
  Future<AttributeDefinition> createDefinition({
    required String key,
    required String name,
    String? description,
    required AttributeType type,
    AttributeScope scope = AttributeScope.task,
    bool required = false,
    bool enabled = true,
    bool searchable = true,
    bool reportable = true,
    bool showInQuickCapture = true,
    bool showInTaskDetails = true,
    int displayOrder = 0,
  }) async {
    final now = DateTime.now().toUtc();
    final def = AttributeDefinition(
      id: 'def-created',
      workspaceId: 'ws-1',
      key: key,
      name: name,
      description: description,
      type: type,
      scope: scope,
      required: required,
      enabled: enabled,
      searchable: searchable,
      reportable: reportable,
      showInQuickCapture: showInQuickCapture,
      showInTaskDetails: showInTaskDetails,
      displayOrder: displayOrder,
      createdAt: now,
      updatedAt: now,
    );
    _list.add(def);
    state = AsyncData(List<AttributeDefinition>.from(_list));
    return def;
  }
}

class _FakeAttributeOptionsController implements AttributeOptionsController {
  final List<AttributeOption> _list;
  _FakeAttributeOptionsController(this._list);

  @override
  Future<AttributeOption> createOption({
    required String definitionId,
    required String value,
    required String label,
    String? colorHex,
    int displayOrder = 0,
    bool isDefault = false,
  }) async {
    final now = DateTime.now().toUtc();
    final opt = AttributeOption(
      id: 'opt-created',
      attributeDefinitionId: definitionId,
      value: value,
      label: label,
      colorHex: colorHex,
      displayOrder: displayOrder,
      isDefault: isDefault,
      createdAt: now,
    );
    _list.add(opt);
    return opt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().toUtc();
  final testWorkspace = Workspace(
    id: 'ws-1',
    name: 'Default',
    createdAt: now,
    updatedAt: now,
  );

  final testTaskDef = AttributeDefinition(
    id: 'def-1',
    workspaceId: testWorkspace.id,
    key: 'jira_key',
    name: 'Jira Key',
    type: AttributeType.text,
    scope: AttributeScope.task,
    required: true,
    createdAt: now,
    updatedAt: now,
  );

  final testSessionDef = AttributeDefinition(
    id: 'def-2',
    workspaceId: testWorkspace.id,
    key: 'meeting_type',
    name: 'Meeting Type',
    type: AttributeType.singleSelect,
    scope: AttributeScope.session,
    createdAt: now,
    updatedAt: now,
  );

  final testOption1 = AttributeOption(
    id: 'opt-1',
    attributeDefinitionId: testSessionDef.id,
    value: 'standup',
    label: 'Daily Standup',
    colorHex: '#0A84FF',
    createdAt: now,
  );

  group('Attributes UI Widget Tests', () {
    testWidgets(
        'AttributeDefinitionsView renders title, search, filter chips, and cards',
        (tester) async {
      // The app's own window is 1200x800; the default 800x600 test surface is
      // shorter than WorkPulse ever runs.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            attributeDefinitionsProvider.overrideWith(() =>
                _FakeAttributeDefinitionsNotifier(
                    [testTaskDef, testSessionDef])),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AttributeDefinitionsView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Custom Attributes'), findsOneWidget);
      expect(find.text('Jira Key'), findsOneWidget);
      expect(find.text('jira_key'), findsOneWidget);
      expect(find.text('TASK'), findsOneWidget);
      expect(find.text('Meeting Type'), findsOneWidget);
      expect(find.text('SESSION'), findsOneWidget);
      expect(find.text('REQUIRED'), findsOneWidget);
      expect(find.text('New Attribute'), findsOneWidget);
    });

    testWidgets('filtering by scope chips updates card list', (tester) async {
      // The app's own window is 1200x800; the default 800x600 test surface is
      // shorter than WorkPulse ever runs.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            attributeDefinitionsProvider.overrideWith(() =>
                _FakeAttributeDefinitionsNotifier(
                    [testTaskDef, testSessionDef])),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AttributeDefinitionsView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The scope filter is now a segmented control reading "All" / "Task" /
      // "Session", replacing the "Task Scope" / "Session Scope" chips. The
      // scope badges on each row are uppercase (TASK / SESSION), so these
      // finders match only the control.
      await tester.tap(find.text('Session'));
      await tester.pumpAndSettle();

      expect(find.text('Meeting Type'), findsOneWidget);
      expect(find.text('Jira Key'), findsNothing);

      await tester.tap(find.text('Task'));
      await tester.pumpAndSettle();

      expect(find.text('Jira Key'), findsOneWidget);
      expect(find.text('Meeting Type'), findsNothing);
    });

    testWidgets(
        'AttributeDefinitionFormDialog validates required name and creates attribute',
        (tester) async {
      // The app's own window is 1200x800; the default 800x600 test surface is
      // shorter than WorkPulse ever runs.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeNotifier = _FakeAttributeDefinitionsNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentWorkspaceProvider
                .overrideWith(() => _FakeWorkspaceNotifier(testWorkspace)),
            attributeDefinitionsProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: AttributeDefinitionFormDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Custom Attribute'), findsOneWidget);

      // Fill name
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Display Name *'), 'Client Code');
      await tester.pumpAndSettle();

      // Tap create
      await tester.tap(find.text('Create Attribute'));
      await tester.pumpAndSettle();

      expect(fakeNotifier._list.length, 1);
      expect(fakeNotifier._list.first.name, 'Client Code');
      expect(fakeNotifier._list.first.key, 'client_code');
    });

    testWidgets('AttributeOptionsEditorDialog renders and adds select options',
        (tester) async {
      // The app's own window is 1200x800; the default 800x600 test surface is
      // shorter than WorkPulse ever runs.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final optionsList = <AttributeOption>[testOption1];
      final fakeOptController = _FakeAttributeOptionsController(optionsList);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attributeOptionsFamilyProvider(testSessionDef.id)
                .overrideWith((ref) => Future.value(optionsList)),
            attributeOptionsControllerProvider
                .overrideWithValue(fakeOptController),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AttributeOptionsEditorDialog(definition: testSessionDef),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Options for "Meeting Type"'), findsOneWidget);
      expect(find.text('Daily Standup'), findsOneWidget);

      // Add a new option
      await tester.enterText(
          find.widgetWithText(TextField, 'Option Label (e.g. High)'),
          'Architecture Review');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Option'));
      await tester.pumpAndSettle();

      expect(fakeOptController._list.length, 2);
    });

    testWidgets(
        'DynamicAttributeFields dynamically renders text and boolean input controls',
        (tester) async {
      // The app's own window is 1200x800; the default 800x600 test surface is
      // shorter than WorkPulse ever runs.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boolDef = AttributeDefinition(
        id: 'def-bool',
        workspaceId: testWorkspace.id,
        key: 'billable',
        name: 'Is Billable',
        type: AttributeType.boolean,
        createdAt: now,
        updatedAt: now,
      );

      final values = <String, dynamic>{};

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DynamicAttributeFields(
                definitions: [testTaskDef, boolDef],
                values: values,
                onValueChanged: (id, val) {
                  values[id] = val;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Custom Attributes'), findsOneWidget);
      expect(find.text('Jira Key *'), findsOneWidget);
      expect(find.text('Is Billable'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Both captions sit above their control, at the same height. The text
      // field used to carry its name as Material's floating `labelText`
      // instead — drawn inside the border, at a different height from the
      // caption its neighbour drew above itself, which is what left the row
      // looking misaligned.
      final textCaption = tester.getTopLeft(find.text('Jira Key *'));
      final boolCaption = tester.getTopLeft(find.text('Is Billable'));
      expect(textCaption.dy, boolCaption.dy);
      expect(textCaption.dx, lessThan(boolCaption.dx));
      expect(
        tester.getTopLeft(find.byType(TextFormField)).dy,
        greaterThan(textCaption.dy),
      );
    });
  });
}
