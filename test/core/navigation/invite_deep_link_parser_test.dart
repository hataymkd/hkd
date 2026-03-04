import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/navigation/invite_deep_link_parser.dart';

void main() {
  group('extractInviteTokenFromUri', () {
    test('parses custom scheme query token', () {
      final Uri uri = Uri.parse('hkd://invite?token=abcDEF1234567890');
      expect(extractInviteTokenFromUri(uri), 'abcDEF1234567890');
    });

    test('parses custom scheme path token', () {
      final Uri uri = Uri.parse('hkd://host/invite/abcDEF1234567890');
      expect(extractInviteTokenFromUri(uri), 'abcDEF1234567890');
    });

    test('parses https invite query token', () {
      final Uri uri =
          Uri.parse('https://example.com/invite?token=abcDEF1234567890');
      expect(extractInviteTokenFromUri(uri), 'abcDEF1234567890');
    });

    test('parses nested invite path token', () {
      final Uri uri =
          Uri.parse('https://example.com/hkd/invite/abcDEF1234567890');
      expect(extractInviteTokenFromUri(uri), 'abcDEF1234567890');
    });

    test('returns null for non invite path', () {
      final Uri uri =
          Uri.parse('https://example.com/profile?token=abcDEF1234567890');
      expect(extractInviteTokenFromUri(uri), isNull);
    });
  });
}
