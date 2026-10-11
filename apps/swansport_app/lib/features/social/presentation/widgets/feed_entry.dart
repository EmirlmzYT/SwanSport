import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class AnnouncementCard extends ConsumerWidget {
  const AnnouncementCard({super.key, required this.item, this.clubName});

  final AnnouncementRow item;
  final String? clubName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final details = club == null ? null : ref.watch(clubDetailsProvider(club.id)).valueOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.lg),
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SocialAvatar(
                initials: 'KL',
                imageUrl: details?.logoUrl,
                size: 40,
                gradientIndex: 0,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm, vertical: SwanSpace.xs),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(SwanRadius.sm)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield_outlined, size: SwanSpace.lg, color: c.inkMuted),
              const SizedBox(width: SwanSpace.xs),
              Flexible(child: Text('RESMİ KULÜP DUYURUSU', style: SwanType.caption(c.inkMuted, w: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: SwanSpace.sm),
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

  Uri? get _link {
    final uri = Uri.tryParse(item.link ?? '');
    return uri != null && uri.hasAuthority &&
        ['https', 'http'].contains(uri.scheme) ? uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.lg),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
      button: _link != null,
      label: '${item.sourceName}: ${item.title}',
      child: InkWell(
        onTap: _link == null ? null : () => _open(context),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm, vertical: SwanSpace.xs),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(SwanRadius.sm)),
                child: Text('SPOR GÜNDEMİ', style: SwanType.caption(c.inkMuted, w: FontWeight.w800)),
              ),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: item.imageUrl == null || item.imageUrl!.trim().isEmpty
                        ? _NewsImageFallback(c: c)
                        : Image(
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
              if (_link != null)
                Padding(
                  padding: const EdgeInsets.only(top: SwanSpace.sm),
                  child: TextButton(
                    onPressed: () => _open(context),
                    child: Text('Haberi Oku ↗', style: SwanType.bodySm(c.accent, w: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = _link;
    if (uri == null) return;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // İşletim sistemi tarayıcıyı açamadığında da kullanıcıya bildirilir.
    }
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
