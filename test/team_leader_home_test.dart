import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/team_leader_home_screen.dart';

/// Tests for the Team Leader "Manager's Inbox" (Chef de Chantier Dashboard).
/// Isar streams don't run in the widget-test VM, so the report stream is
/// injected in-memory.
void main() {
  /// Pumps the dashboard with a canned stream of [reports].
  Future<void> pumpDashboard(
    WidgetTester tester,
    List<Report> reports,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TeamLeaderHomeScreen(
          reportsStream: Stream<List<Report>>.value(reports),
        ),
      ),
    );
    // First pump builds; second settles the one-shot stream emission.
    await tester.pump();
    await tester.pump();
  }

  Report pendingReport(String type) => Report()
    ..type = type
    ..timestamp = DateTime(2026, 9, 17, 9, 30);

  group('TeamLeaderHomeScreen', () {
    testWidgets('shows the all-caught-up message when nothing is pending', (
      tester,
    ) async {
      final validated = pendingReport('work')
        ..tlValidatedAt = DateTime.now();
      await pumpDashboard(tester, [validated]);

      expect(
        find.text('All caught up. No work pending verification.'),
        findsOneWidget,
      );
      expect(find.text('Work report'), findsNothing);
    });

    testWidgets('lists pending work and material reports', (tester) async {
      await pumpDashboard(tester, [
        pendingReport('work'),
        pendingReport('material'),
      ]);

      expect(find.text('Work report'), findsOneWidget);
      expect(find.text('Material report'), findsOneWidget);
    });

    testWidgets('validated reports leave the inbox', (tester) async {
      final validated = pendingReport('work')
        ..tlValidatedAt = DateTime.now();
      await pumpDashboard(tester, [
        pendingReport('work'),
        validated,
      ]);

      expect(find.text('Work report'), findsOneWidget);
    });

    testWidgets('problem reports never enter the gate queue', (tester) async {
      await pumpDashboard(tester, [pendingReport('problem')]);

      expect(find.text('Work report'), findsNothing);
      expect(find.text('Material report'), findsNothing);
      expect(
        find.text('All caught up. No work pending verification.'),
        findsOneWidget,
      );
    });

    testWidgets('the dashboard header is shown', (tester) async {
      await pumpDashboard(tester, []);

      expect(find.text('Chef de Chantier Dashboard'), findsOneWidget);
    });
  });
}