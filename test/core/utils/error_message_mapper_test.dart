import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/utils/error_message_mapper.dart';

void main() {
  group('ErrorMessageMapper', () {
    test('maps auth and jwt errors to Turkish', () {
      final String result = ErrorMessageMapper.toFriendlyTurkish(
        StateError('Bad state: Invalid JWT'),
      );

      expect(result, 'Oturum dogrulanamadi. Lutfen tekrar giris yapin.');
    });

    test('maps network failures to Turkish', () {
      final String result = ErrorMessageMapper.toFriendlyTurkish(
        'SocketException: Failed host lookup',
      );

      expect(
        result,
        'Ag baglantisi kurulamadigi icin islem tamamlanamadi.',
      );
    });

    test('returns Turkish fallback for unknown English technical errors', () {
      final String result = ErrorMessageMapper.toFriendlyTurkish(
        'edge function returned invalid response',
      );

      expect(result, 'Sunucu yaniti gecersiz. Lutfen tekrar deneyin.');
    });

    test('keeps user friendly Turkish messages', () {
      const String message = 'Davet token bilgisi alinamadi.';
      final String result = ErrorMessageMapper.toFriendlyTurkish(message);

      expect(result, message);
    });
  });
}
