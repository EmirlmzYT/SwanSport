import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/social/presentation/notifications_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  NotificationRow notification(
    String kind, {
    String? entityType,
    String? entityId,
  }) =>
      NotificationRow(
        id: 'notification-$kind',
        kind: kind,
        title: 'Bildirim',
        entityType: entityType,
        entityId: entityId,
        createdAt: DateTime(2026, 11, 8),
      );

  test('uygulama içi bildirimler mevcut gerçek hedeflere eşlenir', () {
    expect(
        notificationRouteFor(notification('announcement')), '/announcements');
    expect(notificationRouteFor(notification('fee_reminder')), '/aidatlarim');
    expect(notificationRouteFor(notification('document_expiry')), '/documents');
    expect(notificationRouteFor(notification('support')), '/destek');
    expect(notificationRouteFor(notification('court_waitlist')),
        '/saha-islemlerim');
  });

  test('canlı maç ve sonuç bildirimleri mevcut ayrıntı sözleşmesini korur', () {
    expect(
      notificationRouteFor(notification(
        'match_result',
        entityType: 'official_result',
      )),
      '/resmi-sonuc?notification=notification-match_result',
    );
    expect(
      notificationRouteFor(notification(
        'match_live',
        entityType: 'match',
        entityId: '11111111-1111-4111-8111-111111111111',
      )),
      '/canli-mac/11111111-1111-4111-8111-111111111111',
    );
  });

  test('profil ve gönderi bildirimleri genel rotaya zorlanmaz', () {
    expect(notificationRouteFor(notification('follow')), isNull);
    expect(
      notificationRouteFor(
        notification('comment', entityType: 'post', entityId: 'post-1'),
      ),
      isNull,
    );
  });
}
