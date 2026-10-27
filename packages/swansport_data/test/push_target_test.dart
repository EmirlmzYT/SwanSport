import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('PushAppTarget contracts', () {
    test('PushAppTarget exposes social and pro values with exact wire names',
        () {
      expect(PushAppTarget.values,
          containsAll([PushAppTarget.social, PushAppTarget.pro]));
      expect(PushAppTarget.social.wireName, equals('social'));
      expect(PushAppTarget.pro.wireName, equals('pro'));
    });

    test(
        'PushAppTarget fromWire parses correctly and defaults/falls back to social',
        () {
      expect(PushAppTarget.fromWire('social'), equals(PushAppTarget.social));
      expect(PushAppTarget.fromWire('pro'), equals(PushAppTarget.pro));
      expect(PushAppTarget.fromWire('unknown'), equals(PushAppTarget.social));
      expect(PushAppTarget.fromWire(null), equals(PushAppTarget.social));
    });
  });
}
