import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/widgets/report_detail_bottom_sheet.dart';
import 'package:hydra_v0/widgets/report_sheet_actions.dart';

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
    testWidgets('shows the type title, timestamp, badge and no raw GPS', (
      tester,
    ) async {
      await pumpSheet(tester, report: freshWork());

      expect(find.text('Pending TL Validation'), findsOneWidget);
      // The emoji-prefixed, uppercased type title.
      expect(find.textContaining('WORK'), findsOneWidget);
      // 'd MMM, hh:mm a' in en_US; 2026-09-17 09:30 local.
      expect(find.text('17 Sep, 09:30 AM'), findsOneWidget);
      // The WhatsApp-Profile header never prints raw coordinates.
      expect(find.textContaining('24.71360'), findsNothing);
      expect(find.textContaining('46.67530'), findsNothing);
      expect(find.text('No GPS captured'), findsNothing);
    });

    testWidgets('the map button opens the map centered on the report', (
      tester,
    ) async {
      Report? openedFor;
      await pumpSheet(
        tester,
        report: freshWork(),
        onOpenLocation: (context, report) => openedFor = report,
      );

      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pump();
      expect(openedFor, isNotNull);
      expect(openedFor!.lat, 24.7136);
    });

    testWidgets('the map button works even without captured GPS', (
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

      await tester.tap(find.byIcon(Icons.map_outlined));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('renders the thread: bubbles, labels, red TL rejection', (
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

      // The TL rejection leans right and is a filled red bubble.
      final rejection = find.text('The concrete finish is not acceptable');
      final bubble = tester.widget<Container>(
        find.ancestor(of: rejection, matching: find.byType(Container)).first,
      );
      expect((bubble.decoration! as BoxDecoration).color, Colors.red.shade100);
      final align = tester.widget<Align>(
        find.ancestor(of: rejection, matching: find.byType(Align)).first,
      );
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('an empty thread shows the hint', (tester) async {
      await pumpSheet(tester, report: freshWork());
      expect(find.text('No messages yet.'), findsOneWidget);
    });
  });

  group('Action bar', () {
    /// The solid fill of the giant button carrying [label], read from its
    /// [Material] ancestor.
    Color? buttonColor(WidgetTester tester, String label) {
      final button = find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first;
      return tester.widget<Material>(button).color;
    }

    /// The icon rendered inside the giant button carrying [label].
    Icon buttonIcon(WidgetTester tester, String label) {
      final button = find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first;
      return tester.widget<Icon>(
        find.descendant(of: button, matching: find.byType(Icon)),
      );
    }

    testWidgets('renders two giant labelled buttons and runs the tapped flow', (
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
      // The wording is written on the buttons, never hidden in a tooltip.
      expect(find.text('APPROVE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
      expect(find.byTooltip('APPROVE'), findsNothing);
      expect(find.byTooltip('REJECT'), findsNothing);
      // Giant icons on solid green / red fills.
      expect(buttonIcon(tester, 'APPROVE').icon, Icons.check);
      expect(buttonIcon(tester, 'APPROVE').size, 28);
      expect(buttonIcon(tester, 'REJECT').icon, Icons.close);
      expect(buttonIcon(tester, 'REJECT').size, 28);
      expect(buttonColor(tester, 'APPROVE'), Colors.green);
      expect(buttonColor(tester, 'REJECT'), Colors.red);

      await tester.tap(find.text('REJECT'));
      await tester.pump();
      expect(pressed, 1);
      // Returning false keeps the sheet open.
      expect(find.text('REJECT'), findsOneWidget);
    });

    testWidgets('the TL gate shows three direct buttons in one row', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        report: freshWork(),
        actions: tlGateActions(),
        selfActor: 'tl',
      );

      // The three-way decision, written out on the buttons.
      expect(find.text('REMOTE'), findsOneWidget);
      expect(find.text('ON SITE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);
      expect(buttonIcon(tester, 'REMOTE').icon, Icons.visibility);
      expect(buttonIcon(tester, 'ON SITE').icon, Icons.camera_alt);
      expect(buttonIcon(tester, 'REJECT').icon, Icons.close);
      expect(buttonIcon(tester, 'REMOTE').size, 28);
      expect(buttonColor(tester, 'REMOTE'), Colors.green);
      expect(buttonColor(tester, 'ON SITE'), Colors.green);
      expect(buttonColor(tester, 'REJECT'), Colors.red);

      // The three buttons share the bar roughly 33/34/33: equal widths,
      // each clearly smaller than a half-width bar button.
      final remote = tester.getSize(
        find.ancestor(of: find.text('REMOTE'), matching: find.byType(Material)).first,
      );
      final onSite = tester.getSize(
        find.ancestor(of: find.text('ON SITE'), matching: find.byType(Material)).first,
      );
      final reject = tester.getSize(
        find.ancestor(of: find.text('REJECT'), matching: find.byType(Material)).first,
      );
      expect(remote.width, closeTo(onSite.width, 1));
      expect(remote.width, closeTo(reject.width, 1));
      expect(remote.width, lessThan(400));
    });

    testWidgets('the thread is strictly read-only: no typing anywhere', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        report: rejectedWork(),
        actions: subFixActions(),
        selfActor: 'sub',
      );

      // The "No Typing" rule: media capture is the only way in.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.keyboard), findsNothing);
    });

    testWidgets('the TL gate buttons run their flows directly', (tester) async {
      var ran = '';
      await pumpSheet(
        tester,
        report: freshWork(),
        actions: ReportSheetActions(
          buttons: [
            ReportSheetAction(
              label: 'REMOTE',
              color: Colors.green,
              icon: Icons.visibility,
              onPressed: (_, unneeded) async {
                ran = 'remote';
                return true;
              },
            ),
            ReportSheetAction(
              label: 'ON SITE',
              color: Colors.green,
              icon: Icons.camera_alt,
              onPressed: (_, unneeded) async {
                ran = 'on_site';
                return false;
              },
            ),
          ],
        ),
        selfActor: 'tl',
      );

      // No popup, no intermediate choice: a tap runs its flow at once.
      await tester.tap(find.text('REMOTE'));
      await tester.pump();
      expect(ran, 'remote');
      // Returning true closes the sheet (pump past the exit animation).
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('REMOTE'), findsNothing);

      await pumpSheet(
        tester,
        report: freshWork(),
        actions: ReportSheetActions(
          buttons: [
            ReportSheetAction(
              label: 'ON SITE',
              color: Colors.green,
              icon: Icons.camera_alt,
              onPressed: (_, unneeded) async {
                ran = 'on_site';
                return false;
              },
            ),
          ],
        ),
        selfActor: 'tl',
      );
      await tester.tap(find.text('ON SITE'));
      await tester.pump();
      expect(ran, 'on_site');
      // Returning false keeps the sheet open.
      expect(find.text('ON SITE'), findsOneWidget);
    });

    testWidgets('empty actions render no buttons', (tester) async {
      await pumpSheet(tester, report: freshWork());
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('APPROVE'), findsNothing);
      // Still awaiting the gate, so there is nothing to lock either.
      expect(find.byIcon(Icons.lock), findsNothing);
    });

    testWidgets('a decided report shows the disabled stage bar, not actions', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        report: freshWork()
          ..tlValidatedAt = DateTime(2026, 9, 17, 10, 0)
          ..tlValidationType = 'remote',
      );

      // Nothing left to do: an inert grey lock plus the stage wording (the
      // header badge states the same stage, hence two matching labels).
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(Icons.lock)).color, Colors.grey);
      expect(find.text('Pending Owner Approval'), findsNWidgets(2));
      expect(find.text('APPROVE'), findsNothing);
    });

    testWidgets('a closed report shows the disabled WORK CLOSED bar', (
      tester,
    ) async {
      final closed = freshWork()..ownerStatus = 'validated';
      await pumpSheet(
        tester,
        report: closed,
        actions: defaultActionsFor(closed, role: 'team_leader'),
        selfActor: 'tl',
      );

      expect(find.text('WORK CLOSED'), findsOneWidget);
      expect(find.text('REMOTE'), findsNothing);
      expect(find.text('ON SITE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('a rejected report offers one giant green FIX & RESUBMIT', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        report: rejectedWork(),
        actions: subFixActions(),
        selfActor: 'sub',
      );

      // A single action, so it fills the whole width.
      final fix = find
          .ancestor(
            of: find.text('FIX & RESUBMIT'),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(fix).width, greaterThan(600));
      expect(buttonIcon(tester, 'FIX & RESUBMIT').icon, Icons.camera_alt);
      expect(buttonIcon(tester, 'FIX & RESUBMIT').size, 28);
      expect(buttonColor(tester, 'FIX & RESUBMIT'), Colors.green);
    });
  });

  group('Role-based bar (defaultActionsFor)', () {
    test('a Team Leader sees the three-way gate while it is open', () {
      final pending = freshWork();
      expect(
        defaultActionsFor(pending, role: 'team_leader').buttons.map(
          (b) => b.label,
        ),
        ['REMOTE', 'ON SITE', 'REJECT'],
      );

      final validated = freshWork()
        ..tlValidatedAt = DateTime(2026, 9, 17, 10)
        ..tlValidationType = 'remote';
      expect(defaultActionsFor(validated, role: 'team_leader').isEmpty, isTrue);
    });

    test('the gate is three direct buttons, one flow per tap', () {
      final buttons = defaultActionsFor(
        freshWork(),
        role: 'team_leader',
      ).buttons;

      expect(buttons, hasLength(3));
      final remote = buttons[0];
      expect(remote.label, 'REMOTE');
      expect(remote.icon, Icons.visibility);
      expect(remote.color, Colors.green);
      expect(remote.onPressed, tlValidateRemotelyFlow);
      final onSite = buttons[1];
      expect(onSite.label, 'ON SITE');
      expect(onSite.icon, Icons.camera_alt);
      expect(onSite.color, Colors.green);
      expect(onSite.onPressed, tlValidateOnSiteFlow);
      final reject = buttons[2];
      expect(reject.label, 'REJECT');
      expect(reject.icon, Icons.close);
      expect(reject.color, Colors.red);
      expect(reject.onPressed, tlRejectFlow);
    });

    test('REJECT runs the Dispute Shield directly', () {
      final reject = defaultActionsFor(
        freshWork(),
        role: 'team_leader',
      ).buttons[2];

      expect(reject.label, 'REJECT');
      expect(reject.icon, Icons.close);
      expect(reject.color, Colors.red);
      expect(reject.onPressed, tlRejectFlow);
    });

    test('a subcontractor gets one FIX & RESUBMIT on a rejected report', () {
      final actions = defaultActionsFor(rejectedWork(), role: 'subcontractor');

      expect(actions.buttons, hasLength(1));
      expect(actions.buttons.single.label, 'FIX & RESUBMIT');
      expect(actions.buttons.single.icon, Icons.camera_alt);
      expect(actions.buttons.single.color, Colors.green);
      expect(actions.buttons.single.onPressed, subFixAndResubmitFlow);
    });

    test('a subcontractor gets nothing on a report that was not rejected', () {
      expect(
        defaultActionsFor(freshWork(), role: 'subcontractor').isEmpty,
        isTrue,
      );
    });

    test('a problem report never enters the TL gate', () {
      final problem = freshWork()..type = 'problem';
      expect(defaultActionsFor(problem, role: 'team_leader').isEmpty, isTrue);
    });

    test('a closed report has no actions for anybody', () {
      final closed = freshWork()
        ..ownerStatus = 'validated'
        ..tlValidationType = 'rejected';

      expect(defaultActionsFor(closed, role: 'team_leader').isEmpty, isTrue);
      expect(defaultActionsFor(closed, role: 'subcontractor').isEmpty, isTrue);
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
