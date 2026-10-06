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

                // 4. Öne Çıkan Duyurular (Stitch Hero Cards)
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

                // 5. Popüler Sporcular & Antrenörler
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

                // 6. Google Stitch Screen 25 Trend Challenge Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _buildTrendChallengeBanner(
                      surf, surfHigh, borderCol, textPrimary, textMuted),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 7. Google Stitch Screen 25 Asymmetric 3-Column Bento Grid
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
                              'BENTO GRID',
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

                // 8. Google Stitch Screen 25 Günün Hareketi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _buildMovementOfTheDay(
                      surf, surfHigh, borderCol, textPrimary, textMuted),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 9. Kulüp Gönderileri & Trendler
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

                const SizedBox(height: SwanSpace.xl),

                // 10. Hızlı Keşif Kısayolları
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _QuickExplore(
                    marketplaceEnabled: ref.watch(
                        featureEnabledProvider(FeatureFlags.marketplace)),
                  ),
                ),

                const SizedBox(height: SwanSpace.xl),

                // 11. Modüller: Spor Yap
                const StitchSectionTitle(title: 'Spor yap'),
                StitchActionTile(
                  icon: Icons.stadium_rounded,
                  title: 'Kortlar & Sahalar',
                  subtitle: 'Tesis ve saha rezervasyonları',
                  onTap: () => Navigator.pushNamed(context, '/kortlar'),
                ),
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

                // 12. Modüller: Topluluğa Katıl
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

                // 13. Modüller: İhtiyacını Bul
                const StitchSectionTitle(title: 'İhtiyacını bul'),
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
                      'TREND',
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
            '30 Günlük Swan Push-Up',
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
                              'Bench Press',
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
                          'Muscle-Up',
                          style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary),
                        ),
                        Text(
                          'Calisthenics',
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
                          '20/10 HIIT',
                          style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textPrimary),
                        ),
                        Text(
                          'Tabata KB',
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
                  'Tek Bacak Pistol Squat',
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

/// En çok kullanılan keşif yolları.
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
