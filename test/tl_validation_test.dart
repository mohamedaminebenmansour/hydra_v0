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
      expect((Report()..type = 'work').needsTlValidation, isTrue);
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
    /// Isar is not available in the widget-test VM, so the detail screen's
    /// FutureBuilder lands on its "report no longer exists" state. The gate
    /// buttons live on the Scaffold (outside that builder) and are driven by the
    /// report passed in, so they can still be asserted on.
    Future<void> pumpDetail(
      WidgetTester tester,
      Report report, {
      bool validationMode = false,
      String? userRoleOverride = 'team_leader',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(
            report: report,
            validationMode: validationMode,
            userRoleOverride: userRoleOverride,
          ),
        ),
      );
      // A single pump settles the (failing) Isar future without waiting on the
      // indeterminate progress spinner.
      await tester.pump();
    }

    testWidgets('offers both giant validation actions in validation mode', (
      tester,
    ) async {
      await pumpDetail(tester, Report()..type = 'work', validationMode: true);

      expect(find.text('VALIDATE REMOTELY (Photo Only)'), findsOneWidget);
      expect(find.text('VALIDATE ON SITE (Take Photo)'), findsOneWidget);
      // The "Dispute Shield" rejection action is part of the gate too.
      expect(find.text('REJECT (Photo + Voice)'), findsOneWidget);
    });

    testWidgets('hides the gate buttons outside validation mode', (
      tester,
    ) async {
      await pumpDetail(tester, Report()..type = 'work');

      expect(find.text('VALIDATE REMOTELY (Photo Only)'), findsNothing);
      expect(find.text('VALIDATE ON SITE (Take Photo)'), findsNothing);
      expect(find.text('REJECT (Photo + Voice)'), findsNothing);
    });

    testWidgets('hides the gate buttons once the report is validated', (
      tester,
    ) async {
      final validated = Report()
        ..type = 'work'
        ..tlValidatedAt = DateTime.now()
        ..tlValidationType = 'physical';
      await pumpDetail(tester, validated, validationMode: true);

      expect(find.text('VALIDATE REMOTELY (Photo Only)'), findsNothing);
      expect(find.text('REJECT (Photo + Voice)'), findsNothing);
    });

    testWidgets('a subcontractor never sees the gate buttons, even in '
        'validation mode', (tester) async {
      await pumpDetail(
        tester,
        Report()..type = 'work',
        validationMode: true,
        userRoleOverride: 'subcontractor',
      );

      expect(find.text('VALIDATE REMOTELY (Photo Only)'), findsNothing);
      expect(find.text('VALIDATE ON SITE (Take Photo)'), findsNothing);
      expect(find.text('REJECT (Photo + Voice)'), findsNothing);
    });
  });

  group('Dispute Shield model fields', () {
    test('a rejected report is flagged and carries its proof media', () {
      final r = Report()
        ..type = 'work'
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
