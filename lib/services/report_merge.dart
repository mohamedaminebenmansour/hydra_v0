import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/report.dart';

/// Union-only merge of a remote Supabase row into a local [Report].
///
/// The app is offline-first: a device's local record is its working copy, so a
/// "remote overwrites local" pull is not acceptable (it would drop photos still
/// queued for upload). This merge therefore only ever *adds* information:
///
///  * `timelineEvents` and `activityLog` are unioned (deduped, oldest first), so
///    the Subcontractor <-> Team Leader thread and the audit trail survive a
///    pull from either side. That is what makes a TL rejection reason reach the
///    subcontractor's device, and a "how I fixed it" note reach the TL's device.
///  * the Team Leader gate decision is adopted unless the local decision is
///    newer — a stale remote copy can never undo a fresh local rejection.
///  * the cloud row id, coordinates, media URLs and gate proof media are only
///    filled in where the local value is missing, and local media that still
///    exists on disk always wins.
///  * local working state is NEVER touched: `photoPath`, `voicePath`, the
///    per-piece sync sub-statuses, `status`. The owner status is likewise left
///    alone — it is owned by `SyncService.checkOwnerUpdates`.
///
/// Pure by design: no Isar, no network, no clock. The caller persists the
/// record (see `SyncService.pullRemoteChanges`), which keeps this logic unit
/// testable with plain in-memory [Report] objects.
///
/// Returns true when anything changed, so the caller can skip a pointless write.
bool mergeRemoteReport(Report local, Map<String, dynamic> remote) {
  final changes = _Changes();

  // Identity / linkage: adopt the remote id so the next push updates the
  // existing row instead of inserting a duplicate.
  local.supabaseId = changes.set(
    local.supabaseId,
    _adoptString(local.supabaseId, remote['id']),
  );

  // Coordinates: only when the local report has none (0,0 means "no GPS").
  if (local.lat == 0 && local.lng == 0) {
    final lat = (remote['lat'] as num?)?.toDouble() ?? 0;
    final lng = (remote['lng'] as num?)?.toDouble() ?? 0;
    if (lat != 0 || lng != 0) {
      local.lat = changes.set(local.lat, lat);
      local.lng = changes.set(local.lng, lng);
    }
  }

  // Cloud media URLs: fill gaps only, the local file stays the working copy.
  local.photoUrl = changes.set(
    local.photoUrl,
    _adoptString(local.photoUrl, remote['photo_url']),
  );
  local.voiceUrl = changes.set(
    local.voiceUrl,
    _adoptString(local.voiceUrl, remote['voice_url']),
  );

  _mergeTlGate(local, remote, changes);

  // Shared threads (the chat + the audit trail).
  final timeline = _mergeEventList(
    local.timelineEvents,
    remote['timeline_events'],
  );
  if (!listEquals(timeline, local.timelineEvents)) {
    changes.any = true;
    local.timelineEvents = timeline;
  }
  final activity = _mergeEventList(local.activityLog, remote['activity_log']);
  if (!listEquals(activity, local.activityLog)) {
    changes.any = true;
    local.activityLog = activity;
  }

  return changes.any;
}

/// Merges the Team Leader gate ("Chef de Chantier Gate") state.
///
/// The remote decision wins only when the local side has no decision, or when
/// the remote one was taken strictly later. Proof media URLs are adopted only
/// when the local counterpart is empty, and mirrored into the `...Path` fields
/// so `ReportLocalService.resolveMedia` can display them (same overload used by
/// the initial pull).
void _mergeTlGate(Report local, Map<String, dynamic> remote, _Changes changes) {
  final remoteType = (remote['tl_validation_type'] ?? '').toString();
  final remoteAt = _parseDate(remote['tl_validated_at']);
  final localAt = local.tlValidatedAt;
  final adoptDecision =
      remoteType.isNotEmpty &&
      (localAt == null || (remoteAt != null && remoteAt.isAfter(localAt)));
  if (adoptDecision) {
    local.tlValidationType = changes.set(local.tlValidationType, remoteType);
    if (remoteAt != null) {
      local.tlValidatedAt = changes.set(local.tlValidatedAt, remoteAt);
    }
  }

  local.tlValidationPhotoUrl = changes.set(
    local.tlValidationPhotoUrl,
    _adoptString(local.tlValidationPhotoUrl, remote['tl_validation_photo_url']),
  );
  if (local.tlValidationPhotoPath.isEmpty &&
      local.tlValidationPhotoUrl.isNotEmpty) {
    local.tlValidationPhotoPath = changes.set(
      local.tlValidationPhotoPath,
      local.tlValidationPhotoUrl,
    );
  }

  local.tlRejectionPhotoUrl = changes.set(
    local.tlRejectionPhotoUrl,
    _adoptString(local.tlRejectionPhotoUrl, remote['tl_rejection_photo_url']),
  );
  if (local.tlRejectionPhotoPath.isEmpty &&
      local.tlRejectionPhotoUrl.isNotEmpty) {
    local.tlRejectionPhotoPath = changes.set(
      local.tlRejectionPhotoPath,
      local.tlRejectionPhotoUrl,
    );
  }

  local.tlRejectionVoiceUrl = changes.set(
    local.tlRejectionVoiceUrl,
    _adoptString(local.tlRejectionVoiceUrl, remote['tl_rejection_voice_url']),
  );
}

