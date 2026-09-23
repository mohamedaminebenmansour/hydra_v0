import 'dart:io';

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

  group('Capture sheet (photo-first, voice only on issue)', () {
    /// The InkWell of one giant verdict label (nearest ancestor).
    InkWell verdictInk(WidgetTester tester, String label) =>
        tester.widget<InkWell>(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        );

    /// Smallest valid PNG (1x1, transparent) so `Image.file` resolves for
    /// real instead of falling into its error builder (same bytes
    /// save_report_ui_test uses).
    const png = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];

    /// Writes that tiny image as the "capture" the camera seam hands back.
    /// SYNC on purpose: awaiting dart:io futures inside the FakeAsync
    /// widget-test zone deadlocks (the same rule save_report_ui_test follows).
    String fakeCapture() {
      final file = File(
        '${Directory.systemTemp.path}/reception_test_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      file.writeAsBytesSync(png);
      return file.path;
    }

    testWidgets('auto-opens the camera once; a cancel disables the verdicts', (
      tester,
    ) async {
      var cameraCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialReceptionSheet(
              cameraSource: () async {
                cameraCalls++;
                return null; // the user cancelled the camera
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Spec Step 1: the camera fires automatically, ONE shot only.
      expect(cameraCalls, 1);
      expect(find.text('DELIVERY PHOTO'), findsOneWidget);
      expect(find.text('TAKE PHOTO'), findsOneWidget);
      // The old step structure is gone: no NEXT, no voice on the photo step.
      expect(find.text('NEXT: RECORD VOICE'), findsNothing);
      expect(find.text('RECORD VOICE'), findsNothing);
      // Spec Step 2: both giant verdicts sit directly below the photo…
      expect(find.text('ACCEPT ALL'), findsOneWidget);
      expect(find.text('REPORT ISSUE'), findsOneWidget);
      // …but stay locked until a photo exists.
      expect(verdictInk(tester, 'ACCEPT ALL').onTap, isNull);
      expect(verdictInk(tester, 'REPORT ISSUE').onTap, isNull);
      expect(find.text('Cancel reception'), findsOneWidget);
    });

    testWidgets('happy path: photo then ACCEPT ALL, no voice asked (3 clicks)', (
      tester,
    ) async {
      final capture = fakeCapture();
      MaterialReceptionResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showMaterialReceptionSheet(
                      context,
                      cameraSource: () async => capture,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // The auto-camera adopted the capture and unlocked the verdicts.
      expect(verdictInk(tester, 'ACCEPT ALL').onTap, isNotNull);
      expect(verdictInk(tester, 'REPORT ISSUE').onTap, isNotNull);
      expect(find.text('RECORD VOICE'), findsNothing); // never asked

      await tester.tap(find.text('ACCEPT ALL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(result, isNotNull);
      expect(result!.accepted, isTrue);
      expect(result!.voicePath, ''); // spec: voice only if there is a problem
      expect(result!.photoPath, isNotEmpty);
    });

    testWidgets('REPORT ISSUE opens the mandatory voice step', (tester) async {
      final capture = fakeCapture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialReceptionSheet(cameraSource: () async => capture),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('REPORT ISSUE'));
      await tester.pump();

      expect(find.text('REPORT ISSUE — VOICE NOTE'), findsOneWidget);
      expect(find.text('RECORD VOICE'), findsOneWidget);
      // Mandatory voice: CONFIRM ISSUE does not even appear until a note was
      // recorded (the mic itself is a native plugin tests can't drive).
      expect(find.text('CONFIRM ISSUE'), findsNothing);

      // Mis-tap safety: Back returns to the photo verdict.
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(find.text('DELIVERY PHOTO'), findsOneWidget);
      expect(find.text('ACCEPT ALL'), findsOneWidget);
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

  group('RESOLVE DISPUTE (Owner closure)', () {
    /// A delivery dispute: the Sub reported an issue with the reception.
    Report disputedMaterial() => receivedMaterial(accepted: false);

    test('the condition needs all three spec clauses', () {
      expect(disputeNeedsOwnerResolution(disputedMaterial()), isTrue);
      // Not a material report.
      expect(
        disputeNeedsOwnerResolution(
          disputedMaterial()
            ..type = 'work'
            ..timestamp = DateTime(2026, 9, 22, 9),
        ),
        isFalse,
      );
      // Not rejected (the sub accepted the delivery).
      expect(
        disputeNeedsOwnerResolution(receivedMaterial(accepted: true)),
        isFalse,
      );
      // No reception evidence captured.
      expect(
        disputeNeedsOwnerResolution(
          disputedMaterial()..receptionPhotoPath = '',
        ),
        isFalse,
      );
    });

    test('only the Owner role gets the one giant dark-green button', () {
      final report = disputedMaterial();
      final owner = defaultActionsFor(report, role: 'owner');
      expect(owner.buttons, hasLength(1));
      final button = owner.buttons.single;
      expect(button.label, 'RESOLVE DISPUTE');
      expect(button.color, Colors.green.shade800);
      expect(button.icon, Icons.check_circle);
      for (final role in ['subcontractor', 'team_leader']) {
        final actions = defaultActionsFor(report, role: role);
        expect(
          actions.buttons.map((b) => b.label),
          isNot(contains('RESOLVE DISPUTE')),
          reason: role,
        );
      }
    });

    test('ownerReportActions swaps ORDER/REJECT for the single button', () {
      final actions = ownerReportActions(
        report: disputedMaterial(),
        writeDecision: (localId, status) async {},
      );
      expect(actions.buttons, hasLength(1));
      expect(actions.buttons.single.label, 'RESOLVE DISPUTE');
    });

    test('a resolved (validated) material shows no owner actions at all', () {
      final resolved = receivedMaterial(accepted: true);
      expect(
        ownerReportActions(
          report: resolved,
          writeDecision: (localId, status) async {},
        ).buttons,
        isEmpty,
      );
      expect(
        defaultActionsFor(resolved, role: 'owner').buttons,
        isEmpty,
      );
      // …and the field roles keep the same empty bar (nobody can act).
      expect(
        defaultActionsFor(resolved, role: 'subcontractor').buttons,
        isEmpty,
      );
      expect(
        defaultActionsFor(resolved, role: 'team_leader').buttons,
        isEmpty,
      );
    });

    test('an owner-rejected WORK report keeps its normal bar untouched', () {
      final rejectedWork = Report()
        ..type = 'work'
        ..timestamp = DateTime(2026, 9, 22, 9)
        ..ownerStatus = 'rejected';
      final actions = ownerReportActions(
        report: rejectedWork,
        writeDecision: (localId, status) async {},
      );
      expect(actions.buttons, hasLength(2)); // VALIDATE + REJECT, unchanged
      expect(
        actions.buttons.map((b) => b.label),
        isNot(contains('RESOLVE DISPUTE')),
      );
    });

    testWidgets('tapping RESOLVE writes validated and closes the sheet', (
      tester,
    ) async {
      final report = disputedMaterial()..id = 9;
      String? written;
      await pumpReportSheet(
        tester,
        report: report,
        role: 'owner',
        selfActor: 'owner',
        actions: ownerReportActions(
          report: report,
          writeDecision: (localId, status) async {
            written = status;
          },
        ),
      );

      expect(find.text('RESOLVE DISPUTE'), findsOneWidget);
      expect(find.text('ORDER'), findsNothing);
      expect(find.text('REJECT'), findsNothing);

      await tester.tap(find.text('RESOLVE DISPUTE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(written, 'validated');
      expect(report.ownerStatus, 'validated');
      // The sheet closed itself (flow returned true).
      expect(find.text('RESOLVE DISPUTE'), findsNothing);
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
