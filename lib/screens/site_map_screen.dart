import 'dart:async';
import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report.dart';
import '../role.dart';
import '../services/database_service.dart';
import '../widgets/cluster_list_sheet.dart';
import '../widgets/report_detail_bottom_sheet.dart';
import '../widgets/report_sheet_actions.dart';
import '../widgets/report_thumbnail.dart';
import '../widgets/traffic_card.dart';
import '../widgets/tl_validation_badge.dart';

/// Full-screen offline-capable site map with clustering and TL verification
/// filter.
///
/// The report stream and the tile provider can be injected (tests hand in a
/// canned stream and a blank-pixel tile provider); everything defaults to the
/// real Isar stream and the cached network tiles.
typedef SiteReportsStream = Stream<List<Report>> Function();

class SiteMapScreen extends StatefulWidget {
  const SiteMapScreen({
    super.key,
    this.reportsStream,
    this.tileProvider,
    this.focusReport,
    this.initialOnlyPending,
  });

  /// Live Isar view of every report. Injectable for tests.
  final SiteReportsStream? reportsStream;

  /// Tile provider override (tests use a blank-pixel provider).
  final TileProvider? tileProvider;

  /// When given, the map opens centered on this report's pin (zoom 16)
  /// instead of framing every pin. Used by the report sheet's map button.
  final Report? focusReport;

  /// Initial state of the ⚠️ TO VERIFY filter. Null follows the signed-in
  /// role: the Team Leader opens the map straight onto what needs HIS
  /// attention; everyone else starts with ALL. Injectable for tests.
  final bool? initialOnlyPending;

  @override
  State<SiteMapScreen> createState() => _SiteMapScreenState();
}

// ---------------------------------------------------------------------------
// Pure helpers: the color/cluster logic lives here so it can be unit-tested
// without pumping a map, and so the Owner's map (Step 4) can reuse the rules.
// ---------------------------------------------------------------------------

/// The report's coordinates, or null when they were never captured (0,0).
LatLng? siteMapPointOf(Report report) {
  if (report.lat == 0 && report.lng == 0) return null;
  return LatLng(report.lat, report.lng);
}

/// The pin color of a report: the stage color everyone already knows from the
/// report sheet (amber = pending TL, red = rejected, green = validated, blue =
/// closed by the owner). One source of truth — the map can never disagree with
/// the sheet.
Color siteMapPinColor(Report report) => reportStageStyle(
  reportStageOf(report),
  ownerStatus: report.ownerStatus,
).$2;

/// The type icon shown inside a pin.
IconData siteMapPinIcon(Report report) => switch (report.type) {
  'problem' => Icons.warning_amber_rounded,
  'material' => Icons.inventory_2,
  _ => Icons.handyman,
};

/// Stable key for a point, used to look a tapped [Marker] back up in the index
/// and to group reports that share the exact same coordinates.
String siteMapPointKey(LatLng point) => '${point.latitude},${point.longitude}';

/// Indexes reports by coordinate, so the cluster builder (color) and the
/// marker tap handler (which report was pressed) can both resolve a point.
Map<String, List<Report>> indexReportsByPoint(List<Report> reports) {
  final index = <String, List<Report>>{};
  for (final report in reports) {
    final point = siteMapPointOf(report);
    if (point == null) continue;
    index
        .putIfAbsent(siteMapPointKey(point), () => <Report>[])
        .add(report);
  }
  return index;
}

/// True when any report behind these markers still waits for the Team Leader,
/// i.e. when the cluster must be drawn YELLOW (attention) instead of GREEN.
bool siteMapClusterNeedsAttention(
  List<Marker> markers,
  Map<String, List<Report>> byPoint,
) {
  for (final marker in markers) {
    final reports = byPoint[siteMapPointKey(marker.point)];
    if (reports != null && reports.any((r) => r.needsTlValidation)) {
      return true;
    }
  }
  return false;
}

/// The build key of a report pin (tests and the sheet both address pins by it).
Key siteMapPinKey(Report report) => ValueKey<String>('site_pin_${report.id}');

/// The cluster bubble colour: YELLOW while any report inside still waits for
/// the Team Leader's verification, GREEN once everything inside is verified.
Color siteMapClusterColor(bool needsAttention) =>
    needsAttention ? Colors.yellow : Colors.green;

/// The cluster count text colour: dark on yellow for contrast, white on green.
Color siteMapClusterTextColor(bool needsAttention) =>
    needsAttention ? Colors.black87 : Colors.white;

