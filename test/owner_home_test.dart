import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:hydra_v0/screens/owner_action_sheet.dart';
import 'package:hydra_v0/screens/owner_home_screen.dart';

/// A 1x1 transparent PNG, so the tile layer never touches the network here.
final Uint8List _transparentPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// Tile provider that hands back a blank pixel instead of an HTTP request.
class _BlankTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPixel);
}

/// One raw `reports` row, exactly as the thin client reads it from Supabase.
Map<String, dynamic> reportRow({
  required String localId,
  String type = 'work',
  String ownerStatus = 'pending',
  String tlValidationType = '',
  double lat = 36.8,
  double lng = 10.1,
  String timestamp = '2026-09-18T09:30:00Z',
}) => {
  'local_id': localId,
  'type': type,
  'owner_status': ownerStatus,
  'tl_validation_type': tlValidationType,
  'photo_url': '',
  'voice_url': '',
  'lat': lat,
  'lng': lng,
  'timestamp': timestamp,
};

/// Tests for the Owner's "Site Command" map: the pure row helpers (where all
/// the filtering and color logic lives) plus the screen chrome.
void main() {
  group('owner row helpers', () {
    test('owner_status falls back to pending when the column is missing', () {
      expect(ownerStatusOf({'local_id': '1'}), 'pending');
      expect(ownerStatusOf({'local_id': '1', 'owner_status': null}), 'pending');
      expect(ownerStatusOf({'local_id': '1', 'owner_status': '  '}), 'pending');
      expect(
        ownerStatusOf({'local_id': '1', 'owner_status': 'validated'}),
        'validated',
      );
    });

    test('pin border colors follow the owner status', () {
      expect(ownerStatusBorderColor('pending'), Colors.yellow);
      expect(ownerStatusBorderColor('validated'), Colors.green);
      expect(ownerStatusBorderColor('acknowledged'), Colors.green);
      expect(ownerStatusBorderColor('ordered'), Colors.orange);
      expect(ownerStatusBorderColor('rejected'), Colors.red);
      expect(ownerStatusBorderColor('who-knows'), Colors.yellow);
    });

    test('every report type has its own emoji and word', () {
      expect(ownerTypeEmoji('work'), '🔨');
      expect(ownerTypeEmoji('problem'), '⚠️');
      expect(ownerTypeEmoji('material'), '📦');
      expect(ownerTypeLabel('problem'), 'Problem');
    });

    test('coordinates are only used when they are real', () {
      expect(ownerPointOf(reportRow(localId: '1')), const LatLng(36.8, 10.1));
      expect(ownerPointOf(reportRow(localId: '1', lat: 0, lng: 0)), isNull);
      expect(ownerPointOf({'local_id': '1'}), isNull);
    });

    test('MY ACTIONS keeps only the reports still waiting for the owner', () {
      final rows = [
        reportRow(localId: '1', ownerStatus: 'pending'),
        reportRow(localId: '2', ownerStatus: 'validated'),
        reportRow(localId: '3', ownerStatus: 'rejected'),
      ];
      final filtered = filterOwnerReports(rows, OwnerFilter.myActions);
      expect(filtered.map((row) => row['local_id']), ['1']);
    });

    test('TL VERIFIED keeps physical and remote validations only', () {
      final rows = [
        reportRow(localId: '1', tlValidationType: 'physical'),
        reportRow(localId: '2', tlValidationType: 'remote'),
        reportRow(localId: '3', tlValidationType: 'rejected'),
        reportRow(localId: '4'),
      ];
      final filtered = filterOwnerReports(rows, OwnerFilter.tlVerified);
      expect(filtered.map((row) => row['local_id']), ['1', '2']);
    });

    test('ALL keeps every report', () {
      final rows = [
        reportRow(localId: '1'),
        reportRow(localId: '2', ownerStatus: 'validated'),
      ];
      expect(filterOwnerReports(rows, OwnerFilter.all).length, 2);
    });

    test('pins are built per filtered report and keyed by local_id', () {
      final rows = [
        reportRow(localId: '1'),
        reportRow(localId: '2', ownerStatus: 'validated'),
        reportRow(localId: '3', lat: 0, lng: 0),
      ];
      final all = buildOwnerMarkers(rows, OwnerFilter.all);
      // The row without GPS is skipped; the rest keep their local_id keys.
      expect(all.length, 2);
      expect(all.map((marker) => marker.key), [
        const ValueKey<String>('owner_pin_1'),
        const ValueKey<String>('owner_pin_2'),
      ]);
      expect(buildOwnerMarkers(rows, OwnerFilter.myActions).length, 1);
    });

    test('the point index routes a marker back to the row it stands for', () {
      final rows = [
        reportRow(localId: '1', lat: 36.8, lng: 10.1),
        reportRow(localId: '2', lat: 36.82, lng: 10.1),
      ];
      final index = indexOwnerReportsByPoint(rows);
      final key = ownerPointKey(const LatLng(36.8, 10.1));
      expect(index[key]!.first['local_id'], '1');
      expect(ownerPointsOf(rows).length, 2);
    });

    test('a cluster is red only while one of its reports is pending', () {
      final mixed = [
        reportRow(localId: '1', ownerStatus: 'pending'),
        reportRow(localId: '2', ownerStatus: 'validated'),
      ];
      expect(
        ownerClusterHasPending(
          buildOwnerMarkers(mixed, OwnerFilter.all),
          indexOwnerReportsByPoint(mixed),
        ),
        isTrue,
      );

      final allValidated = [
        reportRow(localId: '1', ownerStatus: 'validated'),
        reportRow(localId: '2', ownerStatus: 'ordered'),
      ];
      expect(
        ownerClusterHasPending(
          buildOwnerMarkers(allValidated, OwnerFilter.all),
          indexOwnerReportsByPoint(allValidated),
        ),
        isFalse,
      );
    });
  });

  group('OwnerHomeScreen', () {
    /// Pumps the screen with an injected loader and a blank tile provider, then
    /// drains the plugin/database errors the test VM has no answer for.
    Future<void> pumpScreen(
      WidgetTester tester, {
      required OwnerReportsLoader loader,
      OwnerDecisionWriter? writer,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OwnerHomeScreen(
            reportsLoader: loader,
            decisionWriter: writer,
            tileProvider: _BlankTileProvider(),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        while (tester.takeException() != null) {
          // Intentionally swallowed: plugin absence in the test VM.
        }
      }
    }

    testWidgets('is titled Site Command and carries a giant refresh icon', (
      tester,
    ) async {
      await pumpScreen(tester, loader: () async => [reportRow(localId: '1')]);

      expect(find.text('Site Command'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.refresh)).size,
        ownerRefreshIconSize,
      );
    });

    testWidgets('shows the three filters and re-renders the pins on tap', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        loader: () async => [
          reportRow(localId: '1', lat: 36.80, lng: 10.10),
          reportRow(
            localId: '2',
            ownerStatus: 'validated',
            lat: 36.82,
            lng: 10.10,
          ),
        ],
      );

      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('🔥 MY ACTIONS'), findsOneWidget);
      expect(find.text('✅ TL VERIFIED'), findsOneWidget);
      // The cluster plugin mirrors a marker's key onto both its positioned
      // wrapper and the marker widget itself, hence `findsWidgets`.
      expect(find.byKey(const ValueKey<String>('owner_pin_1')), findsWidgets);
      expect(find.byKey(const ValueKey<String>('owner_pin_2')), findsWidgets);

      await tester.tap(find.text('🔥 MY ACTIONS'));
      await tester.pump(const Duration(milliseconds: 50));

      // Only the pending report survives the MY ACTIONS filter.
      expect(find.byKey(const ValueKey<String>('owner_pin_1')), findsWidgets);
      expect(find.byKey(const ValueKey<String>('owner_pin_2')), findsNothing);
    });

    testWidgets('tapping a pin opens the action sheet and re-fetches on save', (
      tester,
    ) async {
      var fetches = 0;
      final decisions = <(String, String)>[];
      await pumpScreen(
        tester,
        loader: () async {
          fetches++;
          return [reportRow(localId: '1')];
        },
        writer: (localId, ownerStatus) async {
          decisions.add((localId, ownerStatus));
        },
      );
      expect(fetches, 1);

      // The cluster layer ignores marker taps while its own 500 ms initial
      // zoom animation runs, so let it finish before tapping.
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey<String>('owner_pin_1')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // A bottom sheet, never a map popup.
      expect(find.text('VALIDATE'), findsOneWidget);
      expect(find.text('REJECT'), findsOneWidget);

      await tester.tap(find.text('VALIDATE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(decisions, [('1', 'validated')]);
      expect(find.text('VALIDATE'), findsNothing); // sheet closed
      expect(fetches, 2); // the map refreshed after the decision
      expect(find.text('Report #1 updated'), findsOneWidget);
    });

    testWidgets(
      'shows a retry card and an offline snackbar when the read fails',
      (tester) async {
        await pumpScreen(
          tester,
          loader: () async => throw Exception('no network'),
        );

        expect(find.text('Could not load the site reports.'), findsOneWidget);
        expect(find.text('RETRY'), findsOneWidget);
        expect(find.text('Offline — could not load reports'), findsOneWidget);
      },
    );

    testWidgets('shows the empty card when the cloud has no reports', (
      tester,
    ) async {
      await pumpScreen(tester, loader: () async => []);

      expect(
        find.text('No reports yet.\nTap the big refresh button.'),
        findsOneWidget,
      );
    });
  });
}
