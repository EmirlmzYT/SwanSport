import 'package:swansport_app/app/widgets/swan_floating_header.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'guest_explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_chrome.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/inbox_actions.dart';
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_skeleton.dart';
import '../../social/presentation/widgets/feed_entry.dart';
import '../../social/presentation/widgets/follow_suggestions.dart';
import '../../social/presentation/widgets/social_widgets.dart';

/// İçerik, kişiler ve spor modülleri için keşif ekranı.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  bool _showAllTools = false;
  final _allToolsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(swanAccessProvider).hasAccount)
      return const GuestExploreScreen();
    final c = context.swan;
    return SwanScaffold(
      extendBody: true,
      scrollUnderHeader: true,
      backgroundColor: c.bg,
      appBar: const PreferredSize(
          preferredSize: Size.fromHeight(SwanChrome.headerHeight),
          child: _StitchExploreHeader()),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, SwanSpace.xl * 5),
              children: [
                const SwanHeaderSpacer(),
                const SizedBox(height: SwanSpace.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _ExploreSearchPanel(
                    onSearch: () => Navigator.pushNamed(context, '/ara'),
                  ),
                ),

                const SizedBox(height: SwanSpace.lg),
                const StitchSectionTitle(title: 'Keşfetmeye başla'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: Column(
                    children: [
                      _ExploreFocusCard(
                        icon: Icons.groups_2_rounded,
                        title: 'Kulüp ve kişiler',
                        subtitle:
                            'Sporcu, antrenör ve kulüpleri tek aramada bul',
                        onTap: () => Navigator.pushNamed(context, '/ara'),
                      ),
                      const SizedBox(height: SwanSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _ExploreFocusCard(
                              compact: true,
                              icon: Icons.sports_tennis_rounded,
                              title: 'Spor yap',
                              subtitle: 'Saha, partner ve etkinlik',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/kortlar'),
                            ),
                          ),
                          const SizedBox(width: SwanSpace.sm),
                          Expanded(
                            child: _ExploreFocusCard(
                              compact: true,
                              icon: Icons.bolt_rounded,
                              title: 'Spor gündemi',
                              subtitle: 'Maçlar, sonuçlar ve federasyon',
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/federasyon-merkezi',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SwanSpace.sm),
                      TextButton.icon(
                        key: const Key('explore-all-tools-toggle'),
                        onPressed: () {
                          setState(() => _showAllTools = !_showAllTools);
                          if (!_showAllTools) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final target = _allToolsKey.currentContext;
                            if (target != null && mounted) {
                              Scrollable.ensureVisible(
                                target,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                alignment: 0.08,
                              );
                            }
                          });
                        },
                        icon: Icon(
                          _showAllTools
                              ? Icons.expand_less_rounded
                              : Icons.grid_view_rounded,
                        ),
                        label: Text(
                          _showAllTools
                              ? 'Daha az göster'
                              : 'Tüm keşif araçları',
                        ),
                      ),
                    ],
                  ),
                ),

                ref.watch(announcementsProvider).when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : Column(children: [
                              const SizedBox(height: SwanSpace.lg),
                              StitchSectionTitle(
                                title: 'Duyurular',
                                actionLabel: 'Tümü',
                                onAction: () => Navigator.pushNamed(
                                    context, '/announcements'),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: SwanSpace.lg),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final item in items.take(3))
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
                                            tone:
                                                item.pinned ? c.warning : null,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ]),
                    ),

                const SizedBox(height: SwanSpace.lg),

                // 6. Popüler Sporcular & Antrenörler
                StitchSectionTitle(
                  title: 'Sporcular ve antrenörler',
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

                if (_showAllTools) ...[
                  SizedBox(key: _allToolsKey, height: SwanSpace.lg),

                  // Ayrıntılı keşif kataloğu isteğe bağlı açılır.
                  StitchSectionTitle(
                    title: 'Spor yap',
                    actionLabel: 'Tüm Tesisler',
                    onAction: () => Navigator.pushNamed(context, '/kortlar'),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
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
                                onTap: () => Navigator.pushNamed(
                                    context, '/partner-ara'),
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

                  const SizedBox(height: SwanSpace.lg),

                  // 8. Modüller: Topluluğa Katıl (Kompakt 2 Sütunlu Izgara)
                  StitchSectionTitle(
                    title: 'Topluluğa katıl',
                    actionLabel: 'Kulüpler',
                    onAction: () => Navigator.pushNamed(context, '/kulupler'),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
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
                                onTap: () => Navigator.pushNamed(
                                    context, '/topluluklar'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: SwanSpace.lg),

                  // 9. Modüller: İhtiyacını Bul (Kompakt 2 Sütunlu Izgara)
                  StitchSectionTitle(
                    title: 'İhtiyacını bul',
                    actionLabel: 'İlanlar',
                    onAction: () => Navigator.pushNamed(context, '/ilanlar'),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (ref.watch(featureEnabledProvider(
                                FeatureFlags.marketplace)))
                              SizedBox(
                                width: itemWidth,
                                child: _ModuleGridCard(
                                  icon: Icons.storefront_rounded,
                                  title: 'Pazaryeri',
                                  subtitle: 'Sıfır ve 2. el ekipman',
                                  iconColor: context.swan.warning,
                                  badge: 'Pazar',
                                  onTap: () => Navigator.pushNamed(
                                      context, '/pazaryeri'),
                                ),
                              ),
                            if (ref.watch(featureEnabledProvider(
                                FeatureFlags.liveMatchHub)))
                              SizedBox(
                                  width: itemWidth,
                                  child: _ModuleGridCard(
                                    icon: Icons.scoreboard_outlined,
                                    title: 'Canlı Skor',
                                    subtitle: 'Resmi maçları takip et',
                                    iconColor: context.swan.ink,
                                    badge: 'Müsabaka',
                                    onTap: () => Navigator.pushNamed(
                                        context, '/canli-skor'),
                                  )),
                            SizedBox(
                              width: itemWidth,
                              child: _ModuleGridCard(
                                icon: Icons.verified_rounded,
                                title: 'Federasyon',
                                subtitle: 'Fikstür, sonuç, takvim',
                                iconColor: context.swan.accent,
                                badge: 'Resmi',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/federasyon-merkezi',
                                ),
                              ),
                            ),
                            if (ref.watch(
                                featureEnabledProvider('coach_discovery')))
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

                  const SizedBox(height: SwanSpace.lg),

                  // 13. Kulüp Gönderileri & Trendler (Sosyal Akış - En Altta)
                  StitchSectionTitle(
                    title: 'Kulüplerden paylaşımlar',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                            child: Text('En yeniler',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SwanType.caption(c.inkMuted))),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

class _ExploreSearchPanel extends StatelessWidget {
  const _ExploreSearchPanel({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.accent.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugün ne keşfetmek istersin?',
            style: SwanType.h2(c.ink),
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'İsim, kulüp, branş veya şehir yazarak hızlıca bul.',
            style: SwanType.bodySm(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.md),
          Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            child: InkWell(
              key: const Key('explore-search-entry'),
              onTap: onSearch,
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              child: Container(
                height: 54,
                padding: const EdgeInsets.fromLTRB(
                  SwanSpace.md,
                  0,
                  SwanSpace.xs,
                  0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SwanRadius.lg),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        color: c.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      child: Text(
                        'SwanSport’ta ara',
                        style: SwanType.body(c.inkMuted),
                      ),
                    ),
                    Tooltip(
                      message: 'Arama filtrelerini aç',
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: c.ink,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          Wrap(
            spacing: SwanSpace.xs,
            runSpacing: SwanSpace.xs,
            children: [
              for (final label in const ['Kulüp', 'Antrenör', 'Branş', 'Şehir'])
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    switch (label) {
                      'Kulüp' => Icons.shield_outlined,
                      'Antrenör' => Icons.sports_outlined,
                      'Branş' => Icons.category_outlined,
                      _ => Icons.location_on_outlined,
                    },
                    size: 16,
                    color: c.accent,
                  ),
                  label: Text(label),
                  onPressed: onSearch,
                  backgroundColor: c.surface,
                  side: BorderSide(color: c.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExploreFocusCard extends StatelessWidget {
  const _ExploreFocusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 128 : 86),
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(SwanRadius.lg),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _iconBox(c),
                      const SizedBox(height: SwanSpace.md),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(c.ink, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      _iconBox(c),
                      const SizedBox(width: SwanSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: SwanType.body(c.ink, w: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.bodySm(c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: c.accent,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(SwanPalette c) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Icon(icon, color: c.accent, size: 22),
      );
}

class _StitchExploreHeader extends ConsumerWidget {
  const _StitchExploreHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwanFloatingHeader(
      title: Text('Keşfet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SwanType.h2(context.swan.ink)),
      actions: const [InboxActions(spacing: 0)],
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
    final icCol = iconColor ?? c.accent;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          child: Container(
            height: 78,
            padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.sm,
              vertical: SwanSpace.sm,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: icCol.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Icon(icon, color: icCol, size: 20),
                ),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
