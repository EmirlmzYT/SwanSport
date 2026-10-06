import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Ekipman Ayar ve Tuning Günlüğü ekranı.
///
/// Stitch `ekipman_ayar_ve_tuning_g_nl` tasarımı:
/// - Aktif yarışma yay kurulumu ve seri numarası mühürü
/// - 4'lü teknik parametre matrisi (Kiriş yüksekliği, Tiller, Çekiş gücü, Nock noktası)
/// - Easton X10 ok & SpinWing balistik şematik görseli ve F.O.C. dengesi
/// - Dinamik kağıt testi (Bullet hole) ve 30m çıplak ok (Bare shaft) buton analizi
/// - Ayar değişiklik denetim günlüğü (Audit log timeline)
class EquipmentTuningScreen extends ConsumerStatefulWidget {
  const EquipmentTuningScreen({super.key});

  @override
  ConsumerState<EquipmentTuningScreen> createState() =>
      _EquipmentTuningScreenState();
}

class _EquipmentTuningScreenState extends ConsumerState<EquipmentTuningScreen> {
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
                _buildHeader(context, ink, surf, line),
                const SizedBox(height: 16),
                _buildPrimaryBowCard(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildArrowBallisticsCard(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildDynamicTuningCard(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildAuditLogCard(isDark, surf, line, ink),
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
                Icons.tune_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color ink,
    Color surf,
    Color line,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: kTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Marmara Okçuluk Kulübü',
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Zeynep Yılmaz',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.h2(ink),
              ),
              Text(
                'Olimpik Klasik Yay • Kadınlar A Takımı',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.caption(SwanColors.textSecondary),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Barkod tarayıcı hazır.'),
                    backgroundColor: kTeal,
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, color: kTeal),
              style: IconButton.styleFrom(
                backgroundColor: surf,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: line),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showNewSetupDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Yeni Kurulum'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                textStyle: SwanType.caption(
                  Colors.white,
                  w: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryBowCard(
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
            blurRadius: 12,
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
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: kTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Aktif Yarışma Kurulumu (Mühürlü)',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Text(
                'Seri: #HYT-24-8902',
                style: SwanType.caption(SwanColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hoyt Formula Xi 2024', style: SwanType.h2(ink)),
                  const SizedBox(height: 2),
                  Text(
                    'Kollar: Hoyt Velos 68" / 42 lbs Karbon-Köpük',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? SwanPalette.dark.surfaceAlt
                      : const Color(0xFFF1F4F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: kTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 4'lü Bento Matrix
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildParamTile(
                icon: Icons.height_rounded,
                label: 'Kiriş Yüksekliği',
                val: '22.8',
                unit: 'cm',
                subtext: 'İdeal Aralık (22.5 - 23.0)',
                isPositive: true,
                isDark: isDark,
              ),
              _buildParamTile(
                icon: Icons.balance_rounded,
                label: 'Tiller Farkı (Split)',
                val: '+4',
                unit: 'mm',
                subtext: 'Üst: 18.2 / Alt: 17.8 cm',
                isPositive: false,
                isDark: isDark,
              ),
              _buildParamTile(
                icon: Icons.fitness_center_rounded,
                label: 'Çekiş Gücü (Peak)',
                val: '41.6',
                unit: 'lbs',
                subtext: '@ 27.5" Gerçek Çekiş',
                isPositive: false,
                isDark: isDark,
              ),
              _buildParamTile(
                icon: Icons.straighten_rounded,
                label: 'Nocking Point',
                val: '+6',
                unit: 'mm',
                subtext: 'Kare Cetvel Kalibre',
                isPositive: true,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamTile({
    required IconData icon,
    required String label,
    required String val,
    required String unit,
    required String subtext,
    required bool isPositive,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: SwanType.caption(SwanColors.textSecondary)),
              Icon(icon, size: 16, color: kTeal),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(val, style: SwanType.h2(SwanColors.textPrimary)),
              const SizedBox(width: 3),
              Text(unit, style: SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.caption(
              isPositive ? kTeal : SwanColors.textSecondary,
              w: isPositive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowBallisticsCard(
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: kTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ok & Balistik Uyumluluk', style: SwanType.h3(ink)),
                      Text(
                        '12 Adet Numaralandırılmış Şaft Seti',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? SwanPalette.dark.surfaceAlt
                      : const Color(0xFFE5E8EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Spine 500',
                  style: SwanType.caption(ink, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Easton X10 Carbon/Alu',
                      style: SwanType.bodySm(ink, w: FontWeight.w700),
                    ),
                    Text(
                      'C4 Seviye Tolerans',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Arrow Graphic Representation
                SizedBox(
                  height: 24,
                  child: CustomPaint(
                    size: const Size(double.infinity, 24),
                    painter: _ArrowSchematicPainter(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Uç Ağırlığı',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                          Text(
                            '110 Gr Tungsten',
                            style: SwanType.caption(ink, w: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kanat',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                          Text(
                            'SpinWing 1.75"',
                            style: SwanType.caption(ink, w: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'F.O.C. Dengesi',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                          Text(
                            '%14.2 (Optimal)',
                            style: SwanType.caption(kTeal, w: FontWeight.w700),
                          ),
                        ],
                      ),
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

  Widget _buildDynamicTuningCard(
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      size: 18,
                      color: kTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dinamik Tuning Testleri', style: SwanType.h3(ink)),
                      Text(
                        '18m Salon & 30m Açık Saha Verileri',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Kağıt: Kusursuz',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Bullet Hole card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_tilt_shift_rounded,
                        size: 20,
                        color: kTeal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kağıt Testi (Paper Tear)',
                          style: SwanType.bodySm(ink, w: FontWeight.w700),
                        ),
                        Text(
                          '5 Metre Mesafe Çıkış Açısı',
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: kTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bullet Hole',
                          style: SwanType.caption(kTeal, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      'Sıfır yırtılma açısı',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 30m Bare Shaft card
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
                        const Icon(
                          Icons.adjust_rounded,
                          size: 18,
                          color: kTeal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '30m Çıplak Ok (Bare Shaft)',
                          style: SwanType.bodySm(ink, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    Text(
                      'Tolerans: ±2.0 cm',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Grup merkezinin 1.5 cm soluna toplanma saptandı. Yay dinamik olarak hafif sert reaksiyon veriyor.',
                  style: SwanType.bodySm(ink),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Beiter Buton Sertlik Ayarı',
                            style: SwanType.caption(
                              SwanColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Pozisyon: 6.5 / 10 (+1/4 klik gevşetildi)',
                            style: SwanType.caption(ink, w: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 0.65,
                          minHeight: 6,
                          backgroundColor: Color(0xFFE5E8EB),
                          valueColor: AlwaysStoppedAnimation(kTeal),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard(
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      size: 18,
                      color: kTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Ayar Değişiklik Günlüğü', style: SwanType.h3(ink)),
                ],
              ),
              Text(
                'Son 30 Gün',
                style: SwanType.caption(SwanColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAuditEntry(
            date: '12 Nisan 2025 • 16:40',
            badge: 'Antrenör Müdahalesi',
            description:
                'Başantrenör Ahmet Kaya tarafından kiriş büküm sayısı +2 tur artırıldı.',
            details:
                'Kiriş yüksekliği (Brace height) 22.6 cm\'den 22.8 cm\'ye kalibre edildi. Çıkış sesi optimize edildi.',
            ink: ink,
          ),
          const SizedBox(height: 14),
          _buildAuditEntry(
            date: '04 Nisan 2025 • 11:15',
            badge: 'Tuning Güncellemesi',
            description:
                'Beiter buton sertlik yayı 0.7mm yay ile değiştirildi.',
            details:
                '30m çıplak ok grubu 1.5cm sol sapma toleransına çekildi.',
            ink: ink,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEntry({
    required String date,
    required String badge,
    required String description,
    required String details,
    required Color ink,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: kTeal,
            shape: BoxShape.circle,
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
                  Text(
                    date,
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E8EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: SwanType.caption(
                        SwanColors.textSecondary,
                        w: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: SwanType.bodySm(ink, w: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                details,
                style: SwanType.caption(SwanColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNewSetupDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Kurulum Kaydı', style: SwanType.h3(SwanColors.textPrimary)),
        content: Text(
          'Mevcut yay kurulum parametreleri kopyalanarak yeni bir antrenman veya yarışma profili oluşturulsun mu?',
          style: SwanType.bodySm(SwanColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Yeni kurulum taslağı oluşturuldu.'),
                  backgroundColor: kTeal,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }
}

/// Ok ve balistik şemasını çizen CustomPainter
class _ArrowSchematicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    // 1. Tip (Tungsten point)
    final tipPath = Path()
      ..moveTo(0, centerY)
      ..lineTo(14, centerY - 4)
      ..lineTo(14, centerY + 4)
      ..close();

    final tipPaint = Paint()
      ..color = kTeal
      ..style = PaintingStyle.fill;
    canvas.drawPath(tipPath, tipPaint);

    // 2. Shaft (Easton X10 Carbon/Alu)
    final shaftPaint = Paint()
      ..color = const Color(0xFF6D797A)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final shaftEndX = size.width - 24;
    canvas.drawLine(
      Offset(14, centerY),
      Offset(shaftEndX, centerY),
      shaftPaint,
    );

    // 3. FOC Mark
    final focX = size.width * 0.42;
    final focPaint = Paint()
      ..color = const Color(0xFF00818A)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(focX, centerY - 8),
      Offset(focX, centerY + 8),
      focPaint,
    );

    // 4. SpinWing Vanes
    final vaneStart = shaftEndX - 30;
    final vanePath = Path()
      ..moveTo(vaneStart, centerY - 2)
      ..quadraticBezierTo(
        vaneStart + 15,
        centerY - 8,
        shaftEndX,
        centerY - 4,
      )
      ..lineTo(shaftEndX, centerY + 4)
      ..quadraticBezierTo(
        vaneStart + 15,
        centerY + 8,
        vaneStart,
        centerY + 2,
      )
      ..close();

    final vanePaint = Paint()
      ..color = const Color(0xFF6ED6DF).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(vanePath, vanePaint);

    // 5. Nock
    final nockPaint = Paint()
      ..color = const Color(0xFF004F54)
      ..strokeWidth = 4.0;

    canvas.drawLine(
      Offset(shaftEndX, centerY),
      Offset(size.width, centerY),
      nockPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
