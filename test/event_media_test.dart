import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_v0/services/event_media.dart';

/// An existence probe standing in for the file system: only these two "files"
/// are on disk.
bool _liveOnly(String path) => path == '/live/photo.jpg' || path == '/live/voice.m4a';

void main() {
  group('hostedUrl', () {
    test('accepts http and https, trimmed', () {
      expect(hostedUrl('https://cdn/a.jpg'), 'https://cdn/a.jpg');
      expect(hostedUrl('  http://cdn/a.jpg  '), 'http://cdn/a.jpg');
    });

    test('rejects local paths, empty and missing values', () {
      expect(hostedUrl('/data/user/0/photo.jpg'), isNull);
      expect(hostedUrl(''), isNull);
      expect(hostedUrl('   '), isNull);
      expect(hostedUrl(null), isNull);
    });
  });

  group('eventPhotoOf / eventVoiceOf', () {
    test('reads the new path + url pair', () {
      final event = {
        'photoPath': '/live/photo.jpg',
        'photoUrl': 'https://cdn/photo.jpg',
      };
      expect(eventPhotoOf(event), (
        path: '/live/photo.jpg',
        url: 'https://cdn/photo.jpg',
      ));
    });

    test('understands a legacy event holding a cloud URL', () {
      final event = {
        'photoUrl': 'https://cdn/photo.jpg',
        'voiceUrl': 'https://cdn/voice.m4a',
      };
      expect(eventPhotoOf(event), (path: '', url: 'https://cdn/photo.jpg'));
      expect(eventVoiceOf(event), (path: '', url: 'https://cdn/voice.m4a'));
    });

    test('understands a legacy event holding a local path', () {
      expect(eventPhotoOf({'photoUrl': '/data/photo.jpg'}), (
        path: '/data/photo.jpg',
        url: '',
      ));
    });

    test('a URL stored in the path field is a URL, never a file', () {
      expect(eventPhotoOf({'photoPath': 'https://cdn/pulled.jpg'}), (
        path: '',
        url: 'https://cdn/pulled.jpg',
      ));
    });

    test('empty fields yield an empty pair, and media is detected', () {
      expect(eventPhotoOf(const {}), (path: '', url: ''));
      expect(eventHasMedia(const {}), isFalse);
      expect(eventHasMedia({'photoUrl': 'https://cdn/a.jpg'}), isTrue);
      expect(eventHasMedia({'voicePath': '/data/v.m4a'}), isTrue);
    });
  });

  group('normalizeEventMedia', () {
    test('keeps a live local path beside the cloud URL', () {
      final event = {
        'photoPath': '/live/photo.jpg',
        'photoUrl': 'https://cdn/photo.jpg',
        'actor': 'sub',
      };
      expect(normalizeEventMedia(event, fileExists: _liveOnly), {
        'photoPath': '/live/photo.jpg',
        'photoUrl': 'https://cdn/photo.jpg',
        'actor': 'sub',
      });
    });

    test('drops a path whose file is gone and keeps the cloud URL', () {
      // Exactly what the 7-day cleanup leaves behind: the URL must survive.
      final event = {
        'photoPath': '/gone/photo.jpg',
        'photoUrl': 'https://cdn/photo.jpg',
      };
      expect(normalizeEventMedia(event, fileExists: _liveOnly), {
        'photoUrl': 'https://cdn/photo.jpg',
      });
    });

    test('migrates a legacy local path out of the URL field', () {
      final event = {'photoUrl': '/live/photo.jpg', 'action': 'submit'};
      expect(normalizeEventMedia(event, fileExists: _liveOnly), {
        'photoPath': '/live/photo.jpg',
        'action': 'submit',
      });
    });

    test('a legacy path with no file leaves no media at all', () {
      expect(normalizeEventMedia({'photoUrl': '/gone/photo.jpg'},
          fileExists: _liveOnly), const <String, dynamic>{});
    });

    test('empty keys are left exactly as they were (no churn)', () {
      final event = {
        'actor': 'sub',
        'action': 'submit',
        'text': '',
        'photoPath': '',
        'voicePath': '',
        'photoUrl': '',
        'voiceUrl': '',
        'time': '2026-09-17T09:30:00.000Z',
      };
      expect(normalizeEventMedia(event, fileExists: _liveOnly), event);
    });

    test('normalizeEventJson survives a malformed entry untouched', () {
      expect(normalizeEventJson('not-json', fileExists: _liveOnly), 'not-json');
      expect(
        normalizeEventJson(jsonEncode({'photoUrl': '/gone/p.jpg'}),
            fileExists: _liveOnly),
        '{}',
      );
    });
  });

  group('eventForCloud / cloudEventList', () {
    test('never pushes a local path, always the cloud URL', () {
      final event = {
        'actor': 'tl',
        'action': 'reject',
        'photoPath': '/live/photo.jpg',
        'photoUrl': 'https://cdn/reject.jpg',
        'voicePath': '/live/voice.m4a',
      };
      expect(eventForCloud(event), {
        'actor': 'tl',
        'action': 'reject',
        'photoUrl': 'https://cdn/reject.jpg',
      });
    });

    test('a legacy local path is stripped instead of replacing a URL', () {
      expect(eventForCloud({'photoUrl': '/data/photo.jpg'}), const {});
      expect(eventForCloud({'photoUrl': ''}), const {});
    });

    test('the whole thread is converted, undecodable entries verbatim', () {
      final thread = [
        jsonEncode({'photoUrl': '/data/a.jpg', 'action': 'submit'}),
        'broken',
      ];
      final pushed = cloudEventList(thread);
      expect(jsonDecode(pushed.first), {'action': 'submit'});
      expect(pushed.last, 'broken');
    });
  });

  group('urlOnlyField', () {
    test('omits the column for an empty or path-shaped value', () {
      // This is what stops a push from wiping the cloud URL after cleanup.
      expect(urlOnlyField('photo_url', ''), isEmpty);
      expect(urlOnlyField('photo_url', '/data/photo.jpg'), isEmpty);
    });

    test('includes the column for a real URL', () {
      expect(urlOnlyField('photo_url', 'https://cdn/p.jpg'), {
        'photo_url': 'https://cdn/p.jpg',
      });
    });
  });
}
