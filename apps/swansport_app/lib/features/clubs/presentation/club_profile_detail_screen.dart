import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// SwanSport - Kulüp Detayı (Swan Runners Istanbul)
///
/// Google Stitch "SwanSport - Kulüp Detayı (Swan Runners Istanbul)" tasarımını uygular:
/// - Dinamik Hero Başlık & Arka Plan Görseli
/// - Kulüp Logosu, Rozet ve Üyelik Durumu (Üye Olundu / Katıl)
/// - Temel Metrikler (1.420 Aktif Üye, 3.450 km Haftalık Mesafe)
/// - Segment Sekmeleri (Akış & Duyurular, Etkinlikler, Liderlik, Üyeler)
/// - Sabitlenmiş Kaptan Duyurusu & Patika Koşusu Kayıt Kartı
/// - Haftalık 10.000 KM Kulüpler Kupası İlerleme Barı (%74)
/// - Canlı Üye Antrenman Akışı (Selin Kaya 12.42K, Kudos & Yorum)
/// - Sabit Alt Sohbet & Etkinliğe Katıl Çubuğu
class ClubProfileDetailScreen extends ConsumerStatefulWidget {
  const ClubProfileDetailScreen({
    super.key,
    this.clubId,
    this.clubName = 'Swan Runners Istanbul',
  });

  final String? clubId;
  final String clubName;

  @override
  ConsumerState<ClubProfileDetailScreen> createState() => _ClubProfileDetailScreenState();
}

class _ClubProfileDetailScreenState extends ConsumerState<ClubProfileDetailScreen> {
  int _selectedTab = 0;
  bool _isMember = true;
  bool _isEventRegistered = false;
  int _kudosCount = 34;
  bool _hasGivenKudos = false;

