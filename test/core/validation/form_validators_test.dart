import 'package:flutter_test/flutter_test.dart';
import 'package:hkd/core/validation/form_validators.dart';

void main() {
  group('FormValidators.phone', () {
    test('accepts local format', () {
      expect(FormValidators.phone('05309567362'), isNull);
    });

    test('accepts international formats', () {
      expect(FormValidators.phone('+905309567362'), isNull);
      expect(FormValidators.phone('905309567362'), isNull);
    });

    test('rejects invalid values', () {
      expect(FormValidators.phone('123'), isNotNull);
      expect(FormValidators.phone(''), isNotNull);
      expect(FormValidators.phone(null), isNotNull);
    });
  });
}