/// Unions a local event list with its remote counterpart.
///
/// Both sides are decoded to maps, deduped by actor+action+time+text, and
/// re-encoded oldest first. For an event present on both sides the local media
/// is kept while the file still exists on disk, otherwise the cloud URL is
/// adopted — so a pull can never delete a capture that has not been uploaded
/// yet, and never lose the URL once the file has been reclaimed.
List<String> _mergeEventList(List<String> localRaw, dynamic remoteRaw) {
  final merged = <String, Map<String, dynamic>>{};
  for (final raw in localRaw) {
    final entry = _decodeEntry(raw);
    if (entry == null) continue;
    merged.putIfAbsent(_eventKey(entry), () => entry);
  }
  for (final entry in _decodeRemoteEntries(remoteRaw)) {
    final key = _eventKey(entry);
    final existing = merged[key];
    if (existing == null) {
      merged[key] = entry;
      continue;
    }
    for (final field in const ['photoUrl', 'voiceUrl']) {
      final current = (existing[field] ?? '').toString();
      final remoteValue = (entry[field] ?? '').toString();
      final chosen = _preferLocalMedia(current, remoteValue);
      if (chosen != current) existing[field] = chosen;
    }
  }
  final out = merged.values.toList()
    ..sort((a, b) {
      final byTime = _eventTime(a).compareTo(_eventTime(b));
      // Deterministic tie-break: `List.sort` is not stable, and a pull must
      // produce the same order on every device.
      return byTime != 0 ? byTime : _eventKey(a).compareTo(_eventKey(b));
    });
  return out.map(jsonEncode).toList();
}

/// Normalises the two shapes Supabase can hand back for a JSONB column: an
/// already-decoded list of objects (`timeline_events`) or a JSON string holding
/// that list (`activity_log` is pushed with `jsonEncode`). Anything else — a
/// null column, a malformed value — simply contributes no entries.
List<Map<String, dynamic>> _decodeRemoteEntries(dynamic remoteRaw) {
  dynamic value = remoteRaw;
  if (value is String) {
    if (value.isEmpty) return const <Map<String, dynamic>>[];
    try {
      value = jsonDecode(value);
    } catch (e) {
      debugPrint('MergeFlow: remote event list is not valid JSON: $e');
      return const <Map<String, dynamic>>[];
    }
  }
  if (value is! List) return const <Map<String, dynamic>>[];
  final entries = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is Map) {
      entries.add(Map<String, dynamic>.from(item));
    } else if (item is String) {
      final decoded = _decodeEntry(item);
      if (decoded != null) entries.add(decoded);
    }
  }
  return entries;
}

/// Decodes one stored event, preserving every key (unknown fields written by a
/// different build are carried through rather than dropped).
Map<String, dynamic>? _decodeEntry(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (e) {
    debugPrint('MergeFlow: skipping malformed event: $e');
  }
  return null;
}

/// The identity of an event for deduplication: the same actor doing the same
/// action at the same instant with the same message is one event, not two.
String _eventKey(Map<String, dynamic> entry) {
  return '${(entry['actor'] ?? '')}|${(entry['action'] ?? '')}|'
      '${(entry['time'] ?? '')}|${(entry['text'] ?? '')}';
}

/// The event's instant, or the epoch when it has no (parsable) timestamp so
/// sorting stays deterministic.
DateTime _eventTime(Map<String, dynamic> entry) {
  return _parseDate(entry['time']) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Keeps [localValue] while it still points at a file on this device, otherwise
/// takes the remote (cloud URL) value.
String _preferLocalMedia(String localValue, String remoteValue) {
  if (localValue.isNotEmpty && _isExistingFile(localValue)) return localValue;
  if (remoteValue.isNotEmpty) return remoteValue;
  return localValue;
}

/// Synchronous, never-throwing existence probe: a URL in a path field, an empty
/// string or a permission problem all just mean "not a local file".
bool _isExistingFile(String value) {
  try {
    return File(value).existsSync();
  } catch (e) {
    debugPrint('MergeFlow: media probe failed for "$value": $e');
    return false;
  }
}

/// Keeps [current] when it already holds a value, otherwise adopts the remote
/// one (a blank local field means "never had it").
String _adoptString(String current, dynamic remoteValue) {
  if (current.isNotEmpty) return current;
  return (remoteValue ?? '').toString();
}

/// Parses a remote ISO-8601 timestamp into local time, tolerating the missing /
/// null / literal-"null" values that JDBC-style clients can emit.
DateTime? _parseDate(dynamic value) {
  final raw = (value ?? '').toString();
  if (raw.isEmpty || raw == 'null') return null;
  return DateTime.tryParse(raw)?.toLocal();
}

/// Tiny mutation tracker: every assignment goes through [set] so the merge can
/// report "nothing changed" and the caller can skip a pointless database write.
class _Changes {
  bool any = false;

  T set<T>(T current, T next) {
    if (next != current) any = true;
    return next;
  }
}
