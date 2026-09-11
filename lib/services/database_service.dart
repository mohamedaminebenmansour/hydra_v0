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
          '(id=$id, photo=${report.photoPath}, voice=${report.voicePath})');
      return id;
    } catch (e, st) {
      debugPrint('DatabaseFlow: writeTxn/put failed: $e\n$st');
      rethrow;
    }
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