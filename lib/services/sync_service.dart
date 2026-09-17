import 'dart:async';
import 'dart:convert';
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
  ///
  /// Never throws: a connectivity-plugin failure only costs us the auto-push
  /// trigger, it must never block `main()` from reaching `runApp()`.
  static Future<void> init() async {
    _connectivitySub?.cancel();
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (results) {
          final online = results.any((r) => r != ConnectivityResult.none);
          if (online) {
            debugPrint(
              'SyncFlow: connectivity restored — scheduling auto sync',
            );
            // Small debounce so the network is actually usable.
            Future.delayed(const Duration(seconds: 2), () async {
              await syncPendingReports();
              await pullRemoteChanges();
            });
          }
        },
        onError: (Object e, StackTrace st) {
          debugPrint('SyncFlow: connectivity stream error: $e\n$st');
        },
      );
    } catch (e, st) {
      debugPrint('SyncFlow: connectivity stream unavailable: $e\n$st');
    }
    // Initial pull at startup (fire-and-forget).
    unawaited(pullRemoteChanges());
  }

  /// True if any network interface is currently available.
  ///
  /// Never throws: if the connectivity plugin is unavailable or fails, we
  /// report "offline" so callers defer exactly as they already do without a
  /// network. That matters because [checkOwnerUpdates], [syncPendingReports]
  /// and [pullRemoteChanges] all call this *before* entering their own try
  /// blocks, so a probe failure would otherwise surface as an unhandled async
  /// error.
  static Future<bool> isOnline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e, st) {
      debugPrint(
        'SyncFlow: connectivity probe failed (assuming offline): $e\n$st',
      );
      return false;
    }
  }

  /// Retry (push) a single report — invoked from the History "tap to retry"
  /// tap target. Returns true if the report reached a terminal state.
  static Future<bool> retryReport(int reportId) async {
    final report = await DatabaseService.getReportById(reportId);
    if (report == null || report.isFullySynced) return true;
    await _pushOne(report);
    return report.isFullySynced || report.status == 'failed';
  }

  /// Smart Pull-on-Open: fetches the owner's workflow decisions from Supabase
  /// and applies them to local Isar records. Returns the number of reports
  /// whose owner status changed (drives the red badge on the home screen).
  /// Gracefully no-ops when offline or when the owner_status column does not
  /// exist yet in Supabase.
  static Future<int> checkOwnerUpdates() async {
    if (!await isOnline()) {
      debugPrint('OwnerFlow: offline — owner pull deferred');
      return 0;
    }
    try {
      final rows = await Supabase.instance.client
          .from('reports')
          .select('local_id, owner_status');
      debugPrint('OwnerFlow: ${rows.length} remote row(s) checked');
      int changed = 0;
      for (final row in rows) {
        final remote = Map<String, dynamic>.from(row);
        final localId = int.tryParse(
          remote['local_id']?.toString() ?? '',
        );
        if (localId == null) continue;
        final remoteStatus = (remote['owner_status'] ?? 'pending').toString();
        final local = await DatabaseService.getReportById(localId);
        if (local == null) continue; // unknown report (e.g. pulled row)
        if (local.ownerStatus == remoteStatus) continue;
        await DatabaseService.updateOwnerStatus(local, remoteStatus);
        changed++;
      }
      debugPrint('OwnerFlow: $changed report(s) updated from owner');
      return changed;
    } catch (e, st) {
      debugPrint(
        'OwnerFlow: owner pull failed (missing owner_status column?): '
        '$e\n$st',
      );
      return 0;
    }
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

      // 3) TL validation proof photo ("Chef de Chantier Gate"). Only present when the
      // Team Leader validated on site while offline. The remote URL is persisted
      // as soon as it exists, so a retry never re-uploads the file.
      if (report.tlValidationPhotoPath.isNotEmpty &&
          report.tlValidationPhotoUrl.isEmpty) {
        report.tlValidationPhotoUrl = await _upload(
          'photo',
          report.tlValidationPhotoPath,
          'image/jpeg',
        );
        await DatabaseService.saveSubStatus(report);
        debugPrint('SyncFlow: report ${report.id} TL validation photo synced');
      }

      // 3b) "Dispute Shield": when the TL rejected the report, the mandatory proof
      // photo and voice note must reach the cloud too. Each URL is persisted on
      // success, so a retry never re-uploads the same file.
      if (report.isTlRejected) {
        if (report.tlRejectionPhotoPath.isNotEmpty &&
            report.tlRejectionPhotoUrl.isEmpty) {
          report.tlRejectionPhotoUrl = await _upload(
            'photo',
            report.tlRejectionPhotoPath,
            'image/jpeg',
          );
          await DatabaseService.saveSubStatus(report);
          debugPrint(
            'SyncFlow: report ${report.id} TL rejection photo synced',
          );
        }
        if (report.tlRejectionVoicePath.isNotEmpty &&
            report.tlRejectionVoiceUrl.isEmpty) {
          report.tlRejectionVoiceUrl = await _upload(
            'voice',
            report.tlRejectionVoicePath,
            'audio/mp4',
          );
          await DatabaseService.saveSubStatus(report);
          debugPrint(
            'SyncFlow: report ${report.id} TL rejection voice synced',
          );
        }
      }

      // 4) DB row — only when media are in place.
      if (report.isPhotoSynced && report.isVoiceSynced) {
        if (report.dbStatus != 'synced') {
          if (report.supabaseId.isNotEmpty) {
            // The report already exists remotely: push only the gate decision
            // so re-validating never creates a second report row.
            await _updateTlValidation(report);
          } else {
            await _insertRow(report);
          }
          report.dbStatus = 'synced';
          await DatabaseService.saveSubStatus(report);
        }
      }

      // 5) All pieces done → fully synced.
      if (report.isFullySynced) {
        await DatabaseService.markSynced(report);
        debugPrint('SyncFlow: report ${report.id} fully synced');
      }
    } catch (e, st) {
      debugPrint('SyncFlow: report ${report.id} failed: $e\n$st');
      await DatabaseService.markFailed(report);
    }
  }

    /// The Team Leader gate columns ("Chef de Chantier Gate"). [allowClear]
  /// marks a push that legitimately clears the gate (the subcontractor's
  /// "Fix & Resubmit" resets the decision so the report returns to the TL's
  /// inbox): the type is then sent as an empty string instead of being skipped.
  /// For a fresh unvalidated report nothing is ever sent, so a pull can never
  /// overwrite a remote value with an empty string / null by accident.
  static Map<String, dynamic> _tlValidationPayload(
    Report report, {
    bool allowClear = false,
  }) {
    return {
      if (report.tlValidatedAt != null)
        'tl_validated_at': report.tlValidatedAt!.toUtc().toIso8601String(),
      if (allowClear || report.tlValidationType.isNotEmpty)
        'tl_validation_type': report.tlValidationType,
      if (report.tlValidationPhotoUrl.isNotEmpty)
        'tl_validation_photo_url': report.tlValidationPhotoUrl,
      if (report.tlRejectionPhotoUrl.isNotEmpty)
        'tl_rejection_photo_url': report.tlRejectionPhotoUrl,
      if (report.tlRejectionVoiceUrl.isNotEmpty)
        'tl_rejection_voice_url': report.tlRejectionVoiceUrl,
    };
  }

  /// Inserts (or upserts when supabaseId exists) the metadata row.
  static Future<void> _insertRow(Report report) async {
    final payload = <String, dynamic>{
      'local_id': report.id.toString(),
      'type': report.type,
      'photo_url': report.photoUrl,
      'voice_url': report.voiceUrl,
      'problem_category': report.problemCategory,
      'lat': report.lat,
      'lng': report.lng,
      'timestamp': report.timestamp.toUtc().toIso8601String(),
      'user_id': report.userId,
      'mobile_id': report.mobileId,
      'activity_log': jsonEncode(report.activityLog),
      'timeline_events': report.timelineEvents,
      ..._tlValidationPayload(report),
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

  /// Pushes only the Team Leader gate decision for a report that already has a
  /// remote row. Used when a re-validation re-queues an already-synced report:
  /// a plain insert would duplicate the row, so we update by remote id instead.
  ///
  /// When the remote row has disappeared (owner deleted it), the full payload is
  /// re-inserted so the local report still reaches the cloud.
  static Future<void> _updateTlValidation(Report report) async {
    // This update path only runs for reports that already exist remotely and
    // were locally mutated (gate decision or resubmission), so:
    //  * allowClear: a resubmitted report legitimately clears its gate state
    //    (tl_validation_type -> '') so it returns to the TL's inbox;
    //  * photo_url: the subcontractor may have re-captured the proof photo;
    //  * activity_log: the shared audit trail ("Fix & Resubmit" loop).
    final payload = _tlValidationPayload(report, allowClear: true)
      ..['photo_url'] = report.photoUrl
      ..['activity_log'] = jsonEncode(report.activityLog);
    if (payload.isEmpty) return;
    final updated = await Supabase.instance.client
        .from('reports')
        .update(payload)
        .eq('id', report.supabaseId)
        .select('id');
    if (updated.isEmpty) {
      debugPrint(
        'SyncFlow: report ${report.id} remote row ${report.supabaseId} is '
        'gone — re-inserting',
      );
      await _insertRow(report);
      return;
    }
    debugPrint(
      'SyncFlow: report ${report.id} TL validation pushed '
      '(remote id=${report.supabaseId})',
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
    // "Chef de Chantier Gate": mirror the TL validation decision. The remote
    // photo URL is stored in the path field too (same overload used for
    // photo_url), so [ReportLocalService.resolveMedia] can display it.
    if (row['tl_validated_at'] != null) {
      report.tlValidatedAt = DateTime.parse(
        row['tl_validated_at'].toString(),
      ).toLocal();
    }
    report.tlValidationType = (row['tl_validation_type'] ?? '').toString();
    final tlPhotoUrl = (row['tl_validation_photo_url'] ?? '').toString();
    report.tlValidationPhotoUrl = tlPhotoUrl;
    report.tlValidationPhotoPath = tlPhotoUrl;
    // "Dispute Shield" rejection proof media (pulled as remote URLs).
    final tlRejPhotoUrl = (row['tl_rejection_photo_url'] ?? '').toString();
    report.tlRejectionPhotoUrl = tlRejPhotoUrl;
    if (tlRejPhotoUrl.isNotEmpty) {
      report.tlRejectionPhotoPath = tlRejPhotoUrl;
    }
    report.tlRejectionVoiceUrl =
        (row['tl_rejection_voice_url'] ?? '').toString();
    // "Fix & Resubmit" audit trail: remote JSONB array of entry objects ->
    // local list of raw JSON strings (the Isar representation).
    final remoteLog = row['activity_log'];
    if (remoteLog is List) {
      report.activityLog = remoteLog.map((e) => jsonEncode(e)).toList();
    }
    final remoteTimeline = row['timeline_events'];
    if (remoteTimeline is List) {
      report.timelineEvents = remoteTimeline.map((e) => jsonEncode(e)).toList();
    }
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