  final List<({String label, IconData icon})> _tabs = [
    (label: 'Akış & Duyurular', icon: Icons.newspaper_rounded),
    (label: 'Etkinlikler & Koşular', icon: Icons.event_rounded),
    (label: 'Liderlik Tablosu', icon: Icons.leaderboard_rounded),
    (label: 'Kulüp Üyeleri', icon: Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Scrollable Body
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero App Bar with Cover Image
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                elevation: 0,
                backgroundColor: c.surface,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                      tooltip: 'Geri',
                    ),
                  ),
                ),
                actions: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kulüp profili bağlantısı kopyalandı.')),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                      tooltip: 'Paylaş',
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Colors.white),
                      tooltip: 'Diğer',
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        'https://images.unsplash.com/photo-1452626038306-9aae5e071dd3?q=80&w=1200&auto=format&fit=crop',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [c.surfaceAlt, c.surface],
                            ),
                          ),
                          child: Icon(Icons.sailing_rounded, size: 64, color: c.accent.withValues(alpha: 0.3)),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.4),
                              c.bg.withValues(alpha: 0.95),
                              c.bg,
                            ],
                            stops: const [0.0, 0.4, 0.85, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Club Identity & Stats Section
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileHeader(c),
                          const SizedBox(height: SwanSpace.md),

                          _buildStatsBento(c),
                          const SizedBox(height: SwanSpace.md),

                          _buildSegmentTabs(c),
                          const SizedBox(height: SwanSpace.md),

                          if (_selectedTab == 0) ...[
                            _buildPinnedEventCard(c),
                            const SizedBox(height: SwanSpace.md),

                            _buildWeeklyChallengeCard(c),
                            const SizedBox(height: SwanSpace.md),

                            _buildMemberWorkoutsSection(c),
                            const SizedBox(height: 110),
                          ] else if (_selectedTab == 1) ...[
                            _buildPinnedEventCard(c),
                            const SizedBox(height: 110),
                          ] else if (_selectedTab == 2) ...[
                            _buildWeeklyChallengeCard(c),
                            const SizedBox(height: 110),
                          ] else ...[
                            _buildMemberWorkoutsSection(c),
                            const SizedBox(height: 110),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Sticky Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(c),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Club Avatar with border & verified badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.lg),
                    border: Border.all(color: c.surfaceAlt, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SwanRadius.lg - 3),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            c.accent.withValues(alpha: 0.3),
                            c.surfaceAlt,
                          ],
                        ),
                      ),
                      child: Icon(Icons.sailing_rounded, size: 36, color: c.accent),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: 2),
                    ),
                    child: const Icon(Icons.verified_rounded, size: 13, color: Colors.black),
                  ),
                ),
              ],
            ),

            // Membership Button
            FilledButton.icon(
              onPressed: () {
                setState(() => _isMember = !_isMember);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isMember
                        ? 'Swan Runners Istanbul kulübüne katıldınız!'
                        : 'Kulüp üyeliğinden ayrıldınız.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                _isMember ? Icons.check_circle_rounded : Icons.person_add_rounded,
                size: 16,
                color: _isMember ? c.accent : Colors.black,
              ),
              label: Text(
                _isMember ? 'Üye Olundu' : 'Kulübe Katıl',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isMember ? c.accent : Colors.black,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _isMember ? c.surfaceAlt : c.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),

        // Club Name and Badges
        Text(
          widget.clubName,
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'RESMİ KOŞU KULÜBÜ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: c.accent,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.location_on_rounded, size: 14, color: c.inkMuted),
            const SizedBox(width: 2),
            Text(
              'İstanbul, TR',
              style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBento(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Icon(Icons.group_rounded, size: 20, color: c.accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1.420',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    Text('Aktif Üye', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: c.line),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Icon(Icons.speed_rounded, size: 20, color: c.accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3.450 km',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                    Text('Haftalık Mesafe', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTabs(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
        ),
        child: Row(
          children: _tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isSelected = _selectedTab == idx;

            return InkWell(
              onTap: () => setState(() => _selectedTab = idx),
              borderRadius: BorderRadius.circular(SwanRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 15,
                      color: isSelected ? Colors.black : c.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.black : c.ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPinnedEventCard(SwanPalette c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(SwanSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: const NetworkImage(
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
                              ),
                              backgroundColor: c.surfaceAlt,
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star_rounded, size: 10, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Kaan Yılmaz',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB6A4).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Kaptan',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFFFB6A4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '2 saat önce • Belgrad Ormanı Koşusu',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(Icons.push_pin_rounded, size: 20, color: c.accent),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),

                Text(
                  '🌲 Cumartesi 07:00 Belgrad Ormanı 15K Patika Koşusu kayıtları açıldı!',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yağmurluk ve trail ayakkabısı getirmeyi unutmayın. Çamur ve zemin durumu için grup tempoları 3 farklı hız serisine bölünecektir (5:15 / 5:45 / 6:15 min/km). Bitişte sıcak filtre kahve bizden! ☕⚡',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.45,
                    color: c.inkMuted,
                  ),
                ),
              ],
            ),
          ),

          // Course info & register row
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(SwanRadius.lg)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Icon(Icons.route_rounded, size: 18, color: c.accent),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '15.0 km • Neşet Suyu Parkuru',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        Text(
                          _isEventRegistered ? '39/50 Katılımcı (Kayıtlısınız)' : '38/50 Katılımcı Hazır',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () {
                    setState(() => _isEventRegistered = !_isEventRegistered);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isEventRegistered
                            ? 'Belgrad 15K Koşusuna kaydınız yapıldı!'
                            : 'Kayıt iptal edildi.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _isEventRegistered ? c.surfaceAlt : c.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                  ),
                  child: Text(
                    _isEventRegistered ? 'Kayıtlı' : 'Kaydol',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isEventRegistered ? c.accent : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChallengeCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, size: 20, color: c.accent),
                  const SizedBox(width: 6),
                  Text(
                    'HAFTALIK KULÜP MEYDAN OKUMASI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: c.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Sıralama: 1. / 48 Kulüp',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10.000 KM Kulüpler Kupası',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              Text(
                '7.420 / 10.000 km',
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.74,
              minHeight: 10,
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: c.accent),
                  const SizedBox(width: 3),
                  Text(
                    '%74 Tamamlandı',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: c.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Kalan: 2 Gün 14 Saat',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberWorkoutsSection(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Üye Antrenmanları',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Text(
              'Canlı Akış',
              style: SwanType.caption(c.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),

        // Selin Kaya Activity Card
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: const NetworkImage(
                          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200&auto=format&fit=crop',
                        ),
                        backgroundColor: c.surfaceAlt,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selin Kaya',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            'Kadıköy Sahil Koşusu • 45 dk önce',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_run_rounded, size: 14, color: c.accent),
                        const SizedBox(width: 3),
                        Text(
                          '12.4K',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: c.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.md),

              // 3-Col Stats Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mesafe', style: SwanType.caption(c.inkMuted)),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '12.42 ',
                                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
                                ),
                                TextSpan(text: 'km', style: SwanType.caption(c.inkMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ort. Tempo', style: SwanType.caption(c.inkMuted)),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '4:58 ',
                                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.accent),
                                ),
                                TextSpan(text: '/km', style: SwanType.caption(c.inkMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Süre', style: SwanType.caption(c.inkMuted)),
                          Text(
                            '1:01:48',
                            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SwanSpace.sm),

              // Social kudos and comments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _hasGivenKudos = !_hasGivenKudos;
                            _kudosCount += _hasGivenKudos ? 1 : -1;
                          });
                        },
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _hasGivenKudos ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                size: 16,
                                color: _hasGivenKudos ? c.accent : c.inkMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_kudosCount Tebrik',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: _hasGivenKudos ? FontWeight.w700 : FontWeight.w500,
                                  color: _hasGivenKudos ? c.accent : c.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: c.inkMuted),
                          const SizedBox(width: 4),
                          Text('6 Yorum', style: SwanType.caption(c.ink)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 14, color: c.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Yeni Kişisel Rekor!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, 10, SwanSpace.md, 24),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: c.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/mesajlar'),
              icon: Icon(Icons.forum_outlined, size: 18, color: c.ink),
              label: Text(
                'Sohbet',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.line),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  setState(() => _isEventRegistered = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Belgrad Ormanı 15K Koşusuna başarıyla katıldınız!')),
                  );
                },
                icon: const Icon(Icons.event_available_rounded, size: 18, color: Colors.black),
                label: Text(
                  'Etkinliğe Katıl (15K)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
