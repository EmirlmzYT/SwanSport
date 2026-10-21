import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/social/presentation/widgets/feed_entry.dart';
import 'package:swansport_app/features/social/presentation/widgets/social_widgets.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('RatioImage Android Akıcılık & Placeholder Güvencesi', () {
    testWidgets('Oran çözülene kadar 4/3 varsayılan oran ve hafif statik ikon kullanır',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatioImage(
              image: NetworkImage('https://example.com/test.jpg'),
            ),
          ),
        ),
      );

      // Yükleme sırasında CPU tüketen dönen spinner (CircularProgressIndicator) bulunmamalıdır.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Statik, hafif yer tutucu ikonu bulunmalıdır.
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      // Oran çözülene kadar 4:3 (yaklaşık 1.33) en-boy oranını korumalıdır.
      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, closeTo(4 / 3, 0.01));
    });
  });

  group('FeedEntry Eleman Anahtarları (ValueKey) Güvencesi', () {
    test('Her akış kartına yeniden çizimi ve kaydırma durumunu koruyan ValueKey atanır', () {
      final now = DateTime.now();

      final post = PostRow(
        id: 'post_123',
        authorId: 'user_1',
        authorName: 'Ali Veli',
        body: 'Merhaba',
        createdAt: now,
      );
      final postWidget = FeedEntry.post(post).build();
      expect(postWidget.key, const ValueKey('post_post_123'));

      final ann = AnnouncementRow(
        title: 'Duyuru',
        body: 'İçerik',
        pinned: false,
        createdAt: now,
      );
      final annWidget = FeedEntry.announcement(ann).build();
      expect(
        annWidget.key,
        ValueKey('ann_Duyuru_${now.millisecondsSinceEpoch}'),
      );

      final news = NewsItem(
        title: 'Haber Başlığı',
        summary: 'Özet',
        link: 'https://news.com/123',
        sourceName: 'Spor Haber',
        publishedAt: now,
      );
      final newsWidget = FeedEntry.news(news).build();
      expect(
        newsWidget.key,
        ValueKey('news_https://news.com/123_${now.millisecondsSinceEpoch}'),
      );

      final carouselWidget = FeedEntry.newsCarousel([news]).build();
      expect(
        carouselWidget.key,
        ValueKey('carousel_https://news.com/123_${now.millisecondsSinceEpoch}'),
      );
    });
  });

  group('Profil Ekranı Sanallaştırma & Görsel Bellek Sınırları (Statik Kod Sözleşmesi)', () {
    test('Profil ekranı shrinkWrap GridView yerine CustomScrollView ve sanallaştırılmış sliver kullanır', () {
      final root = Directory.current.path;
      var path = '$root/lib/features/social/presentation/profile_screen.dart';
      if (!File(path).existsSync()) {
        path = '$root/apps/swansport_app/lib/features/social/presentation/profile_screen.dart';
      }
      final file = File(path).readAsStringSync();

      // shrinkWrap: true veya eager Column(children: posts.map) kullanılmamalıdır.
      expect(
        file.contains('shrinkWrap: true'),
        isFalse,
        reason: 'shrinkWrap: true profil kaydırma performansını ve sanallaştırmayı bozar.',
      );
      expect(
        file.contains('posts.map((post) => PostCard(post: post)).toList()'),
        isFalse,
        reason: 'Tüm gönderilerin Column içinde eager oluşturulması kaldırılmalıdır.',
      );

      // CustomScrollView ve SliverGrid / SliverList kullanılmalıdır.
      expect(
        file.contains('CustomScrollView('),
        isTrue,
        reason: 'Profil ekranı CustomScrollView mimarisinde olmalıdır.',
      );
      expect(
        file.contains('SliverGrid(') && file.contains('SliverList('),
        isTrue,
        reason: 'Kare ızgara ve liste görünümleri sliver tabanlı sanallaştırılmalıdır.',
      );

      // Avatar ve ızgara görsellerinde cacheWidth sınırlandırması olmalıdır.
      expect(
        file.contains('cacheWidth: (80 *'),
        isTrue,
        reason: 'Profil avatarında hedef boyuta uygun cacheWidth sınırı bulunmalıdır.',
      );
      expect(
        file.contains('cacheWidth: cacheWidth'),
        isTrue,
        reason: 'Profil ızgara fotoğraflarında ekran sütununa uygun cacheWidth sınırı bulunmalıdır.',
      );
    });

    test('Haber kartlarında bellek optimizasyonu (ResizeImage ve cacheWidth) bulunur', () {
      final root = Directory.current.path;
      var path = '$root/lib/features/social/presentation/widgets/feed_entry.dart';
      if (!File(path).existsSync()) {
        path = '$root/apps/swansport_app/lib/features/social/presentation/widgets/feed_entry.dart';
      }
      final file = File(path).readAsStringSync();

      expect(
        file.contains('ResizeImage('),
        isTrue,
        reason: 'Ana haber kartı görseli hedef ekrana göre ResizeImage ile sınırlandırılmalıdır.',
      );
      expect(
        file.contains('cacheWidth: (240 *'),
        isTrue,
        reason: 'Haber karuseli görseli kart genişliğine göre cacheWidth ile sınırlandırılmalıdır.',
      );
    });
  });
}
