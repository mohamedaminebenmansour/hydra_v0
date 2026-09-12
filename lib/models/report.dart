import 'package:isar_community/isar.dart';

part 'report.g.dart';

/// A locally stored field report.
///
/// [type] is one of: 'work', 'problem', or 'material'.
@collection
class Report {
  Id id = Isar.autoIncrement;

  /// The kind of report: 'work', 'problem', or 'material'.
  String type = 'work';

  /// Identifier of the reporting user (default team lead account).
  String userId = 'tl_1';

  /// Device model captured at save time, e.g. "samsung SM-A035F".
  String mobileId = '';

  /// Path to the captured photo on the local filesystem.
  String photoPath = '';

  /// Optional path to a voice recording. Empty when none was recorded.
  String voicePath = '';

  /// Latitude of the report location.
  double lat = 0.0;

  /// Longitude of the report location.
  double lng = 0.0;

  /// When the report was created.
  late DateTime timestamp;

  /// Workflow status, defaulting to 'pending'.
  String status = 'pending';

  /// Remote (Supabase) row id once the report has been synced. Empty while
  /// pending. Reserved for future upsert/update flows.
  String supabaseId = '';

  /// Convenience checks used by the sync engine. A 'failed' report stays
  /// retryable — it is re-pushed on the next sync trigger.
  bool get isSynced => status == 'synced';
  bool get isRetryable => status == 'pending' || status == 'failed';
}