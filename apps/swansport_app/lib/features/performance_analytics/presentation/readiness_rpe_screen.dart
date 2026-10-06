import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Sporcu Hazırbulunuşluk & RPE İndeksi ekranı.
///
/// Stitch `sporcu_haz_rbulunu_luk_ve_rpe_i_ndeksi` tasarımı:
/// - Günlük biyometrik hazırbulunuşluk skoru (%84)
/// - Uyku, DOMS (kas ağrısı) ve zihinsel stres bento kartları
/// - ACWR (Akut:Kronik iş yükü oranı = 1.14) ve 7 günlük ok atım hacim grafiği
/// - RPE (Algılanan Zorluk Derecesi: 7/10) ve fizyoterapist klinik notu
/// - İnteraktif rejenerasyon & toparlanma kontrol listesi
class ReadinessRpeScreen extends ConsumerStatefulWidget {
  const ReadinessRpeScreen({super.key});

  @override
  ConsumerState<ReadinessRpeScreen> createState() => _ReadinessRpeScreenState();
}

class _ReadinessRpeScreenState extends ConsumerState<ReadinessRpeScreen> {
  double _currentRpe = 7.0;
  final Set<int> _completedTasks = {0}; // Task 0 is checked initially

  final List<({String title, String duration, IconData icon})> _tasks = const [
    (
      title: 'Miyofasiyal Masaj Tabancası',
      duration: '15 dk • Sırt ve Trapez Bölgesi',
      icon: Icons.check_circle_rounded,
    ),
    (
      title: 'Buz / Soğuk Kompres',
      duration: '12 dk • Rotator Kılıf Çevresi',
      icon: Icons.ac_unit_rounded,
    ),
    (
      title: 'Kontrast Duş & Pasif Dinlenme',
      duration: '20 dk • Dolaşım Hızlandırma',
      icon: Icons.water_drop_rounded,
    ),
  ];

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
              children: [
                _buildTopBar(context, ink, surf, line),
                const SizedBox(height: 14),
                _buildHeadline(),
                const SizedBox(height: 14),
                _buildHeroReadinessCard(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildAcwrWorkloadCard(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildRpeSection(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildRegenerationProtocolCard(isDark, surf, line, ink),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRpeUpdateModal,
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded),
        label: Text(
          'RPE Güncelle',
          style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
        ),
      ),
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
                Text('Antrenman', style: SwanType.h2(ink)),
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
                Icons.favorite_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
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
                  'BIYOMETRİK İZLEME',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('Hazırbulunuşluk & RPE', style: SwanType.h1(SwanColors.textPrimary)),
            Text(
              'Günün Değerlendirmesi • Bugün',
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: kTeal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, size: 16, color: kTeal),
              const SizedBox(width: 4),
              Text(
                'Haftalık Trend',
                style: SwanType.caption(kTeal, w: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroReadinessCard(
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: kTeal),
                          const SizedBox(width: 4),
                          Text(
                            'Optimal Yüklenmeye Hazır',
                            style: SwanType.caption(kTeal, w: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('84', style: SwanType.display(kTeal)),
                        const SizedBox(width: 4),
                        Text(
                          '/ 100',
                          style: SwanType.h3(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: kTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Düne göre +6 puan yüksek',
                          style: SwanType.caption(
                            kTeal,
                            w: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SwanRing(
                value: 0.84,
                track: line,
                progress: kTeal,
                size: 78,
                stroke: 8,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 20,
                      color: kTeal,
                    ),
                    Text(
                      '%84',
                      style: SwanType.caption(ink, w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildBentoCol(
                  icon: Icons.bedtime_outlined,
                  title: 'Uyku',
                  value: '7s 45dk',
                  badge: '%88 Derin',
                  isHighlighted: false,
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: line,
                ),
                _buildBentoCol(
                  icon: Icons.sports_martial_arts_rounded,
                  title: 'Kas (DOMS)',
                  value: '2 / 10',
                  badge: 'Hafif Omuz',
                  isHighlighted: true,
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: line,
                ),
                _buildBentoCol(
                  icon: Icons.self_improvement_rounded,
                  title: 'Zihinsel Stres',
                  value: 'Düşük',
                  badge: '3 / 10 Seviye',
                  isHighlighted: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCol({
    required IconData icon,
    required String title,
    required String value,
    required String badge,
    required bool isHighlighted,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: kTeal),
          const SizedBox(height: 2),
          Text(title, style: SwanType.caption(SwanColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: SwanType.caption(
              SwanColors.textPrimary,
              w: FontWeight.w700,
            ),
          ),
          Text(
            badge,
            style: SwanType.caption(
              isHighlighted ? const Color(0xFFE65100) : kTeal,
              w: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcwrWorkloadCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    final weeklyVolume = [
      (day: 'Pzt', val: 180, pct: 0.75, isToday: false),
      (day: 'Sal', val: 210, pct: 0.87, isToday: false),
      (day: 'Çar', val: 0, pct: 0.08, isToday: false), // Dinlenme
      (day: 'Per', val: 240, pct: 1.00, isToday: false),
      (day: 'Cum', val: 190, pct: 0.79, isToday: false),
      (day: 'Bugün', val: 220, pct: 0.91, isToday: true),
      (day: 'Paz', val: 0, pct: 0.30, isToday: false),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
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
                  Row(
                    children: [
                      Text('ACWR Yük Dengesi', style: SwanType.h3(ink)),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: SwanColors.textSecondary,
                      ),
                    ],
                  ),
                  Text(
                    'Akut:Kronik İş Yükü Oranı Takibi',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('1.14', style: SwanType.h2(kTeal)),
                      const SizedBox(width: 4),
                      Text('Oran', style: SwanType.caption(SwanColors.textSecondary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Güvenli Bölge (0.8 - 1.3)',
                      style: SwanType.caption(kTeal, w: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 20,
                  color: kTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sakatlık riski düşük. Planlanan antrenman hacim artışı fizyolojik olarak tolere edilebilir aralıkta seyrediyor.',
                    style: SwanType.bodySm(ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haftalık Atış Hacmi (Ok Adedi)',
                style: SwanType.caption(
                  SwanColors.textSecondary,
                  w: FontWeight.w600,
                ),
              ),
              Text(
                'Toplam: 1.040 Ok',
                style: SwanType.caption(kTeal, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyVolume.map((w) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          w.val == 0 ? '-' : '${w.val}',
                          style: SwanType.caption(
                            w.isToday ? kTeal : SwanColors.textSecondary,
                            w: w.isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 70 * w.pct,
                          decoration: BoxDecoration(
                            color: w.isToday
                                ? kTeal
                                : (isDark
                                    ? SwanPalette.dark.surfaceAlt
                                    : const Color(0xFFE5E8EB)),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          w.day,
                          style: SwanType.caption(
                            w.isToday ? kTeal : SwanColors.textSecondary,
                            w: w.isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRpeSection(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
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
                  Text('Algılanan Zorluk (RPE)', style: SwanType.h3(ink)),
                  Text(
                    'Sabah Seansı Antrenman Yoğunluğu',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_currentRpe.round()}',
                      style: SwanType.h2(kTeal),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '/ 10',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kolay (1-3)', style: SwanType.caption(SwanColors.textSecondary)),
              Text(
                'Zorlayıcı & Kontrollü (${_currentRpe.round()})',
                style: SwanType.caption(kTeal, w: FontWeight.w700),
              ),
              Text(
                'Maksimal (10)',
                style: SwanType.caption(SwanColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _currentRpe / 10,
              minHeight: 10,
              backgroundColor: line,
              valueColor: const AlwaysStoppedAnimation(kTeal),
            ),
          ),
          const SizedBox(height: 16),
          // Sporcu Günlüğü Notu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(12),
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
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: kTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sporcu Günlüğü',
                          style: SwanType.caption(ink, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text('11:45', style: SwanType.caption(SwanColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '“Göz kapalı atış drilinde omuz stabilizasyonu iyi hissettirdi, 5. seride sol trapezde hafif çekme oldu.”',
                  style: SwanType.bodySm(ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Fizyoterapist Notu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kTeal.withValues(alpha: 0.2)),
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
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: kTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fizyoterapist Notu',
                          style: SwanType.caption(kTeal, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      'Uzm. Fzt. Arda K.',
                      style: SwanType.caption(kTeal, w: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '“Isınma bandı protokolünü 10 dakikadan 15 dakikaya çıkarın. Akşam seansı öncesi skapular retraksiyon tekrarlansın.”',
                  style: SwanType.bodySm(ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegenerationProtocolCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
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
                  Text('Rejenerasyon Protokolü', style: SwanType.h3(ink)),
                  Text(
                    'Bugünün Koruyucu Sağlık Görevleri',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? SwanPalette.dark.surfaceAlt
                      : const Color(0xFFF1F4F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_completedTasks.length} / ${_tasks.length} Bitti',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: List.generate(_tasks.length, (i) {
              final task = _tasks[i];
              final isDone = _completedTasks.contains(i);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isDone) {
                      _completedTasks.remove(i);
                    } else {
                      _completedTasks.add(i);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDone
                        ? (isDark
                            ? SwanPalette.dark.surfaceAlt
                            : const Color(0xFFF1F4F7))
                        : surf,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDone ? kTeal : line,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : task.icon,
                          color: isDone ? Colors.white : SwanColors.textSecondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: SwanType.bodySm(
                                ink,
                                w: FontWeight.w600,
                              ).copyWith(
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: isDone
                                    ? SwanColors.textSecondary
                                    : ink,
                              ),
                            ),
                            Text(
                              task.duration,
                              style: SwanType.caption(
                                SwanColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isDone ? 'Tamamlandı' : 'Başla',
                        style: SwanType.caption(
                          isDone ? kTeal : SwanColors.textSecondary,
                          w: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showRpeUpdateModal() {
    double tempRpe = _currentRpe;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RPE Seviyesini Belirle', style: SwanType.h2(SwanColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    'Bugünkü idmanın algılanan zorluk derecesini 1 ile 10 arasında kaydet.',
                    style: SwanType.bodySm(SwanColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zorluk Puanı',
                        style: SwanType.body(SwanColors.textPrimary, w: FontWeight.w700),
                      ),
                      Text(
                        '${tempRpe.round()} / 10',
                        style: SwanType.h2(kTeal),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempRpe,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: kTeal,
                    onChanged: (v) => setModalState(() => tempRpe = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _currentRpe = tempRpe);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Bugünün RPE derecesi güncellendi.',
                            ),
                            backgroundColor: kTeal,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Kaydet',
                        style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
