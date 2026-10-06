import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Antrenör ve Uzman Koçluk Keşfi ekranı.
///
/// Stitch `zel_ders_ve_ko_luk_randevusu` tasarımı:
/// - 1-e-1 Bireysel ve İleri Teknik Klinik format seçicisi
/// - Odak alanı / branş filtre çipleri
/// - Performans gelişim paketi avantaj afişi (%15 tasarruf)
/// - Başantrenör odak seans kartı & metodoloji gridi (240fps video analiz, clicker yönetimi)
/// - Uzman kadro listesi ve doğrudan randevu/mesajlaşma akışı
/// - Esnek iptal ve telafi güvencesi
class CoachDiscoveryScreen extends ConsumerStatefulWidget {
  const CoachDiscoveryScreen({super.key});

  @override
  ConsumerState<CoachDiscoveryScreen> createState() =>
      _CoachDiscoveryScreenState();
}

class _CoachDiscoveryScreenState extends ConsumerState<CoachDiscoveryScreen> {
  final _search = TextEditingController();
  String? _query;
  String? _sport;
  int _formatIndex = 0; // 0: 1-e-1 Özel Bireysel, 1: İleri Teknik Klinik
  int _focusChipIndex = 0;

  final List<String> _focusChips = const [
    'Tümü',
    'Olimpik Yay Teknik',
    'Makaralı Yay',
    'Biyomekanik & Form',
    'Zihinsel Performans & Odak',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final results = ref.watch(
      coachSearchProvider((query: _query, sport: _sport, city: null)),
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
              children: [
                _buildTopBar(context, ink, surf, line),
                const SizedBox(height: 14),
                _buildHeadline(ink),
                const SizedBox(height: 14),
                _buildFormatSwitcher(isDark, surf, line, ink),
                const SizedBox(height: 14),
                _buildFocusChipBar(isDark),
                const SizedBox(height: 14),
                _buildSearchField(surf, line, ink),
                const SizedBox(height: 16),
                _buildPackagePromoBanner(),
                const SizedBox(height: 18),
                _buildFeaturedHeadCoachCard(context, isDark, surf, line, ink),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_rounded,
                            size: 20, color: kTeal),
                        const SizedBox(width: 8),
                        Text('Uzman Kadro', style: SwanType.h3(ink)),
                      ],
                    ),
                    Text(
                      'Doğrulanmış Antrenörler',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                results.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return premiumEmpty(
                        context,
                        icon: Icons.sports_rounded,
                        title: 'Antrenör bulunamadı',
                        subtitle: _sport == null && _query == null
                            ? 'Henüz randevu kabul eden antrenör bulunamadı.'
                            : 'Aramayı veya branşı değiştirip tekrar dene.',
                      );
                    }
                    return Column(
                      children: list
                          .map(
                            (k) => _buildCoachCard(
                              context,
                              isDark,
                              surf,
                              line,
                              ink,
                              k,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildTrustGuaranteeCard(isDark, surf, line, ink),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Color ink,
    Color surf,
    Color line,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SwanSport',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
                Text('Koçluk & Özel Ders', style: SwanType.h2(ink)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: ink),
              onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeadline(Color ink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'ELİT GELİŞİM PROGRAMI',
              style: SwanType.caption(kTeal, w: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('Antrenör & Uzman Mentorluk', style: SwanType.h1(ink)),
        const SizedBox(height: 2),
        Text(
          'Hedeflerinize yönelik biyomekanik hassasiyet, zihinsel denge ve olimpik teknik seansları.',
          style: SwanType.bodySm(SwanColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFormatSwitcher(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _formatIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _formatIndex == 0 ? surf : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _formatIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color:
                          _formatIndex == 0 ? kTeal : SwanColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '1-e-1 Özel Bireysel',
                      style: SwanType.bodySm(
                        _formatIndex == 0 ? kTeal : SwanColors.textSecondary,
                        w: _formatIndex == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _formatIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _formatIndex == 1 ? surf : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _formatIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color:
                          _formatIndex == 1 ? kTeal : SwanColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'İleri Klinik (Maks 3)',
                      style: SwanType.bodySm(
                        _formatIndex == 1 ? kTeal : SwanColors.textSecondary,
                        w: _formatIndex == 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusChipBar(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_focusChips.length, (i) {
          final isSelected = _focusChipIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _focusChipIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kTeal
                      : (isDark ? SwanPalette.dark : SwanPalette.light).surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? kTeal
                        : (isDark ? SwanPalette.dark : SwanPalette.light).line,
                  ),
                ),
                child: Text(
                  _focusChips[i],
                  style: SwanType.caption(
                    isSelected ? Colors.white : SwanColors.textSecondary,
                    w: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchField(Color surf, Color line, Color ink) {
    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: TextField(
        controller: _search,
        onChanged: (v) {
          if (v.isEmpty && _query != null) {
            setState(() => _query = null);
          } else {
            setState(() => _query = v.trim().isEmpty ? null : v.trim());
          }
        },
        style: SwanType.bodySm(ink),
        decoration: InputDecoration(
          hintText: 'İsim, branş veya şehir ara…',
          hintStyle: SwanType.bodySm(SwanColors.textSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF575E70),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPackagePromoBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kTeal, Color(0xFF004F54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kTeal.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PERFORMANS PAKETİ',
                      style: SwanType.caption(Colors.white, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8CF2FC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '%15 Tasarruf',
                  style: SwanType.caption(
                    const Color(0xFF002022),
                    w: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '5 Seanslık Performans Gelişim Paketi',
            style: SwanType.h2(Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Kapsamlı video biyomekanik analiz raporu ve 1 aylık kişiselleştirilmiş dril antrenman programı hediye!',
            style: SwanType.bodySm(Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: Color(0xFF8CF2FC),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Biyomekanik Grafik Dahil',
                    style: SwanType.caption(
                      const Color(0xFF8CF2FC),
                      w: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Performans paketi sepete eklendi.'),
                      backgroundColor: kTeal,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Paketi İncele',
                  style: SwanType.caption(kTeal, w: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedHeadCoachCard(
    BuildContext context,
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.military_tech_rounded,
                    size: 20,
                    color: kTeal,
                  ),
                  const SizedBox(width: 8),
                  Text('Başantrenör Odak Seansı', style: SwanType.h3(ink)),
                ],
              ),
              Text(
                'Kontenjan Sınırlı',
                style: SwanType.caption(SwanColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'AK',
                        style: TextStyle(
                          color: kTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ahmet Kaya', style: SwanType.h2(ink)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F4F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFEAB308),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '5.0',
                                style: SwanType.caption(
                                  ink,
                                  w: FontWeight.w700,
                                ),
                              ),
                              Text(
                                ' (64)',
                                style: SwanType.caption(
                                  SwanColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Başantrenör & Eski Milli Takım Sporcusu',
                      style: SwanType.caption(kTeal, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '14 Yıl Deneyim • 3x Dünya Kupası • Kademe 4 Kıdemli',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Methodology grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildMethodologyRow(
                  Icons.videocam_outlined,
                  'Yüksek hızda kamera (240fps) form & duruş analizi',
                  ink,
                ),
                const SizedBox(height: 6),
                _buildMethodologyRow(
                  Icons.psychology_outlined,
                  'Clicker baskı yönetimi ve mikro-odak optimizasyonu',
                  ink,
                ),
                const SizedBox(height: 6),
                _buildMethodologyRow(
                  Icons.adjust_rounded,
                  'Müsabaka ve rüzgar okuma taktik matrisi',
                  ink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('₺1.200', style: SwanType.h2(kTeal)),
                      const SizedBox(width: 4),
                      Text(
                        '/ 60 dk',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.loyalty_rounded,
                        size: 14,
                        color: kTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Kulüp Sporcularına: ₺950',
                        style: SwanType.caption(kTeal, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/profil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ink,
                      side: BorderSide(color: line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Profil'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/sohbet',
                      arguments: {
                        'id': 'coach-ahmet-kaya',
                        'name': 'Ahmet Kaya',
                      },
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Randevu Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodologyRow(IconData icon, String text, Color ink) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kTeal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: SwanType.caption(ink, w: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildCoachCard(
    BuildContext context,
    bool isDark,
    Color surf,
    Color line,
    Color ink,
    CoachResult k,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    k.fullName.isNotEmpty ? k.fullName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: kTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            k.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F4F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFEAB308),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '4.9',
                                style: SwanType.caption(
                                  ink,
                                  w: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 12,
                          color: kTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          [k.levelLabel, k.cityCode]
                              .where((e) => (e ?? '').isNotEmpty)
                              .join(' · '),
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((k.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              k.bio!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('₺850', style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  const SizedBox(width: 2),
                  Text(
                    '/ 50 dk',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/sohbet',
                  arguments: {'id': k.profileId, 'name': k.fullName},
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Seans Seç',
                  style: SwanType.caption(Colors.white, w: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustGuaranteeCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_clock_rounded, size: 20, color: kTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esnek İptal ve Telafi Güvencesi',
                  style: SwanType.bodySm(ink, w: FontWeight.w700),
                ),
                Text(
                  'Seans başlangıcından 12 saat öncesine kadar kesintisiz erteleme veya iade.',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
