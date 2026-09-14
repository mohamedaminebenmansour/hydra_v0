import 'package:isar_community/isar.dart';

part 'report.g.dart';

/// Semantic sync states derived from the report's status + sub-statuses.
enum SyncState { local, uploading, synced, failed }

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

  /// Workflow status. One of: 'local', 'uploading', 'synced', 'failed'.
  /// Legacy rows may carry 'pending' (treated as 'local').
  String status = 'pending';

  /// Remote (Supabase) row id once the report has been synced. Empty while
  /// pending. Reserved for future upsert/update flows.
  String supabaseId = '';

  /// Sub-status tracking for partial/resilient sync.
  /// Each is one of: 'pending', 'synced', 'failed'.
  String photoStatus = 'pending';
  String voiceStatus = 'pending';
  String dbStatus = 'pending';

  /// Cached public URLs returned by Supabase storage after a successful upload.
  /// Persisted so a later partial-sync run can insert the row without re-uploading.
  String photoUrl = '';
  String voiceUrl = '';

  /// Owner's workflow decision, pulled from Supabase. One of:
  /// 'pending', 'validated', 'acknowledged', 'approved', 'rejected', 'ordered'.
  String ownerStatus = 'pending';

  /// When the owner status last changed (drives the red 24h badge).
  DateTime? ownerStatusAt;

  /// Problem category for problem-type reports.
  /// One of: 'general', 'machine', 'material_missing', 'soil', 'external'.
  String problemCategory = 'general';

  /// True when the photo upload has been completed (local file uploaded).
  bool get isPhotoSynced => photoStatus == 'synced';
  bool get isVoiceSynced =>
      voicePath.isEmpty || voiceStatus == 'synced';
  bool get isDbSynced => dbStatus == 'synced';

  /// A report is fully synced only when all three sub-pieces succeeded.
  bool get isFullySynced =>
      isPhotoSynced && isVoiceSynced && isDbSynced;

  /// Retryable if it hasn't fully synced yet (covers local, failed, and
  /// stale-uploading states left behind by a crash).
  bool get isRetryable => !isFullySynced && status != 'uploading';

  /// Convenience alias kept for call sites that read the legacy getter.
  bool get isSynced => status == 'synced' && isFullySynced;

  /// Semantic overall state derived from status + sub-statuses.
  @ignore
  SyncState get syncState {
    if (isFullySynced) return SyncState.synced;
    if (status == 'uploading') return SyncState.uploading;
    if (status == 'failed') return SyncState.failed;
    return SyncState.local;
  }
}