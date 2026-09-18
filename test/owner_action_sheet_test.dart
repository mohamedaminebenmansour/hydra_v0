import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/screens/owner_action_sheet.dart';
import 'package:hydra_v0/widgets/timeline_audio_player.dart';

/// One raw `reports` row, exactly as the thin client reads it from Supabase.
Map<String, dynamic> reportRow({
  required String localId,
  String type = 'work',
  String ownerStatus = 'pending',
  String tlValidationType = '',
  String photoUrl = '',
  String voiceUrl = '',
  String tlRejectionPhotoUrl = '',
  String tlValidationPhotoUrl = '',
  String timestamp = '2026-09-18T09:30:00Z',
}) => {
  'local_id': localId,
  'type': type,
  'owner_status': ownerStatus,
  'tl_validation_type': tlValidationType,
  'photo_url': photoUrl,
  'voice_url': voiceUrl,
  'tl_rejection_photo_url': tlRejectionPhotoUrl,
  'tl_validation_photo_url': tlValidationPhotoUrl,
  'lat': 36.8,
  'lng': 10.1,
  'timestamp': timestamp,
};

/// Records every decision the sheet writes, and can be made to fail on demand.
class _FakeWriter {
  final List<(String, String)> calls = [];
  Object? failure;

  Future<void> call(String localId, String ownerStatus) async {
    if (failure != null) throw failure!;
    calls.add((localId, ownerStatus));
  }
}

