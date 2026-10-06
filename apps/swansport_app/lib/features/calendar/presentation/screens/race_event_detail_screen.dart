import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';

/// SwanSport - Etkinlik & Yarış Detayı (Stitch Screen 17)
///
/// Yarı Maraton / yarış etkinlik sayfası, rakım & GPX profili,
/// katılımcı kulüpler, resmi pacemaker takımı, zorunlu ekipmanlar ve kayıt akışı.
class RaceEventDetailScreen extends ConsumerStatefulWidget {
  const RaceEventDetailScreen({
    super.key,
    this.eventId,
    this.title = 'Bebek - Rumeli Hisarı Gece Yarı Maratonu',
  });

  final String? eventId;
  final String title;

  @override
  ConsumerState<RaceEventDetailScreen> createState() =>
      _RaceEventDetailScreenState();
}

class _RaceEventDetailScreenState extends ConsumerState<RaceEventDetailScreen> {
  bool _isBookmarked = false;
  bool _isGpxDownloading = false;
  bool _isGpxDownloaded = false;
  bool _isRegistered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
                  children: [
                    // Hero Image & Header Stack
                    _buildHeroHeader(palette, isDark),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Feature Badges (Horizontal)
                          _buildEventBadges(palette),
                          const SizedBox(height: 16),

                          // 2x2 Key Stats Bento Grid
                          _buildStatsGrid(palette),
                          const SizedBox(height: 20),

                          // Route & Elevation Profile Card
                          _buildElevationProfileCard(palette, isDark),
                          const SizedBox(height: 20),

                          // Participating Clubs
                          _buildParticipatingClubs(palette),
                          const SizedBox(height: 20),

                          // Official Pacemaker Team
                          _buildPacemakers(palette),
                          const SizedBox(height: 20),

                          // Mandatory Gear List
                          _buildMandatoryGearCard(palette, isDark),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),

                // Top Sticky Back & Share Bar
                _buildTopBar(palette),

