import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/sync_service.dart';
import 'owner_action_sheet.dart';

// ---------------------------------------------------------------------------
// The Owner's site map: a thin client over Supabase.
//
// Nothing is written to Isar here. Reports are read straight from the `reports`
// table and every owner decision is written straight back to it (keyed by
// `local_id`, the same key the field devices pull through `SyncService`).
// Everything the screen shows is therefore a raw row plus the pure helpers
// below, which keeps the map testable without a database, a network or a
// device.
// ---------------------------------------------------------------------------

/// Loads every report row for the owner. Injected in tests; the default reads
/// the whole `reports` table with the Supabase client initialized in `main()`.
typedef OwnerReportsLoader = Future<List<Map<String, dynamic>>> Function();

/// The filters of the owner tools: three on the floating map panel, five on
/// the Executive List ('Audit & Reports'), which adds MATERIAL and REWORK
/// (the TL-rejected reports the owner audits for payment disputes).
enum OwnerFilter { all, myActions, tlVerified, problems, material, rework }

/// Labels of the filter buttons, in panel order (one glance, no jargon).
const Map<OwnerFilter, String> ownerFilterLabels = {
  OwnerFilter.all: 'ALL',
  OwnerFilter.myActions: '🔥 MY ACTIONS',
  OwnerFilter.tlVerified: '✅ TL VERIFIED',
  OwnerFilter.problems: '⚠️ PROBLEMS',
};

/// The filters the floating MAP panel offers (the reports list adds PROBLEMS).
const List<OwnerFilter> ownerMapFilters = [
  OwnerFilter.all,
  OwnerFilter.myActions,
  OwnerFilter.tlVerified,
];

/// Centre shown until the first batch of pins is known.
const LatLng ownerFallbackCenter = LatLng(36.8, 10.1);

/// Default zoom before the pins (if any) are framed.
const double ownerInitialZoom = 14;

/// Pin diameter and cluster bubble diameter (big enough for a thumb).
const double ownerPinSize = 48;
const double ownerClusterSize = 52;

/// The refresh icon is deliberately oversized: the owner must hit it first try.
const double ownerRefreshIconSize = 36;

/// Border color of a pin, from the row's `owner_status`:
/// Yellow=pending, Green=validated/acknowledged, Orange=ordered, Red=rejected.
Color ownerStatusBorderColor(String ownerStatus) => switch (ownerStatus) {
  'validated' || 'approved' || 'acknowledged' => Colors.green,
  'ordered' => Colors.orange,
  'rejected' => Colors.red,
  _ => Colors.yellow,
};

/// True while the row still waits for the owner (drives the red clusters).
bool ownerRowIsPending(Map<String, dynamic> row) =>
    ownerStatusOf(row) == ownerPendingStatus;

/// True when [row] belongs to the selected [filter]:
///  * MY ACTIONS  -> only reports still waiting for the owner;
///  * TL VERIFIED -> only reports the Team Leader verified (on site / remote);
///  * PROBLEMS    -> only problem-type reports (the reports list);
///  * MATERIAL    -> only material-type reports (payment preparation);
///  * REWORK      -> only the TL-rejected reports (the dispute queue).
bool ownerRowMatchesFilter(Map<String, dynamic> row, OwnerFilter filter) =>
    switch (filter) {
      OwnerFilter.all => true,
      OwnerFilter.myActions => ownerRowIsPending(row),
      OwnerFilter.tlVerified => const {
        'physical',
        'remote',
      }.contains((row['tl_validation_type'] ?? '').toString()),
      OwnerFilter.problems => (row['type'] ?? '').toString() == 'problem',
      OwnerFilter.material => (row['type'] ?? '').toString() == 'material',
      OwnerFilter.rework =>
        (row['tl_validation_type'] ?? '').toString() == 'rejected',
    };

/// The rows the map should show for [filter].
List<Map<String, dynamic>> filterOwnerReports(
  List<Map<String, dynamic>> rows,
  OwnerFilter filter,
) => rows.where((row) => ownerRowMatchesFilter(row, filter)).toList();

