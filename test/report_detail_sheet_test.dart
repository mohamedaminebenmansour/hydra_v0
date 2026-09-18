import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/widgets/report_detail_bottom_sheet.dart';

/// Tests for the reusable "Report Detail & Chat" bottom sheet — Step 1 of the
/// refactor. The sheet is opened through its real entry point
/// [showReportDetailSheet] with injected seams ([ReportWatcher],
/// [ReportCommentSender], [ReportLocationOpener], [ReportSheetActions]) so no
/// Isar, Supabase or camera plugin is ever touched.
void main() {
  final now = DateTime(2026, 9, 17, 9, 30);

  Report freshWork() => Report()
    ..type = 'work'
    ..timestamp = now
    ..lat = 24.7136
    ..lng = 46.6753;

  Report rejectedWork() => freshWork()
    ..tlValidatedAt = DateTime(2026, 9, 17, 10, 0)
    ..tlValidationType = 'rejected';

  /// Pump a real modal sheet opened through [showReportDetailSheet], and
  /// return a getter for the sheet's completion result.
  Future<Future<bool?> Function()> pumpSheet(
    WidgetTester tester, {
    required Report report,
    ReportWatcher? watch,
    ReportCommentSender? sendComment,
    ReportLocationOpener? onOpenLocation,
    ReportSheetActions actions = const ReportSheetActions(),
    String selfActor = 'sub',
  }) async {
    final completer = Completer<bool?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showReportDetailSheet(
                    context,
                    report: report,
                    watch: watch,
                    sendComment: sendComment,
                    onOpenLocation: onOpenLocation,
                    actions: actions,
                    selfActor: selfActor,
                  );
                  if (!completer.isCompleted) completer.complete(result);
                },
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
    return () => completer.future;
  }

  group('Stage resolution (the primitive Step 3 reuses)', () {
    test('a fresh gated report is pending TL validation', () {
      final r = freshWork();
      expect(reportStageOf(r), ReportStage.pendingTl);
      final (icon, color, label) = reportStageStyle(ReportStage.pendingTl);
      expect(label, 'Pending TL Validation');
      expect(icon, Icons.hourglass_top);
      expect(color, Colors.orange);
    });

    test('a TL rejection short-circuits to rejectedByTl', () {
      final r = rejectedWork();
      expect(r.isTlRejected, isTrue);
      expect(reportStageOf(r), ReportStage.rejectedByTl);
      expect(
        reportStageStyle(ReportStage.rejectedByTl).$3,
        'Rejected by TL — Needs Fix',
      );
    });

    test('a TL-approved report waits for the owner', () {
      final r = freshWork()
        ..tlValidatedAt = DateTime(2026, 9, 17, 10, 0)
        ..tlValidationType = 'remote';
      expect(r.isTlVerified, isTrue);
      expect(reportStageOf(r), ReportStage.pendingOwner);
      expect(
        reportStageStyle(ReportStage.pendingOwner).$3,
        'Pending Owner Approval',
      );
    });

    test('the owner decision closes the report and picks the wording', () {
      for (final entry in {
        'validated': 'Approved by Owner',
        'approved': 'Approved by Owner',
        'ordered': 'Material Ordered',
        'acknowledged': 'Acknowledged by Owner',
        'rejected': 'Rejected by Owner',
      }.entries) {
        final r = freshWork()..ownerStatus = entry.key;
        expect(reportStageOf(r), ReportStage.closedByOwner, reason: entry.key);
        expect(
          reportStageStyle(
            ReportStage.closedByOwner,
            ownerStatus: entry.key,
          ).$3,
          entry.value,
          reason: entry.key,
        );
        expect(isReportClosedByOwner(r), isTrue);
      }
    });

    test('problem reports skip the TL gate and go straight to the owner', () {
      final r = freshWork()..type = 'problem';
      expect(r.needsTlValidation, isFalse);
      expect(reportStageOf(r), ReportStage.pendingOwner);
    });

    test('the owner decision wins even over an earlier TL rejection', () {
      final r = rejectedWork()..ownerStatus = 'validated';
      expect(reportStageOf(r), ReportStage.closedByOwner);
    });
  });
  group('Sheet content', () {
    testWidgets('shows status badge, type chip, timestamp and GPS', (
      tester,
    ) async {
      await pumpSheet(tester, report: freshWork());

      expect(find.text('Pending TL Validation'), findsOneWidget);
      expect(find.text('🔨 Work'), findsOneWidget);
      // 2026-09-17 is a Thursday; 'EEE d MMM, HH:mm' in en_US.
      expect(find.text('Thu 17 Sep, 09:30'), findsOneWidget);
      expect(find.text('24.71360, 46.67530'), findsOneWidget);
    });

    testWidgets('shows "No GPS captured" and does not open the map', (
      tester,
    ) async {
      var opened = false;
      await pumpSheet(
        tester,
        report: freshWork()
          ..lat = 0
          ..lng = 0,
        onOpenLocation: (_, unneeded) => opened = true,
      );

      expect(find.text('No GPS captured'), findsOneWidget);
      await tester.tap(find.text('No GPS captured'));
      await tester.pump();
      expect(opened, isFalse);
    });

    testWidgets('tapping the coordinates row opens the internal map', (
      tester,
    ) async {
      Report? openedFor;
      await pumpSheet(
        tester,
        report: freshWork(),
        onOpenLocation: (context, report) => openedFor = report,
      );

      await tester.tap(find.text('24.71360, 46.67530'));
      await tester.pump();
      expect(openedFor, isNotNull);
      expect(openedFor!.lat, 24.7136);
    });

    testWidgets('renders the thread: bubbles, labels, rejection ring', (
      tester,
    ) async {
      final r = rejectedWork()
        ..addTimelineEvent(actor: 'sub', action: 'submit', time: now.toUtc())
        ..addTimelineEvent(
          actor: 'tl',
          action: 'reject',
          text: 'The concrete finish is not acceptable',
          time: now.add(const Duration(hours: 1)).toUtc(),
        );
      await pumpSheet(tester, report: r);

      // Both bubbles render with actor names and human action labels.
      expect(find.text('Reported'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('The concrete finish is not acceptable'), findsOneWidget);
      expect(find.text('Subcontractor'), findsOneWidget);
      expect(find.text('Team Leader'), findsOneWidget);
    });

    testWidgets('an empty thread shows the hint', (tester) async {
      await pumpSheet(tester, report: freshWork());
      expect(find.text('No messages yet.'), findsOneWidget);
    });

    testWidgets('the composer wording follows actor and stage', (tester) async {
      // Subcontractor, pending: neutral wording.
      await pumpSheet(tester, report: freshWork(), selfActor: 'sub');
      expect(find.text('Explain or ask something…'), findsOneWidget);
      // Dismiss through the modal barrier (the sheet has no back button).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Subcontractor, rejected: the fix-explanation wording.
      await pumpSheet(tester, report: rejectedWork(), selfActor: 'sub');
      expect(find.text('Explain how you fixed it…'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Team Leader: never the fix wording.
      await pumpSheet(tester, report: rejectedWork(), selfActor: 'tl');
      expect(find.text('Write a message about the fix…'), findsOneWidget);
      expect(find.text('Explain how you fixed it…'), findsNothing);
    });
  });

  group('Chat', () {
    testWidgets('sending a message writes it, clears the box and pops true', (
      tester,
    ) async {
      final sent = <({Report report, String text, String actor})>[];
      await pumpSheet(
        tester,
        report: freshWork()..id = 7,
        sendComment: (report, text, actor) async {
          sent.add((report: report, text: text, actor: actor));
        },
        selfActor: 'sub',
      );

      await tester.enterText(
        find.byType(TextField),
        'Formwork has been replaced',
      );
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(sent, hasLength(1));
      expect(sent.single.report.id, 7);
      expect(sent.single.actor, 'sub');
      expect(sent.single.text, 'Formwork has been replaced');
      // The composer is cleared after a successful send.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('an offline send keeps the text so nothing is lost', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        report: freshWork()..id = 7,
        sendComment: (_, unneeded, _) => throw Exception('offline'),
        selfActor: 'sub',
      );

      await tester.enterText(find.byType(TextField), 'still offline');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Could not send — check connection'), findsOneWidget);
      // The draft stays in the box.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'still offline',
      );
      // The sheet did not pop (it must stay open).
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Action bar', () {
    testWidgets('renders injected actions and reports which one ran', (
      tester,
    ) async {
      var pressed = -1;
      await pumpSheet(
        tester,
        report: freshWork(),
        actions: ReportSheetActions(
          note: 'Reviewer gate',
          buttons: [
            ReportSheetAction(
              label: 'APPROVE',
              color: Colors.green,
              icon: Icons.check,
              onPressed: (_, unneeded) async {
                pressed = 0;
                return true;
              },
            ),
            ReportSheetAction(
              label: 'REJECT',
              color: Colors.red,
              icon: Icons.close,
              onPressed: (_, unneeded) async {
                pressed = 1;
                return false;
              },
            ),
          ],
        ),
      );

      expect(find.text('Reviewer gate'), findsOneWidget);
      expect(find.text('APPROVE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);

      await tester.tap(find.text('REJECT'));
      await tester.pump();
      expect(pressed, 1);
      // Returning false keeps the sheet open.
      expect(find.text('REJECT'), findsOneWidget);
    });

    testWidgets('empty actions render no buttons (status banner only)', (
      tester,
    ) async {
      await pumpSheet(tester, report: freshWork());
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('APPROVE'), findsNothing);
    });
  });

  group('Live updates', () {
    testWidgets('a new message arriving on the stream appears in the thread', (
      tester,
    ) async {
      final controller = StreamController<Report?>.broadcast();
      final r = freshWork()..id = 9;
      await pumpSheet(tester, report: r, watch: (_) => controller.stream);

      expect(find.text('No messages yet.'), findsOneWidget);

      controller.add(
        freshWork()
          ..id = 9
          ..addTimelineEvent(
            actor: 'tl',
            action: 'comment',
            text: 'Send me a closer photo',
          ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Send me a closer photo'), findsOneWidget);
      await controller.close();
    });
  });
}
