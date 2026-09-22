import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/widgets/traffic_card.dart';

/// The 'Cloud Status' footer on the History cards: green Synced, amber
/// Waiting to sync, red tappable Sync Failed, hidden for the Owner.
void main() {
  final now = DateTime(2026, 9, 17, 9, 30);

  Report base() => Report()
    ..type = 'work'
    ..timestamp = now
    ..isReadByUser = true;

  Report syncedReport() => base()
    ..photoStatus = 'synced'
    ..voiceStatus = 'synced'
    ..dbStatus = 'synced';

  Report localReport() => base(); // status 'pending' -> SyncState.local

  Report uploadingReport() => base()..status = 'uploading';

  Report failedReport() => base()..status = 'failed';

  Future<void> pumpCard(WidgetTester tester, Report report) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TrafficCard(report: report))),
    );
    await tester.pump();
  }

  testWidgets('synced report shows green cloud_done + Synced', (tester) async {
    await pumpCard(tester, syncedReport());
    expect(find.byKey(const Key('cloud_status_synced')), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    expect(find.text('Waiting to sync'), findsNothing);
    expect(find.text('Sync Failed - Tap to retry'), findsNothing);
  });

  testWidgets('local report shows amber Waiting to sync', (tester) async {
    await pumpCard(tester, localReport());
    expect(find.byKey(const Key('cloud_status_pending')), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
  });

  testWidgets('uploading report shows amber Waiting to sync', (tester) async {
    await pumpCard(tester, uploadingReport());
    expect(find.byKey(const Key('cloud_status_pending')), findsOneWidget);
    expect(find.text('Waiting to sync'), findsOneWidget);
  });

  testWidgets('failed report shows red retry row + snackbar on tap',
      (tester) async {
    await pumpCard(tester, failedReport());
    expect(find.byKey(const Key('cloud_status_failed')), findsOneWidget);
    expect(find.text('Sync Failed - Tap to retry'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);

    // The tap path runs SyncService.retryReport (Isar-backed, unopened in
    // tests): the retry must not crash the card and the snackbar shows.
    await tester.tap(find.byKey(const Key('cloud_status_failed')));
    await tester.pump();
    expect(find.text('Retrying sync...'), findsOneWidget);
    // Footer stays red and tappable after the (failed) retry.
    expect(find.text('Sync Failed - Tap to retry'), findsOneWidget);
  });

  testWidgets('owner list hides the cloud status footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrafficCard(report: localReport(), showCloudStatus: false),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('cloud_status_pending')), findsNothing);
    expect(find.byKey(const Key('cloud_status_synced')), findsNothing);
    expect(find.byKey(const Key('cloud_status_failed')), findsNothing);
    expect(find.text('Waiting to sync'), findsNothing);
  });
}