                // Sticky Bottom Action Bar
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildBottomActionBar(palette, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(SwanPalette palette) {
    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: palette.line),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: palette.ink,
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _isBookmarked = !_isBookmarked);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text(_isBookmarked ? 'Etkinlik kaydedildi!' : 'Kayıt kaldırıldı'),
                    ),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(
                    _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 18,
                    color: _isBookmarked ? palette.accent : palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.line),
                ),
                child: Icon(
                  Icons.share_rounded,
                  size: 18,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(SwanPalette palette, bool isDark) {
    return Stack(
      children: [
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            gradient: LinearGradient(
              colors: [
                palette.accent.withValues(alpha: 0.35),
                palette.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.directions_run_rounded,
              size: 80,
              color: palette.accent.withValues(alpha: 0.3),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  palette.bg.withValues(alpha: 0.7),
                  palette.bg,
                ],
                stops: const [0.3, 0.75, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GECE ETABI • KAYITLAR AÇIK',
                      style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: SwanType.h2(palette.ink),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: palette.accent),
                  const SizedBox(width: 4),
                  Text(
                    '24 Ekim 2026 · 21:00',
                    style: SwanType.caption(palette.ink, w: FontWeight.w700),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: palette.inkMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(Icons.near_me_rounded, size: 14, color: palette.inkMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Bebek Parkı Başlangıç',
                      style: SwanType.caption(palette.inkMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventBadges(SwanPalette palette) {
    final badges = [
      (Icons.verified_rounded, 'Resmi Yarı Maraton (21.1K)', palette.accent),
      (Icons.workspace_premium_rounded, 'Sertifikalı Parkur', palette.inkMuted),
      (Icons.sensors_rounded, 'SwanSport Canlı Telemetri', palette.accent),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final b = badges[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(b.$1, size: 14, color: b.$3),
                const SizedBox(width: 6),
                Text(
                  b.$2,
                  style: SwanType.caption(palette.ink, w: FontWeight.w600).copyWith(fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(SwanPalette palette) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildStatCard(
                icon: Icons.group_rounded,
                value: '1.250',
                label: 'Kayıtlı Koşucu',
                palette: palette,
              ),
              const SizedBox(height: 10),
              _buildStatCard(
                icon: Icons.terrain_rounded,
                value: '180m',
                label: 'İrtifa Kazanımı',
                palette: palette,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _buildStatCard(
                icon: Icons.local_drink_rounded,
                value: '3 Nokta',
                label: 'Su & Jel İstasyonu',
                palette: palette,
              ),
              const SizedBox(height: 10),
              _buildStatCard(
                icon: Icons.military_tech_rounded,
                value: '2.500₺',
                label: 'SwanKupa Havuzu',
                valueColor: Colors.deepOrangeAccent,
                palette: palette,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    Color? valueColor,
    required SwanPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: valueColor ?? palette.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: SwanType.bodySm(valueColor ?? palette.ink, w: FontWeight.w800),
                ),
                Text(
                  label,
                  style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElevationProfileCard(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROTA & RAKIM PROFİLİ',
                    style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                  ),
                  Text(
                    'Boğaz Sahil Çizgisi',
                    style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _isGpxDownloading = true);
                  Future.delayed(const Duration(milliseconds: 1200), () {
                    if (mounted) {
                      setState(() {
                        _isGpxDownloading = false;
                        _isGpxDownloaded = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('GPX parkur dosyası başarıyla indirildi.')),
                      );
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGpxDownloading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _isGpxDownloaded ? Icons.check_circle_rounded : Icons.download_rounded,
                          size: 14,
                          color: _isGpxDownloaded ? palette.success : palette.accent,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        _isGpxDownloaded ? 'Hazır' : 'GPX İndir',
                        style: SwanType.caption(palette.ink, w: FontWeight.w700).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Elevation visual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Max 42m', style: SwanType.caption(palette.accent, w: FontWeight.w700).copyWith(fontSize: 10)),
                    Text('Avg Eğim %1.8', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10)),
                    Text('Min 2m', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 8),
                // Simulated Elevation Wave
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ElevationChartPainter(color: palette.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0 KM', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 9)),
                    Text('5 KM (Su)', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 9)),
                    Text('12 KM (Hisar)', style: SwanType.caption(palette.accent, w: FontWeight.w700).copyWith(fontSize: 9)),
                    Text('21.1 KM (Bitiş)', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipatingClubs(SwanPalette palette) {
    final clubs = [
      ('Swan Runners', '342 Sporcu', Icons.sports_gymnastics_rounded),
      ('Iron Swans', '215 Sporcu', Icons.fitness_center_rounded),
      ('Kadıköy Athl.', '184 Sporcu', Icons.directions_run_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Katılımcı Kulüpler',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            Text(
              '18 Kulüp',
              style: SwanType.caption(palette.accent, w: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final c in clubs)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(c.$3, size: 20, color: palette.accent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.$1,
                        style: SwanType.caption(palette.ink, w: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        c.$2,
                        style: SwanType.caption(palette.accent).copyWith(fontSize: 10),
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

  Widget _buildPacemakers(SwanPalette palette) {
    final pacers = [
      ('Mert Kılıç', '4\'15" min/km ritim', '1:30', palette.accent),
      ('Selin Aksoy', '4\'58" min/km ritim', '1:45', Colors.purpleAccent),
      ('Caner Demir', '5\'40" min/km ritim', '2:00', Colors.blueAccent),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPO LİDERLERİ',
                  style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                ),
                Text(
                  'Resmi Pacemaker Takımı',
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                ),
              ],
            ),
            Text(
              'Hedef Tempolar',
              style: SwanType.caption(palette.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final p in pacers)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded, size: 20, color: palette.inkMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.$1,
                        style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                      ),
                      Text(
                        p.$2,
                        style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.$4.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${p.$3} saat',
                    style: SwanType.caption(p.$4, w: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMandatoryGearCard(SwanPalette palette, bool isDark) {
    final gear = [
      (Icons.nfc_rounded, 'Göğüs Numarası Çipi'),
      (Icons.light_mode_rounded, 'Kafa Lambası'),
      (Icons.shield_rounded, 'Reflektörlü Yelek'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, size: 16, color: Colors.deepOrangeAccent),
              const SizedBox(width: 6),
              Text(
                'Zorunlu Ekipman Listesi',
                style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gece maratonu güvenliği gereği başlangıç kit kontrolünde teyit edilecektir:',
            style: SwanType.caption(palette.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in gear)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(g.$1, size: 14, color: palette.accent),
                      const SizedBox(width: 6),
                      Text(
                        g.$2,
                        style: SwanType.caption(palette.ink, w: FontWeight.w600).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Parkur haritası ve canlı istasyonlar açılıyor...')),
                );
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded, size: 16, color: palette.ink),
                    const SizedBox(width: 6),
                    Text(
                      'Parkur',
                      style: SwanType.caption(palette.ink, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                setState(() => _isRegistered = !_isRegistered);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isRegistered
                          ? 'Yarış kaydınız başarıyla tamamlandı!'
                          : 'Kayıt iptal edildi.',
                    ),
                  ),
                );
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _isRegistered ? palette.success : palette.accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRegistered ? palette.success : palette.accent).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRegistered ? Icons.check_circle_rounded : Icons.bolt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isRegistered ? 'Kayıtlısınız' : 'Kayıt Ol (350 ₺)',
                      style: SwanType.caption(Colors.white, w: FontWeight.w800),
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
}

class _ElevationChartPainter extends CustomPainter {
  const _ElevationChartPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height,))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.7, size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.5, size.width * 0.85, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.6);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Peak dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
