import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// "Material Reception": path to the reception photo on the local filesystem,
  /// captured when the field team receives an ordered material. Empty for every
  /// report that did not go through the reception flow.
  String receptionPhotoPath = '';

  /// "Material Reception": path to the reception voice note on the local
  /// filesystem. Empty when none was recorded.
  String receptionVoicePath = '';

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

  /// Public URLs of the "Material Reception" media, returned by Supabase storage
  /// after a successful upload (photo in the `photo` bucket, voice in `voice`).
  /// A non-empty URL is the "already uploaded" flag — exactly like
  /// [tlValidationPhotoUrl] — so a retry never re-uploads the same file.
  String receptionPhotoUrl = '';
  String receptionVoiceUrl = '';

  /// Owner's workflow decision, pulled from Supabase. One of:
  /// 'pending', 'validated', 'acknowledged', 'approved', 'rejected', 'ordered'.
  String ownerStatus = 'pending';

  /// When the owner status last changed (drives the red 24h badge).
  DateTime? ownerStatusAt;

  /// Problem category for problem-type reports.
  /// One of: 'general', 'machine', 'material_missing', 'soil', 'external'.
  String problemCategory = 'general';

  // ---------------------------------------------------------------------------
  // "Chef de Chantier Gate": the Team Leader verification step.
  // ---------------------------------------------------------------------------

  /// When the Team Leader validated this report. Null while still awaiting
  /// verification (the report then shows up under the History 'TO VERIFY' tab).
  DateTime? tlValidatedAt;

  /// Identifier of the Team Leader who validated the report.
  String tlValidatorId = '';

  /// How the validation happened. One of: 'physical' (TL was within 50 m of the
  /// report), 'remote' (photo-only, or the TL wasn't on the exact spot),
  /// 'rejected' ("Dispute Shield": the TL rejected and asked for a fix), or ''
  /// when the report has not been validated yet.
  String tlValidationType = '';

  /// Path to the TL's proof photo on the local filesystem. Empty for
  /// remote-only validations; kept so an offline validation can be uploaded by
  /// the sync flow later (mirrors [photoPath] -> [photoUrl]).
  String tlValidationPhotoPath = '';

  /// Public URL of the TL's proof photo returned by Supabase storage after a
  /// successful upload. Persisted so a retry never re-uploads the same file.
  String tlValidationPhotoUrl = '';

  /// Local path of the "Dispute Shield" rejection proof photo, captured when the
  /// TL rejects a report. Uploaded by the sync flow to
  /// [tlRejectionPhotoUrl]; empty until a rejection happens.
  String tlRejectionPhotoPath = '';

  /// Local path of the "Dispute Shield" rejection voice note, captured when the
  /// TL rejects a report. Uploaded by the sync flow to
  /// [tlRejectionVoiceUrl]; empty until a rejection happens.
  String tlRejectionVoicePath = '';

  /// Remote URL of the "Dispute Shield" rejection proof photo once uploaded.
  String tlRejectionPhotoUrl = '';

  /// Remote URL of the "Dispute Shield" rejection voice note once uploaded.
  String tlRejectionVoiceUrl = '';

  /// Append-only audit trail of the report's life ("Fix & Resubmit" loop).
  /// Each entry is a flat JSON string:
  /// `{"actor":"tl|sub|owner","action":"...","photoPath":"...","voicePath":"...",
  ///   "photoUrl":"...","voiceUrl":"...","time":"ISO-8601"}`. Kept as raw
  /// strings so it maps 1:1 to the Supabase `activity_log JSONB` column without
  /// extra models. The `*Path` fields are the local proof files (dropped once
  /// the file is reclaimed), the `*Url` fields their cloud copies — see
  /// `services/event_media.dart`, the single place both are interpreted.
  List<String> activityLog = [];

  /// Append-only event log for the Detail Screen timeline. Each entry is a
  /// flat JSON string:
  /// `{"actor":"sub|tl","action":"submit|resubmit|reject|comment|...",
  ///   "text":"why it was rejected / how it was fixed","photoPath":"...",
  ///   "voicePath":"...","photoUrl":"...","voiceUrl":"...","time":"ISO-8601"}`.
  /// Never overwritten: every new action appends, so the full dispute history —
  /// and the Sub/TL chat thread built on top of it — is preserved.
  ///
  /// [text] is optional and absent on events written by older builds; those
  /// carry their media in `photoUrl` / `voiceUrl` alone (a local path or a cloud
  /// URL), which `eventPhotoOf` / `eventVoiceOf` still resolve.
  List<String> timelineEvents = [];

  /// Read receipt for the History card's unread indicator (WhatsApp-style
  /// blue dot). A **per-device** flag: the sheet that shows the thread marks
  /// the report read, and every newly appended [timelineEvents] entry marks
  /// it unread again. Never synced — each device tracks its own reading.
  bool isReadByUser = false;

  /// True when this report still needs a Team Leader gate decision.
  ///
  /// Only 'work' and 'material' reports pass through the gate; 'problem'
  /// reports stay on the reporting flow and are never gated.
  @ignore
  bool get needsTlValidation =>
      (type == 'work' || type == 'material') && tlValidatedAt == null;

  /// 'Dispute Shield': a Team Leader rejected this report and asked for a fix.
  /// This is a TL-layer decision and never touches [ownerStatus].
  @ignore
  bool get isTlRejected => tlValidationType == 'rejected';

  // ---------------------------------------------------------------------------
  // "Material Reception": the material the Owner ordered is received on site
  // with a photo of the delivery plus a voice note, and a binary verdict —
  // accepted ('validated') or something missing/broken ('rejected').
  // ---------------------------------------------------------------------------

  /// The field team already handled the delivery: a reception capture exists (a
  /// live local file, or its cloud copy once the file was reclaimed), so the
  /// 'RECEIVE MATERIAL' action is gone for good.
  @ignore
  bool get hasReceptionMedia =>
      receptionPhotoPath.isNotEmpty || receptionPhotoUrl.isNotEmpty;

  /// A material report the Owner ordered and nobody has received yet — exactly
  /// the state that offers the giant 'RECEIVE MATERIAL' button.
  @ignore
  bool get awaitsMaterialReception =>
      type == 'material' && ownerStatus == 'ordered' && !hasReceptionMedia;

  /// The delivery was received with a problem (missing or broken items): the
  /// red delivery-dispute state the Owner must be able to see.
  @ignore
  bool get hasDeliveryDispute =>
      hasReceptionMedia && ownerStatus == 'rejected';

  /// Appends one entry to [activityLog] (see its doc comment for the format).
  /// [time] defaults to now; [photoPath] / [voicePath] record the local proof
  /// files and [photoUrl] / [voiceUrl] their cloud copies, so the thread still
  /// works offline and still has an image once the local file is reclaimed.
  void logActivity({
    required String actor,
    required String action,
    String photoPath = '',
    String voicePath = '',
    String photoUrl = '',
    String voiceUrl = '',
    DateTime? time,
  }) {
    final entry = jsonEncode({
      'actor': actor,
      'action': action,
      'photoPath': photoPath,
      'voicePath': voicePath,
      'photoUrl': photoUrl,
      'voiceUrl': voiceUrl,
      'time': (time ?? DateTime.now()).toUtc().toIso8601String(),
    });
    activityLog = [...activityLog, entry];
  }

  /// Appends one immutable event to [timelineEvents] with safe defaults so a
  /// null or missing field never crashes `jsonEncode` or the UI decoder.
  ///
  /// [text] is the chat message carried by the event: the Team Leader's reason
  /// when [action] is 'reject', or the subcontractor's explanation when it is
  /// 'fix_note'. It is optional so the historical (media-only) call sites keep
  /// working unchanged.
  void addTimelineEvent({
    required String actor,
    required String action,
    String text = '',
    String photoPath = '',
    String voicePath = '',
    String photoUrl = '',
    String voiceUrl = '',
    DateTime? time,
  }) {
    final entry = jsonEncode({
      'actor': actor,
      'action': action,
      'text': text,
      'photoPath': photoPath,
      'voicePath': voicePath,
      'photoUrl': photoUrl,
      'voiceUrl': voiceUrl,
      'time': (time ?? DateTime.now()).toUtc().toIso8601String(),
    });
    timelineEvents = [...timelineEvents, entry];
    // A fresh thread event means there is news on this report: the History
    // card flips to its unread state until the user opens the sheet again.
    // (The acting device re-marks it read in the same session — see the
    // report sheet — so a user never flags their own action as unread.)
    isReadByUser = false;
  }

  /// Decodes [timelineEvents] for display (the shared Sub/TL chat thread).
  /// Malformed entries (older builds, hand-edited rows) are dropped instead of
  /// throwing — a thread must never crash the report sheet.
  ///
  /// Every entry is normalised so the UI can read `actor`, `action`, `text`,
  /// `photoPath`, `photoUrl`, `voicePath`, `voiceUrl` and `time` without null
  /// checks; `text` is `''` for events written before the chat existed, and the
  /// path fields are `''` for events written before the pair existed (their
  /// single media field — a local path or a cloud URL — is read through
  /// `eventPhotoOf` / `eventVoiceOf`, which understand both shapes).
  List<Map<String, dynamic>> parseTimelineEvents() {
    final entries = <Map<String, dynamic>>[];
    for (final raw in timelineEvents) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          entries.add({
            'actor': (decoded['actor'] ?? '').toString(),
            'action': (decoded['action'] ?? '').toString(),
            'text': (decoded['text'] ?? '').toString(),
            'photoPath': (decoded['photoPath'] ?? '').toString(),
            'voicePath': (decoded['voicePath'] ?? '').toString(),
            'photoUrl': (decoded['photoUrl'] ?? '').toString(),
            'voiceUrl': (decoded['voiceUrl'] ?? '').toString(),
            'time': (decoded['time'] ?? '').toString(),
          });
        }
      } catch (e) {
        debugPrint('TimelineFlow: skipping malformed event: $e');
      }
    }
    return entries;
  }

  /// Decodes [activityLog] for display. Malformed entries (older builds,
  /// hand-edited rows) are dropped instead of throwing — a timeline must
  /// never crash the detail screen.
  List<Map<String, dynamic>> parseActivityLog() {
    final entries = <Map<String, dynamic>>[];
    for (final raw in activityLog) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) entries.add(decoded);
      } catch (e) {
        debugPrint('ActivityLog: skipping malformed entry: $e');
      }
    }
    return entries;
  }

  /// The Team Leader has signed off on this report ('physical' or 'remote').
  /// Distinct from the Owner layer ([ownerStatus]) which is driven from Supabase.
  @ignore
  bool get isTlVerified =>
      tlValidationType == 'physical' || tlValidationType == 'remote';

  /// True when the photo upload has been completed (local file uploaded).
  bool get isPhotoSynced => photoStatus == 'synced';
  bool get isVoiceSynced => voicePath.isEmpty || voiceStatus == 'synced';
  bool get isDbSynced => dbStatus == 'synced';

  /// A report is fully synced only when all three sub-pieces succeeded.
  bool get isFullySynced => isPhotoSynced && isVoiceSynced && isDbSynced;

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

  /// Owner decisions that mean the field team is done with a report, so the
  /// local media files are no longer the working copy.
  static const Set<String> terminalOwnerStatuses = {
    'validated',
    'acknowledged',
    'rejected',
  };

  /// True when this report's local media may be reclaimed ("Hybrid Shield"):
  /// the cloud copy is complete ([syncState] is `synced`) AND either the owner
  /// has finished with the report or it is older than [cutoff].
  ///
  /// [syncState] is `@ignore`, so this can never be used inside an Isar filter
  /// — it is evaluated in Dart after a cheap `status` pre-filter.
  bool isMediaReclaimable(DateTime cutoff) =>
      syncState == SyncState.synced &&
      (terminalOwnerStatuses.contains(ownerStatus) ||
          timestamp.isBefore(cutoff));
}
