import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('Notification tap routing and read contracts', () {
    test('NotificationRow handles routes and unread state accurately', () {
      final now = DateTime.now();
      final n1 = NotificationRow(
        id: 'n-1',
        kind: 'follow',
        title: 'Ahmet seni takip etti',
        actorId: 'usr-42',
        createdAt: now,
      );
      expect(n1.isUnread, isTrue);
      expect(n1.resultRoute, isNull);
      expect(n1.refereeRoute, isNull);

      final n2 = NotificationRow(
        id: 'n-2',
        kind: 'referee_assignment',
        title: 'Hakem görevi atandı',
        entityType: 'match',
        createdAt: now,
      );
      expect(n2.refereeRoute, '/hakem/gorevler');

      final n3 = NotificationRow(
        id: 'n-3',
        kind: 'match_result',
        title: 'Resmi sonuç',
        entityType: 'official_result',
        createdAt: now,
      );
      expect(n3.resultRoute, contains('/resmi-sonuc'));
    });

    test('notifications_screen.dart does not have null onTap and handles all notification kinds', () {
      final file = File('lib/features/social/presentation/notifications_screen.dart');
      final content = file.readAsStringSync();

      // onTap must not be null anymore
      expect(content.contains('onTap: route == null ? null :'), isFalse);
      expect(content.contains('_handleNotificationTap'), isTrue);
      expect(content.contains("case 'follow':"), isTrue);
      expect(content.contains("case 'message':"), isTrue);
      expect(content.contains("case 'application':"), isTrue);
      expect(content.contains("case 'comment':"), isTrue);
      expect(content.contains("markRead"), isTrue);
    });
  });

  group('Post composer hardening contracts', () {
    test('post_composer_sheet.dart uses friendly errors and invalidates author and feed providers', () {
      final file = File('lib/features/social/presentation/post_composer_sheet.dart');
      final content = file.readAsStringSync();

      expect(content.contains('friendlyErrorMessage'), isTrue);
      expect(content.contains('authorPostsProvider'), isTrue);
      expect(content.contains('clubPostsProvider'), isTrue);
      expect(content.contains('feedProvider'), isTrue);
      expect(content.contains('discoverProvider'), isTrue);

      // Raw unstyled/hardcoded danger and warning colors should not be in _share
      expect(content.contains("SwanPalette.light.danger"), isFalse);
    });
  });

  group('Comments and Repost hardening contracts', () {
    test('comments_sheet.dart uses friendly errors and token-based danger colors', () {
      final file = File('lib/features/social/presentation/comments_sheet.dart');
      final content = file.readAsStringSync();

      expect(content.contains('friendlyErrorMessage'), isTrue);
      expect(content.contains("Yorum gönderilemedi: \$e"), isFalse);
      expect(content.contains("Silinemedi: \$e"), isFalse);
      expect(content.contains('SwanPalette.light.danger'), isFalse);
    });

    test('saved_posts_screen.dart _RepostSheet invalidates authorPostsProvider and uses friendly error', () {
      final file = File('lib/features/social/presentation/saved_posts_screen.dart');
      final content = file.readAsStringSync();

      expect(content.contains('friendlyErrorMessage'), isTrue);
      expect(content.contains('authorPostsProvider'), isTrue);
      expect(content.contains("Hata: \$e"), isFalse);
    });
  });
}
