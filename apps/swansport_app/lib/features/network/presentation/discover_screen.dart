import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../social/presentation/widgets/social_widgets.dart';

/// Keşfet — kulüpleri il, ilçe, branş ve doğrulanmışlık filtreleriyle bul.
///
/// Kulüp künyesindeki veriler zaten duruyordu; buraya kadar hiçbir yerden
/// filtrelenemiyordu. Ağın dışarıdan ilk temas noktası bu ekran.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  var _filter = const DiscoverFilter();

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

    final async = ref.watch(discoverClubsProvider(_filter));

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                // Top Header & Create Club Action
                _buildTopSection(context, ink, surf, isDark),
                const SizedBox(height: 14),

                // Stitch Club Category Pills
                _buildCategoryPills(isDark, ink),
                const SizedBox(height: 16),

                // My Enrolled Clubs
                _buildEnrolledClubs(isDark, ink, surf),
                const SizedBox(height: 20),

                // Weekly Community XP Leaderboard
                _buildXpLeaderboard(isDark, ink, surf),
                const SizedBox(height: 20),

                // Upcoming Local Sports Events
                _buildLocalEvents(isDark, ink, surf),
                const SizedBox(height: 20),

                // Motivational Kinetic Banner
                _buildKineticBanner(isDark, ink, surf),
                const SizedBox(height: 24),

                // Search & Filter Section for Registered Clubs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tüm Kayıtlı Kulüpler',
                      style: SwanType.bodySm(ink, w: FontWeight.w800),
                    ),
                    Text(
                      'Veritabanı',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Arama
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(
                      () => _filter = _filter.copyWith(query: v.trim())),
                  style: SwanType.bodySm(ink),
                  decoration: InputDecoration(
                    hintText: 'Kulüp adı veya şehir ara…',
                    hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    filled: true,
                    fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: line)),
                  ),
                ),
                const SizedBox(height: 10),

                _filterBar(isDark, ink),
                const SizedBox(height: 12),

                async.when(
                  loading: () => premiumLoading(),
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) => list.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: line),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.travel_explore_rounded, size: 36, color: SwanColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                'Filtreye uygun kulüp bulunamadı',
                                style: SwanType.bodySm(ink, w: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (final club in list)
                              _card(isDark, ink, club),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTopSection(BuildContext context, Color ink, Color surf, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_rounded, size: 14, color: kTeal),
                const SizedBox(width: 4),
                Text(
                  'SWAN KINETIC LEAGUE',
                  style: SwanType.caption(kTeal, w: FontWeight.w800).copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Topluluk Kulüpleri',
              style: SwanType.h2(ink),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/basvurular');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kTeal,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: kTeal.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_circle_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Kulüp Kur',
                  style: SwanType.caption(Colors.white, w: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPills(bool isDark, Color ink) {
    final categories = ['Tümü (12)', 'Koşu & Atletizm', 'Kuvvet & Güç', 'Calisthenics'];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? kTeal : (isDark ? SwanPalette.dark.surface : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? kTeal : (isDark ? SwanPalette.dark.line : SwanPalette.light.line),
              ),
            ),
            child: Text(
              categories[i],
              style: SwanType.caption(
                isSelected ? Colors.white : ink,
                w: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnrolledClubs(bool isDark, Color ink, Color surf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.verified_rounded, size: 16, color: kTeal),
                const SizedBox(width: 6),
                Text(
                  'Katıldığım Kulüpler',
                  style: SwanType.bodySm(ink, w: FontWeight.w800),
                ),
              ],
            ),
            Text(
              '2 Aktif',
              style: SwanType.caption(kTeal, w: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Card 1: Swan Runners
        _buildEnrolledClubCard(
          title: 'Swan Runners Istanbul',
          location: 'Bebek & Belgrad Ormanı',
          tag: 'PACE LİDERİ',
          members: '1.420',
          metric: '3.450 KM',
          metricLabel: 'Haftalık Koşu',
          eventTitle: 'BU CUMARTESİ · Belgrad Ormanı 15K Patika Koşusu',
          icon: Icons.directions_run_rounded,
          isDark: isDark,
          ink: ink,
          surf: surf,
        ),
        const SizedBox(height: 12),
        // Card 2: Iron Swans
        _buildEnrolledClubCard(
          title: 'Iron Swans Powerlifting',
          location: 'Maslak Performance Lab',
          tag: 'ELITE DIVISION',
          members: '680',
          metric: '18.2 TON',
          metricLabel: 'Haftalık Tonaj',
          eventTitle: 'Topluluk rekoru kırıldı: 280kg Squat',
          icon: Icons.fitness_center_rounded,
          isDark: isDark,
          ink: ink,
          surf: surf,
        ),
      ],
    );
  }

  Widget _buildEnrolledClubCard({
    required String title,
    required String location,
    required String tag,
    required String members,
    required String metric,
    required String metricLabel,
    required String eventTitle,
    required IconData icon,
    required bool isDark,
    required Color ink,
    required Color surf,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/kulup-detay'),
      child: Container(
        decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? SwanPalette.dark.line : SwanPalette.light.line),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: kTeal, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tag,
                      style: SwanType.caption(kTeal, w: FontWeight.w800).copyWith(fontSize: 10),
                    ),
                  ],
                ),
                Icon(Icons.sports_score_rounded, size: 16, color: ink),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: SwanType.body(ink, w: FontWeight.w800)),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: kTeal),
                            const SizedBox(width: 3),
                            Text(location, style: SwanType.caption(SwanColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: kTeal),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF3F5F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ÜYE SAYISI', style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700).copyWith(fontSize: 9)),
                            Text('$members Atlet', style: SwanType.bodySm(ink, w: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF3F5F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(metricLabel.toUpperCase(), style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700).copyWith(fontSize: 9)),
                            Text(metric, style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? SwanPalette.dark.line : SwanPalette.light.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 14, color: kTeal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          eventTitle,
                          style: SwanType.caption(ink, w: FontWeight.w600).copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: SwanColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildXpLeaderboard(bool isDark, Color ink, Color surf) {
    final leaders = [
      (1, 'Emir Yılmaz', 'Swan Runners Istanbul', '24.850 XP', 'ALTIN', Colors.amber),
      (2, 'Caner Demir', 'Iron Swans Powerlifting', '22.400 XP', 'GÜMÜŞ', Colors.grey.shade400),
      (3, 'Selin Kaya', 'Swan Runners Istanbul', '19.920 XP', 'BRONZ', Colors.brown.shade400),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? SwanPalette.dark.line : SwanPalette.light.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, size: 18, color: kTeal),
                  const SizedBox(width: 6),
                  Text('Haftalık XP Sıralaması', style: SwanType.bodySm(ink, w: FontWeight.w800)),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/liderlik'),
                child: Row(
                  children: [
                    Text('Tümünü Gör', style: SwanType.caption(kTeal, w: FontWeight.w700)),
                    Icon(Icons.chevron_right_rounded, size: 14, color: kTeal),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final l in leaders)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: l.$6,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${l.$1}',
                        style: SwanType.caption(Colors.white, w: FontWeight.w900).copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.$2, style: SwanType.caption(ink, w: FontWeight.w700)),
                        Text(l.$3, style: SwanType.caption(SwanColors.textSecondary).copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                  Text(l.$4, style: SwanType.caption(kTeal, w: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalEvents(bool isDark, Color ink, Color surf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: kTeal),
                const SizedBox(width: 6),
                Text('Yaklaşan Yerel Etkinlikler', style: SwanType.bodySm(ink, w: FontWeight.w800)),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/calendar'),
              child: Text('Takvim', style: SwanType.caption(kTeal, w: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Event 1
        _buildLocalEventItem(
          title: 'Boğaz Kıyısı Sabah Koşusu',
          location: 'Bebek Parkı Buluşma',
          time: 'Cumartesi 07:00',
          pace: '5:20/km',
          attendees: '+42',
          isDark: isDark,
          ink: ink,
          surf: surf,
        ),
        const SizedBox(height: 10),
        // Event 2
        _buildLocalEventItem(
          title: 'Street Workout Workshop',
          location: 'Caddebostan Sahil Parkuru',
          time: 'Pazar 14:00',
          pace: 'Kuvvet',
          attendees: '+19',
          isDark: isDark,
          ink: ink,
          surf: surf,
        ),
      ],
    );
  }

  Widget _buildLocalEventItem({
    required String title,
    required String location,
    required String time,
    required String pace,
    required String attendees,
    required bool isDark,
    required Color ink,
    required Color surf,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? SwanPalette.dark.line : SwanPalette.light.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time, style: SwanType.caption(kTeal, w: FontWeight.w700).copyWith(fontSize: 10)),
                    Text(title, style: SwanType.bodySm(ink, w: FontWeight.w800)),
                    Row(
                      children: [
                        Icon(Icons.pin_drop_rounded, size: 12, color: SwanColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(location, style: SwanType.caption(SwanColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF3F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(pace, style: SwanType.caption(ink, w: FontWeight.w700).copyWith(fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$attendees atlet katılıyor', style: SwanType.caption(SwanColors.textSecondary)),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Etkinliğe katılımınız kaydedildi!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: kTeal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Katıl', style: SwanType.caption(Colors.white, w: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKineticBanner(bool isDark, Color ink, Color surf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HAFTALIK TAKIM HEDEFİ', style: SwanType.caption(kTeal, w: FontWeight.w800).copyWith(fontSize: 10)),
                Text('Kulübünü Zirveye Taşı!', style: SwanType.bodySm(ink, w: FontWeight.w800)),
                Text('Antrenmanlarını kaydet, kulübün için puan topla.', style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.78,
                  strokeWidth: 4,
                  backgroundColor: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(kTeal),
                ),
                Text('%78', style: SwanType.caption(ink, w: FontWeight.w900).copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Filtre şeridi. Yalnızca kulüp bulunan il ve branşlar listelenir —
  /// sonucu boş çıkacak bir filtreyi kullanıcıya sunmak zaman kaybı.
  Widget _filterBar(bool isDark, Color ink) {
    final opts = ref.watch(filterOptionsProvider).valueOrNull ?? const [];
    final cities = opts.where((o) => o.kind == 'city').toList();
    final sports = opts.where((o) => o.kind == 'sport').toList();

    Widget chip(String label, bool active, VoidCallback onTap,
        {IconData? icon}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? kTeal
                : (isDark ? SwanPalette.dark.surfaceAlt : Colors.white),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: active
                    ? kTeal
                    : (isDark
                        ? SwanPalette.dark.line
                        : SwanPalette.light.line)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: active ? Colors.white : ink),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: SwanType.caption(active ? Colors.white : ink,
                    w: FontWeight.w700)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip(
            _filter.city.isEmpty ? 'Şehir' : _filter.city,
            _filter.city.isNotEmpty,
            () => _pick('Şehir', cities, _filter.city,
                (v) => setState(() => _filter = _filter.copyWith(city: v))),
            icon: Icons.location_on_rounded,
          ),
          chip(
            _filter.sport.isEmpty
                ? 'Branş'
                : (sports
                        .where((s) => s.code == _filter.sport)
                        .map((s) => s.label)
                        .firstOrNull ??
                    'Branş'),
            _filter.sport.isNotEmpty,
            () => _pick('Branş', sports, _filter.sport,
                (v) => setState(() => _filter = _filter.copyWith(sport: v))),
            icon: Icons.sports_volleyball_rounded,
          ),
          chip(
              'Doğrulanmış',
              _filter.verifiedOnly,
              () => setState(() => _filter =
                  _filter.copyWith(verifiedOnly: !_filter.verifiedOnly)),
              icon: Icons.verified_rounded),
          if (!_filter.isEmpty)
            chip('Temizle', false, () {
              _search.clear();
              setState(() => _filter = const DiscoverFilter());
            }, icon: Icons.close_rounded),
        ],
      ),
    );
  }

  Future<void> _pick(String title, List<FilterOption> options, String current,
      ValueChanged<String> onPick) async {
    if (options.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Column(children: [
          Text(title, style: SwanType.h3(ink)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(children: [
              ListTile(
                title: Text('Hepsi',
                    style: SwanType.bodySm(ink, w: FontWeight.w600)),
                trailing: current.isEmpty
                    ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                    : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final o in options)
                ListTile(
                  title: Text(o.label,
                      style: SwanType.bodySm(ink, w: FontWeight.w600)),
                  subtitle: Text('${o.count} kulüp',
                      style: SwanType.caption(SwanColors.textSecondary)),
                  trailing: o.code == current
                      ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                      : null,
                  onTap: () => Navigator.pop(ctx, o.code),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked != null) onPick(picked);
  }

  Widget _card(bool isDark, Color ink, DiscoveredClub c) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/kulup-profil', arguments: c.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          SocialAvatar(
            initials: c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
            imageUrl: c.logoUrl,
            size: 46,
            radius: 15,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  ),
                  if (c.isVerified) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified_rounded, size: 14, color: kTeal),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                    [
                      if ((c.sportName ?? '').isNotEmpty) c.sportName!,
                      if (c.where.isNotEmpty) c.where,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(SwanColors.textSecondary,
                        w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${c.athleteCount} sporcu · ${c.coachCount} antrenör',
                    style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          if (c.isFollowing)
            const Icon(Icons.how_to_reg_rounded, size: 17, color: kTeal)
          else
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }
}
