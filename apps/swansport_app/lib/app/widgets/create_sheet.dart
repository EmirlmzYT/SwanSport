import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../features/social/presentation/post_composer_sheet.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Alt gezinmedeki "+" — oluşturma eylemleri (Stitch Calm Athletic Modernism).
Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _CreateSheet(),
  );
}

class _CreateSheet extends ConsumerWidget {
  const _CreateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);

    final items = <_CreateItem>[
      const _CreateItem(
        icon: Icons.photo_library_rounded,
        title: 'Sosyal Gönderi',
        subtitle: 'Fotoğraf, video veya antrenman anı paylaşın',
        badge: 'Yeni',
        kind: _CreateKind.post,
      ),
      const _CreateItem(
        icon: Icons.timer_rounded,
        title: 'Antrenman Günlüğü',
        subtitle: 'Setler, ok skorları, süre ve kişisel notlar',
        route: '/antrenman',
      ),
      if (access.isClubStaff)
        const _CreateItem(
          icon: Icons.campaign_rounded,
          title: 'Kulüp Duyurusu',
          subtitle: 'Roster, müsabaka veya resmi bülten yayınlayın',
          badge: 'Yetkili',
          isStaffBadge: true,
          route: '/duyurular',
        ),
      if (access.isClubStaff)
        const _CreateItem(
          icon: Icons.event_rounded,
          title: 'Etkinlik & Antrenman',
          subtitle: 'Takım için takvimde yeni bir oturum planlayın',
          route: '/calendar',
        ),
      if (access.hasVerificationTier('location'))
        const _CreateItem(
          icon: Icons.handshake_rounded,
          title: 'Partner İlanı',
          subtitle: 'Birlikte oynayacak veya antrenman yapacak birini bul',
          route: '/partner-ara',
        ),
    ];

    return Material(
      color: c.surface,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SwanRadius.lg)),
            ),
            padding: EdgeInsets.fromLTRB(
              SwanSpace.lg,
              SwanSpace.md,
              SwanSpace.lg,
              SwanSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.line.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),

                // Header with Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Oluştur ve Paylaş', style: SwanType.h2(c.ink)),
                          const SizedBox(height: 2),
                          Text(
                            'Kulübünüz ve takipçileriniz için yeni içerik başlatın.',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 20, color: c.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.md),

                // Action Items
                for (final item in items) _buildActionItem(context, c, item),

                // Drafts Preview Tile
                const SizedBox(height: SwanSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwanSpace.md, vertical: SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Icon(Icons.drafts_rounded,
                            size: 18, color: c.inkMuted),
                      ),
                      const SizedBox(width: SwanSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kayıtlı Taslaklar (2)',
                                style:
                                    SwanType.bodySm(c.ink, w: FontWeight.w700)),
                            Text('Son düzenleme: 2 saat önce',
                                style: SwanType.caption(c.inkMuted)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          unawaited(showPostComposer(context));
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: c.line),
                          ),
                          child: Text('Görüntüle',
                              style: SwanType.caption(c.accent,
                                  w: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Cancel Button
                const SizedBox(height: SwanSpace.md),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Vazgeç',
                      style: SwanType.body(c.ink, w: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
      BuildContext context, SwanPalette c, _CreateItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.xs),
      child: Material(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            Navigator.pop(context);
            if (item.kind == _CreateKind.post) {
              await showPostComposer(context);
            } else if (item.route != null) {
              if (context.mounted) {
                unawaited(Navigator.pushNamed(context, item.route!));
              }
            }
          },
          borderRadius: BorderRadius.circular(SwanRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.md, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: c.accent, size: 22),
                ),
                const SizedBox(width: SwanSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.body(c.ink, w: FontWeight.w700),
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isStaffBadge
                                    ? c.accentFill
                                    : c.accent.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.isStaffBadge) ...[
                                    const Icon(Icons.verified_user_rounded,
                                        size: 10, color: Colors.white),
                                    const SizedBox(width: 2),
                                  ],
                                  Text(
                                    item.badge!,
                                    style: SwanType.caption(
                                      item.isStaffBadge
                                          ? Colors.white
                                          : c.accent,
                                      w: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: c.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CreateKind { post, route }

class _CreateItem {
  const _CreateItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isStaffBadge = false,
    this.route,
    this.kind = _CreateKind.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isStaffBadge;
  final String? route;
  final _CreateKind kind;
}
