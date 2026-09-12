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
  static bool get isInitialized => _isar.isOpen;

  /// Open the Isar database in the application documents directory.
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    try {
      _isar = await Isar.open(
        [ReportSchema],
        directory: dir.path,
        name: _dbName,
      );
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

  /// Retrieve all reports needing a sync attempt (pending or failed),
  /// oldest first.
  static Future<List<Report>> getRetryableReports() {
    return _isar.reports
        .filter()
        .statusEqualTo('pending')
        .or()
        .statusEqualTo('failed')
        .sortByTimestamp()
        .findAll();
  }

  /// Mark a report as failed after an unsuccessful sync attempt. The report
  /// stays retryable and is re-pushed on the next trigger.
  static Future<void> markFailed(Report report) async {
    report.status = 'failed';
    await _isar.writeTxn(
      () => _isar.reports.put(report),
    );
    debugPrint('DatabaseFlow: report ${report.id} marked failed');
  }

  /// Mark a report as synced (after a successful Supabase upload + insert).
  static Future<void> markSynced(Report report) async {
    report.status = 'synced';
    await _isar.writeTxn(
      () => _isar.reports.put(report),
    );
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

  /// Live-sorted stream of all reports (newest first). Emits immediately and
  /// on every Isar write, so list screens update without manual reloads.
  static Stream<List<Report>> watchAllReports() {
    return _isar.reports
        .where()
        .sortByTimestampDesc()
        .watch(fireImmediately: true);
  }
}