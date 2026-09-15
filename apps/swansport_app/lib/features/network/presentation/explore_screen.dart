import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/inbox_actions.dart';
import '../../../app/widgets/premium.dart';
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
                  child: _SearchField(c: c),
                ),
                const SizedBox(height: SwanSpace.md),
                const _DisciplinePills(),
                const SizedBox(height: SwanSpace.lg),
                _section(
                  c,
                  'Öne Çıkan Duyurular',
                  actionLabel: 'Tümü',
                  onAction: () => Navigator.pushNamed(context, '/duyurular'),
                ),
                ref.watch(announcementsProvider).when(
                      loading: () => const LinearProgressIndicator(),
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
                                    _FeaturedAnnouncementCard(
                                      c: c,
                                      item: item,
                                    ),
                                ],
                              ),
                            ),
                    ),
                const SizedBox(height: SwanSpace.xl),
                _section(
                  c,
                  'Popüler Sporcular & Antrenörler',
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
                _section(
                  c,
                  'Kulüp Gönderileri & Trendler',
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
                      loading: () => const LinearProgressIndicator(),
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

                _section(c, 'Spor yap'),
                _Row(
                  c: c,
                  icon: Icons.handshake_rounded,
                  title: 'Partner bul',
                  subtitle: 'Birlikte oynayacak birini ara',
                  route: '/partner-ara',
                ),
                _Row(
                  c: c,
                  icon: Icons.emoji_events_rounded,
                  title: 'Organizasyonlar',
                  subtitle: 'Turnuva, kamp ve etkinlikler',
                  route: '/organizasyonlar',
                ),

                const SizedBox(height: SwanSpace.xl),
                _section(c, 'Topluluğa katıl'),
                _Row(
                  c: c,
                  icon: Icons.travel_explore_rounded,
                  title: 'Kulüpler',
                  subtitle: 'İl, ilçe ve branşa göre bul',
                  route: '/kulupler',
                ),
                _Row(
                  c: c,
                  icon: Icons.forum_rounded,
                  title: 'Topluluklar',
                  subtitle: 'İlinin antrenör grupları',
                  route: '/topluluklar',
                ),
                if (access.isClubStaff)
                  _Row(
                    c: c,
                    icon: Icons.shield_rounded,
                    title: 'Takımlar',
                    subtitle: 'Kadrolar ve takım sayfaları',
                    route: '/teams',
                  ),

                const SizedBox(height: SwanSpace.xl),
                _section(c, 'İhtiyacını bul'),
                // Pazaryeri **özellik bayrağının arkasında** (0053).
                // "Yakında" kartı göstermiyoruz: kullanılamayan bir şeyi
                // göstermek, olmayan bir şeyi göstermekten kötü — kullanıcı
                // her seferinde tekrar deniyor.
                if (ref.watch(featureEnabledProvider(FeatureFlags.marketplace)))
                  _Row(
                    c: c,
                    icon: Icons.storefront_rounded,
                    title: 'Spor Malzemeleri Pazaryeri',
                    subtitle: 'Sıfır ve ikinci el ürünler',
                    route: '/pazaryeri',
                  ),
                if (ref.watch(featureEnabledProvider('coach_discovery')))
                  _Row(
                    c: c,
                    icon: Icons.sports_rounded,
                    title: 'Antrenör bul',
                    subtitle: 'Doğrulanmış antrenörler, branş ve şehre göre',
                    route: '/antrenor-bul',
                  ),
                _Row(
                  c: c,
                  icon: Icons.campaign_rounded,
                  title: 'İlanlar',
                  subtitle: 'Sporcu, antrenör ve seçme ilanları',
                  route: '/ilanlar',
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _section(
    SwanPalette c,
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
    Widget? trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg,
          0,
          SwanSpace.lg,
          SwanSpace.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 18,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(child: Text(title, style: SwanType.h3(c.ink))),
            if (trailing != null) trailing,
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel),
                    const Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _StitchExploreHeader extends ConsumerWidget {
  const _StitchExploreHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: c.isDark ? .88 : .94),
        border: Border(bottom: BorderSide(color: c.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? .18 : .035),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentFill,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Text(
              'S',
              style: SwanType.h2(Colors.white),
            ),
          ),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SwanSport', style: SwanType.h3(c.ink)),
                Text(
                  'CLUB OPS & NETWORK',
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                ),
              ],
            ),
          ),
          const InboxActions(),
          const SizedBox(width: SwanSpace.xs),
          InkWell(
            onTap: profile == null
                ? null
                : () => Navigator.pushNamed(
                      context,
                      '/profil',
                      arguments: profile.id,
                    ),
            borderRadius: BorderRadius.circular(999),
            child: GradientAvatar(
              initials: profile?.initials ?? 'S',
              size: 32,
              radius: 999,
              gradientIndex: (profile?.fullName.length ?? 0) % 4,
            ),
          ),
        ],
      ),
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

class _FeaturedAnnouncementCard extends StatelessWidget {
  const _FeaturedAnnouncementCard({required this.c, required this.item});

  final SwanPalette c;
  final AnnouncementRow item;

  @override
  Widget build(BuildContext context) {
    final tone = item.pinned ? c.warning : c.accent;
    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? .16 : .04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/duyurular'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 128,
              width: double.infinity,
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tone.withValues(alpha: .88),
                    c.accentFill.withValues(alpha: .72),
                    const Color(0xFF111827),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    bottom: -10,
                    child: Icon(
                      Icons.campaign_rounded,
                      size: 82,
                      color: Colors.white.withValues(alpha: .15),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .90),
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                      ),
                      child: Text(
                        item.pinned ? 'Sabit duyuru' : 'Kulüp duyurusu',
                        style: SwanType.caption(tone, w: FontWeight.w800),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          shortAgo(item.createdAt),
                          style: SwanType.caption(
                            Colors.white,
                            w: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 12,
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'SwanSport kulüp ağı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              SwanType.caption(c.inkMuted, w: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SwanSpace.xs),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.body(c.ink, w: FontWeight.w800),
                  ),
                  if (item.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                  const SizedBox(height: SwanSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.pinned ? 'Öne sabitlendi' : 'Yeni duyuru',
                          style: SwanType.caption(c.accent, w: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/duyurular'),
                        child: const Text('Detayları Gör'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
                      border: Border.all(color: c.line),
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

/// "Ne arıyorsun?" — dokununca arama ekranını açar.
///
/// Gerçek `TextField` değil: arama ayrı bir ekran ve orada odaklanmış bir
/// alan var. Burada iki tane arama kutusu olması kafa karıştırırdı.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.c});
  final SwanPalette c;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Arama ekranını aç',
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/ara'),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
              const SizedBox(width: SwanSpace.md),
              Text('Ne arıyorsun?', style: SwanType.body(c.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keşif satırı.
///
/// Kart değil: zemin farkı ve boşlukla ayrılıyor. Brief §19 —
/// *"Card yerine mümkün olduğunca section / list kullan."*
class _Row extends StatelessWidget {
  const _Row({
    required this.c,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final SwanPalette c;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title bölümünü aç',
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Icon(icon, color: c.accent, size: 21),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SwanType.body(c.ink, w: FontWeight.w700),
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
              Icon(Icons.chevron_right_rounded, size: 20, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
