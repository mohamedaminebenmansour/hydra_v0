import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../services/report_local_service.dart';
import '../services/sync_service.dart';
import '../widgets/action_button.dart';
import 'history_screen.dart';
import 'save_report_screen.dart';

/// SharedPreferences key holding the last time the History screen was opened.
/// Owner updates newer than this drive the red badge on the History FAB.
const String _historyLastOpenedKey = 'historyLastOpenedAtMs';

/// The main screen: three giant, tag-free action buttons and a history FAB.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  /// True while a cloud sync is in flight (spinner shown in the app bar).
  bool _syncing = false;

  /// Fresh owner updates (changed after last History open, within 24h).
  /// Drives the red badge on the History FAB.
  int _freshOwnerUpdates = 0;

  @override
  void initState() {
    super.initState();
    checkOwnerUpdates();
  }

  /// Smart Pull-on-Open: pull the owner's decisions from Supabase (when
  /// online) and refresh the red badge count with setState.
  Future<void> checkOwnerUpdates() async {
    await SyncService.checkOwnerUpdates();
    await _refreshOwnerBadge();
  }

  /// Recomputes the fresh-owner-update count (changed after the last History
  /// open, within the last 24 hours) and rebuilds the FAB badge.
  Future<void> _refreshOwnerBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpenedMs = prefs.getInt(_historyLastOpenedKey) ?? 0;
    final count = await DatabaseService.countFreshOwnerUpdates(
      DateTime.fromMillisecondsSinceEpoch(lastOpenedMs),
    );
    if (!mounted) return;
    setState(() => _freshOwnerUpdates = count);
  }

  /// Triggers a Supabase sync of all pending reports.
  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final synced = await SyncService.syncPendingReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $synced report(s)')),
      );
    } catch (e, st) {
      debugPrint('SyncFlow: sync failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync failed — check connection')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Catch any button tap: immediately open the camera, compress the capture,
  /// then open the Save Report screen (voice note + confirm).
  Future<void> _onTap(String type) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null || !mounted) return; // user cancelled

      // Compress the capture down to a small JPEG (640px max, quality 70) and
      // store it persistently in the documents directory so the OS does not
      // delete it and it uploads quickly even on slow 3G networks.
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = await Directory(
        '${dir.path}/reports',
      ).create(recursive: true);
      final savedPath =
          '${reportsDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      String storedPath;
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          photo.path,
          savedPath,
          minWidth: 640,
          minHeight: 640,
          quality: 70,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) {
          storedPath = compressed.path;
          // The original raw capture is no longer needed; remove it to save
          // space (best effort).
          try {
            await File(photo.path).delete();
          } catch (e, st) {
            debugPrint('ImageFlow: raw capture cleanup failed: $e\n$st');
          }
        } else {
          debugPrint(
            'ImageFlow: compressAndGetFile returned null '
            'for $savedPath — falling back to persistent copy',
          );
          storedPath =
              await ReportLocalService.persistMedia(photo.path, 'photo');
        }
      } catch (e, st) {
        // Compression unavailable: fall back to a persistent raw copy.
        debugPrint('ImageFlow: compression threw, using raw copy: $e\n$st');
        storedPath = await ReportLocalService.persistMedia(photo.path, 'photo');
      }

      // Never navigate with a photo path that does not point at a real,
      // non-empty file — otherwise the save step would persist a broken path.
      if (!await ReportLocalService.isValidFile(storedPath)) {
        debugPrint('ImageFlow: stored photo invalid: "$storedPath"');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not store photo')));
        return;
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SaveReportScreen(type: type, photoPath: storedPath),
        ),
      );
      if (mounted) setState(() {});
    } catch (e, st) {
      debugPrint('ImageFlow: camera flow failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera not available')));
    }
  }

  Future<void> _openHistory() async {
    // Capture the navigator before any async gap (lint-safe).
    final navigator = Navigator.of(context);
    // Stamp the open time so owner updates older than this are "seen" and
    // the red badge clears (per spec, stored in prefs).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _historyLastOpenedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    // Await the push so we can refresh the badge after returning.
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
    );
    if (mounted) _refreshOwnerBadge();
  }

  /// Opens a compact bottom sheet with the sync status.
  void _openSyncStatus(BuildContext context, int pendingCount) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                pendingCount == 0 ? Icons.cloud_done : Icons.cloud_upload,
                size: 64,
                color: pendingCount == 0 ? Colors.green : Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                pendingCount == 0
                    ? 'All reports synced'
                    : '$pendingCount report(s) waiting to sync',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: pendingCount == 0 ? null : () => _sync(),
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydra'),
        actions: [
          StreamBuilder<int>(
            stream: DatabaseService.watchPendingCount(),
            builder: (context, snapshot) {
              final pending = snapshot.data ?? 0;
              if (_syncing) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }
              return IconButton(
                icon: Badge.count(
                  count: pending,
                  isLabelVisible: pending > 0,
                  child: Icon(
                    pending == 0 ? Icons.cloud_done : Icons.cloud_upload,
                    color: pending == 0 ? Colors.white : Colors.amber.shade300,
                  ),
                ),
                tooltip: pending == 0 ? 'All synced' : 'Sync to cloud',
                onPressed: () => _openSyncStatus(context, pending),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ActionButton(
                label: 'WORK',
                color: Colors.blue,
                icon: Icons.handyman,
                iconColor: Colors.white,
                onTap: () => _onTap('work'),
              ),
            ),
            Expanded(
              child: ActionButton(
                label: 'PROBLEM',
                color: Colors.red,
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.white,
                onTap: () => _onTap('problem'),
              ),
            ),
            Expanded(
              child: ActionButton(
                label: 'MATERIAL',
                color: Colors.amber.shade600,
                icon: Icons.inventory_2,
                iconColor: Colors.white,
                onTap: () => _onTap('material'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Badge.count(
        count: _freshOwnerUpdates,
        isLabelVisible: _freshOwnerUpdates > 0,
        backgroundColor: Colors.red,
        child: FloatingActionButton(
          onPressed: _openHistory,
          tooltip: 'History',
          child: const Icon(Icons.history),
        ),
      ),
    );
  }
}
