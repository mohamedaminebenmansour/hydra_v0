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
    _isar = await Isar.open(
      [ReportSchema],
      directory: dir.path,
      name: _dbName,
    );
  }

  /// Insert or update a [Report] in the database.
  static Future<void> saveReport(Report report) async {
    await _isar.writeTxn(
      () => _isar.reports.put(report),
    );
  }

  /// Retrieve all saved reports, ordered by id.
  static Future<List<Report>> getAllReports() async {
    return _isar.reports.where().findAll();
  }
}