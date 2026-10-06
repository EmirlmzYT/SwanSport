import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../routing/athlete_detail_route_args.dart';
import '../widgets/add_athlete_sheet.dart';
import '../widgets/link_athletes_sheet.dart';

/// Sporcu & Antrenör Çalışma Alanı (Stitch Calm Athletic Modernism v3).
///
/// Günlük Odak Hub'ı, Etkileşimli Görev Listesi, Taktik Not Defteri,
/// Hızlı Saha Araçları ve Kulüp Kadro Yönetimini tek çatı altında birleştirir.
class AthleteWorkspaceScreen extends ConsumerStatefulWidget {
  const AthleteWorkspaceScreen({super.key});

  @override
  ConsumerState<AthleteWorkspaceScreen> createState() =>
      _AthleteWorkspaceScreenState();
}

class _AthleteWorkspaceScreenState
    extends ConsumerState<AthleteWorkspaceScreen> {
  int _filter = 0;
  static const _filters = ['Tüm Kadro', 'Aktif', 'Bağlantısız', 'Pozisyon'];
  String _searchQuery = '';

  // Görev takip yerel durumu
  final Set<int> _completedTasks = {0};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final clubAsync = ref.watch(activeClubProvider);
    final athletesAsync = ref.watch(clubAthletesProvider);

    final now = DateTime.now();
    final trMonths = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    final trDays = [
      '', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];
    final dateStr = '${now.day} ${trMonths[now.month]} ${trDays[now.weekday]}';

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: () async {
                ref.invalidate(myClubsProvider);
                ref.invalidate(clubAthletesProvider);
                await ref.read(clubAthletesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                children: [
                  // --- 1. Üst Bar: Geri, Başlık, Arama, Filtre, Profil ---
                  _buildHeader(context, c, isDark, clubAsync.valueOrNull),
                  const SizedBox(height: 16),

                  // --- 2. Canlı Operasyon Hub'ı & Tarih Rozeti ---
                  _buildLiveStatusRow(c, dateStr),
                  const SizedBox(height: 12),

                  // --- 3. Kişisel Çalışma Hub'ı & Günlük Odak Bento Kartı ---
                  _buildDailyFocusCard(c, athletesAsync.valueOrNull?.length ?? 24),
                  const SizedBox(height: 24),

                  // --- 4. Günlük Görev Akışı (Interactive Checklist) ---
                  _buildTaskChecklist(c),
                  const SizedBox(height: 24),

                  // --- 5. Öne Çıkan Sporcu Bireysel Gelişim Kartı ---
                  _buildIndividualDevCard(c),
                  const SizedBox(height: 24),

                  // --- 6. Taktik Not Defteri ---
                  _buildTacticalNotebook(c),
                  const SizedBox(height: 24),

                  // --- 7. Hızlı Saha Araçları ---
                  _buildFieldTools(c),
                  const SizedBox(height: 28),

                  // --- 8. Kulüp Kadrosu & Canlı Veri Listesi ---
                  _buildRosterSectionHeader(c, athletesAsync.valueOrNull?.length ?? 0, clubAsync.valueOrNull),
                  const SizedBox(height: 12),

                  if (clubAsync.valueOrNull != null)
                    _unlinkedBanner(c, clubAsync.valueOrNull!),

                  _buildSearchAndFilters(c),
                  const SizedBox(height: 12),

                  // Liste Durumları
                  clubAsync.when(
                    loading: () => premiumLoading(),
                    error: (e, _) => _errorState(c, '$e'),
                    data: (club) {
                      if (club == null) return _noClubState(c);
                      return athletesAsync.when(
                        loading: () => premiumLoading(),
                        error: (e, _) => _errorState(c, '$e'),
                        data: (athletes) {
                          if (athletes.isEmpty) return _emptyRosterState(c, club);

                          final filtered = athletes.where((a) {
                            if (_searchQuery.isNotEmpty) {
                              final q = _searchQuery.toLowerCase();
                              final name = a.fullName.toLowerCase();
                              final pos = (a.position ?? '').toLowerCase();
                              if (!name.contains(q) && !pos.contains(q)) return false;
                            }
                            if (_filter == 1) return a.isActive;
                            if (_filter == 2) return !a.isActive;
                            return true;
                          }).toList();

                          return Column(
                            children: List.generate(filtered.length, (i) {
                              return _athleteRow(context, c, filtered[i], i, i == filtered.length - 1);
                            }),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
      floatingActionButton: clubAsync.valueOrNull != null
          ? Container(
              margin: const EdgeInsets.only(bottom: 70),
              child: FloatingActionButton.extended(
                backgroundColor: c.accent,
                elevation: 4,
                onPressed: () => _showAddAthlete(clubAsync.valueOrNull!),
                icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
                label: Text(
                  'Yeni Sporcu Ekle',
                  style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                ),
              ),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // ÜST BAR
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    SwanPalette c,
    bool isDark,
    ClubRef? club,
  ) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back, color: c.ink, size: 22),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Antrenör Çalışma Alanı',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              Text(
                club?.name ?? 'SwanSport Akademi',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.tune, color: c.inkMuted, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.accent.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CANLI HUB SATIRI
  // ---------------------------------------------------------------------------
  Widget _buildLiveStatusRow(SwanPalette c, String dateStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'CANLI OPERASYON HUB\'I',
              style: SwanType.caption(
                c.accent,
                w: FontWeight.w800,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 13, color: c.accent),
              const SizedBox(width: 5),
              Text(
                dateStr,
                style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GÜNLÜK ODAK BENTO KARTI
  // ---------------------------------------------------------------------------
  Widget _buildDailyFocusCard(SwanPalette c, int rosterCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERFORMANS FAZI',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.bolt, color: c.accent, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Güç & Reaksiyon',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  children: [
                    Text(
                      'HAZIRLIK',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                    ),
                    Text(
                      '%92',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _focusMetricTile(
                  c,
                  icon: Icons.task_alt,
                  iconColor: c.accent,
                  label: 'Öncelik',
                  value: '3 Görev',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _focusMetricTile(
                  c,
                  icon: Icons.timer,
                  iconColor: const Color(0xFFFFB6A4),
                  label: 'Yoğunluk',
                  value: 'RPE 8.4',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _focusMetricTile(
                  c,
                  icon: Icons.groups,
                  iconColor: c.inkMuted,
                  label: 'Kadro',
                  value: '22/$rosterCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _focusMetricTile(
    SwanPalette c, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GÖREV LİSTESİ
  // ---------------------------------------------------------------------------
  Widget _buildTaskChecklist(SwanPalette c) {
    final tasks = [
      (
        '10:00 • MAÇ ÖNCESİ',
        'U18 Maç Önü Taktik Video Analizi',
        'Görsel set ve hücum varyasyonları sunuldu.',
        c.accent,
      ),
      (
        '14:30 • VERİ AKTARIMI',
        'Saha İçi GPS Yelek Verilerinin Senkronizasyonu',
        'Kalan 4 cihaz senkronize ediliyor.',
        c.accent,
      ),
      (
        '17:00 • MEDİKAL PROTOKOL',
        'Sakatlık İyileşme Protokolü Takibi: Merih D.',
        'İzokinetik kuvvet testi sonuçları bekleniyor.',
        const Color(0xFFFFB6A4),
      ),
      (
        '18:30 • İLETİŞİM',
        'Velilere Maç Servis Bilgilendirme SMS Gönderimi',
        'Deplasman güzergah listesi taslakta.',
        c.inkMuted,
      ),
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
                  'Günlük Görev Akışı',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  'Tamamlanması beklenen operasyonlar',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_completedTasks.length} / ${tasks.length} Bitti',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(tasks.length, (i) {
            final t = tasks[i];
            final done = _completedTasks.contains(i);
            final isGps = i == 1;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: done ? c.accent.withValues(alpha: 0.3) : c.line,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (done) {
                              _completedTasks.remove(i);
                            } else {
                              _completedTasks.add(i);
                            }
                          });
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 2, right: 10),
                          decoration: BoxDecoration(
                            color: done ? c.accent : c.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: done ? c.accent : c.line,
                            ),
                          ),
                          child: done
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t.$1,
                                  style: SwanType.caption(t.$4, w: FontWeight.w800),
                                ),
                                if (done)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: c.accent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Tamamlandı',
                                      style: SwanType.caption(c.accent,
                                          w: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.$2,
                              style: SwanType.bodySm(
                                c.ink,
                                w: FontWeight.w600,
                              ).copyWith(
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: done ? c.inkMuted : c.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.$3,
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isGps && !done) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Senkronizasyon: %60',
                            style: SwanType.caption(c.accent)),
                        Text('Kalan 4 Cihaz',
                            style: SwanType.caption(const Color(0xFFFFB6A4))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.60,
                        minHeight: 5,
                        backgroundColor: c.bg,
                        valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ÖNE ÇIKAN GELİŞİM KARTI
  // ---------------------------------------------------------------------------
  Widget _buildIndividualDevCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Öne Çıkan Gelişim',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
              Text(
                'Detaylı Rapor',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'SK',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Semih Kılıçsoy',
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#9',
                            style: SwanType.caption(c.ink, w: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bireysel Özel Hücum & Bitiricilik Çalışması',
                      style: SwanType.caption(c.accent, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: c.bg,
              ),
              icon: Icon(Icons.arrow_forward, size: 16, color: c.accent),
              label: Text(
                'Gelişim Planını Gör',
                style: SwanType.bodySm(c.ink, w: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAKTİK NOT DEFTERİ
  // ---------------------------------------------------------------------------
  Widget _buildTacticalNotebook(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
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
                  Icon(Icons.draw, color: c.accent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Taktik Not Defteri',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.edit, size: 14, color: c.inkMuted),
                label: Text('Düzenle', style: SwanType.caption(c.inkMuted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(12),
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
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFB6A4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Kuzey Akademi Maçı Duran Top',
                          style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text('Dün, 19:40', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Bölge alan parselasyonu ve ön direk eşleşmeleri optimize edildi. Rakibin ters ayaklı kanat oyuncularının kornerlerinde kaleci 6 pas hakimiyet çizgisinde konumlanacak.',
                  style: SwanType.caption(c.inkMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _tagChip(c, '#DuranTop'),
                    _tagChip(c, '#AlanSavunması'),
                    _tagChip(c, '#KaleciTalimatı'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(SwanPalette c, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.line),
      ),
      child: Text(text, style: SwanType.caption(c.ink, w: FontWeight.w600)),
    );
  }

  // ---------------------------------------------------------------------------
  // HIZLI SAHA ARAÇLARI
  // ---------------------------------------------------------------------------
  Widget _buildFieldTools(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı Saha Araçları',
          style: GoogleFonts.sora(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _toolButton(
                c,
                icon: Icons.timer,
                iconColor: c.accent,
                title: 'Kronometre',
                subtitle: 'Tur sayacı',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toolButton(
                c,
                icon: Icons.sports,
                iconColor: const Color(0xFFFFB6A4),
                title: 'Düdük & Sinyal',
                subtitle: 'Tempo uyarısı',
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _toolButton(
                c,
                icon: Icons.gesture,
                iconColor: c.accent,
                title: 'Taktik Tahtası',
                subtitle: '2D çizim',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toolButton(
                c,
                icon: Icons.edit_note,
                iconColor: c.inkMuted,
                title: 'Hızlı Not Al',
                subtitle: 'Sesli / metin',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolButton(
    SwanPalette c, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KADRO BÖLÜMÜ BAŞLIK & ARAMA & FİLTRELER
  // ---------------------------------------------------------------------------
  Widget _buildRosterSectionHeader(SwanPalette c, int count, ClubRef? club) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kulüp Kadrosu · $count',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            Text(
              'Sporcu listesi ve hesap bağlantıları',
              style: SwanType.caption(c.inkMuted),
            ),
          ],
        ),
        if (club != null)
          IconButton(
            onPressed: () => _showAddAthlete(club),
            icon: Icon(Icons.person_add_alt_1, color: c.accent, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilters(SwanPalette c) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: c.inkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Sporcu ara...',
                    hintStyle: SwanType.bodySm(c.inkMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final active = i == _filter;
              return InkWell(
                onTap: () => setState(() => _filter = i),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: active ? c.accent : c.line),
                  ),
                  child: Text(
                    _filters[i],
                    style: SwanType.caption(
                      active ? Colors.white : c.inkMuted,
                      w: FontWeight.w700,
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

  // ---------------------------------------------------------------------------
  // KADRO SATIRI
  // ---------------------------------------------------------------------------
  Widget _athleteRow(
    BuildContext context,
    SwanPalette c,
    AthleteRow a,
    int index,
    bool isLast,
  ) {
    final ok = a.isActive;
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/athlete-detail',
        arguments: AthleteDetailRouteArgs(athleteId: SwanId(a.id)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            GradientAvatar(initials: a.initials, gradientIndex: index % 4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.fullName,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.position ?? 'Sporcu',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ok
                    ? c.accent.withValues(alpha: 0.15)
                    : const Color(0xFFFFB6A4).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ok ? Icons.check_circle : Icons.pause_circle_filled,
                    size: 14,
                    color: ok ? c.accent : const Color(0xFFFFB6A4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ok ? 'Aktif' : 'Pasif',
                    style: SwanType.caption(
                      ok ? c.accent : const Color(0xFFFFB6A4),
                      w: FontWeight.w700,
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

  // ---------------------------------------------------------------------------
  // BAĞLANTISIZ SPORCU UYARISI
  // ---------------------------------------------------------------------------
  Widget _unlinkedBanner(SwanPalette c, ClubRef club) {
    final rows = ref.watch(unlinkedAthletesProvider(club.id)).valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          await showLinkAthletesSheet(context, club.id);
          if (mounted) ref.invalidate(clubAthletesProvider);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFB6A4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_off_rounded, size: 20, color: Color(0xFFFFB6A4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${rows.length} sporcu hesaba bağlı değil — antrenman oturumuna katılamaz',
                  style: SwanType.bodySm(c.ink),
                ),
              ),
              Text(
                'Eşleştir',
                style: SwanType.bodySm(c.accent, w: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // YARDIMCI VE DİYALOGLAR
  // ---------------------------------------------------------------------------
  Widget _errorState(SwanPalette c, String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 36, color: Colors.red),
            const SizedBox(height: 8),
            Text('Veri yüklenemedi', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            Text(msg, style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _noClubState(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.add_business_rounded, color: c.accent, size: 36),
            const SizedBox(height: 12),
            Text('Henüz bir kulübün yok', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 4),
            Text('Başlamak için bir kulüp oluştur.', style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _emptyRosterState(SwanPalette c, ClubRef club) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_rounded, color: c.accent, size: 36),
            const SizedBox(height: 12),
            Text('Kadro boş', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 4),
            Text('İlk sporcunu ekleyerek başla.', style: SwanType.caption(c.inkMuted)),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAthlete(ClubRef club) async {
    final choice = await showAddAthleteSheet(context, club.id);
    if (choice == null || !mounted) return;

    switch (choice) {
      case AddAthleteFromMember(:final profileId, :final fullName):
        await _addFromMember(club, profileId, fullName);
      case AddAthleteManually():
        await _addManually(club);
    }
  }

  Future<void> _addFromMember(ClubRef club, String profileId, String fullName) async {
    String? first;
    String? last;

    if (fullName.trim().isEmpty) {
      final firstCtrl = TextEditingController();
      final lastCtrl = TextEditingController();
      final ok = await _formDialog(
        title: 'Sporcunun Adı',
        fields: [
          _DialogField('Ad', firstCtrl),
          _DialogField('Soyad', lastCtrl),
        ],
        action: 'Ekle',
      );
      if (ok != true) return;
      if (firstCtrl.text.trim().isEmpty) return;
      first = firstCtrl.text.trim();
      last = lastCtrl.text.trim();
    }

    await _run(() async {
      await ref.read(athleteServiceProvider).createAthleteFromMember(
            clubId: club.id,
            profileId: profileId,
            firstName: first,
            lastName: last,
          );
      ref.invalidate(clubAthletesProvider);
      ref.invalidate(clubMemberCandidatesProvider(club.id));
      ref.invalidate(unlinkedAthletesProvider(club.id));
    }, success: 'Sporcu eklendi ve hesabına bağlandı');
  }

  Future<void> _addManually(ClubRef club) async {
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final ok = await _formDialog(
      title: 'Hesabı Olmayan Sporcu',
      fields: [
        _DialogField('Ad', firstCtrl),
        _DialogField('Soyad', lastCtrl),
        _DialogField('Pozisyon (opsiyonel)', posCtrl),
      ],
      action: 'Ekle',
    );
    if (ok != true) return;
    if (firstCtrl.text.trim().isEmpty || lastCtrl.text.trim().isEmpty) return;
    await _run(() async {
      await ref.read(athleteServiceProvider).addAthlete(
            clubId: club.id,
            firstName: firstCtrl.text.trim(),
            lastName: lastCtrl.text.trim(),
            position: posCtrl.text.trim(),
          );
      ref.invalidate(clubAthletesProvider);
      ref.invalidate(unlinkedAthletesProvider(club.id));
    }, success: 'Sporcu eklendi — henüz bir hesaba bağlı değil');
  }

  Future<void> _run(Future<void> Function() task, {required String success}) async {
    final c = Theme.of(context).brightness == Brightness.dark
        ? SwanPalette.dark
        : SwanPalette.light;
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: c.accent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool?> _formDialog({
    required String title,
    required List<_DialogField> fields,
    required String action,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: c.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in fields) ...[
              TextField(
                controller: f.controller,
                style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: f.label,
                  labelStyle: SwanType.caption(c.inkMuted),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: SwanType.bodySm(c.inkMuted, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: SwanType.bodySm(c.accent, w: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _DialogField {
  const _DialogField(this.label, this.controller);
  final String label;
  final TextEditingController controller;
}
