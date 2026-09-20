import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/history_screen.dart';

/// The WhatsApp-style unread indicator on the History cards and the
/// subcontractor's REWORK view.
void main() {
  final now = DateTime(2026, 9, 17, 9, 30);

  Report freshWork() => Report()
    ..type = 'work'
    ..timestamp = now;

  Report rejectedWork() => freshWork()
    ..tlValidatedAt = now
    ..tlValidationType = 'rejected';

  group('Report.isReadByUser (the model layer)', () {
    test('a report starts unread', () {
      expect(Report().isReadByUser, isFalse);
    });

    test('a new timeline event flags the report unread again', () {
      final r = freshWork()..isReadByUser = true;
      expect(r.isReadByUser, isTrue);

      r.addTimelineEvent(
        actor: 'tl',
        action: 'reject',
        text: 'Fix the finish',
      );
      expect(r.isReadByUser, isFalse);
    });
  });

  group('History screen unread dot', () {
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

    testWidgets('an unread report shows the blue dot', (tester) async {
      await pumpHistory(tester, [freshWork()], role: 'subcontractor');

      final dot = find.byKey(const Key('history_unread_dot'));
      expect(dot, findsOneWidget);
      final decoration =
          tester.widget<Container>(dot).decoration! as BoxDecoration;
      expect(decoration.color, Colors.blue);
    });

    testWidgets('a read report hides the dot', (tester) async {
      await pumpHistory(
        tester,
        [freshWork()..isReadByUser = true],
        role: 'subcontractor',
      );

      expect(find.byKey(const Key('history_unread_dot')), findsNothing);
    });
  });

  group('Subcontractor REWORK view', () {
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
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a subcontractor gets REWORK instead of TO VERIFY', (
      tester,
    ) async {
      await pumpHistory(tester, [rejectedWork()], role: 'subcontractor');

      expect(find.textContaining('REWORK'), findsOneWidget);
      expect(find.textContaining('TO VERIFY'), findsNothing);
    });

    testWidgets('a Team Leader keeps TO VERIFY and never sees REWORK', (
      tester,
    ) async {
      await pumpHistory(tester, [freshWork()], role: 'team_leader');

      expect(find.textContaining('TO VERIFY'), findsOneWidget);
      expect(find.textContaining('REWORK'), findsNothing);
    });

    testWidgets('REWORK lists only the TL-rejected reports', (tester) async {
      await pumpHistory(
        tester,
        [freshWork(), rejectedWork()],
        role: 'subcontractor',
      );

      // Select the REWORK view.
      await tester.tap(find.textContaining('REWORK'));
      await tester.pump();

      // Only the rejected report survives the filter.
      expect(find.text('TL: Rejected'), findsOneWidget);
      expect(find.text('TL: Pending'), findsNothing);
    });

    testWidgets('an empty REWORK view shows its all-clear hint', (
      tester,
    ) async {
      await pumpHistory(tester, [freshWork()], role: 'subcontractor');

      await tester.tap(find.textContaining('REWORK'));
      await tester.pump();

      expect(find.text('Nothing to rework. All clear!'), findsOneWidget);
    });
  });
}
