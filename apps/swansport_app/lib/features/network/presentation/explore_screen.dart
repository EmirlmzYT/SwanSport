import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/inbox_actions.dart';
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_skeleton.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../social/presentation/widgets/feed_entry.dart';
import '../../social/presentation/widgets/follow_suggestions.dart';
import '../../social/presentation/widgets/social_widgets.dart';

/// Keşfet — uygulamanın ikinci ana merkezi.
///
/// **34 girişlik modül menüsünün yerini alan iki ekrandan biri** (öteki
/// Profil > Yönetim). Menü kalktı ama hiçbir rota silinmedi; buradan
/// gidiliyor.
///
/// Brief §7'nin uyarısı tasarımı belirledi: *"Keşfet ekranı bir admin menüsü
/// gibi görünmemeli."* Bu yüzden küçük ikonlu ızgara değil — her satır
/// başlığı, açıklaması ve nefes alanı olan bir liste. İkon ızgarası tam da
/// kaçtığımız "katalog" hissini geri getirirdi.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 132),
              children: [
                const _StitchExploreHeader(),
                const SizedBox(height: SwanSpace.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: StitchSearchBar(
                    hint: 'Sporcu, kulüp, etkinlik veya branş ara...',
                    onTap: () => Navigator.pushNamed(context, '/ara'),
                    onFilter: () => Navigator.pushNamed(context, '/ara'),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),
                const _DisciplinePills(),
                const SizedBox(height: SwanSpace.lg),
                StitchSectionTitle(
                  title: 'Öne Çıkan Duyurular',
                  actionLabel: 'Tümü',
                  onAction: () => Navigator.pushNamed(context, '/duyurular'),
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
                                horizontal: SwanSpace.lg,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final item in items.take(6))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: SwanSpace.md,
                                      ),
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
                                            context,
                                            '/duyurular',
                                          ),
                                          tone: item.pinned ? c.warning : null,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                const SizedBox(height: SwanSpace.xl),
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
                StitchSectionTitle(
                  title: 'Kulüp Gönderileri & Trendler',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 17,
                        color: c.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text('En yeniler', style: SwanType.caption(c.inkMuted)),
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
                const SizedBox(height: SwanSpace.xl),

                // Üç bölüm, üç ayrı niyet: "bugün spor yapacağım",
                // "bir yere ait olmak istiyorum", "bir şeye ihtiyacım var".
                // Öncekinde iki bölüm vardı ve pazaryeri ile kort aynı
                // başlığın altındaydı — ikisi farklı sorulara cevap veriyor.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _QuickExplore(
                    marketplaceEnabled: ref.watch(
                      featureEnabledProvider(FeatureFlags.marketplace),
                    ),
                  ),
                ),
                const SizedBox(height: SwanSpace.xl),

                const StitchSectionTitle(title: 'Spor yap'),
                StitchActionTile(
                  icon: Icons.handshake_rounded,
                  title: 'Partner bul',
                  subtitle: 'Birlikte oynayacak birini ara',
                  onTap: () => Navigator.pushNamed(context, '/partner-ara'),
                ),
                StitchActionTile(
                  icon: Icons.emoji_events_rounded,
                  title: 'Organizasyonlar',
                  subtitle: 'Turnuva, kamp ve etkinlikler',
                  onTap: () => Navigator.pushNamed(context, '/organizasyonlar'),
                ),
                StitchActionTile(
                  icon: Icons.military_tech_rounded,
                  title: 'Liderlik & Ligler',
                  subtitle: 'Sezon 4 canlı sıralama, podyum ve meydan okumalar',
                  onTap: () => Navigator.pushNamed(context, '/liderlik'),
                ),
                StitchActionTile(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Beslenme & Makrolar',
                  subtitle: 'Metabolik yakıt dengesi, hidrasyon ve öğün takibi',
                  onTap: () => Navigator.pushNamed(context, '/beslenme'),
                ),

                const SizedBox(height: SwanSpace.xl),
                const StitchSectionTitle(title: 'Topluluğa katıl'),
                StitchActionTile(
                  icon: Icons.travel_explore_rounded,
                  title: 'Kulüpler',
                  subtitle: 'İl, ilçe ve branşa göre bul',
                  onTap: () => Navigator.pushNamed(context, '/kulupler'),
                ),
                StitchActionTile(
                  icon: Icons.forum_rounded,
                  title: 'Topluluklar',
                  subtitle: 'İlinin antrenör grupları',
                  onTap: () => Navigator.pushNamed(context, '/topluluklar'),
                ),
                if (access.isClubStaff)
                  StitchActionTile(
                    icon: Icons.shield_rounded,
                    title: 'Takımlar',
                    subtitle: 'Kadrolar ve takım sayfaları',
                    onTap: () => Navigator.pushNamed(context, '/teams'),
                  ),

                const SizedBox(height: SwanSpace.xl),
                const StitchSectionTitle(title: 'İhtiyacını bul'),
                // Pazaryeri **özellik bayrağının arkasında** (0053).
                // "Yakında" kartı göstermiyoruz: kullanılamayan bir şeyi
                // göstermek, olmayan bir şeyi göstermekten kötü — kullanıcı
                // her seferinde tekrar deniyor.
                if (ref.watch(featureEnabledProvider(FeatureFlags.marketplace)))
                  StitchActionTile(
                    icon: Icons.storefront_rounded,
                    title: 'Spor Malzemeleri Pazaryeri',
                    subtitle: 'Sıfır ve ikinci el ürünler',
                    onTap: () => Navigator.pushNamed(context, '/pazaryeri'),
                  ),
                if (ref.watch(featureEnabledProvider('coach_discovery')))
                  StitchActionTile(
                    icon: Icons.sports_rounded,
                    title: 'Antrenör bul',
                    subtitle: 'Doğrulanmış antrenörler, branş ve şehre göre',
                    onTap: () => Navigator.pushNamed(context, '/antrenor-bul'),
                  ),
                StitchActionTile(
                  icon: Icons.campaign_rounded,
                  title: 'İlanlar',
                  subtitle: 'Sporcu, antrenör ve seçme ilanları',
                  onTap: () => Navigator.pushNamed(context, '/ilanlar'),
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

class _DisciplinePills extends StatelessWidget {
  const _DisciplinePills();

  static const _items = [
    ('Tümü', null),
    ('Okçuluk', '12'),
    ('Yüzme', '8'),
    ('Basketbol', '15'),
    ('Voleybol', '6'),
    ('Tenis', '9'),
    ('Futbol', '14'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: SwanSpace.xs),
        itemBuilder: (context, index) {
          final item = _items[index];
          final selected = index == 0;
          return InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              '/ara',
              arguments: item.$1 == 'Tümü' ? null : {'query': item.$1},
            ),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? c.accentFill : c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.$1,
                    style: SwanType.caption(
                      selected ? Colors.white : c.inkMuted,
                      w: FontWeight.w700,
                    ),
                  ),
                  if (item.$2 != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.$2!,
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// En çok kullanılan keşif yolları. Liste görünümünü bozmadan, kullanıcıyı
/// birkaç ekran derinliğine göndermeden doğrudan niyetine götürür.
class _QuickExplore extends StatelessWidget {
  const _QuickExplore({required this.marketplaceEnabled});
  final bool marketplaceEnabled;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final items = [
      (Icons.stadium_rounded, 'Saha', '/kortlar'),
      (Icons.handshake_rounded, 'Partner', '/partner-ara'),
      (Icons.groups_rounded, 'Kulüp', '/kulupler'),
      if (marketplaceEnabled)
        (Icons.storefront_rounded, 'Pazaryeri', '/pazaryeri'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hızlı keşfet', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: SwanSpace.sm),
            itemBuilder: (context, index) {
              final item = items[index];
              return Semantics(
                button: true,
                label: '${item.$2} bölümünü aç',
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, item.$3),
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.all(SwanSpace.md),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                      border: Border.all(color: c.line.withValues(alpha: .5)),
                    ),
                    child: Row(
                      children: [
                        Icon(item.$1, color: c.accent, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(c.ink, w: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
