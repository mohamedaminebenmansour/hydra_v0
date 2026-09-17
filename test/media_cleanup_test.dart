import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_v0/models/report.dart';
import 'package:hydra_v0/services/report_local_service.dart';

void main() {
  group('Report.isMediaReclaimable', () {
    test('terminal owner status + synced qualifies', () {
      final r = Report()
        ..status = 'synced'
        ..photoStatus = 'synced'
        ..voiceStatus = 'synced'
        ..dbStatus = 'synced'
        ..ownerStatus = 'validated'
        ..photoUrl = 'https://example.com/p.jpg'
        ..voiceUrl = 'https://example.com/v.mp3';
      expect(r.isMediaReclaimable(DateTime.now()), isTrue);
    });

    test('rejected owner status qualifies', () {
      final r = Report()
        ..status = 'synced'
        ..photoStatus = 'synced'
        ..voiceStatus = 'synced'
        ..dbStatus = 'synced'
        ..ownerStatus = 'rejected'
        ..photoUrl = 'https://example.com/p.jpg'
        ..voiceUrl = 'https://example.com/v.mp3';
      expect(r.isMediaReclaimable(DateTime.now()), isTrue);
    });

    test('acknowledged owner status qualifies', () {
      final r = Report()
        ..status = 'synced'
        ..photoStatus = 'synced'
        ..voiceStatus = 'synced'
        ..dbStatus = 'synced'
        ..ownerStatus = 'acknowledged'
        ..photoUrl = 'https://example.com/p.jpg'
        ..voiceUrl = 'https://example.com/v.mp3';
      expect(r.isMediaReclaimable(DateTime.now()), isTrue);
    });

    final cutoff7d = DateTime.now().subtract(const Duration(days: 7));

    test('pending owner status + 8-day-old timestamp qualifies', () {
      final r = Report()
        ..status = 'synced'
        ..photoStatus = 'synced'
        ..voiceStatus = 'synced'
        ..dbStatus = 'synced'
        ..ownerStatus = 'pending'
        ..timestamp = DateTime.now().subtract(const Duration(days: 8))
        ..photoUrl = 'https://example.com/p.jpg'
        ..voiceUrl = 'https://example.com/v.mp3';
      expect(r.isMediaReclaimable(cutoff7d), isTrue);
    });

    test('pending owner status + 6-day-old timestamp does NOT qualify', () {
      final r = Report()
        ..status = 'synced'
        ..photoStatus = 'synced'
        ..voiceStatus = 'synced'
        ..dbStatus = 'synced'
        ..ownerStatus = 'pending'
        ..timestamp = DateTime.now().subtract(const Duration(days: 6))
        ..photoUrl = 'https://example.com/p.jpg'
        ..voiceUrl = 'https://example.com/v.mp3';
      expect(r.isMediaReclaimable(cutoff7d), isFalse);
    });
  });

  test('partially synced report does not qualify', () {
    final r = Report()
      ..status = 'synced'
      ..photoStatus =
          'failed' // not fully synced
      ..voiceStatus = 'synced'
      ..dbStatus = 'synced'
      ..ownerStatus = 'validated';
    expect(r.isMediaReclaimable(DateTime.now()), isFalse);
  });

  test(
    'report with failed sub-status does not qualify even with terminal owner',
    () {
      final r = Report()
        ..status = 'failed'
        ..photoStatus = 'failed'
        ..voiceStatus = 'failed'
        ..dbStatus = 'failed'
        ..ownerStatus = 'validated';
      expect(r.isMediaReclaimable(DateTime.now()), isFalse);
    },
  );

  group('ReportLocalService.resolveMedia', () {
    test('local path that exists wins over URL', () async {
      final dir = await Directory.systemTemp.createTemp();
      final file = File('${dir.path}/photo.jpg')..writeAsStringSync('x');
      addTearDown(() => dir.delete(recursive: true));

      final m = ReportLocalService.resolveMedia(file.path, 'https://c/u.jpg');
      expect(m.origin, MediaOrigin.localFile);
      expect(m.location, file.path);
    });

    test('local path empty falls back to URL', () {
      final m = ReportLocalService.resolveMedia('', 'https://c/u.jpg');
      expect(m.origin, MediaOrigin.network);
      expect(m.location, 'https://c/u.jpg');
    });

    test('local path is a missing file, URL present falls back', () {
      final m = ReportLocalService.resolveMedia(
        '/nope/missing.jpg',
        'https://c/u.jpg',
      );
      expect(m.origin, MediaOrigin.network);
      expect(m.location, 'https://c/u.jpg');
    });

    test('legacy row with URL stored in path resolves to network', () {
      final m = ReportLocalService.resolveMedia('https://c/legacy.jpg', '');
      expect(m.origin, MediaOrigin.network);
      expect(m.location, 'https://c/legacy.jpg');
    });

    test('nothing available returns none', () {
      final m = ReportLocalService.resolveMedia('', '');
      expect(m.origin, MediaOrigin.none);
      expect(m.location, '');
    });
  });
}
