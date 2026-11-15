import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('bildirim aktör ve kategori bilgisini modelde korur', () {
    final row = NotificationRow.fromMap({
      'id': 'notification-1',
      'kind': 'comment',
      'title': 'Ayşe, gönderine yorum yaptı.',
      'created_at': '2026-11-08T08:30:00Z',
      'actor_id': 'actor-1',
      'actor_name': 'Ayşe Yılmaz',
      'actor_avatar_url': 'https://example.test/avatar.jpg',
      'category': 'sosyal',
    });

    expect(row.actorName, 'Ayşe Yılmaz');
    expect(row.actorInitials, 'AY');
    expect(row.actorAvatarUrl, 'https://example.test/avatar.jpg');
    expect(row.category, 'sosyal');
  });

  test('aktör zenginleştirme bildirim hedefini ve okunma durumunu korur', () {
    final readAt = DateTime(2026, 11, 8, 12);
    final row = NotificationRow(
      id: 'notification-2',
      kind: 'follow',
      title: 'Yeni takipçi',
      actorId: 'actor-2',
      entityType: 'profile',
      entityId: 'actor-2',
      createdAt: DateTime(2026, 11, 8, 11),
      readAt: readAt,
      category: 'sosyal',
    ).withActor(name: 'Mert Demir', avatarUrl: 'avatar-url');

    expect(row.actorInitials, 'MD');
    expect(row.entityId, 'actor-2');
    expect(row.readAt, readAt);
    expect(row.isUnread, isFalse);
  });
}