/// The row's coordinates, or null when they are missing or unusable (0,0).
LatLng? ownerPointOf(Map<String, dynamic> row) {
  final lat = (row['lat'] as num?)?.toDouble() ?? 0;
  final lng = (row['lng'] as num?)?.toDouble() ?? 0;
  if (lat == 0 && lng == 0) return null;
  return LatLng(lat, lng);
}

/// Stable key for a point, used to look a tapped [Marker] back up in the index.
String ownerPointKey(LatLng point) => '${point.latitude},${point.longitude}';

/// Every pin the map should draw (rows without usable GPS are skipped).
List<LatLng> ownerPointsOf(List<Map<String, dynamic>> rows) {
  final points = <LatLng>[];
  for (final row in rows) {
    final point = ownerPointOf(row);
    if (point != null) points.add(point);
  }
  return points;
}

/// Indexes rows by coordinate, so the cluster builder (color) and the marker
/// tap handler (which report was pressed) can both resolve a [Marker].
Map<String, List<Map<String, dynamic>>> indexOwnerReportsByPoint(
  List<Map<String, dynamic>> rows,
) {
  final index = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final point = ownerPointOf(row);
    if (point == null) continue;
    index
        .putIfAbsent(ownerPointKey(point), () => <Map<String, dynamic>>[])
        .add(row);
  }
  return index;
}

/// True when any report behind [markers] still waits for the owner, i.e. when a
/// cluster must be drawn RED instead of GREEN.
bool ownerClusterHasPending(
  List<Marker> markers,
  Map<String, List<Map<String, dynamic>>> byPoint,
) {
  for (final marker in markers) {
    final rows = byPoint[ownerPointKey(marker.point)];
    if (rows != null && rows.any(ownerRowIsPending)) return true;
  }
  return false;
}

/// One 48px pin: the report emoji inside a white circle whose 4px border is the
/// report's owner-status color.
Marker buildOwnerMarker(
  Map<String, dynamic> row,
  LatLng point, {
  required String key,
}) {
  return Marker(
    key: ValueKey<String>(key),
    point: point,
    width: ownerPinSize,
    height: ownerPinSize,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: ownerStatusBorderColor(ownerStatusOf(row)),
          width: 4,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        ownerTypeEmoji((row['type'] ?? 'work').toString()),
        style: const TextStyle(fontSize: 20),
      ),
    ),
  );
}

/// All pins for [filter]. Marker keys carry the row's `local_id` (with a
/// numeric suffix on the rare id+coordinate collision, so the map can never
/// throw on duplicate keys) — that is what widget tests address a pin by.
List<Marker> buildOwnerMarkers(
  List<Map<String, dynamic>> rows,
  OwnerFilter filter,
) {
  final markers = <Marker>[];
  final usedKeys = <String>{};
  for (final row in filterOwnerReports(rows, filter)) {
    final point = ownerPointOf(row);
    if (point == null) continue;
    final base = 'owner_pin_${ownerLocalIdOf(row)}';
    var key = base;
    var suffix = 1;
    while (!usedKeys.add(key)) {
      key = '$base#$suffix';
      suffix++;
    }
    markers.add(buildOwnerMarker(row, point, key: key));
  }
  return markers;
}

/// The Owner's home: "Site Command".
///
/// A full-screen map of every report in the cloud, cluster-colored by owner
/// status, with a floating glass filter panel at the bottom and a giant refresh
/// icon in the app bar. Tapping a pin opens the decision sheet; saving a
/// decision re-fetches so the map updates at once.
class OwnerMapScreen extends StatefulWidget {
  const OwnerMapScreen({
    super.key,
    this.reportsLoader,
    this.decisionWriter,
    this.tileProvider,
  });

  /// Injected report source (tests pass a canned list). Defaults to reading the
  /// `reports` table straight from Supabase.
  final OwnerReportsLoader? reportsLoader;

