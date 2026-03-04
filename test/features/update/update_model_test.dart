import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/features/update/update_model.dart';

void main() {
  group('compareSemanticVersions', () {
    test('returns 0 for same semantic value', () {
      expect(compareSemanticVersions('1.2.3', '1.2.3+5'), 0);
    });

    test('returns -1 when left is older', () {
      expect(compareSemanticVersions('1.2.2', '1.2.3'), -1);
      expect(compareSemanticVersions('1.2', '1.2.1'), -1);
    });

    test('returns 1 when left is newer', () {
      expect(compareSemanticVersions('1.3.0', '1.2.9'), 1);
    });
  });

  group('UpdateManifest.fromJson', () {
    test('parses valid payload', () {
      final UpdateManifest manifest = UpdateManifest.fromJson(
        <String, dynamic>{
          'latest_version': '1.0.3',
          'min_supported_version': '1.0.0',
          'apk_url': 'https://example.com/hkd.apk',
          'apk_fallback_urls': <String>[
            'https://example.com/releases',
          ],
          'release_page_url': 'https://example.com/releases/tag/v1.0.3',
          'release_notes': <String>['A', 'B'],
          'published_at': '2026-02-28T00:00:00Z',
        },
      );

      expect(manifest.latestVersion, '1.0.3');
      expect(manifest.minSupportedVersion, '1.0.0');
      expect(manifest.apkUrl, 'https://example.com/hkd.apk');
      expect(manifest.fallbackUrls.length, 1);
      expect(
        manifest.releasePageUrl,
        'https://example.com/releases/tag/v1.0.3',
      );
      expect(manifest.releaseNotes.length, 2);
      expect(manifest.publishedAt, isNotNull);
      expect(manifest.downloadCandidates.length, 3);
    });

    test('throws for invalid payload', () {
      expect(
        () => UpdateManifest.fromJson(
          <String, dynamic>{
            'latest_version': '',
            'min_supported_version': '1.0.0',
            'apk_url': 'https://example.com/hkd.apk',
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
