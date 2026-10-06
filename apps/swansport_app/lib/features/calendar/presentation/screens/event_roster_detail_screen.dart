import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Etkinlik Detayı ve Takım Roster Seans Listesi.
///
/// Stitch "etkinlik_detay_ve_roster" tasarımını tam uygular:
/// - Canlı Seans ve Etap 03 başlık kartı
/// - Tarih, saat ve poligon yerleşim (Hedef 1-8 · Rüzgar Koridor Alanı)
/// - Başantrenör (Ahmet Kaya Kademe IV) profil kartı ve iletişim aksiyonu
/// - Seans odak noktaları (70m Seri Atışları, Rüzgar Düzeltme, Zamanlayıcı Skor Simülasyonu)
/// - Asil (12), Yedek (2), Mazeretli (2) sayısal rozetleri
/// - Hedef numaralı sporcu katılımcı listesi (Kaptan, onaylı, yedek sıralaması)
/// - Roster düzenleme ve sporculara mobil bildirim iletme aksiyonları
class EventRosterDetailScreen extends ConsumerStatefulWidget {
  const EventRosterDetailScreen({
    super.key,
    this.eventId,
    this.title = 'U18 Klasik Yay Bölge Şampiyonası Ön Hazırlık Seansı',
  });

  final String? eventId;
  final String title;

  @override
  ConsumerState<EventRosterDetailScreen> createState() => _EventRosterDetailScreenState();
}

class _EventRosterDetailScreenState extends ConsumerState<EventRosterDetailScreen> {
  String _filterMode = 'Hedefe Göre';