  /// Injected decision writer (tests pass a closure). Defaults to updating
  /// `reports.owner_status` by `local_id` on Supabase.
  final OwnerDecisionWriter? decisionWriter;

  /// Injected tile provider (tests pass a blank one so no HTTP request is made).
  final TileProvider? tileProvider;

  @override
  State<OwnerMapScreen> createState() => _OwnerMapScreenState();
}

class _OwnerMapScreenState extends State<OwnerMapScreen> {
  final MapController _mapController = MapController();

  /// Every remote row, newest first (the unfiltered source of truth).
  List<Map<String, dynamic>> _rows = [];

  /// Rows indexed by coordinate; refreshed together with [_rows].
  Map<String, List<Map<String, dynamic>>> _byPoint = const {};

  OwnerFilter _filter = OwnerFilter.all;

  /// True while a fetch is in flight.
  bool _loading = false;

  /// Set when the last fetch failed; drives the big retry card.
  String? _error;

  /// Offline-capable CartoDB tile cache (same scheme as the field-staff map).
  CacheStore? _cacheStore;

  /// The map is framed once, on the first data that arrives.
  bool _mapReady = false;
  bool _framedOnce = false;

  @override
  void initState() {
    super.initState();
    _prepareCacheStore();
    fetchReports();
  }

  /// Points the tile layer at a temporary file cache, so the site map keeps
  /// working when the network drops. Best effort: without a cache directory the
  /// layer simply uses plain network tiles.
  Future<void> _prepareCacheStore() async {
    try {
      final dir = await getTemporaryDirectory();
      final store = FileCacheStore(
        '${dir.path}${Platform.pathSeparator}MapTiles',
      );
      if (!mounted) return;
      setState(() => _cacheStore = store);
    } catch (e) {
      debugPrint('OwnerCommand: tile cache store failed: $e');
    }
  }

