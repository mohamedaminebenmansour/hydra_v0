import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/save_report_screen.dart';
import 'package:hydra_v0/services/event_media.dart';
import 'package:hydra_v0/widgets/material_reception_sheet.dart';
import 'package:hydra_v0/widgets/reception_media_block.dart';
import 'package:hydra_v0/widgets/report_detail_bottom_sheet.dart';
import 'package:hydra_v0/widgets/report_sheet_actions.dart';
import 'package:hydra_v0/widgets/report_timeline.dart';

/// "Material Reception" ("binary reception"): an ordered material is received on
/// site with a photo + voice note, and either accepted ('validated') or disputed
/// ('rejected'). These tests cover the model gates, the role-based action bar,
/// the capture sheet's shape and the delivery block in the thread. No Isar,
/// Supabase, camera or microphone plugin is ever touched.
void main() {
  /// The Owner ordered this material and nobody has received it yet.
  Report orderedMaterial() => Report()
    ..type = 'material'
    ..timestamp = DateTime(2026, 9, 22, 9)
    ..ownerStatus = 'ordered'
    ..ownerStatusAt = DateTime(2026, 9, 21, 16);

  /// A reception that already happened (both media on the local disk).
  ///
  /// The TL gate was passed long ago (that is how the material reached the
  /// Owner), so the reception is the only thing left to do.
  Report receivedMaterial({required bool accepted}) => orderedMaterial()
    ..tlValidatedAt = DateTime(2026, 9, 22, 8)
    ..tlValidationType = 'physical'
    ..receptionPhotoPath = '/data/reception.jpg'
    ..receptionVoicePath = '/data/reception.m4a'
    ..ownerStatus = accepted ? 'validated' : 'rejected';

  group('Model gates', () {
    test('an ordered material awaits its reception', () {
      final report = orderedMaterial();
      expect(report.awaitsMaterialReception, isTrue);
      expect(report.hasReceptionMedia, isFalse);
      expect(report.hasDeliveryDispute, isFalse);
    });

    test('a work report never awaits a reception', () {
      final report = orderedMaterial()..type = 'work';
      expect(report.awaitsMaterialReception, isFalse);
    });

    test('a received material awaits nothing', () {
      final report = receivedMaterial(accepted: true);
      expect(report.awaitsMaterialReception, isFalse);
      expect(report.hasReceptionMedia, isTrue);
      expect(report.hasDeliveryDispute, isFalse);
    });

    test('a reported issue is the delivery dispute', () {
      final report = receivedMaterial(accepted: false);
      expect(report.hasDeliveryDispute, isTrue);
      expect(report.awaitsMaterialReception, isFalse);
    });

    test('a reclaimed capture keeps the reception alive through its URL', () {
      final report = orderedMaterial()
        ..receptionPhotoUrl = 'https://cdn/reception.jpg';
      expect(report.hasReceptionMedia, isTrue);
      expect(report.awaitsMaterialReception, isFalse);
    });
  });

  group('RECEIVE MATERIAL action (defaultActionsFor)', () {
    test('both field roles get the one giant blue button', () {
      for (final role in ['subcontractor', 'team_leader']) {
        final actions = defaultActionsFor(orderedMaterial(), role: role);
        expect(actions.buttons, hasLength(1), reason: role);
        final button = actions.buttons.single;
        expect(button.label, 'RECEIVE MATERIAL');
        expect(button.color, Colors.blue);
        expect(button.icon, Icons.inventory_2);
        expect(button.onPressed, materialReceptionFlow);
      }
    });

    test('the Owner is never asked to receive what he ordered', () {
      expect(
        defaultActionsFor(orderedMaterial(), role: 'owner').isEmpty,
        isTrue,
      );
    });

    test('the button is gone once the delivery was handled', () {
      for (final accepted in [true, false]) {
        final report = receivedMaterial(accepted: accepted);
        expect(defaultActionsFor(report, role: 'team_leader').isEmpty, isTrue);
        // A delivery dispute is the supplier's to settle, not the sub's work:
        // no FIX & RESUBMIT is offered for it.
        expect(
          defaultActionsFor(report, role: 'subcontractor').isEmpty,
          isTrue,
        );
      }
    });

    test('a material still awaiting the TL gate keeps its gate actions', () {
      final report = orderedMaterial()..ownerStatus = 'pending';
      expect(
        defaultActionsFor(
          report,
          role: 'team_leader',
        ).buttons.map((b) => b.label),
        ['REMOTE', 'ON SITE', 'REJECT'],
      );
    });
  });

  group('ReceptionMediaBlock', () {
    testWidgets('shows the verdict, the photo and the voice player', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceptionMediaBlock(report: receivedMaterial(accepted: true)),
          ),
        ),
      );
      expect(find.text('MATERIAL RECEIVED'), findsOneWidget);
      expect(find.text('PLAY VOICE'), findsOneWidget);
    });

    testWidgets('a reported issue is the red delivery dispute', (tester) async {
      final report = receivedMaterial(accepted: false);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ReceptionMediaBlock(report: report))),
      );
      expect(find.text('DELIVERY ISSUE REPORTED'), findsOneWidget);
      expect(receptionVerdictStyle(report).$1, Colors.red.shade700);
      expect(
        receptionVerdictStyle(receivedMaterial(accepted: true)).$1,
        Colors.green.shade700,
      );
    });

    testWidgets('renders nothing without a reception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReceptionMediaBlock(report: orderedMaterial())),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('sits at the bottom of the chat thread', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportTimeline(report: receivedMaterial(accepted: true)),
          ),
        ),
      );
      expect(find.text('MATERIAL RECEIVED'), findsOneWidget);
      expect(find.text('No messages yet.'), findsOneWidget);
    });
  });

  group('Capture sheet (step 1)', () {
    testWidgets('asks for the delivery photo before the voice note', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MaterialReceptionSheet())),
      );
      expect(find.text('STEP 1/2 — DELIVERY PHOTO'), findsOneWidget);
      expect(find.text('TAKE PHOTO'), findsOneWidget);
      expect(find.text('RECORD VOICE'), findsNothing);
      expect(find.text('ACCEPT ALL'), findsNothing);
      // Nothing captured yet: the next step stays locked.
      final next = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'NEXT: RECORD VOICE'),
      );
      expect(next.onPressed, isNull);
      expect(find.text('Cancel reception'), findsOneWidget);
    });
  });

  group('Report sheet (the giant action)', () {
    testWidgets('an ordered material shows one full-width RECEIVE button', (
      tester,
    ) async {
      final report = orderedMaterial();
      await pumpReportSheet(
        tester,
        report: report,
        role: 'team_leader',
        selfActor: 'tl',
      );

      expect(find.text('RECEIVE MATERIAL'), findsOneWidget);
      final button = find
          .ancestor(
            of: find.text('RECEIVE MATERIAL'),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(button).width, greaterThan(600));
      expect(find.text('WORK CLOSED'), findsNothing);
      expect(find.text('MATERIAL RECEIVED'), findsNothing);
    });

    testWidgets('a received material hides the button and shows the block', (
      tester,
    ) async {
      final report = receivedMaterial(accepted: false)..id = 7;
      await pumpReportSheet(
        tester,
        report: report,
        role: 'team_leader',
        selfActor: 'tl',
      );

      expect(find.text('RECEIVE MATERIAL'), findsNothing);
      expect(find.text('DELIVERY ISSUE REPORTED'), findsOneWidget);
    });
  });

  group('Sheet-level guarantee (empty injected actions)', () {
    // The detail sheet owes the RECEIVE button to the spec condition itself
    // (material + 'ordered' + no reception photo) even when the caller
    // injects nothing — and never shows it to the Owner.
    testWidgets('both field roles get the button without injected actions', (
      tester,
    ) async {
      for (final selfActor in ['sub', 'tl']) {
        await pumpReportSheet(
          tester,
          report: orderedMaterial(),
          role: 'subcontractor',
          selfActor: selfActor,
          actions: const ReportSheetActions(),
        );
        expect(find.text('RECEIVE MATERIAL'), findsOneWidget, reason: selfActor);
        expect(find.text('WORK CLOSED'), findsNothing);
        // Close the sheet before pumping the next role.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    });

    testWidgets('the exact condition applies to every actor, '
        'including the Owner', (tester) async {
      await pumpReportSheet(
        tester,
        report: orderedMaterial(),
        role: 'owner',
        selfActor: 'owner',
        actions: const ReportSheetActions(),
      );

      // Spec rule: material + 'ordered' + empty receptionPhotoPath shows the
      // button — with no role clause in front of it.
      expect(find.text('RECEIVE MATERIAL'), findsOneWidget);
      expect(find.text('WORK CLOSED'), findsNothing);
    });

    testWidgets('a reception photo path alone hides the button', (
      tester,
    ) async {
      await pumpReportSheet(
        tester,
        report: orderedMaterial()..receptionPhotoPath = '/data/reception.jpg',
        role: 'subcontractor',
        selfActor: 'sub',
        actions: const ReportSheetActions(),
      );

      expect(find.text('RECEIVE MATERIAL'), findsNothing);
    });
  });

  group('Material request (SaveReportScreen)', () {
    testWidgets('shows the giant RECORD YOUR REQUEST mic, no photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SaveReportScreen(type: 'material', photoPath: ''),
        ),
      );
      await tester.pump();

      expect(find.text('RECORD YOUR REQUEST'), findsOneWidget);
      expect(find.text('ADD VOICE NOTE'), findsNothing);
      // The photo is optional and offered by its own smaller button.
      expect(find.text('📷 Add Photo (Optional)'), findsOneWidget);
      // No photo preview at all until one is captured.
      expect(find.byIcon(Icons.broken_image), findsNothing);
    });

    testWidgets('saving without a voice note blocks with the spec message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SaveReportScreen(type: 'material', photoPath: ''),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('DONE'));
      // Geolocator/DeviceInfo have no plugin in tests: both probes throw and
      // are caught, so _save reaches the voice check and blocks the save.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Voice note required'), findsOneWidget);
      // The empty photo must never trigger the photo guard for material.
      expect(find.text('Photo file missing, cannot save'), findsNothing);
    });

    testWidgets('a work report still demands its photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SaveReportScreen(type: 'work', photoPath: ''),
        ),
      );
      await tester.pump();

      // The optional-photo button belongs to the material request only.
      expect(find.text('📷 Add Photo (Optional)'), findsNothing);
      await tester.tap(find.text('DONE'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Photo file missing, cannot save'), findsOneWidget);
      expect(find.text('Voice note required'), findsNothing);
    });
  });

  group('Push payload rule', () {
    test('the reception columns only ever carry a real URL', () {
      expect(urlOnlyField('reception_photo_url', ''), isEmpty);
      expect(
        urlOnlyField('reception_photo_url', '/data/reception.jpg'),
        isEmpty,
      );
      expect(urlOnlyField('reception_voice_url', 'https://cdn/r.m4a'), {
        'reception_voice_url': 'https://cdn/r.m4a',
      });
    });
  });

}

/// Opens the shared report sheet the way the History list does, with no local
/// database and no network: the live watcher simply emits nothing.
///
/// [actions] overrides the injected bar (pass
/// `const ReportSheetActions()` to exercise the sheet's own guarantee).
Future<void> pumpReportSheet(
  WidgetTester tester, {
  required Report report,
  required String role,
  required String selfActor,
  ReportSheetActions? actions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showReportDetailSheet(
                context,
                report: report,
                watch: (_) => Stream<Report?>.value(null),
                onOpenLocation: noopOpenLocation,
                actions: actions ?? defaultActionsFor(report, role: role),
                selfActor: selfActor,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Two pumps: the modal route entrance animation and its settle frame.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// A location opener that goes nowhere (the sheet must never open a map here).
void noopOpenLocation(BuildContext context, Report report) {}
