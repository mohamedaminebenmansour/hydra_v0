import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/history_screen.dart';
import 'package:hydra_v0/screens/report_detail_screen.dart';

/// Tests for the "Fix & Resubmit" loop: the activity log model, the
/// subcontractor's green FIX & RESUBMIT bar, the red rejection card, and the
/// role-based status dots on the history cards.
void main() {
  Report rejectedReport() => Report()
    ..type = 'work'
    ..timestamp = DateTime(2026, 9, 17, 9, 30)
    ..tlValidatedAt = DateTime(2026, 9, 17, 10, 0)
    ..tlValidationType = 'rejected'
    ..tlRejectionPhotoPath = '/docs/reports/reject_1.jpg'
    ..tlRejectionVoicePath = '/docs/reports/reject_1.m4a';

  group('Activity log model', () {
    test('logActivity appends a well-formed JSON entry', () {
      final r = Report();
      expect(r.activityLog, isEmpty);

      final at = DateTime.utc(2026, 9, 17, 8, 0);
      r.logActivity(
        actor: 'tl',
        action: 'rejected',
        photoUrl: 'https://cdn/reject.jpg',
        voiceUrl: 'https://cdn/reject.m4a',
        time: at,
      );

      expect(r.activityLog, hasLength(1));
      final entry = jsonDecode(r.activityLog.first) as Map<String, dynamic>;
      expect(entry['actor'], 'tl');
      expect(entry['action'], 'rejected');
      expect(entry['photoUrl'], 'https://cdn/reject.jpg');
      expect(entry['voiceUrl'], 'https://cdn/reject.m4a');
      expect(entry['time'], at.toIso8601String());
    });

    test('logActivity appends (never replaces) and parseActivityLog round-trips',
        () {
      final r = Report()
        ..logActivity(actor: 'tl', action: 'rejected', time: DateTime(2026))
        ..logActivity(actor: 'sub', action: 'resubmitted', time: DateTime(2026));

      expect(r.activityLog, hasLength(2));
      final parsed = r.parseActivityLog();
      expect(parsed, hasLength(2));
      expect(parsed[0]['actor'], 'tl');
      expect(parsed[1]['action'], 'resubmitted');
    });

    test('parseActivityLog drops malformed entries instead of throwing', () {
      final r = Report()
        ..activityLog = ['not json at all', '{"actor":"tl","action":"ok"}'];
      expect(r.parseActivityLog(), hasLength(1));
    });
  });

  group('ReportDetailScreen dispute & resubmit UI', () {
    Future<void> pumpDetail(
      WidgetTester tester,
      Report report, {
      required String role,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportDetailScreen(
            report: report,
            userRoleOverride: role,
          ),
        ),
      );
      // One pump settles the (failing) Isar future.
      await tester.pump();
    }

    testWidgets('a rejected report gives the subcontractor FIX & RESUBMIT', (
      tester,
    ) async {
      await pumpDetail(tester, rejectedReport(), role: 'subcontractor');

      // One giant green camera button, labelled in full.
      expect(find.text('FIX & RESUBMIT'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.camera_alt)).size, 28);
      expect(find.byTooltip('FIX & RESUBMIT'), findsNothing);
      expect(find.text('APPROVE'), findsNothing);
      expect(find.text('REMOTE'), findsNothing);
    });

    testWidgets('a Team Leader never gets the Fix & Resubmit bar', (
      tester,
    ) async {
      await pumpDetail(tester, rejectedReport(), role: 'team_leader');

      // The report is already rejected (tlValidatedAt is set), so the TL has
      // nothing left to decide and no fix button either.
      expect(find.text('FIX & RESUBMIT'), findsNothing);
      expect(find.text('APPROVE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
    });

    testWidgets('no Fix & Resubmit button when the report was not rejected', (
      tester,
    ) async {
      final clean = Report()
        ..type = 'work'
        ..timestamp = DateTime(2026, 9, 17);
      await pumpDetail(tester, clean, role: 'subcontractor');

      expect(find.text('FIX & RESUBMIT'), findsNothing);
      expect(find.byIcon(Icons.camera_alt), findsNothing);
    });

    testWidgets('a closed report shows the banner and WORK CLOSED', (
      tester,
    ) async {
      final closed = rejectedReport()..ownerStatus = 'validated';
      await pumpDetail(tester, closed, role: 'subcontractor');

      // The header still states the stage, and the bar is disabled.
      expect(find.text('Approved by Owner'), findsOneWidget);
      expect(find.text('WORK CLOSED'), findsOneWidget);
      expect(find.text('FIX & RESUBMIT'), findsNothing);
    });

    testWidgets('the closed banner also overrides the TL gate buttons', (
      tester,
    ) async {
      final closed = Report()
        ..type = 'work'
        ..timestamp = DateTime(2026, 9, 17)
        ..ownerStatus = 'validated';
      await pumpDetail(tester, closed, role: 'team_leader');

      // The header states the closed stage and every action is suppressed.
      expect(find.text('Approved by Owner'), findsOneWidget);
      expect(find.text('WORK CLOSED'), findsOneWidget);
      expect(find.text('APPROVE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
    });
  });

  group('History card role-based status dots', () {
    Future<void> pumpHistory(
      WidgetTester tester,
      List<Report> reports, {
      required String role,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(
            userRoleOverride: role,
            reportsStream: Stream<List<Report>>.value(reports),
          ),
        ),
      );
      // Settle the one-shot stream emission.
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a subcontractor sees the TL chip and the owner chip', (
      tester,
    ) async {
      await pumpHistory(
        tester,
        [rejectedReport()..ownerStatus = 'pending'],
        role: 'subcontractor',
      );

      expect(find.text('TL: Rejected'), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget); // owner: pending
    });

    testWidgets('a verified report shows TL: Verified in green context', (
      tester,
    ) async {
      final r = rejectedReport()
        ..tlValidationType = 'physical'
        ..ownerStatus = 'pending';
      await pumpHistory(tester, [r], role: 'subcontractor');

      expect(find.text('TL: Verified'), findsOneWidget);
    });

    testWidgets('a Team Leader sees only the owner chip', (tester) async {
      await pumpHistory(
        tester,
        [rejectedReport()..ownerStatus = 'pending'],
        role: 'team_leader',
      );

      expect(find.text('TL: Rejected'), findsNothing);
      expect(find.text('Waiting'), findsOneWidget);
    });
  });
}