  /// Reads every report row straight from Supabase (no Isar) and rebuilds the
  /// pins. Called on open, by the giant refresh icon, and after every saved
  /// decision so the map always mirrors the cloud.
  Future<void> fetchReports() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await (widget.reportsLoader ?? _fetchReportsFromSupabase)();
      if (!mounted) return;
      setState(() {
        _rows = _sortNewestFirst(rows);
        _byPoint = indexOwnerReportsByPoint(_rows);
        _loading = false;
      });
      _frameAllPins();
    } catch (e, st) {
      debugPrint('OwnerCommand: fetch failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the site reports.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline — could not load reports')),
      );
    }
  }

  /// The one place this screen reads from the cloud.
  static Future<List<Map<String, dynamic>>> _fetchReportsFromSupabase() async {
    final rows = await Supabase.instance.client.from('reports').select();
    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// Newest first, so a marker overlapping another is always the freshest one.
  /// Rows with an unparsable timestamp keep their order at the end.
  static List<Map<String, dynamic>> _sortNewestFirst(
    List<Map<String, dynamic>> rows,
  ) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final at = ownerTimestampOf(a);
      final bt = ownerTimestampOf(b);
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return sorted;
  }

  /// The rows currently shown on the map (filter applied).
  List<Map<String, dynamic>> get _visibleRows =>
      filterOwnerReports(_rows, _filter);

  /// The pins currently shown on the map (filter applied).
  List<Marker> get _markers => buildOwnerMarkers(_rows, _filter);

  /// Frames every pin the first time data arrives, so the owner sees the whole
  /// site without touching the map. Best effort: a map that is not laid out yet
  /// (or a single pin) simply keeps the default view.
  void _frameAllPins() {
    if (_framedOnce || !_mapReady) return;
    final points = ownerPointsOf(_visibleRows);
    if (points.length < 2) {
      _framedOnce = true;
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(64),
          maxZoom: 17,
        ),
      );
      _framedOnce = true;
    } catch (e) {
      debugPrint('OwnerCommand: framing the pins failed: $e');
    }
  }

  /// Routes a pin tap through the coordinate index: the cluster plugin hands
  /// back a [Marker], and the index maps it to the row it stands for.
  void _onMarkerTap(Marker marker) {
    final rows = _byPoint[ownerPointKey(marker.point)];
    if (rows == null || rows.isEmpty) return;
    unawaited(_openReport(rows.first));
  }

  /// Opens the decision sheet; when a decision was saved the reports are
  /// re-fetched so the pin and cluster colors change immediately.
  Future<void> _openReport(Map<String, dynamic> row) async {
    final saved = await showOwnerActionSheet(
      context,
      row: row,
      writeDecision: widget.decisionWriter ?? _writeDecisionToSupabase,
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report #${ownerLocalIdOf(row)} updated')),
    );
    await fetchReports();
  }

  /// Thin-client write: the decision goes straight to the cloud row keyed by
  /// `local_id` — the same key `SyncService.checkOwnerUpdates` uses to pull the
  /// owner's status back into the field devices.
  ///
  /// Throws [OwnerOfflineException] when there is no connectivity (so the sheet
  /// can show its offline message) and a [StateError] when no remote row
  /// matched, i.e. nothing was actually updated.
  static Future<void> _writeDecisionToSupabase(
    String localId,
    String ownerStatus,
  ) async {
    if (!await SyncService.isOnline()) {
      throw const OwnerOfflineException();
    }
    final updated = await Supabase.instance.client
        .from('reports')
        .update({'owner_status': ownerStatus})
        .eq('local_id', localId)
        .select('id');
    if (updated.isEmpty) {
      throw StateError('No remote report with local_id=$localId');
    }
    debugPrint('OwnerCommand: report $localId -> owner_status=$ownerStatus');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Command'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: ownerRefreshIconSize),
            tooltip: 'Refresh',
            onPressed: _loading ? null : fetchReports,
          ),
        ],
        // A thin progress bar under the app bar while a fetch is in flight.
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (_error != null) _errorCard(),
          if (_error == null && !_loading && _rows.isEmpty) _emptyCard(),
          _filterPanel(),
        ],
      ),
    );
  }

  /// Full-screen map: CartoDB Voyager tiles (cached) plus clustered,
  /// owner-colored pins. No PopupLayer is registered anywhere, so tapping a pin
  /// can only reach our bottom sheet.
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: ownerFallbackCenter,
        initialZoom: ownerInitialZoom,
        onMapReady: () {
          _mapReady = true;
          _frameAllPins();
        },
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
            maxClusterRadius: 45,
            size: const Size(ownerClusterSize, ownerClusterSize),
            zoomToBoundsOnClick: true,
            spiderfyCluster: false,
            markers: _markers,
            onMarkerTap: _onMarkerTap,
            builder: (context, markers) => _clusterBubble(markers),
          ),
        ),
      ],
    );
  }

  /// One cluster: a count circle that turns RED as soon as it hides a report
  /// still waiting for the owner, and stays GREEN when everything inside is
  /// validated.
  Widget _clusterBubble(List<Marker> markers) {
    final hasPending = ownerClusterHasPending(markers, _byPoint);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasPending ? Colors.red : Colors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        '${markers.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// Floating glass filter panel: translucent white over a blur, one giant tap
  /// target per filter. Picking a filter re-renders the markers on the map.
  Widget _filterPanel() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(24),
                constraints: const BoxConstraints(minHeight: 52, minWidth: 0),
                isSelected: [
                  for (final filter in ownerMapFilters) filter == _filter,
                ],
                onPressed: (index) =>
                    setState(() => _filter = ownerMapFilters[index]),
                children: [
                  for (final filter in ownerMapFilters)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        ownerFilterLabels[filter] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Big, unmissable retry card (offline, or the server refused the read).
  Widget _errorCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: _loading ? null : fetchReports,
                icon: const Icon(Icons.refresh, size: 30),
                label: const Text(
                  'RETRY',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quiet placeholder when the cloud has nothing to show yet.
  Widget _emptyCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No reports yet.\nTap the big refresh button.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
