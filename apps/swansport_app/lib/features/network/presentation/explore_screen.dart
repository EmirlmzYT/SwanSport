import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

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
import '../../social/presentation/widgets/social_widgets.dart';

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
  int _selectedCategory = 0;
  bool _challengeJoined = false;

  static const _categories = [
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF132031) : SwanPalette.light.surface;
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFEAEFF8);
    final borderCol = isDark ? const Color(0xFF293547) : SwanPalette.light.line;
    final textPrimary =
        isDark ? const Color(0xFFD6E3FA) : SwanPalette.light.ink;
    final textMuted =
        isDark ? const Color(0xFF869491) : SwanColors.textSecondary;
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

                // 3. Kategori Rozetleri (Discipline Pills)
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: SwanSpace.xs),
                    itemBuilder: (context, index) {
                      final item = _categories[index];
                      final selected = _selectedCategory == index;
                      return InkWell(
                        onTap: () => setState(() => _selectedCategory = index),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
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
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item.$2!,
                                    style: SwanType.caption(c.inkMuted,
                                        w: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: SwanSpace.lg),

                // 4. Hızlı Modül Hub'ı (4 Ana Kategori Kartı)
                const _ExploreModuleHub(),

                const SizedBox(height: SwanSpace.xl),

                // 5. Öne Çıkan Duyurular (Stitch Hero Cards)
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
                                              context, '/duyurular'),
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
                              subtitle: 'Tesis rezervasyonları',
                              iconColor: kTeal,
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
                              iconColor: const Color(0xFF38BDF8),
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
                              iconColor: const Color(0xFFF59E0B),
                              badge: 'Turnuva',
                              onTap: () => Navigator.pushNamed(
                                  context, '/organizasyonlar'),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.military_tech_rounded,
                              title: 'Liderlik & Ligler',
                              subtitle: 'Sezon 4 canlı sıralama',
                              iconColor: const Color(0xFFEC4899),
                              badge: 'Lig',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/liderlik'),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _ModuleGridCard(
                              icon: Icons.restaurant_menu_rounded,
                              title: 'Beslenme & Makro',
                              subtitle: 'Metabolik yakıt & öğün',
                              iconColor: const Color(0xFF10B981),
                              badge: 'Sağlık',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/beslenme'),
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
                              iconColor: const Color(0xFF8B5CF6),
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
                              iconColor: const Color(0xFF6366F1),
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
                                iconColor: kTeal,
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
                                iconColor: const Color(0xFFF97316),
                                badge: 'Pazar',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/pazaryeri'),
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
                                iconColor: const Color(0xFF06B6D4),
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
                              iconColor: const Color(0xFFEC4899),
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

                // 10. Google Stitch Screen 25 Trend Challenge Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _buildTrendChallengeBanner(
                      surf, surfHigh, borderCol, textPrimary, textMuted),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 11. Google Stitch Screen 25 Asymmetric 3-Column Bento Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Performans & Keşif Kinetiği',
                            style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'KEŞİF IZGARASI',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: kTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildBentoGrid(
                          surf, surfHigh, borderCol, textPrimary, textMuted),
                    ],
                  ),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 12. Google Stitch Screen 25 Günün Hareketi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _buildMovementOfTheDay(
                      surf, surfHigh, borderCol, textPrimary, textMuted),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 13. Kulüp Gönderileri & Trendler (Sosyal Akış - En Altta)
                StitchSectionTitle(
                  title: 'Kulüp Gönderileri & Trendler',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_rounded,
                          size: 17, color: c.inkMuted),
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTrendChallengeBanner(
    Color surf,
    Color surfHigh,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surfHigh,
            surf,
            const Color(0xFF020F1F),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        size: 13, color: kTeal),
                    const SizedBox(width: 3),
                    Text(
                      'GÜNCEL',
                      style: GoogleFonts.plusJakartaSans(
                        color: kTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        size: 15, color: Color(0xFFFFB6A4)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '1.000 XP + Rozet',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFFB6A4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '30 Günlük Swan Şınav Meydan Okuması',
            style: GoogleFonts.sora(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Her gün formunu mükemmelleştir, patlayıcı itiş gücü kazan ve global sıralamada yerini al.',
            style: GoogleFonts.plusJakartaSans(
              color: textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.group_rounded, size: 15, color: kTeal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '4.280 sporcu',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _challengeJoined = !_challengeJoined);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _challengeJoined
                            ? '30 Günlük Swan Push-Up meydan okumasına katıldınız! +50 XP'
                            : 'Meydan okuma takibinden ayrıldınız.',
                      ),
                      backgroundColor:
                          _challengeJoined ? kTeal : SwanColors.textSecondary,
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        _challengeJoined ? kTeal.withValues(alpha: 0.2) : kTeal,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kTeal),
                  ),
                  child: Text(
                    _challengeJoined ? 'Takipte ✓' : 'Katıl & Başla',
                    style: GoogleFonts.plusJakartaSans(
                      color: _challengeJoined ? kTeal : const Color(0xFF003734),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(
    Color surf,
    Color surfHigh,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol Kart: Koparma Tekniği & Bar Hızı (Büyük Kart)
            Expanded(
              flex: 3,
              child: Container(
                height: 236,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E2B3C),
                      Color(0xFF132031),
                      Color(0xFF061424),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded,
                              size: 12, color: kTeal),
                          const SizedBox(width: 4),
                          Text(
                            'Form Analizi',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Koparma Tekniği & Bar Hızı',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '42.5K',
                              style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70, fontSize: 10),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 12, color: Color(0xFFFF8C6F)),
                                const SizedBox(width: 2),
                                Text(
                                  '1.4K',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Sağ Kartlar: PR Kutucuğu + Runner Kutucuğu
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Container(
                    height: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF8C6F)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PR',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFFF8C6F),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(Icons.trending_up_rounded,
                                size: 16, color: Color(0xFFFF8C6F)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '142.5 kg',
                              style: GoogleFonts.sora(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Göğüs Pres (Bench Press)',
                              style: GoogleFonts.plusJakartaSans(
                                  color: textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bebek Sahil',
                              style: GoogleFonts.plusJakartaSans(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Icon(Icons.route_rounded,
                                size: 16, color: kTeal),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '12.4 km',
                              style: GoogleFonts.sora(
                                color: kTeal,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "4'18\" tempo",
                              style: GoogleFonts.plusJakartaSans(
                                  color: textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Alt Satır: Makro Kase + Calisthenics + Tabata (3'lü Bento)
        Row(
          children: [
            Expanded(
              child: Container(
                height: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.restaurant_rounded,
                        color: Color(0xFF75F7ED), size: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '52g Protein',
                          style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary),
                        ),
                        Text(
                          'Makro Kase',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.sports_gymnastics_rounded,
                        color: kTeal, size: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Barfiks & Çekiş (Muscle-Up)',
                          style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary),
                        ),
                        Text(
                          'Vücut Ağırlığı (Kalistenik)',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 104,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Color(0xFFFF8C6F), size: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '20/10 HIIT Kardiyo',
                          style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary),
                        ),
                        Text(
                          'Tabata Girya (KB)',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMovementOfTheDay(
    Color surf,
    Color surfHigh,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.self_improvement_rounded,
                color: kTeal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'GÜNÜN HAREKETİ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kTeal,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· 4 Set x 6 Tekrar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Tek Bacak Çömelme (Pistol Squat)',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Tek bacak stabilizasyonu, kalça mobilitesi ve quadriceps gücü.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textMuted, size: 22),
        ],
      ),
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
class _ExploreModuleHub extends ConsumerWidget {
  const _ExploreModuleHub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? const Color(0xFFD6E3FA) : SwanPalette.light.ink;
    final marketplaceEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.marketplace));

    final hubs = [
      (
        title: 'Spor Yap',
        badge: 'Kort & Lig',
        icon: Icons.stadium_rounded,
        color: kTeal,
        route: '/kortlar',
      ),
      (
        title: 'Topluluk',
        badge: 'Kulüpler',
        icon: Icons.groups_rounded,
        color: const Color(0xFF8B5CF6),
        route: '/kulupler',
      ),
      (
        title: 'Pazar & İlan',
        badge: 'Fırsatlar',
        icon: Icons.storefront_rounded,
        color: const Color(0xFFF59E0B),
        route: marketplaceEnabled ? '/pazaryeri' : '/ilanlar',
      ),
      (
        title: 'Liderlik',
        badge: 'Sezon 4',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFEC4899),
        route: '/liderlik',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hızlı Modül Hub\'ı',
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/kortlar'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Tüm Servisler →',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < hubs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, hubs[i].route),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              hubs[i].color.withValues(alpha: isDark ? 0.16 : 0.10),
                              isDark
                                  ? const Color(0xFF132031)
                                  : SwanPalette.light.surface,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hubs[i].color.withValues(alpha: isDark ? 0.35 : 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: hubs[i].color.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(hubs[i].icon,
                                  color: hubs[i].color, size: 19),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hubs[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hubs[i].badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: hubs[i].color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF132031) : SwanPalette.light.surface;
    final borderCol = isDark ? const Color(0xFF293547) : SwanPalette.light.line;
    final textPrimary =
        isDark ? const Color(0xFFD6E3FA) : SwanPalette.light.ink;
    final textMuted =
        isDark ? const Color(0xFF869491) : SwanColors.textSecondary;
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
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: icCol,
                            ),
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
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: textMuted,
                      ),
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
