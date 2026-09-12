import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report.dart';
import 'database_service.dart';

/// Local-first storage helper for reports and their media files.
///
/// Every photo/voice file is persisted into the permanent application
/// documents directory (`/reports`) before a [Report] is saved to Isar, so
/// the app is fully functional offline and files survive OS cache cleaning.
/// All IO is async and tolerant of missing/empty source paths.
class ReportLocalService {
  ReportLocalService._();

  /// Async check that [path] points at an existing, non-empty file.
  static Future<bool> isValidFile(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final f = File(path);
      if (!await f.exists()) return false;
      return (await f.length()) > 0;
    } catch (e, st) {
      debugPrint('LocalStore: validation failed for "$path": $e\n$st');
      return false;
    }
  }

  /// Copies a media file from a temporary location (camera / recorder cache)
  /// into the permanent `<documents>/reports` directory and returns the new
  /// absolute path. Returns '' if the source is missing or empty.
  static Future<String> persistMedia(String? srcPath, String prefix) async {
    if (!await isValidFile(srcPath)) {
      debugPrint('LocalStore: persistMedia skipped — invalid source '
          '"$srcPath"');
      return '';
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir =
          await Directory('${dir.path}/reports').create(recursive: true);
      final ext = srcPath!.contains('.') ? srcPath.split('.').last : 'bin';
      final dest =
          '${reportsDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(srcPath).copy(dest);
      debugPrint('LocalStore: persisted "$srcPath" -> "$dest"');
      return dest;
    } catch (e, st) {
      debugPrint('LocalStore: persistMedia failed: $e\n$st');
      return '';
    }
  }

  /// Persists a [Report] in Isar inside a write transaction and returns the
  /// generated local id.
  static Future<int> saveReport(Report report) async {
    final id = await DatabaseService.saveReport(report);
    debugPrint('LocalStore: report persisted (id=$id, '
        'photo=${report.photoPath}, voice=${report.voicePath}, '
        'status=${report.status})');
    return id;
  }

  /// Reactive stream of all reports, newest first — drives the UI list.
  static Stream<List<Report>> watchReports() =>
      DatabaseService.watchAllReports();
}
