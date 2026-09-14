import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import 'post_card.dart';
import 'social_widgets.dart';

/// Akıştaki tek bir öğe — gönderi, duyuru veya haber.
///
/// Üç kaynak tek listede zaman sırasına göre harmanlanır; böylece ana sayfa
/// yalnız gönderilerden ibaret kalmaz.
class FeedEntry {
  const FeedEntry.post(this.post)
      : announcement = null,
        news = null,
        clubName = null;

  const FeedEntry.announcement(this.announcement, {this.clubName})
      : post = null,
        news = null;

  const FeedEntry.news(this.news)
      : post = null,
        announcement = null,
        clubName = null;

  final PostRow? post;
  final AnnouncementRow? announcement;
  final NewsItem? news;
  final String? clubName;

  DateTime get sortDate =>
      post?.createdAt ?? announcement?.createdAt ?? news!.publishedAt;

  Widget build() {
    if (post != null) return PostCard(post: post!);
    if (announcement != null) {
      return AnnouncementCard(item: announcement!, clubName: clubName);
    }
    return NewsCard(item: news!);
  }
}

/// Kulüp duyurusu — sosyal gönderilerle aynı ritimde, daha sakin bir yüzey.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item, this.clubName});

  final AnnouncementRow item;
  final String? clubName;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.lg),
      padding: const EdgeInsets.fromLTRB(
        0,
        SwanSpace.md,
        0,
        SwanSpace.lg,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  size: 20,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clubName ?? 'Kulüp duyurusu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                    ),
                    Text(
                      'Duyuru · ${shortAgo(item.createdAt)}',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
              if (item.pinned)
                Icon(Icons.push_pin_rounded, size: 16, color: c.warning),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          Text(item.title, style: SwanType.h3(c.ink)),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              item.body,
              style: SwanType.bodySm(c.ink).copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spor haberi kartı — kaynağı belirtilir, dokununca haberin sayfası açılır.
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Semantics(
      button: item.link != null,
      label: '${item.sourceName}: ${item.title}',
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Container(
          margin: const EdgeInsets.only(bottom: SwanSpace.lg),
          padding: const EdgeInsets.only(bottom: SwanSpace.lg),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: SwanSpace.md,
                  bottom: SwanSpace.sm,
                ),
                child: Row(
                  children: [
                    SocialAvatar(
                      initials: item.sourceName.trim().isEmpty
                          ? 'H'
                          : item.sourceName
                              .trim()
                              .split(RegExp(r'\s+'))
                              .take(2)
                              .map((word) => word.characters.first)
                              .join(),
                      size: 40,
                      imageUrl: item.sourceIconUrl,
                      gradientIndex: item.sourceName.length % 4,
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                          ),
                          Text(
                            'Spor haberi · ${shortAgo(item.publishedAt)}',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: c.inkMuted,
                    ),
                  ],
                ),
              ),
              if (item.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _NewsImageFallback(c: c),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: SwanSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.h3(c.ink),
                    ),
                    if (item.summary != null &&
                        item.summary!.trim().isNotEmpty) ...[
                      const SizedBox(height: SwanSpace.xs),
                      Text(
                        item.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            SwanType.bodySm(c.inkMuted).copyWith(height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.link != null)
                Padding(
                  padding: const EdgeInsets.only(top: SwanSpace.sm),
                  child: Text(
                    'Haberi oku',
                    style: SwanType.caption(c.accent, w: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final link = item.link;
    if (link == null) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bağlantı açılamadı'),
          backgroundColor: context.swan.danger,
        ),
      );
    }
  }
}

class _NewsImageFallback extends StatelessWidget {
  const _NewsImageFallback({required this.c});

  final SwanPalette c;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: c.surfaceAlt,
        child: Center(
          child: Icon(Icons.sports_rounded, size: 38, color: c.inkMuted),
        ),
      );
}
