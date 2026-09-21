import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/services/report_merge.dart';

/// The fixed instant all fixtures share.
final DateTime _t0 = DateTime.utc(2026, 9, 18, 9, 30);
final DateTime _t1 = DateTime.utc(2026, 9, 18, 10, 0);

/// One event exactly as it is stored: raw JSON, the same shape both the local
/// `timelineEvents` list and the Supabase `timeline_events` column use.
String eventJson({
  required String actor,
  required String action,
  String text = '',
  String photoUrl = '',
  String voiceUrl = '',
  DateTime? time,
}) => jsonEncode({
  'actor': actor,
  'action': action,
  'text': text,
  'photoUrl': photoUrl,
  'voiceUrl': voiceUrl,
  'time': (time ?? _t0).toUtc().toIso8601String(),
});

/// A pending local report with one 'submit' event from the subcontractor.
Report localReport() {
  final report = Report()
    ..type = 'work'
    ..timestamp = _t0;
  report.addTimelineEvent(actor: 'sub', action: 'submit', time: _t0);
  return report;
}

/// Tests for the union-only pull merge: the piece that lets a Team Leader's
/// rejection reason reach the subcontractor's device (and a fix note reach the
/// TL's device) without ever discarding local, not-yet-uploaded work.
void main() {
  group('threads', () {
    test('a rejection typed on the TL device lands in the local thread', () {
      final local = localReport();
      final merged = mergeRemoteReport(local, {
        'local_id': '1',
        'timeline_events': [
          {
            'actor': 'tl',
            'action': 'reject',
            'text': 'Chantier non nettoyé, merci de reprendre.',
            'photoUrl': 'https://cdn/reject.jpg',
            'voiceUrl': '',
            'time': _t1.toUtc().toIso8601String(),
          },
        ],
      });

      expect(merged, isTrue);
      final events = local.parseTimelineEvents();
      expect(events.length, 2);
      // Oldest first: the submission, then the rejection.
      expect(events.first['action'], 'submit');
      expect(events.last['actor'], 'tl');
      expect(events.last['action'], 'reject');
      expect(events.last['text'], 'Chantier non nettoyé, merci de reprendre.');
      expect(events.last['photoUrl'], 'https://cdn/reject.jpg');
    });

    test('a fix note typed on the sub device lands in the local thread', () {
      final local = localReport();
      final merged = mergeRemoteReport(local, {
        'timeline_events': [
          {
            'actor': 'sub',
            'action': 'fix_note',
            'text': 'Nettoyé et évacué ce matin.',
            'time': _t1.toUtc().toIso8601String(),
          },
        ],
      });

      expect(merged, isTrue);
      expect(
        local.parseTimelineEvents().last['text'],
        'Nettoyé et évacué ce matin.',
      );
    });

    test('the same event on both sides is stored once', () {
      final local = localReport();
      final merged = mergeRemoteReport(local, {
        // The very same jsonEncode'd entry coming back from the cloud.
        'timeline_events': local.timelineEvents,
      });

      expect(merged, isFalse);
      expect(local.parseTimelineEvents().length, 1);
    });

    test('media-only events from older builds still merge', () {
      // An event written before the chat existed: no `text` key at all.
      final legacy = jsonEncode({
        'actor': 'tl',
        'action': 'reject',
        'photoUrl': 'https://cdn/reject.jpg',
        'voiceUrl': 'https://cdn/reject.m4a',
        'time': _t1.toUtc().toIso8601String(),
      });
      final local = localReport();

      expect(
        mergeRemoteReport(local, {
          'timeline_events': [legacy],
        }),
        isTrue,
      );
      final events = local.parseTimelineEvents();
      expect(events.length, 2);
      expect(events.last['text'], '');
      expect(events.last['voiceUrl'], 'https://cdn/reject.m4a');
    });

    test('the audit trail is merged too, whether list or JSON string', () {
      final local = localReport();
      local.logActivity(actor: 'sub', action: 'submitted', time: _t0);
      final remoteEntry = jsonEncode({
        'actor': 'tl',
        'action': 'rejected',
        'photoUrl': '',
        'voiceUrl': '',
        'time': _t1.toUtc().toIso8601String(),
      });

      // The app pushes activity_log as a JSON *string*; both shapes must work.
      expect(
        mergeRemoteReport(local, {'activity_log': '[$remoteEntry]'}),
        isTrue,
      );
      expect(local.parseActivityLog().length, 2);
      expect(
        mergeRemoteReport(local, {'activity_log': '[$remoteEntry]'}),
        isFalse,
      );
    });

    test('malformed entries are skipped instead of aborting the pull', () {
      final local = localReport();
      expect(
        mergeRemoteReport(local, {
          'timeline_events': ['not-json', 42],
          'activity_log': 'not-json-either',
        }),
        isFalse,
      );
      expect(local.parseTimelineEvents().length, 1);
    });
  });

  group('media inside events', () {
    test('a local capture survives the pull while its file exists', () {
      // A real file on disk stands in for a capture still queued for upload.
      final dir = Directory.systemTemp.createTempSync('hydra_merge_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/photo.jpg')..writeAsStringSync('jpeg');

      final local = Report()..timestamp = _t0;
      local.addTimelineEvent(
        actor: 'sub',
        action: 'submit',
        photoUrl: file.path,
        time: _t0,
      );

      final merged = mergeRemoteReport(local, {
        'timeline_events': [
          {
            'actor': 'sub',
            'action': 'submit',
            'text': '',
            'photoUrl': 'https://cdn/submit.jpg',
            'voiceUrl': '',
            'time': _t0.toUtc().toIso8601String(),
          },
        ],
      });

      // Nothing was rewritten: the local path is still the working copy.
      expect(merged, isFalse);
      expect(local.parseTimelineEvents().single['photoUrl'], file.path);
    });

    test('the cloud URL is adopted once the local file is gone', () {
      final local = Report()..timestamp = _t0;
      local.addTimelineEvent(
        actor: 'sub',
        action: 'submit',
        photoUrl: '/tmp/that/file/is/gone.jpg',
        time: _t0,
      );

      expect(
        mergeRemoteReport(local, {
          'timeline_events': [
            {
              'actor': 'sub',
              'action': 'submit',
              'text': '',
              'photoUrl': 'https://cdn/submit.jpg',
              'voiceUrl': '',
              'time': _t0.toUtc().toIso8601String(),
            },
          ],
        }),
        isTrue,
      );
      expect(
        local.parseTimelineEvents().single['photoUrl'],
        'https://cdn/submit.jpg',
      );
    });

    test('a reclaimed path is dropped and the cloud URL adopted (pair shape)', () {
      // The event carries the new (path + url) pair, but the file has been
      // reclaimed: the URL must be adopted and the dead path must NOT come back.
      final local = Report()..timestamp = _t0;
      local.addTimelineEvent(
        actor: 'sub',
        action: 'submit',
        photoPath: '/tmp/reclaimed/photo.jpg',
        time: _t0,
      );

      final merged = mergeRemoteReport(local, {
        'timeline_events': [
          {
            'actor': 'sub',
            'action': 'submit',
            'text': '',
            'photoPath': '/tmp/reclaimed/photo.jpg',
            'photoUrl': 'https://cdn/submit.jpg',
            'voiceUrl': '',
            'time': _t0.toUtc().toIso8601String(),
          },
        ],
      });

      expect(merged, isTrue);
      final event = local.parseTimelineEvents().single;
      expect(event['photoUrl'], 'https://cdn/submit.jpg');
      expect(event['photoPath'], ''); // gone for good, never resurrected
    });
  });

  group('Team Leader gate', () {
    test('the remote decision is adopted when the local report has none', () {
      final local = localReport();

      expect(
        mergeRemoteReport(local, {
          'id': 'row-1',
          'tl_validated_at': _t1.toUtc().toIso8601String(),
          'tl_validation_type': 'rejected',
          'tl_rejection_photo_url': 'https://cdn/reject.jpg',
          'tl_rejection_voice_url': 'https://cdn/reject.m4a',
        }),
        isTrue,
      );

      expect(local.tlValidationType, 'rejected');
      expect(local.isTlRejected, isTrue);
      expect(local.tlValidatedAt, isNotNull);
      // Rejection proof media is adopted, and mirrored into the path fields the
      // media resolver reads.
      expect(local.tlRejectionPhotoUrl, 'https://cdn/reject.jpg');
      expect(local.tlRejectionPhotoPath, 'https://cdn/reject.jpg');
      expect(local.tlRejectionVoiceUrl, 'https://cdn/reject.m4a');
      // The remote id is adopted so the next push updates instead of inserting.
      expect(local.supabaseId, 'row-1');
    });

    test('a stale remote decision never undoes a fresh local rejection', () {
      final local = localReport()
        ..tlValidatedAt = _t1.add(const Duration(hours: 1))
        ..tlValidationType = 'rejected';

      expect(
        mergeRemoteReport(local, {
          'tl_validated_at': _t0.toUtc().toIso8601String(),
          'tl_validation_type': 'physical',
        }),
        isFalse,
      );
      expect(local.tlValidationType, 'rejected');
    });

    test('a cleared remote decision does not erase the local one', () {
      final local = localReport()
        ..tlValidatedAt = _t1
        ..tlValidationType = 'physical';

      expect(
        mergeRemoteReport(local, {
          'tl_validated_at': _t0.toUtc().toIso8601String(),
          'tl_validation_type': '',
        }),
        isFalse,
      );
      expect(local.tlValidationType, 'physical');
    });
  });

  group('local working state', () {
    test('media paths, sync statuses and owner status are never touched', () {
      final local = localReport()
        ..photoPath = '/tmp/local.jpg'
        ..voicePath = '/tmp/local.m4a'
        ..photoStatus = 'pending'
        ..voiceStatus = 'pending'
        ..dbStatus = 'pending'
        ..status = 'local'
        ..ownerStatus = 'validated';

      final merged = mergeRemoteReport(local, {
        'id': 'row-9',
        'photo_url': 'https://cdn/photo.jpg',
        'voice_url': 'https://cdn/voice.m4a',
        'lat': 36.8,
        'lng': 10.1,
        'owner_status': 'rejected',
        'tl_validation_type': 'physical',
        'tl_validated_at': _t1.toUtc().toIso8601String(),
      });

      expect(merged, isTrue);
      // Cloud URLs fill the gaps...
      expect(local.photoUrl, 'https://cdn/photo.jpg');
      expect(local.voiceUrl, 'https://cdn/voice.m4a');
      expect(local.lat, 36.8);
      expect(local.lng, 10.1);
      // ...but the local working copy and its sync machine are untouched.
      expect(local.photoPath, '/tmp/local.jpg');
      expect(local.voicePath, '/tmp/local.m4a');
      expect(local.photoStatus, 'pending');
      expect(local.voiceStatus, 'pending');
      expect(local.dbStatus, 'pending');
      expect(local.status, 'local');
      // The owner layer belongs to `checkOwnerUpdates`, not to this merge.
      expect(local.ownerStatus, 'validated');
    });

    test('existing cloud URLs and coordinates are not overwritten', () {
      final local = localReport()
        ..photoUrl = 'https://cdn/mine.jpg'
        ..lat = 36.9
        ..lng = 10.2;

      expect(
        mergeRemoteReport(local, {
          'photo_url': 'https://cdn/theirs.jpg',
          'lat': 1.0,
          'lng': 2.0,
        }),
        isFalse,
      );
      expect(local.photoUrl, 'https://cdn/mine.jpg');
      expect(local.lat, 36.9);
      expect(local.lng, 10.2);
    });

    test('an empty remote row is a no-op', () {
      final local = localReport();
      expect(mergeRemoteReport(local, {}), isFalse);
      expect(local.parseTimelineEvents().length, 1);
    });
  });
}