/// Tests for the Owner's decision sheet: context-aware giant buttons, the
/// Team Leader badge, the disabled banner and the network-error paths.
void main() {
  /// Opens the sheet through its real entry point and settles its animation
  /// (fixed pumps, so an on-screen spinner can never hang the test).
  Future<void> pumpSheet(
    WidgetTester tester, {
    required Map<String, dynamic> row,
    required OwnerDecisionWriter writer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showOwnerActionSheet(
                  context,
                  row: row,
                  writeDecision: writer,
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('context-aware giant buttons', () {
    testWidgets('work offers VALIDATE and writes "validated"', (tester) async {
      final writer = _FakeWriter();
      await pumpSheet(
        tester,
        row: reportRow(localId: '7', type: 'work'),
        writer: writer.call,
      );

      expect(find.text('🔨'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('VALIDATE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);

      await tester.tap(find.text('VALIDATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(writer.calls, [('7', 'validated')]);
      // The sheet closed, so the map is free to re-fetch.
      expect(find.text('VALIDATE'), findsNothing);
    });

    testWidgets('problem offers ACKNOWLEDGE and writes "acknowledged"', (
      tester,
    ) async {
      final writer = _FakeWriter();
      await pumpSheet(
        tester,
        row: reportRow(localId: '8', type: 'problem'),
        writer: writer.call,
      );

      expect(find.text('⚠️'), findsOneWidget);
      expect(find.text('Problem'), findsOneWidget);
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
      expect(find.text('VALIDATE'), findsNothing);

      await tester.tap(find.text('ACKNOWLEDGE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(writer.calls, [('8', 'acknowledged')]);
    });

    testWidgets('material offers ORDER and writes "ordered"', (tester) async {
      final writer = _FakeWriter();
      await pumpSheet(
        tester,
        row: reportRow(localId: '9', type: 'material'),
        writer: writer.call,
      );

      expect(find.text('📦'), findsOneWidget);
      expect(find.text('Material'), findsOneWidget);
      expect(find.text('ORDER'), findsOneWidget);

      await tester.tap(find.text('ORDER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(writer.calls, [('9', 'ordered')]);
    });

    testWidgets('REJECT is always offered and writes "rejected"', (
      tester,
    ) async {
      final writer = _FakeWriter();
      await pumpSheet(
        tester,
        row: reportRow(localId: '10', type: 'material'),
        writer: writer.call,
      );

      await tester.tap(find.text('REJECT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(writer.calls, [('10', 'rejected')]);
    });
  });

  group('report context', () {
    testWidgets('shows the type emoji, the word and the timestamp', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        row: reportRow(localId: '1', type: 'work'),
        writer: _FakeWriter().call,
      );

      expect(find.text('🔨'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      // A parsable timestamp is rendered as a date, never as the dash fallback.
      expect(find.text('—'), findsNothing);
    });
  });

  group('Team Leader badge', () {
    testWidgets('a physical validation reads "Verified On Site"', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        row: reportRow(localId: '1', tlValidationType: 'physical'),
        writer: _FakeWriter().call,
      );

      expect(find.text('✓ TL Verified On Site'), findsOneWidget);
    });

    testWidgets('a remote validation reads "Verified Remotely"', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        row: reportRow(localId: '1', tlValidationType: 'remote'),
        writer: _FakeWriter().call,
      );

      expect(find.text('✓ TL Verified Remotely'), findsOneWidget);
    });

    testWidgets('a rejection shows the TL rejection thumbnail', (tester) async {
      await pumpSheet(
        tester,
        row: reportRow(
          localId: '1',
          tlValidationType: 'rejected',
          tlRejectionPhotoUrl: 'https://example.com/reject.jpg',
        ),
        writer: _FakeWriter().call,
      );

      expect(find.text('TL Rejected'), findsOneWidget);
      // The row has no subcontractor photo, so the only network image is the
      // TL's rejection proof.
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      while (tester.takeException() != null) {
        // Intentionally swallowed: no image cache plugin in the test VM.
      }
    });

    testWidgets('an unverified report says so', (tester) async {
      await pumpSheet(
        tester,
        row: reportRow(localId: '1'),
        writer: _FakeWriter().call,
      );

      expect(find.text('TL Not Verified Yet'), findsOneWidget);
    });
  });

  group('already-decided reports', () {
    testWidgets('hide the buttons and show the status banner', (tester) async {
      final writer = _FakeWriter();
      await pumpSheet(
        tester,
        row: reportRow(localId: '3', ownerStatus: 'validated'),
        writer: writer.call,
      );

      expect(find.text('VALIDATE'), findsNothing);
      expect(find.text('REJECT'), findsNothing);
      expect(find.text('Validated'), findsOneWidget);
      expect(
        find.text('Already decided — nothing left to do here.'),
        findsOneWidget,
      );
      expect(writer.calls, isEmpty);
    });

    testWidgets('an ordered report shows the ordered banner', (tester) async {
      await pumpSheet(
        tester,
        row: reportRow(localId: '4', ownerStatus: 'ordered'),
        writer: _FakeWriter().call,
      );

      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('ORDER'), findsNothing);
    });
  });

  group('network failures', () {
    testWidgets('keep the sheet open and explain the problem', (tester) async {
      final writer = _FakeWriter()..failure = Exception('500');
      await pumpSheet(
        tester,
        row: reportRow(localId: '5'),
        writer: writer.call,
      );

      await tester.tap(find.text('VALIDATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Could not save the decision — check your connection.'),
        findsOneWidget,
      );
      // Still open, so the owner can simply tap again.
      expect(find.text('VALIDATE'), findsOneWidget);
    });

    testWidgets('an offline device gets its own message', (tester) async {
      final writer = _FakeWriter()..failure = const OwnerOfflineException();
      await pumpSheet(
        tester,
        row: reportRow(localId: '6'),
        writer: writer.call,
      );

      await tester.tap(find.text('VALIDATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Offline — decision not saved. Connect and try again.'),
        findsOneWidget,
      );
      expect(find.text('VALIDATE'), findsOneWidget);
    });
  });

  group('voice note', () {
    testWidgets('offers a play button when the row has a voice note', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        row: reportRow(
          localId: '11',
          voiceUrl: 'https://example.com/voice.m4a',
        ),
        writer: _FakeWriter().call,
      );

      expect(find.byType(TimelineAudioPlayer), findsOneWidget);
      while (tester.takeException() != null) {
        // Intentionally swallowed: no audio plugin in the test VM.
      }
    });

    testWidgets('shows no player when there is no voice note', (tester) async {
      await pumpSheet(
        tester,
        row: reportRow(localId: '12'),
        writer: _FakeWriter().call,
      );

      expect(find.byType(TimelineAudioPlayer), findsNothing);
    });
  });
}
