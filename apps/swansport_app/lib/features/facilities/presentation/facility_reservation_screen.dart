import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Tesis ve Poligon Rezervasyonu — Puta & Hat (Lane) Tahsis Ekranı.
/// Stitch Calm Athletic Modernism spesifikasyonuyla birebir uyumlu.
class FacilityReservationScreen extends ConsumerStatefulWidget {
  const FacilityReservationScreen({this.facilityId, super.key});
  final String? facilityId;

  @override
  ConsumerState<FacilityReservationScreen> createState() =>
      _FacilityReservationScreenState();
}

class _FacilityReservationScreenState
    extends ConsumerState<FacilityReservationScreen> {
  int _selectedType = 0; // 0 = Açık Saha, 1 = Kapalı Salon, 2 = Kondisyon
  int _selectedDate = 0; // index in date list
  int _selectedSlot = 2; // 14:00 - 15:30
  String _selectedLane = 'Hat 3A';

  // Ekstra Hizmetler
  bool _hasScope = true;
  bool _hasTuning = false;
  bool _hasTargetFaces = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;
    final club = ref.watch(activeClubProvider).valueOrNull;

    // Fiyat hesabı
    const basePrice = 250;
    final extrasPrice = (_hasScope ? 100 : 0) + (_hasTuning ? 150 : 0);
    const clubDiscount = 100;
    final totalPrice = basePrice + extrasPrice;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                // 1. Top Bar
                _buildTopBar(context, palette),
                const SizedBox(height: 14),

                // 2. Location & Facility Header Card
                _buildFacilityCard(palette, club?.name ?? 'Marmara Okçuluk Kulübü'),
                const SizedBox(height: 14),

                // 3. Visual Atmospheric Range Banner
                _buildVisualBanner(palette, isDark),
                const SizedBox(height: 14),

                // 4. Date & Time Slot Selector
                _buildDateTimeSection(palette, isDark),
                const SizedBox(height: 14),

                // 5. Interactive Target & Lane Layout Map
                _buildLaneMap(palette, isDark),
                const SizedBox(height: 14),

                // 6. Optional Add-on Services
                _buildAddonsSection(palette, isDark),
                const SizedBox(height: 14),

                // 7. Reservation Summary & Fixed Action Deck
                _buildSummaryAndAction(
                  palette,
                  isDark,
                  totalPrice: totalPrice,
                  extrasPrice: extrasPrice,
                  clubDiscount: clubDiscount,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // --- Top App Bar ---
  Widget _buildTopBar(BuildContext context, SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: palette.ink),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Poligon Rezervasyonu',
                  style: SwanType.h2(palette.ink),
                ),
                Text(
                  'Puta & Hat Tahsisi',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 14, color: kTeal),
              const SizedBox(width: 4),
              Text(
                'FITA Onaylı',
                style: SwanType.caption(kTeal, w: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Facility / Campus Card ---
  Widget _buildFacilityCard(SwanPalette palette, String clubName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_circle_rounded,
                    size: 24, color: kTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TESİS & KAMPÜS',
                      style: SwanType.caption(palette.inkMuted,
                          w: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clubName,
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Maslak Ana Kampüs · Poligon 4',
                      style: SwanType.caption(palette.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Facility Segmented Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _typeTab(0, 'Açık Saha', '70m / 50m', palette),
                _typeTab(1, 'Kapalı Salon', '18m FITA', palette),
                _typeTab(2, 'Kondisyon', 'Özel Alan', palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTab(
      int index, String title, String subtitle, SwanPalette palette) {
    final isSelected = _selectedType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: SwanType.caption(
                  isSelected ? kTeal : palette.inkMuted,
                  w: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: SwanType.caption(
                  palette.inkMuted,
                  w: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Visual Hero Banner ---
  Widget _buildVisualBanner(SwanPalette palette, bool isDark) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF131D2E), const Color(0xFF0F2B30)]
              : [const Color(0xFF004D54), const Color(0xFF00757E)],
        ),
        boxShadow: [
          BoxShadow(
            color: kTeal.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle pattern
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.track_changes_rounded,
              size: 160,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.air_rounded,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Rüzgar: 4.2 km/s KD (Sakin)',
                            style: SwanType.caption(Colors.white,
                                w: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kTealBright,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Olimpik 70m',
                        style: SwanType.caption(Colors.white,
                            w: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Açık Saha Poligon 4',
                      style: SwanType.h2(Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Elektronik puanlama ve canlı rüzgar sensörlü profesyonel atış hattı.',
                      style: SwanType.caption(Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Date & Time Slot Section ---
  Widget _buildDateTimeSection(SwanPalette palette, bool isDark) {
    const dates = [
      ('Bugün', '15', 'Sal'),
      ('Nis', '16', 'Çar'),
      ('Nis', '17', 'Per'),
      ('Nis', '18', 'Cum'),
      ('H.Sonu', '19', 'Cmt'),
    ];

    const slots = [
      ('09:00 - 10:30', '4 Hat Boş', true, false),
      ('11:00 - 12:30', 'Dolu (Milli Takım)', false, true),
      ('14:00 - 15:30', 'Seçildi • Müsait', true, false),
      ('16:00 - 17:30', 'Son 2 Yer!', true, false),
      ('18:00 - 19:30', '3 Hat (Gece Atışı)', true, false),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 18, color: kTeal),
                  const SizedBox(width: 6),
                  Text('Tarih ve Seans Seçimi',
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w800)),
                ],
              ),
              Text('Nisan 2026',
                  style: SwanType.caption(palette.inkMuted, w: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          // Date Carousel
          Row(
            children: List.generate(dates.length, (i) {
              final d = dates[i];
              final isSelected = _selectedDate == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDate = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? kTeal : palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kTeal.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          d.$1,
                          style: SwanType.caption(
                            isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : palette.inkMuted,
                            w: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.$2,
                          style: SwanType.bodySm(
                            isSelected ? Colors.white : palette.ink,
                            w: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.$3,
                          style: SwanType.caption(
                            isSelected ? Colors.white : palette.inkMuted,
                            w: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(
            '90 Dakikalık Antrenman Seansları',
            style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // Slots Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(slots.length, (i) {
              final s = slots[i];
              final isFull = s.$4;
              final isSelected = _selectedSlot == i;
              final width = (i == 4) ? double.infinity : null;

              return SizedBox(
                width: width ??
                    (MediaQuery.of(context).size.width > 400 ? 170 : 150),
                child: GestureDetector(
                  onTap: isFull
                      ? null
                      : () => setState(() => _selectedSlot = i),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kTeal
                          : (isFull
                              ? palette.surfaceAlt.withValues(alpha: 0.5)
                              : palette.surfaceAlt),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? kTeal
                            : (isFull
                                ? Colors.transparent
                                : palette.line.withValues(alpha: 0.5)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.$1,
                              style: SwanType.caption(
                                isSelected
                                    ? Colors.white
                                    : (isFull
                                        ? palette.inkMuted
                                        : palette.ink),
                                w: FontWeight.w800,
                              ),
                            ),
                            if (isFull)
                              Icon(Icons.block_rounded,
                                  size: 14, color: palette.danger)
                            else if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: Colors.white),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          s.$2,
                          style: SwanType.caption(
                            isSelected
                                ? Colors.white.withValues(alpha: 0.85)
                                : (isFull ? palette.danger : palette.inkMuted),
                            w: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- Target & Lane Map ---
  Widget _buildLaneMap(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_score_rounded,
                      size: 18, color: kTeal),
                  const SizedBox(width: 6),
                  Text('Hedef ve Hat (Lane) Şeması',
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w800)),
                ],
              ),
              Text('70 Metre FITA',
                  style: SwanType.caption(kTeal, w: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          // Target End Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.adjust_rounded, size: 14, color: palette.inkMuted),
                const SizedBox(width: 6),
                Text(
                  'FITA HEDEF MİNDERLERİ HATTI (70 METRE)',
                  style: SwanType.caption(palette.inkMuted,
                      w: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Lane Pairs
          Row(
            children: [
              _laneTile('Hat 1A', 'Dolu', 'Makaralı Ant.', false, palette),
              const SizedBox(width: 8),
              _laneTile('Hat 1B', 'Dolu', 'Bakım / Kalibrasyon', false, palette),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _laneTile('Hat 2A', 'Dolu', 'Zeynep Y. (Lisanslı)', false, palette),
              const SizedBox(width: 8),
              _laneTile('Hat 2B', 'Müsait', 'Bu Hattı Seç', true, palette),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _laneTile('Hat 3A', 'Seçili Puta', 'Minder 128cm FITA', true, palette),
              const SizedBox(width: 8),
              _laneTile('Hat 3B', 'Müsait', 'Bu Hattı Seç', true, palette),
            ],
          ),
          const SizedBox(height: 10),
          // Shooting Line Corridor Indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.straighten_rounded, size: 14, color: kTeal),
                const SizedBox(width: 6),
                Text(
                  'ATIŞ ÇİZGİSİ VE BEKLEME KORİDORU',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Selected Lane Tech Specs
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 15, color: kTeal),
                    const SizedBox(width: 6),
                    Text('$_selectedLane Teknik Özellikleri',
                        style: SwanType.caption(palette.ink, w: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _specBadge('Mesafe', '70 Metre', 'Olimpik Boy', palette),
                    const SizedBox(width: 6),
                    _specBadge('Rüzgar', 'Sensörlü', 'Anlık Veri', palette),
                    const SizedBox(width: 6),
                    _specBadge('Kamera', 'Dürbünlü', 'HD Puta', palette),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specBadge(
      String label, String value, String sub, SwanPalette palette) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: SwanType.caption(palette.inkMuted)),
            const SizedBox(height: 2),
            Text(value, style: SwanType.bodySm(palette.ink, w: FontWeight.w800)),
            Text(sub, style: SwanType.caption(kTeal, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _laneTile(String name, String status, String note, bool available,
      SwanPalette palette) {
    final isSelected = _selectedLane == name;

    return Expanded(
      child: GestureDetector(
        onTap: available ? () => setState(() => _selectedLane = name) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? kTeal
                : (available
                    ? palette.surface
                    : palette.surfaceAlt.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? kTeal
                  : (available
                      ? palette.line
                      : palette.line.withValues(alpha: 0.4)),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kTeal.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: SwanType.bodySm(
                      isSelected ? Colors.white : palette.ink,
                      w: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : (status == 'Müsait'
                              ? kTeal.withValues(alpha: 0.12)
                              : palette.line.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: SwanType.caption(
                        isSelected
                            ? Colors.white
                            : (status == 'Müsait' ? kTeal : palette.inkMuted),
                        w: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : (available
                            ? Icons.add_circle_outline_rounded
                            : Icons.lock_clock_rounded),
                    size: 13,
                    color: isSelected ? Colors.white : palette.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(
                        isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : palette.inkMuted,
                        w: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Optional Add-on Services ---
  Widget _buildAddonsSection(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: kTeal),
                  const SizedBox(width: 6),
                  Text('Ekstra Hizmetler & Ekipman',
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w800)),
                ],
              ),
              Text('İsteğe Bağlı',
                  style: SwanType.caption(palette.inkMuted, w: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          _addonTile(
            title: 'Teleskopik Gözlem Dürbünü',
            subtitle: 'Tripodlu Vortex HD 20-60x',
            price: '+₺100',
            icon: Icons.visibility_rounded,
            value: _hasScope,
            onChanged: (v) => setState(() => _hasScope = v),
            palette: palette,
          ),
          const SizedBox(height: 8),
          _addonTile(
            title: 'Kağıt Tuning Test Alanı',
            subtitle: 'Ok çıkış ayarı kabini (15 dk)',
            price: '+₺150',
            icon: Icons.architecture_rounded,
            value: _hasTuning,
            onChanged: (v) => setState(() => _hasTuning = v),
            palette: palette,
          ),
          const SizedBox(height: 8),
          _addonTile(
            title: 'Antrenman Hedef Kağıtları',
            subtitle: '3 Adet FITA 80cm kuşe kağıt',
            price: 'Ücretsiz',
            isFree: true,
            icon: Icons.center_focus_strong_rounded,
            value: _hasTargetFaces,
            onChanged: (v) => setState(() => _hasTargetFaces = v),
            palette: palette,
          ),
        ],
      ),
    );
  }

  Widget _addonTile({
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required SwanPalette palette,
    bool isFree = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: kTeal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: SwanType.caption(palette.ink, w: FontWeight.w700)),
                Text(subtitle,
                    style: SwanType.caption(palette.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            price,
            style: SwanType.caption(
              isFree ? kTeal : palette.ink,
              w: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeTrackColor: kTeal,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // --- Summary & Action Deck ---
  Widget _buildSummaryAndAction(
    SwanPalette palette,
    bool isDark, {
    required int totalPrice,
    required int extrasPrice,
    required int clubDiscount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seçilen Hat ve Seans',
                  style: SwanType.caption(palette.inkMuted)),
              Text('15 Nisan · 14:00 - 15:30',
                  style: SwanType.caption(palette.ink, w: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Puta Bilgisi',
                  style: SwanType.caption(palette.inkMuted)),
              Text('$_selectedLane (Açık Saha 70m)',
                  style: SwanType.caption(kTeal, w: FontWeight.w800)),
            ],
          ),
          if (extrasPrice > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dürbün & Ekstralar',
                    style: SwanType.caption(palette.inkMuted)),
                Text('+₺$extrasPrice',
                    style: SwanType.caption(palette.ink, w: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sporcu Lisans İndirimi',
                  style: SwanType.caption(palette.inkMuted)),
              Text('-₺$clubDiscount (Kulüp Katkısı)',
                  style: SwanType.caption(palette.danger, w: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          // Price Display Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOPLAM TUTAR',
                        style: SwanType.caption(palette.inkMuted,
                            w: FontWeight.w700)),
                    Row(
                      children: [
                        Text('₺$totalPrice',
                            style: SwanType.h2(kTeal)),
                        const SizedBox(width: 6),
                        Text('₺${totalPrice + clubDiscount}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: palette.inkMuted,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '%28 Kulüp İndirimi',
                    style: SwanType.caption(kTeal, w: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Confirm Button
          GestureDetector(
            onTap: () => _confirmBooking(context),
            child: Container(
              height: 48,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kTealBright, kTeal],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: kTeal.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.done_all_rounded,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Rezervasyonu Onayla ve Puta Ayırt',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBooking(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final palette = isDark ? SwanPalette.dark : SwanPalette.light;
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 32, color: kTeal),
              ),
              const SizedBox(height: 14),
              Text('Puta Ayrıldı!',
                  style: SwanType.h2(palette.ink)),
              const SizedBox(height: 6),
              Text(
                '$_selectedLane 15 Nisan Salı 14:00 için adınıza rezerve edildi.\nQR biletiniz Profil > Rezervasyonlarım bölümüne eklendi.',
                textAlign: TextAlign.center,
                style: SwanType.caption(palette.inkMuted),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.maybePop(context);
                },
                child: Container(
                  height: 44,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [kTealBright, kTeal]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Tamam',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
