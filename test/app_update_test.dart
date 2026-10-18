import 'package:flutter_test/flutter_test.dart';
import 'package:goodnight/features/update/app_update.dart';

AppRelease _release(String tag, {bool required = false}) => AppRelease(
      tag: tag,
      version: tag.substring(1),
      notes: '',
      apkUrl: 'https://example.com/a.apk',
      apkSize: 1,
      required: required,
    );

void main() {
  group('parseVersion', () {
    test('accepts tags, build suffixes and short versions', () {
      expect(parseVersion('v0.2.2'), [0, 2, 2]);
      expect(parseVersion('0.2.2+4'), [0, 2, 2]);
      expect(parseVersion('1.10.0-beta'), [1, 10, 0]);
      expect(parseVersion('0.3'), [0, 3, 0]);
    });

    test('rejects anything else', () {
      expect(parseVersion(''), isNull);
      expect(parseVersion('latest'), isNull);
      expect(parseVersion('1.2.3.4'), isNull);
    });
  });

  group('isNewer', () {
    test('compares numerically, not as text', () {
      expect(isNewer('0.10.0', '0.9.9'), isTrue);
      expect(isNewer('0.2.2', '0.2.1'), isTrue);
      expect(isNewer('1.0.0', '0.99.0'), isTrue);
    });

    test('the same or an older version is not newer', () {
      expect(isNewer('0.2.1', '0.2.1'), isFalse);
      expect(isNewer('v0.2.1', '0.2.1+3'), isFalse);
      expect(isNewer('0.2.0', '0.2.1'), isFalse);
    });

    test('unparseable versions never count as newer', () {
      expect(isNewer('nightly', '0.2.1'), isFalse);
      expect(isNewer('0.3.0', ''), isFalse);
    });
  });

  group('shouldOffer', () {
    final now = DateTime(2026, 10, 18, 12);

    test('offers a newer release', () {
      expect(shouldOffer(release: _release('v0.2.2'), installed: '0.2.1', now: now), isTrue);
    });

    test('never offers the installed or an older version', () {
      expect(shouldOffer(release: _release('v0.2.1'), installed: '0.2.1', now: now), isFalse);
      expect(shouldOffer(release: _release('v0.2.1', required: true), installed: '0.2.2', now: now),
          isFalse);
    });

    test('Later hides that release until the snooze ends', () {
      final until = now.add(const Duration(hours: 5));
      expect(
        shouldOffer(
            release: _release('v0.2.2'), installed: '0.2.1', now: now, snoozedTag: 'v0.2.2', snoozedUntil: until),
        isFalse,
      );
      expect(
        shouldOffer(
            release: _release('v0.2.2'),
            installed: '0.2.1',
            now: until.add(const Duration(minutes: 1)),
            snoozedTag: 'v0.2.2',
            snoozedUntil: until),
        isTrue,
      );
    });

    test('a newer release or a required one ignores the snooze', () {
      final until = now.add(const Duration(hours: 5));
      expect(
        shouldOffer(
            release: _release('v0.2.3'), installed: '0.2.1', now: now, snoozedTag: 'v0.2.2', snoozedUntil: until),
        isTrue,
      );
      expect(
        shouldOffer(
            release: _release('v0.2.2', required: true),
            installed: '0.2.1',
            now: now,
            snoozedTag: 'v0.2.2',
            snoozedUntil: until),
        isTrue,
      );
    });
  });

  group('AppRelease.fromGitHub', () {
    Map<String, dynamic> json({String body = '', List<Map<String, dynamic>>? assets}) => {
          'tag_name': 'v0.2.2',
          'body': body,
          'assets': assets ??
              [
                {'name': 'goodnight-v0.2.2.aab', 'browser_download_url': 'https://x/aab', 'size': 9},
                {'name': 'goodnight-v0.2.2.apk', 'browser_download_url': 'https://x/apk', 'size': 1234},
              ],
        };

    test('picks the APK asset', () {
      final r = AppRelease.fromGitHub(json())!;
      expect(r.tag, 'v0.2.2');
      expect(r.version, '0.2.2');
      expect(r.apkUrl, 'https://x/apk');
      expect(r.apkSize, 1234);
      expect(r.required, isFalse);
    });

    test('the hidden marker makes it required', () {
      expect(AppRelease.fromGitHub(json(body: 'Fixes.\n$requiredMarker'))!.required, isTrue);
    });

    test('a release without an APK or with a bad tag is ignored', () {
      expect(AppRelease.fromGitHub(json(assets: [])), isNull);
      expect(AppRelease.fromGitHub({...json(), 'tag_name': 'latest'}), isNull);
    });
  });

  group('releaseHighlights', () {
    test('takes bullets up to their first colon or full stop', () {
      const notes = '### Added\n'
          '- Love notes: send your partner a short message.\n'
          '- Tonight now shows a live card. You both see it.\n'
          '* **Bold** and [linked](https://x) text\n'
          'Not a bullet\n'
          '- A fourth one';
      expect(releaseHighlights(notes), [
        'Love notes',
        'Tonight now shows a live card',
        'Bold and linked text',
      ]);
    });

    test('shortens long bullets', () {
      final h = releaseHighlights('- ${'word ' * 30}', maxLen: 20);
      expect(h.single.length, lessThanOrEqualTo(20));
      expect(h.single.endsWith('…'), isTrue);
    });

    test('empty notes give no highlights', () {
      expect(releaseHighlights(''), isEmpty);
    });
  });

  test('formatSize', () {
    expect(formatSize(0), '');
    expect(formatSize(5 * 1024 * 1024 + 300000), '5.3 MB');
    expect(formatSize(48 * 1024 * 1024), '48 MB');
  });
}
