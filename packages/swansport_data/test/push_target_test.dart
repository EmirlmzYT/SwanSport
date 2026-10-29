import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('PushAppTarget contracts', () {
    test('PushAppTarget exposes social and pro values with exact wire names',
        () {
      expect(
        PushAppTarget.values,
        containsAll([PushAppTarget.social, PushAppTarget.pro]),
      );
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

    test(
        'PushSubscriptionService defaults to social and can be overridden for pro',
        () {
      final containerSocial = ProviderContainer();
      addTearDown(containerSocial.dispose);
      expect(
        containerSocial.read(pushAppTargetProvider),
        equals(PushAppTarget.social),
      );
      expect(
        containerSocial.read(pushSubscriptionServiceProvider).target,
        equals(PushAppTarget.social),
      );

      final containerPro = ProviderContainer(
        overrides: [
          pushAppTargetProvider.overrideWithValue(PushAppTarget.pro),
        ],
      );
      addTearDown(containerPro.dispose);
      expect(
        containerPro.read(pushAppTargetProvider),
        equals(PushAppTarget.pro),
      );
      expect(
        containerPro.read(pushSubscriptionServiceProvider).target,
        equals(PushAppTarget.pro),
      );
    });

    test('proNotificationKinds inventory and isProNotificationKind validation',
        () {
      expect(proNotificationKinds.length, equals(33));
      // Pro-only examples
      expect(isProNotificationKind('referee_assignment'), isTrue);
      expect(isProNotificationKind('expense_approval'), isTrue);
      expect(isProNotificationKind('turf_slot_request'), isTrue);
      // Both examples
      expect(isProNotificationKind('match_live'), isTrue);
      expect(isProNotificationKind('attendance'), isTrue);
      expect(isProNotificationKind('fee'), isTrue);
      // Social-only examples
      expect(isProNotificationKind('message'), isFalse);
      expect(isProNotificationKind('follow'), isFalse);
      expect(isProNotificationKind('mention'), isFalse);
      expect(isProNotificationKind('post_repost'), isFalse);
      expect(isProNotificationKind('unknown'), isFalse);
      expect(isProNotificationKind(null), isFalse);
    });
  });
}
