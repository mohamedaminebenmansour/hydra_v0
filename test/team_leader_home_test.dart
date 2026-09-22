import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/team_leader_home_screen.dart';

/// Tests for the Team Leader "Action Center" (Chef de Chantier Inbox).
/// Isar streams don't run in the widget-test VM, so the report stream is
/// injected in-memory; the queue ordering itself is a pure function.
void main() {
  /// Pumps the inbox with a canned stream of [reports].
  Future<void> pumpInbox(WidgetTester tester, List<Report> reports) async {
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

  Report pendingReport(String type, {DateTime? at}) => Report()
    ..type = type
    ..timestamp = at ?? DateTime(2026, 9, 17, 9, 30);

  group('tlInboxQueue (the pure queue rule)', () {
    test('keeps only reports still waiting for the TL', () {
      final validated = pendingReport('work')..tlValidatedAt = DateTime.now();
      final queue = tlInboxQueue([
        pendingReport('work'),
        pendingReport('material'),
        validated,
        pendingReport('problem'), // never passes the gate
      ]);

      expect(queue.map((r) => r.type), ['material', 'work']);
    });

    test('ranks material above work and sorts oldest first', () {
      final newestWork = pendingReport('work', at: DateTime(2026, 9, 20, 8));
      final oldestWork = pendingReport('work', at: DateTime(2026, 9, 1, 8));
      final material = pendingReport('material', at: DateTime(2026, 9, 10, 8));

      final queue = tlInboxQueue([newestWork, oldestWork, material]);

      expect(queue.first, same(material));
      expect(queue[1], same(oldestWork));
      expect(queue[2], same(newestWork));
    });
  });

  group('tlInboxTypeLabel', () {
    test('every type gets its own request wording', () {
      expect(tlInboxTypeLabel('work'), '🔨 WORK REQUEST');
      expect(tlInboxTypeLabel('material'), '📦 MATERIAL REQUEST');
      expect(tlInboxTypeLabel('problem'), '⚠️ PROBLEM REPORT');
    });
  });

  group('TeamLeaderHomeScreen', () {
    testWidgets('shows the Inbox Zero state when nothing is pending', (
      tester,
    ) async {
      final validated = pendingReport('work')..tlValidatedAt = DateTime.now();
      await pumpInbox(tester, [validated]);

      expect(find.text('Inbox Zero. All caught up.'), findsOneWidget);
      expect(find.byIcon(Icons.coffee), findsOneWidget);
      expect(find.text('🔨 WORK REQUEST'), findsNothing);
    });

    testWidgets('lists pending work and material requests', (tester) async {
      await pumpInbox(tester, [
        pendingReport('work'),
        pendingReport('material'),
      ]);

      expect(find.text('🔨 WORK REQUEST'), findsOneWidget);
      expect(find.text('📦 MATERIAL REQUEST'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('material requests sit above work', (tester) async {
      await pumpInbox(tester, [
        pendingReport('work', at: DateTime(2026, 9, 1, 8)),
        pendingReport('material', at: DateTime(2026, 9, 20, 8)),
      ]);

      final materialY =
          tester.getTopLeft(find.text('📦 MATERIAL REQUEST')).dy;
      final workY = tester.getTopLeft(find.text('🔨 WORK REQUEST')).dy;
      expect(materialY, lessThan(workY));
    });

    testWidgets('validated reports leave the inbox', (tester) async {
      final validated = pendingReport('work')..tlValidatedAt = DateTime.now();
      await pumpInbox(tester, [pendingReport('work'), validated]);

      expect(find.text('🔨 WORK REQUEST'), findsOneWidget);
    });

    testWidgets('problem reports never enter the gate queue', (tester) async {
      await pumpInbox(tester, [pendingReport('problem')]);

      expect(find.text('⚠️ PROBLEM REPORT'), findsNothing);
      expect(find.text('Inbox Zero. All caught up.'), findsOneWidget);
    });

    testWidgets('the action-center header and History door are shown', (
      tester,
    ) async {
      await pumpInbox(tester, []);

      expect(find.text('Chef de Chantier'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('the CAPTURE button opens the three-type picker', (
      tester,
    ) async {
      await pumpInbox(tester, []);

      expect(find.text('CAPTURE'), findsOneWidget);
      await tester.tap(find.text('CAPTURE'));
      await tester.pumpAndSettle();

      expect(find.text('NEW REPORT'), findsOneWidget);
      expect(find.text('WORK'), findsOneWidget);
      expect(find.text('PROBLEM'), findsOneWidget);
      expect(find.text('MATERIAL'), findsOneWidget);
    });

    testWidgets('a tap on a row opens the validation sheet', (tester) async {
      await pumpInbox(tester, [pendingReport('work')]);

      await tester.tap(find.text('🔨 WORK REQUEST'));
      await tester.pumpAndSettle();

      // The shared sheet renders its TL gate bar for a pending report.
      expect(find.text('REMOTE'), findsOneWidget);
      expect(find.text('ON SITE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
    });
  });
}
