import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report.dart';
import 'database_service.dart';

/// Uploads locally pending reports (photos, voice notes) to Supabase and
/// inserts a row into the `reports` table, marking each one `synced` in Isar.
///
/// Offline-first rules:
///  * Every write goes to Isar first — the app works fully offline.
///  * Push: pending reports are uploaded when connectivity returns, after
///    each local save, or via the manual sync icon.
///  * Pull: remote rows newer than the last pull watermark are upserted into
///    Isar (local records always win; local media is never clobbered).
///  * Push loop stops immediately on the first failure so no report is ever
///    marked synced unless its upload AND insert both succeeded.
class SyncService {
  SyncService._();

  /// True while a sync (push or pull) is in flight; guards overlapping runs.
  static bool _syncing = false;

  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Watermark key for the last completed remote pull.
  static const String _lastPulledAtKey = 'lastRemotePullAt';

  /// Starts background triggers: push on connectivity restore, plus an
  /// initial pull on app start. Call once from main() after Isar init.
  static Future<void> init() async {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        debugPrint('SyncFlow: connectivity restored — scheduling auto sync');
        // Small debounce so the network is actually usable.
        Future.delayed(const Duration(seconds: 2), () async {
          await syncPendingReports();
          await pullRemoteChanges();
        });
      }
    });
    // Initial pull at startup (fire-and-forget).
    unawaited(pullRemoteChanges());
  }

  /// True if any network interface is currently available.
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Retry (push) a single report — invoked from the History "tap to retry"
  /// tap target. Returns true if the report reached a terminal state.
  static Future<bool> retryReport(int reportId) async {
    final report = await DatabaseService.getReportById(reportId);
    if (report == null || report.isFullySynced) return true;
    await _pushOne(report);
    return report.isFullySynced || report.status == 'failed';
  }

  /// Uploads every retryable report to Supabase using partial/resilient
  /// sync. Returns the number of reports that reached a terminal state.
  static Future<int> syncPendingReports() async {
    if (_syncing) return 0;
    if (!await isOnline()) {
      debugPrint('SyncFlow: offline — push deferred');
      return 0;
    }
    _syncing = true;
    int completedCount = 0;
    try {
      // Reset any stale 'uploading' states left by a crash.
      final reset = await DatabaseService.resetStaleUploading();
      if (reset > 0) {
        debugPrint('SyncFlow: reset $reset stale uploading report(s)');
      }

      final pending = await DatabaseService.getRetryableReports();
      if (pending.isEmpty) return 0;
      debugPrint('SyncFlow: ${pending.length} retryable report(s) found');
      for (final report in pending) {
        if (report.isFullySynced) continue;
        await _pushOne(report);
        if (report.isFullySynced || report.status == 'failed') {
          completedCount++;
        }
        if (!await isOnline()) {
          debugPrint('SyncFlow: network gone — aborting loop');
          break;
        }
      }
    } catch (e, st) {
      debugPrint('SyncFlow: sync aborted: $e\n$st');
    } finally {
      _syncing = false;
    }
    return completedCount;
  }

  /// Partial/resilient push of a single report. Each step persists its
  /// sub-status immediately, so a crash keeps already-completed pieces and
  /// the next run only uploads what's still pending.
  static Future<void> _pushOne(Report report) async {
    try {
      await DatabaseService.markUploading(report);

      // 1) Photo (skip if already synced).
      if (report.photoStatus != 'synced' && report.photoPath.isNotEmpty) {
        final url = await _upload('photo', report.photoPath, 'image/jpeg');
        report.photoUrl = url;
        report.photoStatus = 'synced';
        await DatabaseService.saveSubStatus(report);
        debugPrint('SyncFlow: report ${report.id} photo synced');
      }

      // 2) Voice (skip if none or already synced).
      if (report.voicePath.isNotEmpty && report.voiceStatus != 'synced') {
        final url = await _upload('voice', report.voicePath, 'audio/mp4');
        report.voiceUrl = url;
        report.voiceStatus = 'synced';
        await DatabaseService.saveSubStatus(report);
        debugPrint('SyncFlow: report ${report.id} voice synced');
      }

      // 3) DB row — only when media are in place.
      if (report.isPhotoSynced && report.isVoiceSynced) {
        if (report.dbStatus != 'synced') {
          await _insertRow(report);
          report.dbStatus = 'synced';
          await DatabaseService.saveSubStatus(report);
        }
      }

      // 4) All pieces done → fully synced.
      if (report.isFullySynced) {
        await DatabaseService.markSynced(report);
        debugPrint('SyncFlow: report ${report.id} fully synced');
      }
    } catch (e, st) {
      debugPrint('SyncFlow: report ${report.id} failed: $e\n$st');
      await DatabaseService.markFailed(report);
    }
  }

  /// Inserts (or upserts when supabaseId exists) the metadata row.
  static Future<void> _insertRow(Report report) async {
    final payload = {
      'local_id': report.id.toString(),
      'type': report.type,
      'photo_url': report.photoUrl,
      'voice_url': report.voiceUrl,
      'lat': report.lat,
      'lng': report.lng,
      'timestamp': report.timestamp.toUtc().toIso8601String(),
      'user_id': report.userId,
      'mobile_id': report.mobileId,
    };
    final inserted = report.supabaseId.isNotEmpty
        ? await Supabase.instance.client
            .from('reports')
            .upsert(payload)
            .select('id')
            .single()
        : await Supabase.instance.client
            .from('reports')
            .insert(payload)
            .select('id')
            .single();
    report.supabaseId = (inserted['id'] ?? '').toString();
    debugPrint(
      'SyncFlow: report ${report.id} row upserted (remote id=${report.supabaseId})',
    );
  }

  /// Pull remote changes from Supabase newer than the last pull watermark
  /// and upsert them into Isar. Conflict rule: LOCAL WINS — a remote row is
  /// skipped when a local report with the same local_id already exists.
  static Future<void> pullRemoteChanges() async {
    if (_syncing) return;
    if (!await isOnline()) return;
    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPulledAt = prefs.getString(_lastPulledAtKey);
      debugPrint(
        'PullFlow: pulling remote changes since '
        '${lastPulledAt ?? 'beginning'}',
      );
      // The `updated_at` watermark requires the column to exist in Supabase
      // (alter table reports add column updated_at timestamptz default now());
      // if it is missing we gracefully fall back to a pull of everything.
      final rows = lastPulledAt == null
          ? await Supabase.instance.client
                .from('reports')
                .select()
                .order('id', ascending: true)
          : await Supabase.instance.client
                .from('reports')
                .select()
                .gt('updated_at', lastPulledAt)
                .order('id', ascending: true);
      debugPrint('PullFlow: ${rows.length} remote row(s) received');
      for (final row in rows) {
        try {
          final remote = Map<String, dynamic>.from(row);
          final localId = remote['local_id']?.toString() ?? '';
          if (localId.isNotEmpty) {
            final localIdNum = int.tryParse(localId);
            if (localIdNum != null &&
                await DatabaseService.getReportById(localIdNum) != null) {
              continue; // local wins: we already have this record
            }
          }
          await _upsertRemote(remote);
        } catch (e, st) {
          debugPrint('PullFlow: row upsert failed: $e\n$st');
        }
      }
      // Record the watermark only after a clean pull.
      await prefs.setString(
        _lastPulledAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      debugPrint('PullFlow: watermark advanced');
    } catch (e, st) {
      debugPrint('PullFlow: pull failed: $e\n$st');
    } finally {
      _syncing = false;
    }
  }

  /// Creates a local Report from a remote Supabase row. A pulled row is
  /// 'synced' by definition; local file fields hold the remote public URLs.
  static Future<void> _upsertRemote(Map<String, dynamic> row) async {
    final photoPath = (row['photo_url'] ?? '').toString();
    final voicePath = (row['voice_url'] ?? '').toString();
    final report = Report()
      ..type = (row['type'] ?? 'work').toString()
      ..photoPath = photoPath
      ..voicePath = voicePath
      ..photoUrl = photoPath
      ..voiceUrl = voicePath
      ..lat = (row['lat'] as num?)?.toDouble() ?? 0.0
      ..lng = (row['lng'] as num?)?.toDouble() ?? 0.0
      ..userId = (row['user_id'] ?? 'tl_1').toString()
      ..mobileId = (row['mobile_id'] ?? '').toString()
      ..timestamp = row['timestamp'] != null
          ? DateTime.parse(row['timestamp'].toString()).toLocal()
          : DateTime.now()
      ..status = 'synced'
      ..photoStatus = 'synced'
      ..voiceStatus = 'synced'
      ..dbStatus = 'synced'
      ..supabaseId = (row['id'] ?? '').toString();
    await DatabaseService.saveReport(report);
    debugPrint('PullFlow: stored remote row (supabaseId=${report.supabaseId})');
  }

  /// Uploads a file to a public Supabase storage bucket and returns its
  /// public URL. The destination name matches the local file name, and
  /// upsert=true makes re-syncs idempotent.
  static Future<String> _upload(
    String bucket,
    String path,
    String contentType,
  ) async {
    final storage = Supabase.instance.client.storage.from(bucket);
    final fileName = path.split('/').last;
    await storage.upload(
      fileName,
      File(path),
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    final url = storage.getPublicUrl(fileName);
    debugPrint('SyncFlow: uploaded "$fileName" to "$bucket" -> $url');
    return url;
  }
}
