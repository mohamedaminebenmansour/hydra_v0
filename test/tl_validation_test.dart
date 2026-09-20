import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/report_detail_screen.dart';

/// Tests for the "Chef de Chantier Gate": the Team Leader verification step
/// added on top of the existing reporting flow.
void main() {
  group('Report TL gate fields', () {
    test('a fresh report awaits TL validation', () {
      final r = Report();
      expect(r.tlValidatedAt, isNull);
      expect(r.tlValidatorId, '');
      expect(r.tlValidationType, '');
      expect(r.tlValidationPhotoPath, '');
      expect(r.tlValidationPhotoUrl, '');
    });

    test('work reports need TL validation', () {
      expect((Report()..type = 'work'..timestamp = DateTime(2026, 9, 17)).needsTlValidation, isTrue);
    });

    test('material reports need TL validation', () {
      expect((Report()..type = 'material').needsTlValidation, isTrue);
    });

    test('problem reports never pass through the gate', () {
      expect((Report()..type = 'problem').needsTlValidation, isFalse);
    });

    test('a validated work report leaves the TO VERIFY list', () {
      final r = Report()
        ..type = 'work'
        ..timestamp = DateTime(2026, 9, 17)
        ..tlValidatedAt = DateTime.now()
        ..tlValidationType = 'physical';
      expect(r.needsTlValidation, isFalse);
    });

    test('validating a problem report does not unsettle the gate flag', () {
      final r = Report()
        ..type = 'problem'
        ..tlValidatedAt = DateTime.now();
      expect(r.needsTlValidation, isFalse);
    });
  });

  group('tlValidationTypeForDistance', () {
    test('the physical radius is 50 m', () {
      expect(tlPhysicalRadiusMeters, 50);
    });

    test('just inside the radius is a physical validation', () {
      expect(tlValidationTypeForDistance(0), 'physical');
      expect(tlValidationTypeForDistance(49.9), 'physical');
    });

    test('exactly 50 m and beyond is downgraded to remote', () {
      expect(tlValidationTypeForDistance(50), 'remote');
      expect(tlValidationTypeForDistance(120), 'remote');
    });

    test('an unmeasurable distance (negative) is never physical', () {
      expect(tlValidationTypeForDistance(-1), 'remote');
    });
  });

  group('ReportDetailScreen TL gate UI', () {
    /// Isar is not available in the widget-test VM, so the watch stream yields
    /// nothing and the screen keeps the report it was handed. The role-based bar
    /// is driven by that report + the compile-time role, so it is assertable.
    Future<void> pumpDetail(
      WidgetTester tester,
      Report report, {
      String? userRoleOverride = 'team_leader',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(
            report: report,
            userRoleOverride: userRoleOverride,
          ),
        ),
      );
      // A single pump settles the (failing) Isar future without waiting on the
      // indeterminate progress spinner.
      await tester.pump();
    }

    testWidgets('a Team Leader gets the three giant gate buttons', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        Report()..type = 'work'..timestamp = DateTime(2026, 9, 17),
      );

      // Written-out giant buttons: never an ambiguous icon chip, never a tooltip.
      expect(find.text('REMOTE'), findsOneWidget);
      expect(find.text('ON SITE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.visibility)).size, 28);
      expect(tester.widget<Icon>(find.byIcon(Icons.camera_alt)).size, 28);
      // The bar's REJECT icon and the header's close button share Icons.close.
      expect(find.byIcon(Icons.close), findsNWidgets(2));
      // Every button is a single direct tap: no hidden choice menu.
      expect(find.text('VALIDATE ON SITE'), findsNothing);
      expect(find.text('VALIDATE REMOTELY'), findsNothing);
    });

    testWidgets('a problem report never enters the gate', (tester) async {
      await pumpDetail(
        tester,
        Report()..type = 'problem'..timestamp = DateTime(2026, 9, 17),
      );

      expect(find.text('REMOTE'), findsNothing);
      expect(find.text('ON SITE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
      // Nothing to lock either: a problem report goes straight to the owner.
      expect(find.byIcon(Icons.lock), findsNothing);
    });

    testWidgets('locks the bar once the report is validated', (tester) async {
      final validated = Report()
        ..type = 'work'
        ..timestamp = DateTime(2026, 9, 17)
        ..tlValidatedAt = DateTime.now()
        ..tlValidationType = 'physical';
      await pumpDetail(tester, validated);

      expect(find.text('REMOTE'), findsNothing);
      expect(find.text('ON SITE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
      // A decided report shows the disabled grey bar labelled with its stage
      // (the header badge states the same thing, hence two matching labels).
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('Pending Owner Approval'), findsNWidgets(2));
    });

    testWidgets('a subcontractor never sees the gate buttons', (tester) async {
      await pumpDetail(
        tester,
        Report()..type = 'work'..timestamp = DateTime(2026, 9, 17),
        userRoleOverride: 'subcontractor',
      );

      expect(find.text('REMOTE'), findsNothing);
      expect(find.text('ON SITE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });
  });

  group('Dispute Shield model fields', () {
    test('a rejected report is flagged and carries its proof media', () {
      final r = Report()
        ..type = 'work'
        ..timestamp = DateTime(2026, 9, 17)
        ..tlValidatedAt = DateTime.now()
        ..tlValidationType = 'rejected'
        ..tlRejectionPhotoPath = '/docs/reports/reject_1.jpg'
        ..tlRejectionVoicePath = '/docs/reports/reject_1.m4a';

      expect(r.isTlRejected, isTrue);
      expect(r.needsTlValidation, isFalse);
      expect(r.tlRejectionPhotoUrl, isEmpty);
      // The on-site validation proof is not reused for a rejection.
      expect(r.tlValidationPhotoPath, isEmpty);
    });

    test('an accepted report is not flagged as rejected', () {
      final r = Report()
        ..tlValidationType = 'physical'
        ..tlValidatedAt = DateTime.now();

      expect(r.isTlRejected, isFalse);
      expect(r.tlRejectionPhotoPath, isEmpty);
      expect(r.tlRejectionVoicePath, isEmpty);
      expect(r.tlRejectionVoiceUrl, isEmpty);
    });
  });
}
