import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/report.dart';
import 'database_service.dart';

/// Where a report's photo / voice media should be read from right now.
enum MediaOrigin { localFile, network, none }

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

  // ---------------------------------------------------------------------------
  // Hybrid Shield: reading media offline-first + reclaiming local disk.
  // ---------------------------------------------------------------------------

  /// Resolves where a report's media should be read from, offline-first:
  ///  * the local file while it still exists on disk,
  ///  * otherwise the cloud URL (cached by the UI layer),
  ///  * otherwise nothing.
  ///
  /// [localPath] is historically overloaded: pulled remote rows store the
  /// public URL in the path field. A value that is not an existing file simply
  /// falls through to the URL branch instead of throwing.
  static ({MediaOrigin origin, String location}) resolveMedia(
    String localPath,
    String url,
  ) {
    if (localPath.isNotEmpty && _isExistingFile(localPath)) {
      return (origin: MediaOrigin.localFile, location: localPath);
    }
    if (url.isNotEmpty) return (origin: MediaOrigin.network, location: url);
    if (localPath.isNotEmpty) {
      // Legacy / pulled row: the "path" really is a remote URL.
      return (origin: MediaOrigin.network, location: localPath);
    }
    return (origin: MediaOrigin.none, location: '');
  }

  /// Synchronous existence probe that never throws (a URL stored in the path
  /// field, an empty string or a permission problem all mean "not a file").
  static bool _isExistingFile(String path) {
    try {
      return File(path).existsSync();
    } catch (e) {
      debugPrint('LocalStore: existence probe failed for "$path": $e');
      return false;
    }
  }

  /// "Hybrid Shield": silently reclaims disk space by deleting local photo and
  /// voice files for reports whose cloud copy is complete and which the owner
  /// has finished with (or which are older than [olderThan]).
  ///
  /// Safety rules: only fully-synced reports are touched, the matching cloud
  /// URL must be present before a file is released, and every single deletion
  /// is guarded — a missing file, or a path that is really a URL, is harmless.
  /// The Isar record keeps `photoUrl` / `voiceUrl` and only loses the local
  /// paths. Returns the number of reports whose paths were cleared.
  static Future<int> cleanUpLocalMedia({
    Duration olderThan = const Duration(days: 7),
  }) async {
    try {
      final cutoff = DateTime.now().subtract(olderThan);
      final candidates = await DatabaseService.getMediaCleanupCandidates(
        cutoff,
      );
      if (candidates.isEmpty) return 0;

      var reportsCleaned = 0;
      var filesDeleted = 0;
      for (final report in candidates) {
        var changed = false;
        if (report.photoPath.isNotEmpty && report.photoUrl.isNotEmpty) {
          if (await _deleteMediaQuietly(report.photoPath)) filesDeleted++;
          report.photoPath = '';
          changed = true;
        }
        if (report.voicePath.isNotEmpty && report.voiceUrl.isNotEmpty) {
          if (await _deleteMediaQuietly(report.voicePath)) filesDeleted++;
          report.voicePath = '';
          changed = true;
        }
        if (changed) {
          await DatabaseService.clearLocalMediaPaths(report);
          reportsCleaned++;
        }
      }
      debugPrint(
        'CleanupFlow: reclaimed $filesDeleted file(s) across '
        '$reportsCleaned report(s) (cutoff ${olderThan.inDays}d)',
      );
      return reportsCleaned;
    } catch (e, st) {
      // Disk hygiene must never break startup or sync.
      debugPrint('CleanupFlow: local media cleanup failed: $e\n$st');
      return 0;
    }
  }

  /// Deletes [path] when it exists. Returns true only when a file was actually
  /// removed; every failure (missing file, URL instead of a path, permission)
  /// is logged and swallowed so a stale record can never crash the app.
  static Future<bool> _deleteMediaQuietly(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      await file.delete();
      debugPrint('CleanupFlow: deleted "$path"');
      return true;
    } catch (e, st) {
      debugPrint('CleanupFlow: delete skipped for "$path": $e\n$st');
      return false;
    }
  }
}
