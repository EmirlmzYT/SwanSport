import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('converts 10-digit Turkish mobile starting with 5 to +90', () {
      expect(normalizePhoneNumber('5321234567'), '+905321234567');
      expect(normalizePhoneNumber('555 987 65 43'), '+905559876543');
    });
    test('converts 11-digit Turkish mobile starting with 05 to +90', () {
      expect(normalizePhoneNumber('05321234567'), '+905321234567');
      expect(normalizePhoneNumber('0 (532) 123-4567'), '+905321234567');
    });
    test('preserves existing country codes', () {
      expect(normalizePhoneNumber('+905321234567'), '+905321234567');
      expect(normalizePhoneNumber('+1 415 555 2671'), '+14155552671');
      expect(normalizePhoneNumber('+49 151 1234567'), '+491511234567');
    });
    test('handles international 00 prefix', () {
      expect(normalizePhoneNumber('00905321234567'), '+905321234567');
    });
    test('removes dots and preserves empty input for validation', () {
      expect(normalizePhoneNumber('0532.123.45.67'), '+905321234567');
      expect(normalizePhoneNumber('  '), '');
      expect(normalizePhoneNumber('905321234567'), '+905321234567');
    });
  });
}
