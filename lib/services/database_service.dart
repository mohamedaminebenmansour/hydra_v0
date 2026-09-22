import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report.dart';

/// Handles initialization of the local Isar database and basic CRUD.
class DatabaseService {
  DatabaseService._();

  /// The single shared Isar instance. Initialized by [init] before use.
  static late Isar _isar;

  /// The name of the Isar database on disk.
  static const String _dbName = 'hydra_db';

  /// True once [init] has completed successfully.
  static bool _initialized = false;

  /// True once [init] has completed successfully. Safe to call before [init]
  /// (unlike `_isar.isOpen`, which would throw on the uninitialized field).
  static bool get isInitialized => _initialized && _isar.isOpen;

  /// Open the Isar database in the application documents directory.
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    try {
      _isar = await Isar.open(
        [ReportSchema],
        directory: dir.path,
        name: _dbName,
      );
      _initialized = true;
      debugPrint('DatabaseFlow: Isar opened at ${dir.path}/$_dbName');
    } catch (e, st) {
      debugPrint('DatabaseFlow: Isar.open failed: $e\n$st');
      rethrow;
    }
  }

  /// Insert or update a [Report] in the database.
  /// Returns the generated Isar id of the saved record.
  static Future<int> saveReport(Report report) async {
    try {
      final id = await _isar.writeTxn(() => _isar.reports.put(report));
      debugPrint(
        'DatabaseFlow: report saved '
        '(id=$id, photo=${report.photoPath}, voice=${report.voicePath}, '
        'lat=${report.lat}, lng=${report.lng}, '
        'userId=${report.userId}, mobileId=${report.mobileId})',
      );
      return id;
    } catch (e, st) {
      debugPrint('DatabaseFlow: writeTxn/put failed: $e\n$st');
      rethrow;
    }
  }

  /// Retrieve all reports needing a sync attempt (local, failed, or stale
  /// uploading from a crash), oldest first so the queue is FIFO.
  static Future<List<Report>> getRetryableReports() {
    return _isar.reports
        .filter()
        .anyOf([
          'local',
          'failed',
          'uploading',
          'pending',
        ], (q, s) => q.statusEqualTo(s))
        .sortByTimestamp()
        .findAll();
  }

  /// Mark a report as currently uploading (UI shows the spinner).
  static Future<void> markUploading(Report report) async {
    report.status = 'uploading';
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint('DatabaseFlow: report ${report.id} marked uploading');
  }

  /// Persist incremental sub-status progress during a partial sync so a
  /// crash keeps already-completed pieces.
  static Future<void> saveSubStatus(Report report) async {
    await _isar.writeTxn(() => _isar.reports.put(report));
  }

  /// Reset any 'uploading' reports (left by a crash) back to 'failed' so they
  /// are retried on the next sync. Returns the count reset.
  static Future<int> resetStaleUploading() async {
    final stale = await _isar.reports
        .filter()
        .statusEqualTo('uploading')
        .findAll();
    for (final r in stale) {
      r.status = 'failed';
    }
    if (stale.isNotEmpty) {
      await _isar.writeTxn(() => _isar.reports.putAll(stale));
    }
    return stale.length;
  }

  /// Mark a report as failed after an unsuccessful sync attempt. The report
  /// stays retryable and is re-pushed on the next trigger. Sub-statuses of
  /// already-completed pieces are preserved.
  static Future<void> markFailed(Report report) async {
    report.status = 'failed';
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint('DatabaseFlow: report ${report.id} marked failed');
  }

  /// Mark a report as fully synced — all three sub-pieces succeeded.
  static Future<void> markSynced(Report report) async {
    report.status = 'synced';
    report.photoStatus = 'synced';
    report.voiceStatus = 'synced';
    report.dbStatus = 'synced';
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint('DatabaseFlow: report ${report.id} marked synced');
  }

  /// Retrieve a single report by its Isar id.
  static Future<Report?> getReportById(int id) async {
    return await _isar.reports.get(id);
  }

  /// Retrieve all saved reports, newest first (ORDER BY timestamp DESC).
  static Future<List<Report>> getAllReports() {
    return _isar.reports.where().sortByTimestampDesc().findAll();
  }

  /// Reports whose local media may be reclaimed: the cloud copy is complete
  /// and the owner has finished with them, or they are older than [cutoff].
  ///
  /// [Report.syncState] is `@ignore` (computed), so it can never appear in an
  /// Isar filter: we pre-filter on the persisted `status` column — the same
  /// cheap pattern used by [watchPendingCount] — and finish the evaluation in
  /// Dart via [Report.isMediaReclaimable].
  static Future<List<Report>> getMediaCleanupCandidates(DateTime cutoff) async {
    if (!isInitialized) return const <Report>[];
    final synced = await _isar.reports
        .filter()
        .statusEqualTo('synced')
        .findAll();
    return synced.where((r) => r.isMediaReclaimable(cutoff)).toList();
  }

  /// Persist a report after its local media files were released. The cloud URLs
  /// ([Report.photoUrl] / [Report.voiceUrl]) are intentionally kept.
  static Future<void> clearLocalMediaPaths(Report report) async {
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint(
      'CleanupFlow: report ${report.id} local media released '
      '(photoUrl=${report.photoUrl}, voiceUrl=${report.voiceUrl})',
    );
  }

  /// Persist a Team Leader validation decision ("Chef de Chantier Gate") and
  /// re-queue the report for a cloud push.
  ///
  /// [Report.status] / [Report.dbStatus] are deliberately reset to a pending
  /// state so [SyncService] picks the report up again even when it was already
  /// fully synced before validation. The already-synced media sub-statuses are
  /// preserved, so the next push only uploads the TL proof photo (if any) and
  /// upserts the remote row via its existing [Report.supabaseId].
  static Future<void> markTlValidated(Report report) async {
    report.tlValidatedAt = DateTime.now();
    report.dbStatus = 'pending';
    report.status = 'local';
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint(
      'TlGate: report ${report.id} validated '
      '(type=${report.tlValidationType}, validator=${report.tlValidatorId})',
    );
  }

  /// Marks a report as read by the local user (the History card's unread
  /// dot disappears). Called by the report sheet when the thread is on
  /// screen. No-op (with a log line) when the local database is not open —
  /// the Owner's thin client has no Isar and simply never shows the dot.
  static Future<void> markReportRead(Report report) async {
    if (!isInitialized) {
      debugPrint('DatabaseFlow: report ${report.id} read state skipped '
          '(no local database)');
      return;
    }
    if (report.isReadByUser) return;
    report.isReadByUser = true;
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint('DatabaseFlow: report ${report.id} marked read');
  }

  /// Appends one event to a report's shared thread (the Subcontractor <->
  /// Team Leader chat) and re-queues the report for the next cloud push, so a
  /// message typed on this device reaches the other device — the push path
  /// sends `timeline_events` on both its insert and its update branch.
  ///
  /// [Report.status] / [Report.dbStatus] are reset to a pending state exactly
  /// like [markTlValidated] does, so [SyncService] picks the report up again
  /// even when it was already fully synced. The media sub-statuses are
  /// preserved, so an already-uploaded photo is never re-uploaded just because
  /// a message was added.
  ///
  /// No-op (with a log line) when the local database is not open: the Owner's
  /// thin client has no Isar and must still be able to show the sheet.
  static Future<void> appendReportEvent(
    Report report, {
    required String actor,
    required String action,
    String text = '',
    String photoPath = '',
    String voicePath = '',
    String photoUrl = '',
    String voiceUrl = '',
    DateTime? time,
  }) async {
    report.addTimelineEvent(
      actor: actor,
      action: action,
      text: text,
      photoPath: photoPath,
      voicePath: voicePath,
      photoUrl: photoUrl,
      voiceUrl: voiceUrl,
      time: time,
    );
    if (!isInitialized) {
      debugPrint(
        'DatabaseFlow: report ${report.id} event "$action" kept in memory only '
        '(no local database)',
      );
      return;
    }
    report.dbStatus = 'pending';
    report.status = 'local';
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint(
      'DatabaseFlow: report ${report.id} event "$action" appended by $actor '
      '(queued for cloud)',
    );
  }

  /// Update a report's owner status (pulled from Supabase) and stamp when it
  /// changed, so the home-screen badge can count fresh 24h updates.
  static Future<void> updateOwnerStatus(
    Report report,
    String ownerStatus,
  ) async {
    report.ownerStatus = ownerStatus;
    report.ownerStatusAt = DateTime.now();
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint('OwnerFlow: report ${report.id} ownerStatus=$ownerStatus');
  }

  /// Count of reports whose owner status changed after [after] (the
  /// last-history-open marker) within the last 24 hours. Drives the red badge.
  static Future<int> countFreshOwnerUpdates(DateTime after) async {
    if (!isInitialized) return 0;
    final since24h = DateTime.now().subtract(const Duration(hours: 24));
    final reports = await _isar.reports.where().findAll();
    return reports
        .where(
          (r) =>
              r.ownerStatusAt != null &&
              r.ownerStatusAt!.isAfter(after) &&
              r.ownerStatusAt!.isAfter(since24h),
        )
        .length;
  }

  /// Live stream of the count of pending-or-failed reports. Used by the sync
  /// badge to show an amber count when work is queued.
  static Stream<int> watchPendingCount() {
    // Never throw from a build-phase stream getter: an unopened database
    // simply reports "nothing queued".
    if (!isInitialized) return Stream<int>.value(0);
    return _isar.reports
        .filter()
        .statusEqualTo('pending')
        .or()
        .statusEqualTo('local')
        .or()
        .statusEqualTo('failed')
        .or()
        .statusEqualTo('uploading')
        .watch(fireImmediately: true)
        .map((list) => list.length);
  }

  /// Live-sorted stream of all reports (newest first). Emits immediately and
  /// on every Isar write, so list screens update without manual reloads.
  static Stream<List<Report>> watchAllReports() {
    if (!isInitialized) return const Stream<List<Report>>.empty();
    return _isar.reports.where().sortByTimestampDesc().watch(
      fireImmediately: true,
    );
  }

  /// Live view of a single report: emits immediately and on every write, so an
  /// open report sheet follows changes made underneath it (a pull bringing the
  /// Team Leader's answer in, a background edit). Emits a single null when the
  /// local database is not open — the Owner's thin client has no Isar and keeps
  /// its in-memory snapshot instead.
  static Stream<Report?> watchReport(int id) {
    if (!isInitialized) return Stream<Report?>.value(null);
    return _isar.reports.watchObject(id, fireImmediately: true);
  }
}
