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

    test('siteMapClusterReports dedupes by pin key and sorts newest first', () {
      final a = report(1)..timestamp = DateTime(2026, 9, 17, 9);
      final b = report(2)..timestamp = DateTime(2026, 9, 17, 10);
      final c = report(3)..timestamp = DateTime(2026, 9, 17, 11);
      final reportByKey = {
        siteMapPinKey(a): a,
        siteMapPinKey(b): b,
        siteMapPinKey(c): c,
      };
      Marker pin(Report r) => Marker(
        key: siteMapPinKey(r),
        point: const LatLng(36.8, 10.1),
        width: 40,
        height: 40,
        child: const SizedBox(),
      );
      // b appears twice (a repeated child) and must be listed once; the
      // result is newest first regardless of the marker order.
      final reports = siteMapClusterReports(
        [pin(b), pin(c), pin(a), pin(b)],
        reportByKey,
      );
      expect(reports.map((r) => r.id), [3, 2, 1]);
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

    test('a cluster is YELLOW while it hides TL work, GREEN once verified', () {
      // The Team Leader only reads one colour: yellow = "you have something to
      // do here", green = "nothing left for you here".
      expect(siteMapClusterColor(true), Colors.yellow);
      expect(siteMapClusterColor(false), Colors.green);
      // The count stays readable on both backgrounds.
      expect(siteMapClusterTextColor(true), Colors.black87);
      expect(siteMapClusterTextColor(false), Colors.white);
    });
  });

  group('SiteMapScreen', () {
    // The plugin needs a deterministic pump: pump a few frames and swallow
    // the plugin/database exceptions the test VM has no answer for.
    Future<void> pumpScreen(
      WidgetTester tester, {
      required StreamController<List<Report>> controller,
      bool? initialOnlyPending,
    }) async {
      // The caller's data was buffered into the single-subscription
      // controller before the pump; it is delivered on listen (initState).
      await tester.pumpWidget(
        MaterialApp(
          home: SiteMapScreen(
            reportsStream: () => controller.stream,
            tileProvider: _BlankTileProvider(),
            initialOnlyPending: initialOnlyPending,
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

    testWidgets('tapping a cluster opens the Cluster List popup, newest first', (
      tester,
    ) async {
      final controller = StreamController<List<Report>>();
      addTearDown(controller.close);
      // Three reports at the exact same coordinates: they must collapse into
      // one cluster whose tap NEVER zooms, but lists them instead.
      await pumpScreen(
        tester,
        controller: controller..add([
          report(1)..timestamp = DateTime(2026, 9, 17, 9),
          report(2)..timestamp = DateTime(2026, 9, 17, 10),
          report(3)..timestamp = DateTime(2026, 9, 17, 11),
        ]),
      );
      // Let the cluster plugin's initial camera animation finish.
      await tester.pump(const Duration(milliseconds: 600));
      while (tester.takeException() != null) {}

      // The cluster bubble shows the count — tap it.
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      while (tester.takeException() != null) {}

      // The Cluster List popup: 50% height, one tile per report.
      expect(find.text('3 reports at this location'), findsOneWidget);
      expect(find.text('17 Sep, 11:00'), findsOneWidget);
      expect(find.text('17 Sep, 10:00'), findsOneWidget);
      expect(find.text('17 Sep, 09:00'), findsOneWidget);
      // Newest first: 11:00 above 10:00 above 09:00.
      final newestY = tester.getTopLeft(find.text('17 Sep, 11:00')).dy;
      final middleY = tester.getTopLeft(find.text('17 Sep, 10:00')).dy;
      final oldestY = tester.getTopLeft(find.text('17 Sep, 09:00')).dy;
      expect(newestY, lessThan(middleY));
      expect(middleY, lessThan(oldestY));

      // Tapping a tile closes the popup and opens the full report chat.
      await tester.tap(find.text('17 Sep, 11:00'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      while (tester.takeException() != null) {}

      expect(find.text('3 reports at this location'), findsNothing);
      expect(find.text('Pending TL Validation'), findsOneWidget);
    });

    testWidgets('the Team Leader map opens straight on ⚠️ TO VERIFY', (
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
        initialOnlyPending: true,
      );
      // Let the framer run against the filtered pin set.
      await tester.pump(const Duration(milliseconds: 200));
      while (tester.takeException() != null) {}

      // The pending pin is there, the verified one is filtered out — the TL
      // never has to hunt for his work when the map opens.
      expect(find.byKey(const ValueKey<String>('site_pin_1')), findsWidgets);
      expect(find.byKey(const ValueKey<String>('site_pin_2')), findsNothing);
    });

    testWidgets('shows the blue Locate Me button clear of the filter pill', (
      tester,
    ) async {
      final controller = StreamController<List<Report>>();
      addTearDown(controller.close);
      await pumpScreen(tester, controller: controller..add([report(1)]));

      final locate = find.byIcon(Icons.my_location);
      expect(locate, findsOneWidget);

      final fab = tester.widget<FloatingActionButton>(
        find.ancestor(of: locate, matching: find.byType(FloatingActionButton)),
      );
      expect(fab.backgroundColor, Colors.blue);

      // Bottom right, stacked fully ABOVE the bottom-center filter pill: the
      // two can never overlap, whatever the screen height is.
      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      final pillRect = tester.getRect(find.byType(ToggleButtons));
      expect(fabRect.right, greaterThan(pillRect.right));
      expect(fabRect.bottom, lessThanOrEqualTo(pillRect.top));
    });

  });
}