/// The reports behind a tapped cluster's child markers: deduplicated by
/// marker key and sorted newest first, ready for the Cluster List popup.
List<Report> siteMapClusterReports(
  List<Marker> markers,
  Map<Key, Report> reportByKey,
) {
  final seen = <Key>{};
  final reports = <Report>[];
  for (final marker in markers) {
    final key = marker.key;
    if (key == null || !seen.add(key)) continue;
    final report = reportByKey[key];
    if (report != null) reports.add(report);
  }
  reports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return reports;
}

class _SiteMapScreenState extends State<SiteMapScreen> {
  static const double _pinSize = 40;

  final MapController _mapController = MapController();

  /// Set on the first map-ready frame so the camera frames every pin exactly
  /// once instead of fighting the user's later gestures.
  bool _framedOnce = false;

  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<Report>>? _reportsSub;
  List<Report> _reports = [];
  CacheStore? _cacheStore;
  late bool showOnlyPending;

  @override
  void initState() {
    super.initState();
    // The Team Leader opens the map straight onto what needs his immediate
    // attention (⚠️ TO VERIFY); everyone else starts with ALL.
    showOnlyPending =
        widget.initialOnlyPending ?? (userRole == 'team_leader');
    _prepareCacheStore();
    _watchReports();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _reportsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Live view: a report validated on another device re-colors its pin the
  /// moment the merge lands, without any manual refresh.
  void _watchReports() {
    final stream = widget.reportsStream;
    _reportsSub = (stream != null ? stream() : DatabaseService.watchAllReports())
        .listen((reports) {
          if (!mounted) return;
          setState(() => _reports = reports);
        });
  }

  Future<void> _prepareCacheStore() async {
    try {
      final dir = await getTemporaryDirectory();
      final store = FileCacheStore(
        '${dir.path}${Platform.pathSeparator}MapTiles',
      );
      if (!mounted) return;
      setState(() => _cacheStore = store);
    } catch (e) {
      debugPrint('MapFlow: cache store failed: $e');
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((pos) {
            if (!mounted) return;
            setState(
              () => _currentPosition = LatLng(pos.latitude, pos.longitude),
            );
          });
    } catch (e) {
      debugPrint('MapFlow: location failed: $e');
    }
  }

  List<Report> get _filteredReports {
    if (!showOnlyPending) return _reports;
    return _reports.where((r) => r.needsTlValidation).toList();
  }

  /// Locate Me: centers the camera on the user. Reuses the already-tracked
  /// GPS position when available, otherwise fetches it once. Errors (no
  /// service, denied permission, timeout) are swallowed — the map simply
  /// stays where it is.
  Future<void> _locateMe() async {
    var target = _currentPosition;
    if (target == null) {
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        target = LatLng(pos.latitude, pos.longitude);
        if (!mounted) return;
        setState(() => _currentPosition = target);
      } catch (e) {
        debugPrint('MapFlow: locate me failed: $e');
        return;
      }
    }
    if (!mounted) return;
    _mapController.move(target, 17);
  }

