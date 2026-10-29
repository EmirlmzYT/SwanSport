import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_pro/app/push/pro_notification_route_handler.dart';

void main() {
  group('Pro Notification Deep-Link Routing Matrix', () {
    test('referee assignments route to referee duty screen', () {
      expect(
        resolveProNotificationRoute(kind: 'referee_assignment'),
        equals('/operasyon/hakem-gorevleri'),
      );
    });

    test('attendance notifications route to live attendance screen', () {
      expect(
        resolveProNotificationRoute(kind: 'attendance'),
        equals('/operasyon/yoklama'),
      );
      expect(
        resolveProNotificationRoute(kind: 'attendance_reminder'),
        equals('/operasyon/yoklama'),
      );
    });

    test('training notifications route to training list screen', () {
      expect(
        resolveProNotificationRoute(kind: 'training_session'),
        equals('/operasyon/antrenmanlar'),
      );
      expect(
        resolveProNotificationRoute(kind: 'training_result'),
        equals('/operasyon/antrenmanlar'),
      );
    });

    test('finance and expense notifications route to accounting screen', () {
      final financeKinds = [
        'expense_approval',
        'expense_rejected',
        'commitment_due',
        'account_negative',
        'bank_unmatched',
        'period_closed',
        'period_blocked',
        'fee',
        'fee_reminder',
        'payment',
        'donation',
      ];
      for (final kind in financeKinds) {
        expect(
          resolveProNotificationRoute(kind: kind),
          equals('/operasyon/muhasebe'),
          reason: 'Expected $kind to route to /operasyon/muhasebe',
        );
      }
    });

    test('turf and facility notifications route to turf duties screen', () {
      final facilityKinds = [
        'turf_slot_request',
        'turf_field',
        'turf_manager',
        'court_waitlist',
        'turf_delegation',
      ];
      for (final kind in facilityKinds) {
        expect(
          resolveProNotificationRoute(kind: kind),
          equals('/operasyon/tesis-gorevleri'),
          reason: 'Expected $kind to route to /operasyon/tesis-gorevleri',
        );
      }
    });

    test('live matches use the cockpit only with a valid match id', () {
      expect(
        resolveProNotificationRoute(
          kind: 'match_live',
          entityType: 'match',
          entityId: '00000000-0000-0000-0000-000000000001',
        ),
        equals(
          '/operasyon/hakem-canli/00000000-0000-0000-0000-000000000001',
        ),
      );
      expect(
        resolveProNotificationRoute(
          kind: 'match_live',
          entityType: 'match',
          entityId: '../hesap',
        ),
        equals('/operasyon/federasyon-maclar'),
      );
      expect(
        resolveProNotificationRoute(kind: 'match_result'),
        equals('/operasyon/federasyon-maclar'),
      );
    });

    test('platform and moderation notifications route to platform operations',
        () {
      expect(
        resolveProNotificationRoute(kind: 'store_decision'),
        equals('/operasyon/platform'),
      );
      expect(
        resolveProNotificationRoute(kind: 'moderation'),
        equals('/operasyon/platform'),
      );
    });

    test('social or unmapped kinds safely fallback to inbox (/gelen-kutusu)',
        () {
      final fallbackKinds = [
        'message',
        'follow',
        'mention',
        'post_repost',
        'post_quote',
        'unknown_custom_kind',
        '',
        'INVALID_KIND',
      ];
      for (final kind in fallbackKinds) {
        expect(
          resolveProNotificationRoute(kind: kind),
          equals('/gelen-kutusu'),
          reason: 'Expected $kind to fallback to /gelen-kutusu',
        );
      }
    });
  });

  group('native push URL allowlist', () {
    test('accepts known static and valid dynamic routes', () {
      expect(resolveProPushUrl('/gelen-kutusu'), '/gelen-kutusu');
      expect(
        resolveProPushUrl(
          '/operasyon/hakem-rapor/00000000-0000-0000-0000-000000000001',
        ),
        '/operasyon/hakem-rapor/00000000-0000-0000-0000-000000000001',
      );
    });

    test('rejects external, malformed, queried, and unknown routes', () {
      for (final route in [
        'https://evil.example/hesap',
        '/operasyon/hakem-canli/not-a-uuid',
        '/gelen-kutusu?next=/hesap',
        '/bilinmeyen',
        '',
      ]) {
        expect(resolveProPushUrl(route), proFallbackRoute);
      }
    });
  });
}