  final List<_RosterItem> _athletes = const [
    _RosterItem(
      name: 'Zeynep Yılmaz',
      target: 'Hedef 4A',
      status: 'Kadroda (Onaylandı)',
      isCaptain: false,
      isSubstitute: false,
      scoreReady: true,
    ),
    _RosterItem(
      name: 'Selin Demir',
      target: 'Hedef 4B',
      status: 'Kadroda (Onaylandı)',
      isCaptain: true,
      isSubstitute: false,
      scoreReady: true,
    ),
    _RosterItem(
      name: 'Barış Alper',
      target: 'Hedef 5A',
      status: 'Kadroda (Onaylandı)',
      isCaptain: false,
      isSubstitute: false,
      scoreReady: true,
    ),
    _RosterItem(
      name: 'Caner Erkin',
      target: 'Hedef 5B',
      status: 'Yedek Liste',
      isCaptain: false,
      isSubstitute: true,
      scoreReady: false,
    ),
    _RosterItem(
      name: 'Mete Gazoz (Misafir)',
      target: 'Hedef 6A',
      status: 'Kadroda (Onaylandı)',
      isCaptain: false,
      isSubstitute: false,
      scoreReady: true,
    ),
    _RosterItem(
      name: 'Kerem Aktürkoğlu',
      target: 'Hedef 6B',
      status: 'Mazeretli (İzinli)',
      isCaptain: false,
      isSubstitute: false,
      scoreReady: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.md,
                SwanSpace.sm,
                SwanSpace.md,
                110,
              ),
              children: [
                _buildHeader(c),
                const SizedBox(height: SwanSpace.md),

                // 1. Event Hero Card
                _buildHeroCard(c),
                const SizedBox(height: SwanSpace.md),

                // 2. Session Focus Points
                _buildFocusPointsCard(c),
                const SizedBox(height: SwanSpace.md),

                // 3. Roster / Attendance Metric Tiles
                _buildMetricTiles(c),
                const SizedBox(height: SwanSpace.md),

                // 4. Participant Roster List
                _buildParticipantSection(c),
                const SizedBox(height: SwanSpace.md),

                // 5. Bottom Actions
                _buildBottomActionButtons(c),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.ink),
              tooltip: 'Geri',
            ),
            const SizedBox(width: SwanSpace.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etkinlik Detayı',
                  style: SwanType.h2(c.ink),
                ),
                Row(
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
                      'Canlı Seans',
                      style: SwanType.caption(c.accent, w: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.share_outlined, size: 20, color: c.ink),
              tooltip: 'Paylaş',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Seans bağlantısı kopyalandı.')),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: c.ink),
              tooltip: 'Seçenekler',
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard(SwanPalette c) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.track_changes_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Okçuluk · Klasik Yay',
                      style: SwanType.caption(c.accent, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  'Etap 03',
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Text(
            widget.title,
            style: SwanType.h3(c.ink),
          ),
          const SizedBox(height: SwanSpace.md),
          // Date & Location Metadata Tile
          Container(
            padding: const EdgeInsets.all(SwanSpace.sm),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                        border: Border.all(color: c.line),
                      ),
                      child: Icon(Icons.calendar_today_rounded, size: 15, color: c.accent),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('18 Nisan 2025 · Cuma', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                        Text('10:00 - 13:00 (180 dk)', style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xs),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                        border: Border.all(color: c.line),
                      ),
                      child: Icon(Icons.location_on_outlined, size: 15, color: c.accent),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Açık Saha Poligonu', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                        Text('Hedef 1-8 · Rüzgar Koridor Alanı', style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          // Responsible Coach Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: c.accent,
                    child: const Text('AK', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Ahmet Kaya', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 14, color: c.accent),
                        ],
                      ),
                      Text('Başantrenör · Kademe IV', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  unawaited(
                    Navigator.pushNamed(
                      context,
                      '/sohbet',
                      arguments: {'id': 'coach-ahmet', 'name': 'Ahmet Kaya'},
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.line),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text('İletişim', style: SwanType.caption(c.ink, w: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFocusPointsCard(SwanPalette c) {
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
                  Icon(Icons.flag_outlined, size: 18, color: c.accent),
                  const SizedBox(width: SwanSpace.xs),
                  Text('Seans Odak Noktaları', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                ],
              ),
              Text('3 Görev', style: SwanType.caption(c.inkMuted)),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          _buildFocusItem(c, Icons.my_location_rounded, '70m Seri Atışları (36 Ok x 2)'),
          const SizedBox(height: SwanSpace.xs),
          _buildFocusItem(c, Icons.air_rounded, 'Rüzgar Düzeltme & Yay Sertlik Ayarı'),
          const SizedBox(height: SwanSpace.xs),
          _buildFocusItem(c, Icons.timer_outlined, 'Resmi Zamanlayıcı Skor Simülasyonu'),
        ],
      ),
    );
  }

  Widget _buildFocusItem(SwanPalette c, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Icon(icon, size: 14, color: c.accent),
          ),
          const SizedBox(width: SwanSpace.sm),
          Expanded(child: Text(text, style: SwanType.caption(c.ink, w: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildMetricTiles(SwanPalette c) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            c: c,
            label: 'Asil Sporcu',
            count: '12',
            badge: 'Kadroda',
            color: c.accent,
          ),
        ),
        const SizedBox(width: SwanSpace.xs),
        Expanded(
          child: _buildMetricTile(
            c: c,
            label: 'Yedek',
            count: '2',
            badge: 'Beklemede',
            color: c.inkMuted,
          ),
        ),
        const SizedBox(width: SwanSpace.xs),
        Expanded(
          child: _buildMetricTile(
            c: c,
            label: 'Mazeretli',
            count: '2',
            badge: 'İzinli',
            color: c.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required SwanPalette c,
    required String label,
    required String count,
    required String badge,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Text(label, style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: 2),
          Text(count, style: SwanType.h2(color)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge, style: SwanType.caption(color, w: FontWeight.w700).copyWith(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantSection(SwanPalette c) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Katılımcı Listesi', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: c.surfaceAlt,
                  child: Text(
                    '${_athletes.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.ink),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _filterMode = _filterMode == 'Hedefe Göre' ? 'Ada Göre' : 'Hedefe Göre';
                });
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 14, color: c.accent),
                    const SizedBox(width: 4),
                    Text(_filterMode, style: SwanType.caption(c.accent, w: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        for (final a in _athletes) _buildAthleteTile(c, a),
      ],
    );
  }

  Widget _buildAthleteTile(SwanPalette c, _RosterItem a) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.xs),
      padding: const EdgeInsets.all(SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: c.surfaceAlt,
                    child: Text(
                      a.name.substring(0, 1),
                      style: TextStyle(color: c.ink, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (a.isCaptain)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Text('K', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: SwanSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(a.name, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                      if (a.isCaptain) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Kaptan', style: SwanType.caption(c.accent, w: FontWeight.w700).copyWith(fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(a.target, style: SwanType.caption(c.inkMuted, w: FontWeight.w600).copyWith(fontSize: 10)),
                      ),
                      const SizedBox(width: 4),
                      Text('·', style: TextStyle(color: c.inkMuted)),
                      const SizedBox(width: 4),
                      Text(
                        a.status,
                        style: SwanType.caption(
                          a.isSubstitute ? c.inkMuted : c.accent,
                          w: FontWeight.w600,
                        ).copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (a.scoreReady)
                IconButton(
                  onPressed: () {
                    unawaited(Navigator.pushNamed(context, '/musabaka-simulasyonu'));
                  },
                  icon: Icon(Icons.sports_score_rounded, size: 18, color: c.accent),
                  tooltip: 'Skor Girişi',
                ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(SwanPalette c) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hedef atamaları & yedek sıralaması düzenleme moduna geçildi.')),
              );
            },
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Roster\'ı Düzenle'),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
            ),
          ),
        ),
        const SizedBox(height: SwanSpace.xs),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('14 sporcu ve 2 antrenöre seans hatırlatması iletildi.')),
              );
            },
            icon: Icon(Icons.send_to_mobile_rounded, size: 18, color: c.accent),
            label: Text('Gruba Bildirim Gönder', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RosterItem {
  const _RosterItem({
    required this.name,
    required this.target,
    required this.status,
    required this.isCaptain,
    required this.isSubstitute,
    required this.scoreReady,
  });

  final String name;
  final String target;
  final String status;
  final bool isCaptain;
  final bool isSubstitute;
  final bool scoreReady;
}
