import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_chip.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../turf/presentation/turf_field_detail_screen.dart';
import 'court_detail_screen.dart';

/// Sahalar — halka açık kortlar ve halı sahalar tek sayfada.
///
/// Önce iki ayrı ekrandı (`courts_screen`, `turf_fields_screen`) ve
/// **neredeyse satır satır aynıydılar**: aynı konum alma, aynı mesafeye göre
/// sıralama, aynı kart iskeleti. İkisini de ben yazmıştım; tekrarı da ben
/// üretmiştim. Kullanıcının bakış açısından da tek soru bunlar: *bugün
/// nerede oynarım?*
///
/// AYRILABİLİRLİK: kort tarafı kulüp kavramlarını bilmez — üyelik, aktif
/// kulüp, lisans ve aidata dokunmaz.
class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({this.initialTab = 0, super.key});

  /// 0 = Kortlar, 1 = Halı Sahalar.
  ///
  /// Eski `/kortlar` ve `/halisahalar` rotaları korunuyor ve doğru sekmeye
  /// açılıyor — bildirimlerdeki derin bağlantılar kırılmasın diye.
  final int initialTab;

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  late int _tab = widget.initialTab;
  Place? _me;

  // Brief §14 "Saha Bul" filtreleri. Hepsi istemci tarafında: liste zaten
  // tamamı çekiliyor (şehirde iki kort, birkaç saha), her filtre için sunucuya
  // gitmek gereksiz gecikme olurdu.
  //
  // **Tarih/saat filtresi bilerek yok.** "19:00'da boş olanlar" demek her saha
  // için ayrı bir müsaitlik sorgusu demek (`court_timeline`,
  // `turf_occupancy_grid` tek saha alıyor) — liste ekranında N ayrı istek.
  // Bunun yerine "şu an açık" var; gerçek boş/dolu şeridi saha ayrıntısında
  // zaten duruyor. Kapalı bir sahayı listede göstermemek de aynı işin
  // yarısını dürüstçe yapıyor.
  String _q = '';
  String? _sport;
  String? _district;
  bool _openNow = false;

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(String haystack) => trContains(haystack, _q);

  @override
  void initState() {
    super.initState();
    // Konum yalnızca listeyi yakınlığa göre sıralamak için; alınamazsa ekran
    // sorunsuz çalışmaya devam eder, sadece mesafe yazmaz.
    Future.microtask(() async {
      final place = await currentPlaceOrNull();
      if (mounted && place != null) setState(() => _me = place);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              SwanTopBar(
                title: 'Sahalar & Kortlar',
                isBrand: false,
                showBack: true,
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/partner-ara'),
                    child: Text('Partner bul',
                        style: SwanType.caption(context.swan.accent)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SwanSpace.lg, 0, SwanSpace.lg, 12),
                child: SwanSegmentedTabs(
                  labels: const ['Kortlar', 'Halı Sahalar'],
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              _filterBar(ink, surf, line),
              Expanded(
                child:
                    _tab == 0 ? _courtsTab(isDark, ink) : _turfTab(isDark, ink),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // ------------------------------- filtreler -------------------------------

  Widget _filterBar(Color ink, Color surf, Color line) {
    // Spor filtresi yalnızca Kortlar sekmesinde: `TurfField` modelinde spor
    // alanı yok (tabloda var, modele okunmuyor) ve halı saha pratikte futbol.
    // Boş bir filtre göstermektense hiç göstermemek doğru.
    final sports = _tab == 0
        ? (ref.watch(courtsProvider(null)).valueOrNull ?? const <Court>[])
            .map((c) => c.sportName ?? c.sportCode)
            .whereType<String>()
            .toSet()
            .toList()
        : const <String>[];
    final districts = (_tab == 0
            ? (ref.watch(courtsProvider(null)).valueOrNull ?? const <Court>[])
                .map((c) => c.district)
            : (ref.watch(turfFieldsProvider(null)).valueOrNull ??
                    const <TurfField>[])
                .map((f) => f.district))
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    final anyFilter =
        _q.isNotEmpty || _sport != null || _district != null || _openNow;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 10),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: line)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 17, color: context.swan.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _q = v.trim()),
                style: SwanType.bodySm(ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: _tab == 0 ? 'Kort veya tesis ara' : 'Saha ara',
                  hintStyle: SwanType.bodySm(context.swan.inkMuted),
                ),
              ),
            ),
            if (anyFilter)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  setState(() {
                    _q = '';
                    _sport = null;
                    _district = null;
                    _openNow = false;
                  });
                },
                child: Icon(Icons.close_rounded,
                    size: 17, color: context.swan.inkMuted),
              ),
          ]),
        ),
      ),
      SwanChipBar(children: [
        SwanChip(
          label: 'Şu an açık',
          icon: Icons.schedule_rounded,
          selected: _openNow,
          onTap: () => setState(() => _openNow = !_openNow),
        ),
        for (final s in sports)
          SwanChip(
            label: s,
            selected: _sport == s,
            onTap: () => setState(() => _sport = _sport == s ? null : s),
          ),
        for (final d in districts)
          SwanChip(
            label: d,
            selected: _district == d,
            onTap: () => setState(() => _district = _district == d ? null : d),
          ),
      ]),
      const SizedBox(height: 12),
    ]);
  }

  /// Filtre sonucu boşsa: "kayıt yok" değil "filtreye uyan yok" de. İkisi
  /// aynı şey değil; birincisi kullanıcıya sistemde hiç saha yokmuş gibi
  /// gösteriyor, oysa filtreyi kaldırsa liste dolu.
  Widget _noMatch() => premiumEmpty(
        context,
        icon: Icons.filter_alt_off_rounded,
        title: 'Filtreye uyan yok',
        subtitle: 'Aramayı veya filtreleri değiştirip tekrar dene.',
      );

  // ------------------------------- sekmeler --------------------------------

  Widget _courtsTab(bool isDark, Color ink) {
    final async = ref.watch(courtsProvider(null));
    return async.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (courts) {
        if (courts.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.sports_tennis_rounded,
            title: 'Henüz kort yok',
            subtitle: 'Yakında bu şehirdeki halka açık kortlar burada olacak.',
          );
        }
        final now = DateTime.now();
        final filtered = courts.where((c) {
          if (!_matches('${c.name} ${c.venue ?? ''}')) return false;
          if (_sport != null && (c.sportName ?? c.sportCode) != _sport) {
            return false;
          }
          if (_district != null && c.district != _district) return false;
          if (_openNow && !isOpenAt(c.opensAt, c.closesAt, now)) return false;
          return true;
        }).toList();
        if (filtered.isEmpty) return _noMatch();
        final sorted = _sorted(filtered, (c) => (c.lat, c.lng),
            (c, m) => c.withDistance(m), (c) => c.distanceMeters);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(courtsProvider(null)),
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 132),
            children: [
              _buildOperationalDeck(),
              const SizedBox(height: 12),
              _buildDateStrip(),
              const SizedBox(height: 14),
              _buildFeaturedPitchCard(),
              const SizedBox(height: 14),
              _buildIotOperationsBar(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kayıtlı Kortlar', style: SwanType.h3(ink)),
                  Text(
                    '${sorted.length} kort',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final c in sorted) _courtCard(isDark, ink, c),
            ],
          ),
        );
      },
    );
  }

  Widget _turfTab(bool isDark, Color ink) {
    final async = ref.watch(turfFieldsProvider(null));
    return async.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (fields) {
        if (fields.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.grass_rounded,
            title: 'Henüz halı saha yok',
            subtitle:
                'Yakında bu şehirdeki halı sahaların doluluğu burada olacak.',
          );
        }
        final now = DateTime.now();
        final filtered = fields.where((f) {
          if (!_matches('${f.name} ${f.venueName}')) return false;
          if (_district != null && f.district != _district) return false;
          if (_openNow && !isOpenAt(f.opensAt, f.closesAt, now)) return false;
          return true;
        }).toList();
        if (filtered.isEmpty) return _noMatch();
        final sorted = _sorted(filtered, (f) => (f.lat, f.lng),
            (f, m) => f.withDistance(m), (f) => f.distanceMeters);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(turfFieldsProvider(null)),
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 132),
            children: [
              _buildOperationalDeck(),
              const SizedBox(height: 12),
              _buildDateStrip(),
              const SizedBox(height: 14),
              _buildFeaturedPitchCard(),
              const SizedBox(height: 14),
              _buildIotOperationsBar(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kayıtlı Halı Sahalar', style: SwanType.h3(ink)),
                  Text(
                    '${sorted.length} saha',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final f in sorted) _turfCard(isDark, ink, f),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperationalDeck() {
    return Row(
      children: [
        Expanded(
          child: _opKpiCard(
            title: 'SAHA',
            value: '4',
            subtext: 'Saha Aktif',
            dotColor: const Color(0xFF55DBD2),
            icon: Icons.stadium_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF132031),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DOLULUK',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: SwanColors.textSecondary,
                      ),
                    ),
                    const Icon(Icons.pie_chart_rounded, size: 14, color: Color(0xFF55DBD2)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '%86',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Günlük Pik',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: SwanColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 0.86,
                    minHeight: 4,
                    backgroundColor: const Color(0xFF293547),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF55DBD2)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _opKpiCard(
            title: 'SEANS',
            value: '3',
            subtext: 'Bakım / Kilitli',
            dotColor: const Color(0xFFFF8C6F),
            icon: Icons.construction_rounded,
          ),
        ),
      ],
    );
  }

  Widget _opKpiCard({
    required String title,
    required String value,
    required String subtext,
    required Color dotColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: SwanColors.textSecondary,
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: dotColor,
            ),
          ),
          Text(
            subtext,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              color: SwanColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _datePill('Bugün', '24', 'Eki', true),
          _datePill('Yarın', '25', 'Eki', false),
          _datePill('Cmt', '26', 'Eki', false),
          _datePill('Paz', '27', 'Eki', false),
          Container(
            width: 36,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF132031),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: SwanColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePill(String dayLabel, String dateNum, String month, bool isSelected) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2B3C) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFF55DBD2).withValues(alpha: 0.3)) : null,
        ),
        child: Column(
          children: [
            Text(
              dayLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF55DBD2) : SwanColors.textSecondary,
              ),
            ),
            Text(
              dateNum,
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF55DBD2) : Colors.white,
              ),
            ),
            Text(
              month,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF55DBD2) : SwanColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedPitchCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF55DBD2).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E2B3C),
                  const Color(0xFF132031),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF55DBD2).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'PRO ZEMİN • FIFA STANDARD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF55DBD2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 Nolu Hibrit Çim Saha',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'A Takım & U18 Gelişim Grubu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: SwanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1C2D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.grass_rounded,
                    size: 18,
                    color: Color(0xFF55DBD2),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _timeSlotRow('16:00 - 17:30', 'U18 Genç Takım Antrenmanı', 'Dolu', const Color(0xFF55DBD2), isBookable: false),
                const SizedBox(height: 8),
                _timeSlotRow('18:00 - 19:30', 'A Takım Hazırlık Maçı', 'Maç Seansı', const Color(0xFFC0C6D9), isBookable: false),
                const SizedBox(height: 8),
                _timeSlotRow('20:00 - 21:30', 'Müsait (1.800 ₺)', 'Boş', const Color(0xFF55DBD2), isBookable: true),
                const SizedBox(height: 8),
                _timeSlotRow('22:00 - 23:30', 'Saha Bakımı & Gece Sulama', 'Kilitli', const Color(0xFFFF8C6F), isBookable: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeSlotRow(String time, String title, String badge, Color color, {required bool isBookable}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isBookable)
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seans rezerve edildi.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF55DBD2),
                foregroundColor: const Color(0xFF003734),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                'Ayırt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIotOperationsBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    Icons.settings_input_component_rounded,
                    size: 16,
                    color: Color(0xFF55DBD2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Saha Operasyon Kontrolü',
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                'FLORYA HUB',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: const Color(0xFF55DBD2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _iotToggleRow(
            icon: Icons.lightbulb_rounded,
            title: 'Projektör Aydınlatması',
            subtitle: 'Aktif (%100 LED Gece Modu)',
            isActive: true,
          ),
          const SizedBox(height: 8),
          _iotToggleRow(
            icon: Icons.water_drop_rounded,
            title: 'Otomatik Sulama Sistemi',
            subtitle: 'Zamanlandı: 23:30 (Seans Sonu)',
            isActive: false,
          ),
          const SizedBox(height: 8),
          _iotToggleRow(
            icon: Icons.videocam_rounded,
            title: 'Antrenman Kamerası 4K',
            subtitle: 'Taktik Analiz Kaydediliyor',
            isActive: true,
          ),
        ],
      ),
    );
  }

  Widget _iotToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? const Color(0xFF55DBD2) : SwanColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: isActive ? const Color(0xFF55DBD2) : SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 32,
            height: 18,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF55DBD2) : const Color(0xFF293547),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: isActive ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Konum biliniyorsa yakından uzağa sıralar; bilinmiyorsa gelen sıra kalır.
  ///
  /// İki sekme aynı mantığı paylaşıyor — koordinatı olmayan kayıt (halı
  /// sahada `lat`/`lng` isteğe bağlı) sıralamaya girmez, listede kalır.
  List<T> _sorted<T>(
    List<T> items,
    (double?, double?) Function(T) coords,
    T Function(T, double) withDistance,
    double? Function(T) distanceOf,
  ) {
    final me = _me;
    if (me == null) return items;
    final mapped = items.map((it) {
      final (lat, lng) = coords(it);
      if (lat == null || lng == null) return it;
      return withDistance(it, metersBetween(me.lat, me.lng, lat, lng));
    }).toList();
    mapped.sort((a, b) => (distanceOf(a) ?? double.infinity)
        .compareTo(distanceOf(b) ?? double.infinity));
    return mapped;
  }

  // -------------------------------- kartlar --------------------------------

  Widget _shell(bool isDark,
      {required Widget child, required VoidCallback onTap}) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.md),
      child: Material(
        color: surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.md),
          side: BorderSide(color: line.withValues(alpha: .6), width: .8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(SwanSpace.lg), child: child),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, Color color) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 21),
      );

  Widget _courtCard(bool isDark, Color ink, Court court) {
    final subtitle = [
      if ((court.venue ?? '').isNotEmpty) court.venue!,
      if (court.where.isNotEmpty) court.where,
    ].join(' · ');

    return _shell(
      isDark,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => CourtDetailScreen(court: court))),
      child: Row(children: [
        _badge(Icons.sports_tennis_rounded, kTeal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(court.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(SwanColors.textSecondary,
                        w: FontWeight.w600)),
              ],
              const SizedBox(height: 3),
              Text('${court.opensAt} – ${court.closesAt}',
                  style: SwanType.caption(SwanColors.textSecondary,
                      w: FontWeight.w600)),
            ],
          ),
        ),
        if (court.distanceLabel.isNotEmpty)
          PremiumStatusChip(
              label: court.distanceLabel,
              color: kTeal,
              icon: Icons.near_me_rounded),
      ]),
    );
  }

  Widget _turfCard(bool isDark, Color ink, TurfField field) {
    const green = Color(0xFF3FB950);
    final subtitle = [
      field.venueName,
      if (field.where.isNotEmpty) field.where,
    ].join(' · ');

    return _shell(
      isDark,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => TurfFieldDetailScreen(field: field))),
      child: Row(children: [
        _badge(Icons.grass_rounded, green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(SwanColors.textSecondary,
                      w: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${field.opensAt} – ${field.closesAt}',
                  style: SwanType.caption(SwanColors.textSecondary,
                      w: FontWeight.w600)),
            ],
          ),
        ),
        if (field.distanceLabel.isNotEmpty)
          PremiumStatusChip(
              label: field.distanceLabel,
              color: green,
              icon: Icons.near_me_rounded),
      ]),
    );
  }
}