  @override
  Widget build(BuildContext context) {
    final visibleReports = _filteredReports;
    final byPoint = indexReportsByPoint(visibleReports);
    final clusteredReports = visibleReports
        .where((r) => siteMapPointOf(r) != null)
        .toList();
    final reportByKey = {
      for (final report in clusteredReports) siteMapPinKey(report): report,
    };
    final reportMarkers = <Marker>[
      for (final report in clusteredReports)
        Marker(
          key: siteMapPinKey(report),
          point: siteMapPointOf(report)!,
          width: _pinSize,
          height: _pinSize,
          child: _buildReportPin(report),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Site Map')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(36.8, 10.1),
              initialZoom: 14,
              onMapReady: _frameAllPinsOnce,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.hydra.app',
                tileProvider:
                    widget.tileProvider ??
                    (_cacheStore == null
                        ? NetworkTileProvider()
                        : CachedTileProvider(
                            store: _cacheStore!,
                            maxStale: const Duration(days: 30),
                          )),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 50,
                  size: const Size(46, 46),
                  // A cluster tap does NOT zoom (several reports can share the
                  // exact same coordinates, so zooming would never separate
                  // them). The tap is handled manually: the Cluster List popup
                  // lists every report behind the bubble, newest first.
                  zoomToBoundsOnClick: false,
                  spiderfyCluster: false,
                  onClusterTap: (cluster) =>
                      _openClusterList(cluster.mapMarkers, reportByKey),
                  // Taps are handled by the cluster layer itself: a child
                  // GestureDetector never fires when the marker is drawn
                  // inside a cluster, so this is the only reliable hook.
                  // The tapped Marker is identified by its build key.
                  onMarkerTap: (marker) {
                    final report = reportByKey[marker.key];
                    if (report == null) return;
                    showDefaultReportDetailSheet(context, report);
                  },
                  builder: (context, markers) {
                    final urgent = siteMapClusterNeedsAttention(markers, byPoint);
                    return Container(
                      decoration: BoxDecoration(
                        color: siteMapClusterColor(urgent),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: TextStyle(
                            color: siteMapClusterTextColor(urgent),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                  markers: reportMarkers,
                ),
              ),
              // The GPS dot lives OUTSIDE the cluster layer: the user's own
              // position must never be counted or zoomed-to as a report.
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Locate Me: one thumb-sized button, bottom right, above the
          // ALL / ⚠️ TO VERIFY pill (which sits bottom center) — no overlap.
          Positioned(
            right: 16,
            bottom: 80,
            child: FloatingActionButton(
              heroTag: 'site_map_locate_me',
              tooltip: 'Locate me',
              backgroundColor: Colors.blue,
              onPressed: _locateMe,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ToggleButtons(
                  borderRadius: BorderRadius.circular(30),
                  isSelected: [!showOnlyPending, showOnlyPending],
                  onPressed: (index) {
                    setState(() {
                      showOnlyPending = index == 1;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text('ALL'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text('⚠️ TO VERIFY'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Frames every pin once on the first map-ready frame, so the user always
  /// starts looking at their reports instead of a zoomed-in street. When the
  /// screen was opened with a [SiteMapScreen.focusReport], the map is instead
  /// centered on that report's pin (zoom 16) — the sheet's map button lands
  /// right on the report it came from.
  void _frameAllPinsOnce() {
    if (_framedOnce) return;
    _framedOnce = true;
    final focus = widget.focusReport;
    if (focus != null) {
      final point = siteMapPointOf(focus);
      if (point != null) {
        _mapController.move(point, 16);
        return;
      }
    }
    final points = [
      for (final report in _filteredReports) ?siteMapPointOf(report),
    ];
    if (points.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  /// Cluster tap: never zoom — several reports can share the exact same
  /// coordinates, so zooming would never separate them. Collect the reports
  /// behind the bubble (newest first) and show the Cluster List popup; a
  /// lonely report (defensive: clusters hold >= 2 pins) opens directly.
  Future<void> _openClusterList(
    List<Marker> markers,
    Map<Key, Report> reportByKey,
  ) async {
    final reports = siteMapClusterReports(markers, reportByKey);
    if (reports.isEmpty) return;
    if (reports.length == 1) {
      await showDefaultReportDetailSheet(context, reports.single);
      return;
    }
    await showClusterListSheet<Report>(
      context,
      title: '${reports.length} reports at this location',
      items: reports,
      tileBuilder: (context, report) => _clusterTile(context, report),
      onItemTap: (report) async {
        await showDefaultReportDetailSheet(context, report);
      },
    );
  }

  /// One Cluster List row: the 50x50 photo, the type icon, the timestamp and
  /// the TL/Owner badges. Tapping closes the popup and opens the full report.
  Widget _clusterTile(BuildContext context, Report report) {
    final (ownerColor, ownerLabel, _) = trafficOwnerNode(report);
    return ListTile(
      onTap: () => openClusterListItem(context, () async {
        await showDefaultReportDetailSheet(context, report);
      }),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 50,
          height: 50,
          child: ReportThumbnail(report: report, size: 50),
        ),
      ),
      title: Row(
        children: [
          Icon(
            trafficTypeIcon(report.type),
            size: 16,
            color: trafficTypeColor(report.type),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              trackerTimeLabel(report.timestamp),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TlValidationBadge(report: report, iconSize: 12, fontSize: 10),
          _miniStatusChip(ownerLabel, ownerColor),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  /// The tiny owner-status pill shown next to the TL badge on cluster tiles.
  Widget _miniStatusChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    ),
  );

  Widget _buildReportPin(Report report) {
    final color = siteMapPinColor(report);
    final icon = siteMapPinIcon(report);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
