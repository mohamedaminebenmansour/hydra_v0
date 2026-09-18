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
import '../services/database_service.dart';
import 'report_detail_screen.dart';

/// Full-screen offline-capable site map with clustering and TL verification
/// filter.
class SiteMapScreen extends StatefulWidget {
  const SiteMapScreen({super.key});

  @override
  State<SiteMapScreen> createState() => _SiteMapScreenState();
}

class _SiteMapScreenState extends State<SiteMapScreen> {
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  List<Report> _reports = [];
  CacheStore? _cacheStore;
  bool showOnlyPending = false;

  @override
  void initState() {
    super.initState();
    _prepareCacheStore();
    _loadReports();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _prepareCacheStore() async {
    try {
      final dir = await getTemporaryDirectory();
      final store = FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
      if (!mounted) return;
      setState(() => _cacheStore = store);
    } catch (e) {
      debugPrint('MapFlow: cache store failed: $e');
    }
  }

  Future<void> _loadReports() async {
    final reports = await DatabaseService.getAllReports();
    if (!mounted) return;
    setState(() => _reports = reports);
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
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
      });
    } catch (e) {
      debugPrint('MapFlow: location failed: $e');
    }
  }

  List<Report> get _filteredReports {
    if (!showOnlyPending) return _reports;
    return _reports.where((r) => r.needsTlValidation).toList();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      if (_currentPosition != null)
        Marker(
          point: _currentPosition!,
          width: 20,
          height: 20,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      for (final report in _filteredReports)
        if (report.lat != 0 || report.lng != 0)
          Marker(
            point: LatLng(report.lat, report.lng),
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReportDetailScreen(report: report),
                  ),
                );
              },
              child: _buildReportPin(report),
            ),
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Site Map')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter:
                  _currentPosition ?? const LatLng(36.8, 10.1),
              initialZoom: 14,
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
                tileProvider: _cacheStore == null
                    ? NetworkTileProvider()
                    : CachedTileProvider(
                        store: _cacheStore!,
                        maxStale: const Duration(days: 30),
                      ),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  builder: (context, markers) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                  markers: markers,
                ),
              ),
            ],
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
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('ALL'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildReportPin(Report report) {
    final color = showOnlyPending
        ? Colors.red
        : switch (report.ownerStatus) {
            'validated' => Colors.green,
            'rejected' => Colors.red,
            _ => Colors.amber,
          };
    final icon = switch (report.type) {
      'problem' => Icons.warning_amber_rounded,
      'material' => Icons.inventory_2,
      _ => Icons.handyman,
    };
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
