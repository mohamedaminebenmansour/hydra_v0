import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// One place where a thread event's media is interpreted ("Hybrid Shield").
//
// Events live inside `Report.timelineEvents` / `Report.activityLog` as flat JSON
// strings (`{"actor":..,"action":..,"text":..,"photoUrl":..,"voiceUrl":..,
// "time":..}`) and are mirrored 1:1 into the Supabase `timeline_events` /
// `activity_log` JSONB columns.
//
// Historically ONE field carried both meanings: a freshly captured event stored
// the LOCAL FILE PATH in `photoUrl` / `voiceUrl` and the sync flow replaced it
// with the public URL after the upload. That overload is what made local
// cleanup dangerous — once the file was reclaimed the URL was gone, so the
// event could neither fall back to the cloud nor be reclaimed safely, and
// pushing it could put a dead path over a valid cloud URL.
//
// The shape is now a pair (`photoPath` + `photoUrl`, `voicePath` + `voiceUrl`):
// the path addresses the local file while it exists, the URL always addresses
// the cloud copy. Every legacy shape is still understood, so rows written by
// older builds keep rendering exactly as before.
// ---------------------------------------------------------------------------

/// One medium of an event: [path] is the local file ('' when there is none),
/// [url] is the cloud copy ('' when it was never uploaded).
typedef EventMedia = ({String path, String url});

/// The two media pairs every event can carry, in processing order.
const List<(String, String)> _mediaFields = [
  ('photoPath', 'photoUrl'),
  ('voicePath', 'voiceUrl'),
];

/// [value] when it is a real cloud URL, otherwise null. A local path, an empty
/// string and a whitespace-only value all mean "not a URL": this is the guard
/// used before any URL field is written, so a push can never store a path — or
/// an empty string — where a URL belongs.
String? hostedUrl(String? value) {
  final raw = (value ?? '').trim();
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  return null;
}

/// Existence probe used when a caller injects none of its own: synchronous and
/// never throwing (a URL passed as a path, or a permission problem, simply means
/// "not a local file").
bool defaultEventFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (e) {
    debugPrint('EventMedia: existence probe failed for "$path": $e');
    return false;
  }
}

/// Reads the (path, url) pair behind [pathKey] / [urlKey] of [event],
/// normalising both legacy shapes:
///  * new shape — the path field is explicit (a URL that ended up in it, as
///    pulled rows do, is still a URL and never a file);
///  * legacy shape — one field carried both: an http(s) value is the cloud URL,
///    anything else is the local path.
EventMedia eventMediaOf(
  Map<String, dynamic> event,
  String pathKey,
  String urlKey,
) {
  final rawPath = (event[pathKey] ?? '').toString().trim();
  final rawUrl = (event[urlKey] ?? '').toString().trim();

  if (rawPath.isNotEmpty) {
    final hostedPath = hostedUrl(rawPath);
    if (hostedPath != null) {
      return (path: '', url: hostedUrl(rawUrl) ?? hostedPath);
    }
    return (path: rawPath, url: hostedUrl(rawUrl) ?? '');
  }

  final hosted = hostedUrl(rawUrl);
  if (hosted != null) return (path: '', url: hosted);
  if (rawUrl.isNotEmpty) return (path: rawUrl, url: '');
  return (path: '', url: '');
}

/// The photo of [event] (local path + cloud URL). Never throws.
EventMedia eventPhotoOf(Map<String, dynamic> event) =>
    eventMediaOf(event, 'photoPath', 'photoUrl');

/// The voice note of [event] (local path + cloud URL). Never throws.
EventMedia eventVoiceOf(Map<String, dynamic> event) =>
    eventMediaOf(event, 'voicePath', 'voiceUrl');

/// True when [event] carries any photo or voice at all.
bool eventHasMedia(Map<String, dynamic> event) {
  final photo = eventPhotoOf(event);
  final voice = eventVoiceOf(event);
  return photo.path.isNotEmpty ||
      photo.url.isNotEmpty ||
      voice.path.isNotEmpty ||
      voice.url.isNotEmpty;
}

