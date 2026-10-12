import 'guest_explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/inbox_actions.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_skeleton.dart';
import '../../social/presentation/widgets/feed_entry.dart';
import '../../social/presentation/widgets/follow_suggestions.dart';

/// Keşfet & Arama — Google Stitch Calm Athletic Modernism (Screen 25 & 18).
///
/// Duyurular, Popüler Sporcular, Trend Challenge, 3-Sütunlu Bento Grid,
/// Günün Hareketi ve tüm spor/kulüp ağ modüllerine doğrudan erişim.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    if (!ref.watch(swanAccessProvider).hasAccount) return const GuestExploreScreen();
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, SwanSpace.xl * 5),
              children: [
                // 1. Üst Bar: Başlık & Bildirim/Mesaj Rozetleri
                const _StitchExploreHeader(),

                const SizedBox(height: SwanSpace.md),

                // 2. Atletik Arama Çubuğu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: StitchSearchBar(
                    hint: 'Sporcu, kulüp, etkinlik veya branş ara...',
                    onTap: () => Navigator.pushNamed(context, '/ara'),
                    onFilter: () => Navigator.pushNamed(context, '/ara'),
                  ),
                ),

                const SizedBox(height: SwanSpace.md),

                // 5. Öne Çıkan Duyurular (Stitch Hero Cards)
                StitchSectionTitle(
                  title: 'Öne Çıkan Duyurular',
                  actionLabel: 'Tümü',
                  onAction: () =>
                      Navigator.pushNamed(context, '/announcements'),
                ),
                ref.watch(announcementsProvider).when(
                      loading: () => const SwanCardSkeleton(),
                      error: (_, __) => TextButton(
                        onPressed: () => ref.invalidate(announcementsProvider),
                        child: const Text('Duyuruları yeniden yükle'),
                      ),
                      data: (items) => items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(SwanSpace.lg),
                              child: Text(
                                'Henüz bir kulüp duyurusu yok.',
                                style: SwanType.bodySm(c.inkMuted),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: SwanSpace.lg),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final item in items.take(6))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: SwanSpace.md),
                                      child: SizedBox(
                                        width: 290,
                                        child: StitchHeroCard(
                                          title: item.title,
                                          subtitle: item.body,
                                          icon: Icons.campaign_rounded,
                                          badge: item.pinned
                                              ? 'Sabit duyuru'
                                              : 'Kulüp duyurusu',
                                          meta: shortAgo(item.createdAt),
                                          actionLabel: 'Detayları Gör',
                                          onAction: () => Navigator.pushNamed(
                                              context, '/announcements'),
                                          tone: item.pinned ? c.warning : null,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),

                const SizedBox(height: SwanSpace.xl),

                // 6. Popüler Sporcular & Antrenörler
                StitchSectionTitle(
                  title: 'Popüler Sporcular & Antrenörler',
                  actionLabel: 'Tümü',
                  onAction: () => Navigator.pushNamed(context, '/ara'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: FollowSuggestions(
                    compact: true,
                    showCompactTitle: false,
                  ),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 7. Modüller: Spor Yap (Kompakt 2 Sütunlu Izgara)
                StitchSectionTitle(
                  title: 'Spor yap',
                  actionLabel: 'Tüm Tesisler',
                  onAction: () => Navigator.pushNamed(context, '/kortlar'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.stadium_rounded,
                              title: 'Kortlar & Sahalar',
                              subtitle: 'Sahaları ve müsait saatleri keşfet',
                              iconColor: context.swan.accent,
                              badge: 'Rezervasyon',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/kortlar'),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.handshake_rounded,
                              title: 'Partner bul',
                              subtitle: 'Birlikte oynayacak biri',
                              iconColor: context.swan.accent,
                              badge: 'Eşleş',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/partner-ara'),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.emoji_events_rounded,
                              title: 'Organizasyonlar',
                              subtitle: 'Turnuva, kamp & etkinlik',
                              iconColor: context.swan.warning,
                              badge: 'Turnuva',
                              onTap: () => Navigator.pushNamed(
                                  context, '/organizasyonlar'),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.military_tech_rounded,
                              title: 'Antrenmanlarım',
                              subtitle: 'Kendi antrenman geçmişin',
                              iconColor: context.swan.accent,
                              badge: 'Geçmiş',
                              onTap: () => Navigator.pushNamed(
                                  context, '/antrenmanlarim'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 8. Modüller: Topluluğa Katıl (Kompakt 2 Sütunlu Izgara)
                StitchSectionTitle(
                  title: 'Topluluğa katıl',
                  actionLabel: 'Kulüpler',
                  onAction: () => Navigator.pushNamed(context, '/kulupler'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.travel_explore_rounded,
                              title: 'Kulüpler',
                              subtitle: 'İl, ilçe ve branşa göre',
                              iconColor: context.swan.accent,
                              badge: 'Keşfet',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/kulupler'),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.forum_rounded,
                              title: 'Topluluklar',
                              subtitle: 'Antrenör ve sporcu odaları',
                              iconColor: context.swan.accent,
                              badge: 'Sohbet',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/topluluklar'),
                            ),
                          ),
                          if (access.isClubStaff)
                            SizedBox(
                              width: itemWidth,
                              child: _ModuleGridCard(
                                icon: Icons.shield_rounded,
                                title: 'Takımlar',
                                subtitle: 'Kadrolar ve takım sayfaları',
                                iconColor: context.swan.accent,
                                badge: 'Kulüp',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/teams'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 9. Modüller: İhtiyacını Bul (Kompakt 2 Sütunlu Izgara)
                StitchSectionTitle(
                  title: 'İhtiyacını bul',
                  actionLabel: 'İlanlar',
                  onAction: () => Navigator.pushNamed(context, '/ilanlar'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (ref.watch(
                              featureEnabledProvider(FeatureFlags.marketplace)))
                            SizedBox(
                              width: itemWidth,
                              child: _ModuleGridCard(
                                icon: Icons.storefront_rounded,
                                title: 'Pazaryeri',
                                subtitle: 'Sıfır ve 2. el ekipman',
                                iconColor: context.swan.warning,
                                badge: 'Pazar',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/pazaryeri'),
                              ),
                            ),
                          if (ref
                              .watch(featureEnabledProvider('coach_discovery')))
                            SizedBox(
                              width: itemWidth,
                              child: _ModuleGridCard(
                                icon: Icons.sports_rounded,
                                title: 'Antrenör bul',
                                subtitle: 'Onaylı antrenör kadrosu',
                                iconColor: context.swan.accent,
                                badge: 'Eğitmen',
                                onTap: () => Navigator.pushNamed(
                                    context, '/antrenor-bul'),
                              ),
                            ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.campaign_rounded,
                              title: 'İlanlar',
                              subtitle: 'Sporcu, antrenör, seçme',
                              iconColor: context.swan.accent,
                              badge: 'Duyuru',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/ilanlar'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 13. Kulüp Gönderileri & Trendler (Sosyal Akış - En Altta)
                StitchSectionTitle(
                  title: 'Kulüp Gönderileri & Trendler',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('En yeniler', maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(c.inkMuted))),
                    ],
                  ),
                ),
                ref.watch(discoverProvider).when(
                      loading: () => const SwanListSkeleton(rows: 3),
                      error: (_, __) => TextButton(
                        onPressed: () => ref.invalidate(discoverProvider),
                        child: const Text('Gönderileri yeniden yükle'),
                      ),
                      data: (posts) {
                        final hidden =
                            ref.watch(hiddenProfilesProvider).valueOrNull ??
                                const <String>{};
                        final visible = posts
                            .where((p) => !hidden.contains(p.authorId))
                            .take(8);
                        return Column(
                          children: [
                            if (visible.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(SwanSpace.lg),
                                child: Text(
                                  'Henüz gösterilecek bir paylaşım yok.',
                                  style: SwanType.bodySm(c.inkMuted),
                                ),
                              ),
                            for (final post in visible)
                              FeedEntry.post(post).build(),
                          ],
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

class _StitchExploreHeader extends ConsumerWidget {
  const _StitchExploreHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SwanTopBar(
      title: 'Keşfet',
      subtitle: 'Kulüpler, sahalar ve topluluk',
      showBrandBadge: false,
      showBack: false,
      actions: [
        InboxActions(),
      ],
    );
  }
}

/// Göz hizası hızlı modül erişim merkezi (4 Ana Kategori).
/// 2 Sütunlu Kompakt Modül Kartı
class _ModuleGridCard extends StatelessWidget {
  const _ModuleGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final textPrimary = c.ink;
    final textMuted = c.inkMuted;
    final icCol = iconColor ?? c.accent;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: context.swan.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: icCol.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: icCol, size: 20),
                    ),
                    if (badge != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: icCol.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(icCol, w: FontWeight.w800),
                          ),
                        ),
                      )
                    else
                      Icon(Icons.arrow_forward_rounded,
                          size: 16, color: textMuted.withValues(alpha: 0.6)),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(textPrimary, w: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
