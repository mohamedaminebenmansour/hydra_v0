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
      final id = await _isar.writeTxn(
        () => _isar.reports.put(report),
      );
      debugPrint('DatabaseFlow: report saved '
          '(id=$id, photo=${report.photoPath}, voice=${report.voicePath}, '
          'lat=${report.lat}, lng=${report.lng}, '
          'userId=${report.userId}, mobileId=${report.mobileId})');
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
        .anyOf(
          ['local', 'failed', 'uploading', 'pending'],
          (q, s) => q.statusEqualTo(s),
        )
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

  /// Update a report's owner status (pulled from Supabase) and stamp when it
  /// changed, so the home-screen badge can count fresh 24h updates.
  static Future<void> updateOwnerStatus(
    Report report,
    String ownerStatus,
  ) async {
    report.ownerStatus = ownerStatus;
    report.ownerStatusAt = DateTime.now();
    await _isar.writeTxn(() => _isar.reports.put(report));
    debugPrint(
      'OwnerFlow: report ${report.id} ownerStatus=$ownerStatus',
    );
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
    if (!isInitialized) return const Stream<int>.empty();
    return _isar.reports
        .filter()
        .statusEqualTo('pending')
        .or()
        .statusEqualTo('failed')
        .watch(fireImmediately: true)
        .map((list) => list.length);
  }

  /// Live-sorted stream of all reports (newest first). Emits immediately and
  /// on every Isar write, so list screens update without manual reloads.
  static Stream<List<Report>> watchAllReports() {
    if (!isInitialized) return const Stream<List<Report>>.empty();
    return _isar.reports
        .where()
        .sortByTimestampDesc()
        .watch(fireImmediately: true);
  }
}