/// The event with its media fields normalised for LOCAL storage:
///  * a path is kept only while the file is really on disk (a path whose file
///    was reclaimed is dropped, never resurrected);
///  * the URL fields only ever hold a real http(s) URL, and an existing URL is
///    always preserved;
///  * every other key is carried through untouched.
Map<String, dynamic> normalizeEventMedia(
  Map<String, dynamic> event, {
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? defaultEventFileExists;
  final out = Map<String, dynamic>.from(event);
  for (final pair in _mediaFields) {
    final media = eventMediaOf(out, pair.$1, pair.$2);
    final url = hostedUrl(media.url);
    if (url != null) {
      out[pair.$2] = url;
    } else if ((out[pair.$2] ?? '').toString().isNotEmpty) {
      // A non-URL value has no business in a URL field; a live local path it
      // may hold is preserved below, in the PATH field.
      out.remove(pair.$2);
    }
    if (media.path.isNotEmpty && exists(media.path)) {
      out[pair.$1] = media.path;
    } else if ((out[pair.$1] ?? '').toString().isNotEmpty) {
      // A path whose file is gone is dropped, never resurrected.
      out.remove(pair.$1);
    }
  }
  return out;
}

/// [normalizeEventMedia] for one stored JSON event. An entry that cannot be
/// decoded is returned exactly as it was — a malformed event must survive a
/// cleanup untouched, never become an empty one.
String normalizeEventJson(String raw, {bool Function(String path)? fileExists}) {
  final event = decodeEvent(raw);
  if (event == null) return raw;
  final encoded = jsonEncode(
    normalizeEventMedia(event, fileExists: fileExists),
  );
  return encoded == raw ? raw : encoded;
}

/// The event exactly as it may be PUSHED to Supabase: cloud URLs only.
///
/// Local paths are dropped (a device path means nothing in the cloud, and could
/// otherwise overwrite remote evidence), and a URL field is written only when it
/// really holds an http(s) URL — never a path, never an empty string. The keys
/// are removed instead, so an upsert can only ever add information.
Map<String, dynamic> eventForCloud(Map<String, dynamic> event) {
  final out = Map<String, dynamic>.from(event);
  for (final pair in _mediaFields) {
    final url = hostedUrl(eventMediaOf(out, pair.$1, pair.$2).url);
    if (url == null) {
      out.remove(pair.$2);
    } else {
      out[pair.$2] = url;
    }
    out.remove(pair.$1);
  }
  return out;
}

/// [eventForCloud] applied to a whole stored thread, ready for the push payload.
List<String> cloudEventList(List<String> rawEvents) => [
  for (final raw in rawEvents) _cloudEventJson(raw),
];

/// A URL-only column for a push payload: present only when [value] really is a
/// cloud URL.
///
/// "Hybrid Shield" guarantee: the 7-day cleanup may empty a local path at any
/// moment, and a device can hold a stale or path-shaped value — none of that may
/// ever reach Supabase, where it would replace evidence that is still valid.
/// Omitting the key leaves the remote value untouched on an upsert instead of
/// overwriting it with a path or an empty string.
Map<String, dynamic> urlOnlyField(String column, String value) {
  final url = hostedUrl(value);
  return url == null ? const <String, dynamic>{} : {column: url};
}

/// One stored event encoded for the cloud (undecodable entries stay verbatim).
String _cloudEventJson(String raw) {
  final event = decodeEvent(raw);
  if (event == null) return raw;
  return jsonEncode(eventForCloud(event));
}

/// Decodes one stored event, or null when it is not a JSON object.
Map<String, dynamic>? decodeEvent(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (e) {
    debugPrint('EventMedia: skipping malformed event: $e');
  }
  return null;
}
