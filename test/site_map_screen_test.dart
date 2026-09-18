import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/screens/site_map_screen.dart';

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

Report report(
  int id, {
  String type = 'work',
  double lat = 36.8,
  double lng = 10.1,
  DateTime? tlValidatedAt,
  String tlValidationType = '',
}) {
  return Report()
    ..id = id
    ..type = type
    ..lat = lat
    ..lng = lng
    ..timestamp = DateTime(2026, 9, 17, 9, 30)
    ..tlValidatedAt = tlValidatedAt
    ..tlValidationType = tlValidationType;
}

void main() {
  group('site map helpers', () {
    test('siteMapPointOf drops reports without captured coordinates', () {
      expect(siteMapPointOf(report(1)), isNotNull);
      expect(siteMapPointOf(report(1)..lat = 0..lng = 0), isNull);
    });

    test('pin color follows the shared report stage colors', () {
      // Pending TL -> orange (Pending TL Validation); rejected -> red; a TL
      // approval moves the report to the owner layer -> blue (Pending Owner
      // Approval). The colors come from the sheet's reportStageStyle, so the
      // map and the sheet can never disagree.
      final pending = report(1);
      final rejected = report(2)
        ..tlValidatedAt = DateTime(2026, 9, 17, 10)
        ..tlValidationType = 'rejected';
      final validated = report(3)
        ..tlValidatedAt = DateTime(2026, 9, 17, 10)
        ..tlValidationType = 'physical';

      expect(siteMapPinColor(pending), isNot(siteMapPinColor(rejected)));
      expect(siteMapPinColor(validated), isNot(siteMapPinColor(rejected)));
      expect(siteMapPinColor(pending), Colors.orange);
      expect(siteMapPinColor(rejected), Colors.red);
      expect(siteMapPinColor(validated), Colors.blue);

      // Once the owner closes the report the pin takes the owner's colour.
      final ordered = report(4)
        ..tlValidatedAt = DateTime(2026, 9, 17, 10)
        ..tlValidationType = 'physical'
        ..ownerStatus = 'ordered';
      expect(siteMapPinColor(ordered), Colors.orange);
    });

    test('index groups reports that share the exact same coordinates', () {
      final reports = [
        report(1, lat: 36.8, lng: 10.1),
        report(2, lat: 36.8, lng: 10.1),
        report(3, lat: 36.82, lng: 10.1),
        report(4, lat: 0, lng: 0), // never indexed
      ];
      final index = indexReportsByPoint(reports);
      expect(index, hasLength(2));
      expect(
        index[siteMapPointKey(const LatLng(36.8, 10.1))],
        hasLength(2),
      );
      expect(
        index[siteMapPointKey(const LatLng(36.82, 10.1))]!.single.id,
        3,
      );
    });

    test('a cluster needs attention while any report inside waits for the TL', () {
      final pending = report(1);
      final validated = report(2)
        ..tlValidatedAt = DateTime(2026, 9, 17, 10)
        ..tlValidationType = 'physical';
      final reports = [pending, validated];
      final byPoint = indexReportsByPoint(reports);
      final markers = [
        for (final r in reports)
          Marker(
            key: siteMapPinKey(r),
            point: siteMapPointOf(r)!,
            width: 40,
            height: 40,
            child: const SizedBox(),
          ),
      ];
      expect(siteMapClusterNeedsAttention(markers, byPoint), isTrue);

      final allValidated = [validated, validated];
      expect(
        siteMapClusterNeedsAttention(
          [
            for (final r in allValidated)
              Marker(
                key: siteMapPinKey(r),
                point: siteMapPointOf(r)!,
                width: 40,
                height: 40,
                child: const SizedBox(),
              ),
          ],
          indexReportsByPoint(allValidated),
        ),
        isFalse,
      );
    });
  });

  group('SiteMapScreen', () {
    // The plugin needs a deterministic pump: pump a few frames and swallow
    // the plugin/database exceptions the test VM has no answer for.
    Future<void> pumpScreen(
      WidgetTester tester, {
      required StreamController<List<Report>> controller,
    }) async {
      // The caller's data was buffered into the single-subscription
      // controller before the pump; it is delivered on listen (initState).
      await tester.pumpWidget(
        MaterialApp(
          home: SiteMapScreen(
            reportsStream: () => controller.stream,
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

    testWidgets('shows its pins and the pending filter', (tester) async {
      final controller = StreamController<List<Report>>();
      addTearDown(controller.close);
      await pumpScreen(
        tester,
        controller: controller..add([
          report(1),
          report(2, lat: 36.82),
          report(3, lat: 0, lng: 0), // no GPS: no pin
        ]),
      );

      expect(find.text('Site Map'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('site_pin_1')), findsWidgets);
      expect(find.byKey(const ValueKey<String>('site_pin_2')), findsWidgets);
      expect(find.byKey(const ValueKey<String>('site_pin_3')), findsNothing);
      expect(find.text('⚠️ TO VERIFY'), findsOneWidget);
    });

    testWidgets('re-renders only pending pins when the filter is on', (
      tester,
    ) async {
      final controller = StreamController<List<Report>>();
      addTearDown(controller.close);
      final validated = report(2)
        ..tlValidatedAt = DateTime(2026, 9, 17, 10)
        ..tlValidationType = 'physical';
      await pumpScreen(
        tester,
        controller: controller..add([report(1), validated]),
      );

      await tester.tap(find.text('⚠️ TO VERIFY'));
      await tester.pump(const Duration(milliseconds: 50));
      while (tester.takeException() != null) {}

      expect(find.byKey(const ValueKey<String>('site_pin_1')), findsWidgets);
      expect(find.byKey(const ValueKey<String>('site_pin_2')), findsNothing);
    });

    testWidgets('tapping a pin opens the shared report detail sheet', (
      tester,
    ) async {
      final controller = StreamController<List<Report>>();
      addTearDown(controller.close);
      await pumpScreen(
        tester,
        controller: controller..add([report(1)]),
      );

      // Let the cluster plugin's initial camera animation finish: it swallows
      // marker taps for ~500 ms after the first frame.
      await tester.pump(const Duration(milliseconds: 600));
      while (tester.takeException() != null) {}

      await tester.tap(find.byKey(const ValueKey<String>('site_pin_1')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      while (tester.takeException() != null) {}

      // The sheet is the Step 1 sheet: the photo header + status + composer.
      expect(find.text('Pending TL Validation'), findsOneWidget);
    });
  });
}