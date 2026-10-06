import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Kulüp Bülteni ve Duyurular.
///
/// Google Stitch "SwanSport - Resmi Kulüp Duyuruları" tasarımını birebir uygular:
/// - Canlı akış & Tesis durum rozeti
/// - Okunmamış duyuru sayacı
/// - Kategori filtre çipleri (Tümü, Acil, Maç & Saha, İdari, Sağlık)
/// - Sabitlenmiş Öncelikli Bildirim Kartı (Veli okuma onay çubuğu & interaktif onay)
/// - Resmi Duyuru Akışı (PDF evrak eki, Maç servisi detay kartı, Beslenme semineri linki)
/// - Bildirim Kanalları & Veli Hattı durum kutusu
/// - Yönetici/Antrenör yeni duyuru & toplu bildirim hızlı aksiyonları
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Tümü';
  bool _isAcknowledged = false;

  final List<({String label, int count, IconData icon, Color? iconColor})> _categories = [
    (label: 'Tümü', count: 14, icon: Icons.all_inbox_rounded, iconColor: null),
    (label: 'Acil / Önemli', count: 2, icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFFFB6A4)),
    (label: 'Maç & Saha', count: 5, icon: Icons.sports_soccer_rounded, iconColor: const Color(0xFF55DBD2)),
    (label: 'İdari & Aidat', count: 4, icon: Icons.request_quote_rounded, iconColor: const Color(0xFFC0C6D9)),
    (label: 'Sağlık', count: 3, icon: Icons.health_and_safety_rounded, iconColor: const Color(0xFF54DAD1)),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              color: c.accent,
              backgroundColor: c.surface,
              onRefresh: () async {
                ref.invalidate(announcementsProvider);
                await ref.read(announcementsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SwanSpace.md,
                  SwanSpace.sm,
                  SwanSpace.md,
                  110,
                ),
                children: [
                  _buildHeader(c, club),
                  const SizedBox(height: SwanSpace.md),

                  // Search field
                  _buildSearchField(c),
                  const SizedBox(height: SwanSpace.sm),

                  // Filter Pills
                  _buildFilterPills(c),
                  const SizedBox(height: SwanSpace.md),

                  // Pinned / Urgent Priority Announcement Card
                  _buildPinnedAnnouncement(c),
                  const SizedBox(height: SwanSpace.lg),

                  // Feed Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resmi Duyuru Akışı',
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            'Kronolojik Sıralama',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Yeniden Eskiye', style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.sort_rounded, size: 16, color: c.inkMuted),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: SwanSpace.sm),

                  // Dynamic Announcements from Supabase Provider
                  announcementsAsync.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (items) {
                      final needle = _query.toLowerCase();
                      final filtered = needle.isEmpty
                          ? items
                          : items
                              .where(
                                (item) =>
                                    trContains(item.title, needle) ||
                                    trContains(item.body, needle),
                              )
                              .toList();

                      if (filtered.isEmpty && needle.isNotEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.search_off_rounded,
                          title: 'Duyuru bulunamadı',
                          subtitle: 'Başlık veya içerikte “$_query” geçmiyor.',
                        );
                      }

                      return Column(
                        children: [
                          for (final a in filtered) _buildAnnouncementCard(c, a),
                        ],
                      );
                    },
                  ),

                  // Stitch Curated Feed Items (Rich interactive cards)
                  _buildStitchNotices(c),
                  const SizedBox(height: SwanSpace.lg),

                  // Bildirim Kanalları & Veli Hattı Card
                  _buildNotificationChannelsCard(c),
                  const SizedBox(height: SwanSpace.lg),

                  // Alt Hızlı Aksiyon Butonları
                  _buildBottomActionButtons(c, club),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c, ClubRef? club) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.ink),
                  tooltip: 'Geri',
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Icon(Icons.campaign_rounded, size: 22, color: c.accent),
                ),
                const SizedBox(width: SwanSpace.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SWANSPORT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: c.accent,
                      ),
                    ),
                    Text(
                      'Resmi Duyurular',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.filter_list_rounded, size: 20, color: c.inkMuted),
                  style: IconButton.styleFrom(
                    backgroundColor: c.surfaceAlt.withValues(alpha: 0.6),
                  ),
                  tooltip: 'Filtrele',
                ),
                const SizedBox(width: 4),
                Stack(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.notifications_none_rounded, size: 20, color: c.inkMuted),
                      style: IconButton.styleFrom(
                        backgroundColor: c.surfaceAlt.withValues(alpha: 0.6),
                      ),
                      tooltip: 'Bildirimler',
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'CANLI AKIŞ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${club?.name ?? 'FLORYA MERKEZ TESİSLERİ'}',
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kulüp Duyuruları & Pano',
                    style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Resmi Yönetim ve Antrenör Bildirimleri',
                    style: SwanType.bodySm(c.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB6A4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 16, color: Color(0xFFFFB6A4)),
                  const SizedBox(width: 6),
                  Text(
                    '3 Yeni Okunmamış',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFB6A4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField(SwanPalette c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v.trim()),
        style: SwanType.bodySm(c.ink),
        decoration: InputDecoration(
          hintText: 'Duyurularda ara…',
          hintStyle: SwanType.bodySm(c.inkMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.inkMuted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFilterPills(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat.label;
          return Padding(
            padding: const EdgeInsets.only(right: SwanSpace.xs),
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = cat.label),
              borderRadius: BorderRadius.circular(SwanRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? c.accent : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      size: 15,
                      color: isSelected
                          ? Colors.black
                          : (cat.iconColor ?? c.inkMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${cat.label} (${cat.count})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.black : c.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPinnedAnnouncement(SwanPalette c) {
    final ackCount = _isAcknowledged ? 43 : 42;
    final ackPercent = ackCount / 48.0;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: const Color(0xFFFFB6A4).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Line
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFB6A4), Color(0xFFFF8C6F), Color(0xFF55DBD2)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(SwanSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB6A4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.crisis_alert_rounded, size: 14, color: Color(0xFFFFB6A4)),
                            const SizedBox(width: 4),
                            Text(
                              'ACİL • SAHA & HAVA DURUMU BİLGİLENDİRMESİ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFB6A4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: c.inkMuted),
                          const SizedBox(width: 3),
                          Text('Bugün 13:45', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: SwanSpace.sm),

                  Text(
                    'Yoğun Yağış Sebebiyle U14 ve U16 İdmanları Kapalı Sahaya Alınmıştır',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: SwanSpace.xs),
                  Text(
                    'Meteoroloji genel müdürlüğü uyarıları ve yoğun sağanak yağış nedeniyle bu akşam 18:00\'deki açık çim saha antrenmanları 2 Nolu Isıtmalı Kapalı Sentetik Sahaya kaydırılmıştır. Velilerimizin sporcuları kapalı tesis girişinden teslim almaları rica olunur.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      height: 1.45,
                      color: c.inkMuted,
                    ),
                  ),
                  const SizedBox(height: SwanSpace.sm),

                  // Tag Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildTagChip(c, '# Tüm Veliler & Sporcular', null),
                      _buildTagChip(c, 'Tesis Değişikliği', Icons.stadium_outlined, iconColor: c.accent),
                      _buildTagChip(c, 'Şiddetli Yağış', Icons.thunderstorm_outlined, iconColor: const Color(0xFFFFB6A4)),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Acknowledgment Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 12),
              color: c.surfaceAlt.withValues(alpha: 0.5),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(SwanRadius.md),
                            ),
                            child: Icon(Icons.assignment_turned_in_outlined, size: 18, color: c.accent),
                          ),
                          const SizedBox(width: SwanSpace.xs),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Veli Okuma Onayı',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                ),
                              ),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: ackPercent,
                                        minHeight: 5,
                                        backgroundColor: c.surfaceAlt,
                                        valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$ackCount / 48 Onay',
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
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isAcknowledged = !_isAcknowledged;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_isAcknowledged
                                  ? 'Onayınız kulüp sistemine kaydedildi (43/48).'
                                  : 'Onay geri çekildi.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(
                          _isAcknowledged ? Icons.check_circle_rounded : Icons.done_all_rounded,
                          size: 16,
                          color: _isAcknowledged ? c.accent : Colors.black,
                        ),
                        label: Text(
                          _isAcknowledged ? 'Onayınız Kaydedildi' : 'Okudum & Onayladım',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isAcknowledged ? c.accent : Colors.black,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isAcknowledged ? c.surfaceAlt : c.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
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

  Widget _buildTagChip(SwanPalette c, String label, IconData? icon, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? c.inkMuted),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: iconColor ?? c.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchNotices(SwanPalette c) {
    return Column(
      children: [
        // Notice 1: Lisans Vize Evrakları (PDF Attachment)
        Container(
          margin: const EdgeInsets.only(top: SwanSpace.sm),
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                        ),
                        child: Icon(Icons.badge_outlined, size: 20, color: c.inkMuted),
                      ),
                      const SizedBox(width: SwanSpace.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İdari İşler Departmanı',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                          ),
                          Text('Dün 16:20 • Resmi Belge Bildirimi', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                    ),
                    child: Text('İdari', style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),
              Text(
                '2024-2025 Sezonu Lisans Vize Evrakları Son Teslim Tarihi',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'TFF vizesi için sağlık kurulu raporları ve noter onaylı veli muvafakatnamelerinin en geç 15 Kasım Cuma gününe kadar kulüp sekreterliğine teslim edilmesi gerekmektedir. Zamanında teslim edilmeyen evraklar sebebiyle lisans işlemleri geciken sporcular resmi müsabaka kadrosuna dahil edilemeyecektir.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.sm),

              // PDF Attachment Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB4AB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(SwanRadius.sm),
                          ),
                          child: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFFFB4AB)),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gerekli_Evraklar_Listesi.pdf',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
                            ),
                            Text('1.2 MB • Resmi Şablon Paketi', style: SwanType.caption(c.inkMuted)),
                          ],
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Evrak paketi indiriliyor (Gerekli_Evraklar_Listesi.pdf)...')),
                        );
                      },
                      icon: Icon(Icons.download_rounded, size: 14, color: c.accent),
                      label: Text('İndir', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.accent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Notice 2: U18 Deplasman Maçı Servis Kalkış
        Container(
          margin: const EdgeInsets.only(top: SwanSpace.sm),
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                        ),
                        child: Icon(Icons.directions_bus_filled_rounded, size: 20, color: c.accent),
                      ),
                      const SizedBox(width: SwanSpace.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mert Koç', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                          Text('Baş Antrenör • 2 Gün Önce', style: SwanType.caption(c.accent, w: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                    ),
                    child: Text('U18 Lig', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),
              Text(
                'Cumartesi Günü U18 Deplasman Maçı Servis Kalkış Saatleri',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Kartal deplasmanı için kulüp servisimiz Florya tesis önünden 11:30\'da hareket edecektir. Kafiledeki 18 sporcumuzun en geç 11:00\'de toplantı odasında maç kitleri ve seyahat eşofmanlarıyla hazır bulunması zorunludur.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.sm),

              // Match info grid
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.departure_board_rounded, size: 18, color: c.accent),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Toplanma Saati', style: SwanType.caption(c.inkMuted)),
                              Text('11:00 • Tesis Önü', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sports_score_rounded, size: 18, color: Color(0xFFFFB6A4)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Başlama Düdüğü', style: SwanType.caption(c.inkMuted)),
                              Text('14:00 • Kartal Stadı', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('18 Kişilik U18 Maç Kafilesi: Arda T., Kerem D., Selim V., ...')),
                    );
                  },
                  icon: Icon(Icons.group_rounded, size: 16, color: c.accent),
                  label: Text('Servis Listesini Gör (18 Sporcu)', style: TextStyle(color: c.ink, fontSize: 12, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.surfaceAlt,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Notice 3: Beslenme Semineri (Online link)
        Container(
          margin: const EdgeInsets.only(top: SwanSpace.sm),
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF54DAD1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                        ),
                        child: const Icon(Icons.restaurant_rounded, size: 20, color: Color(0xFF54DAD1)),
                      ),
                      const SizedBox(width: SwanSpace.xs),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uzm. Dyt. Pelin Demir', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                          Text('Kulüp Diyetisyeni • 3 Gün Önce', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                    ),
                    child: Text('Sağlık', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),
              Text(
                'Beslenme Semineri & Sporcu Aileleri Bilgilendirme Toplantısı',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Akademi sporcularımızın sezon içi performans ve hidrasyon takibi için Zoom üzerinden veli semineri düzenlenecektir. Maç öncesi ve sonrası toparlanma menüleri ile sporcu takviyeleri detaylı şekilde aktarılacaktır.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.sm),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam_outlined, size: 18, color: Color(0xFFFFB6A4)),
                        const SizedBox(width: 6),
                        Text(
                          '12 Kasım Salı 20:30 • Çevrim İçi Veli Paneli',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
                        ),
                      ],
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Zoom toplantı bağlantısı panoya kopyalandı.')),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
                      ),
                      child: Text(
                        'Katılım Linki',
                        style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationChannelsCard(SwanPalette c) {
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    child: Icon(Icons.notifications_active_outlined, size: 20, color: c.accent),
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bildirim Kanalları & Veli Hattı',
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink),
                      ),
                      Text('Anlık kritik kulüp duyuru erişimi', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.tune_rounded, size: 18, color: c.inkMuted),
                style: IconButton.styleFrom(backgroundColor: c.surfaceAlt),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),

          Row(
            children: [
              // SMS Channel
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sms_outlined, size: 18, color: c.accent),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Acil SMS', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink)),
                              Text('+90 532 *** ** 84', style: SwanType.caption(c.inkMuted)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Text('AKTİF', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: c.accent)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Push Channel
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.cell_tower_rounded, size: 18, color: c.accent),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mobil Push', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink)),
                              Text('İzin verildi', style: SwanType.caption(c.inkMuted)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Text('AÇIK', style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: c.accent)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(SwanPalette c, ClubRef? club) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: club == null ? null : () => _compose(context, club),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.black),
            label: Text(
              '+ Yeni Resmi Duyuru',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton.tonalIcon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Toplu SMS ve Push bildirim konsolu hazır.')),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFFFFB6A4)),
            label: Text(
              'Toplu Bildirim',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: c.ink),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: c.surfaceAlt,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(SwanPalette c, AnnouncementRow a) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
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
                  Icon(Icons.campaign_outlined, size: 16, color: c.accent),
                  const SizedBox(width: 4),
                  Text('Kulüp Duyurusu', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                ],
              ),
              Text(
                '${a.createdAt.day}.${a.createdAt.month}.${a.createdAt.year}',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(a.title, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(a.body, style: SwanType.caption(c.inkMuted)),
        ],
      ),
    );
  }

  Future<void> _compose(BuildContext context, ClubRef club) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.swan;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yeni Duyuru Yaz', style: SwanType.h3(c.ink)),
                const SizedBox(height: SwanSpace.md),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duyuru Başlığı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Duyuru Metni',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      try {
                        await ref.read(clubDataServiceProvider).addAnnouncement(
                              club.id,
                              titleCtrl.text.trim(),
                              bodyCtrl.text.trim(),
                              false,
                            );
                        ref.invalidate(announcementsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Hata: $e')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: c.accent),
                    child: const Text('Duyuruyu Yayınla'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
