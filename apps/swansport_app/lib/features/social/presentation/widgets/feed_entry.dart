import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/widgets/premium.dart';
import 'post_card.dart';
import 'social_widgets.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

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

/// Kulüp duyurusu kartı — akışta gönderiden ayırt edilebilir dursun.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item, this.clubName});

  final AnnouncementRow item;
  final String? clubName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTeal.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.campaign_rounded, size: 19, color: kTeal),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clubName ?? 'Kulüp duyurusu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  Text('Duyuru · ${shortAgo(item.createdAt)}',
                      style: SwanType.caption(SwanColors.textSecondary)),
                ],
              ),
            ),
            if (item.pinned)
              const Icon(Icons.push_pin_rounded, size: 15, color: kCoral),
          ]),
          const SizedBox(height: 12),
          Text(item.title, style: SwanType.h3(ink)),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.body,
                style: SwanType.bodySm(ink).copyWith(height: 1.45)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kCoral.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.newspaper_rounded,
                      size: 19, color: kCoral),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.bodySm(ink, w: FontWeight.w800)),
                      Text('Haber · ${shortAgo(item.publishedAt)}',
                          style: SwanType.caption(SwanColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCoral.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('HABER',
                      style: SwanType.caption(kCoral, w: FontWeight.w800)),
                ),
              ]),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  15, 0, 15, item.imageUrl == null ? 14 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: SwanType.h3(ink)),
                  if (item.summary != null &&
                      item.summary!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.summary!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(SwanColors.textSecondary)
                            .copyWith(height: 1.4)),
                  ],
                ],
              ),
            ),
            if (item.imageUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: RatioImage(image: NetworkImage(item.imageUrl!)),
              ),
            if (item.link != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 13),
                child: Row(children: [
                  Text('Habere git',
                      style: SwanType.caption(kTeal, w: FontWeight.w800)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_outward_rounded,
                      size: 15, color: kTeal),
                ]),
              ),
          ],
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bağlantı açılamadı'),
          backgroundColor: SwanPalette.light.danger));
    }
  }
}
