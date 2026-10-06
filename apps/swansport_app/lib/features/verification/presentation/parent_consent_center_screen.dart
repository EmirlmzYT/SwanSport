import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Veli İzin Merkezi ve KVKK Rıza Yönetimi ekranı.
///
/// Stitch `veli_i_zin_merkezi_ve_kvkk_r_za_y_netimi` tasarımı:
/// - E-Devlet muvafakat senkronizasyonu ve KVKK Seviye-3 rozeti
/// - Veli - Sporcu yasal temsil ve eşleşme kartı
/// - 4 adet kulüp faaliyet izni (Turnuva/kamp seyahati, Medya, Doping/sağlık, Servis/ulaşım)
/// - KVKK veri işleme tercihleri (Biyometrik SwanBand, Burs/sponsor, Mali maskeleme sistem kilidi)
/// - Dijital imza ve BTK onaylı mobil muvafakat günlüğü
class ParentConsentCenterScreen extends ConsumerStatefulWidget {
  const ParentConsentCenterScreen({super.key});

  @override
  ConsumerState<ParentConsentCenterScreen> createState() =>
      _ParentConsentCenterScreenState();
}

class _ParentConsentCenterScreenState
    extends ConsumerState<ParentConsentCenterScreen> {
  bool _travelConsent = true;
  bool _mediaConsent = true;
  bool _transportConsent = true;
  bool _biometricConsent = true;
  bool _sponsorConsent = false;

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
                _buildStatusFeedbackBanner(surf, line, ink),
                const SizedBox(height: 16),
                _buildLegalRepresentationCard(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildClubActivityPermissions(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildKvkkDataPreferences(isDark, surf, line, ink),
                const SizedBox(height: 16),
                _buildDigitalSignatureLog(isDark, surf, line, ink),
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
                  'SwanSport Güvenlik',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
                Text('Veli İzin & KVKK', style: SwanType.h2(ink)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 20,
                color: kTeal,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusFeedbackBanner(Color surf, Color line, Color ink) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
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
                  color: kTeal.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 18,
                  color: kTeal,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E-Devlet Muvafakat Senkronize',
                    style: SwanType.bodySm(ink, w: FontWeight.w700),
                  ),
                  Text(
                    'Tüm veli izin protokolleri 2025 sezonu için aktiftir',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'KVKK Seviye-3',
              style: SwanType.caption(kTeal, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalRepresentationCard(
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
                  const Icon(
                    Icons.family_restroom_rounded,
                    size: 20,
                    color: kTeal,
                  ),
                  const SizedBox(width: 8),
                  Text('Yasal Temsil & Eşleşme', style: SwanType.h3(ink)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Aktif Temsil',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Veli Profil Bloğu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF575E70),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'AY',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ayşe Yılmaz',
                              style: SwanType.bodySm(ink, w: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: kTeal,
                            ),
                          ],
                        ),
                        Text(
                          'Anne / Yasal Vasi • T.C. Kimlik Doğrulandı',
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
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
                    'E-Devlet Mühürlü',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          // Connector Pill
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sync_alt_rounded, size: 14, color: kTeal),
                  const SizedBox(width: 4),
                  Text(
                    '1. Derece Yasal Eşleşme',
                    style: SwanType.caption(kTeal, w: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // Sporcu Profil Bloğu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanPalette.dark.surfaceAlt
                  : const Color(0xFFF1F4F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'ZY',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Zeynep Yılmaz',
                              style: SwanType.bodySm(ink, w: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: kTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'U18 Lisanslı',
                                style: SwanType.caption(
                                  kTeal,
                                  w: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '17 Yaş • D. Tarihi: 12.08.2008 • Lisans: #TR-99401',
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: kTeal,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Veli Denetimli',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
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

  Widget _buildClubActivityPermissions(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kulüp Faaliyet İzinleri', style: SwanType.h3(ink)),
                  Text(
                    '2024-2025 Sezonu resmi müsabaka ve idari onayları',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Text(
                '4 / 4 İzinli',
                style: SwanType.caption(kTeal, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 1. Seyahat İzni
          _buildPermissionTile(
            icon: Icons.flight_takeoff_rounded,
            title: 'Şehir Dışı Turnuva ve Kamp Seyahat İzni',
            description:
                '2025 Antalya Bahar Kupası ve yaz hazırlık kampı seyahat muvafakatnamesi',
            value: _travelConsent,
            onChanged: (v) => setState(() => _travelConsent = v),
            pdfName: 'Muvafakat_Antalya_2025.pdf (E-İmzalı)',
            isDark: isDark,
            surf: surf,
            ink: ink,
          ),
          const SizedBox(height: 10),
          // 2. Medya İzni
          _buildPermissionTile(
            icon: Icons.photo_camera_rounded,
            title: 'Fotoğraf, Video ve Medya Paylaşım İzni',
            description:
                'Kulüp bülteni, sosyal kanallar ve antrenman teknik video analizi için onay',
            value: _mediaConsent,
            onChanged: (v) => setState(() => _mediaConsent = v),
            isDark: isDark,
            surf: surf,
            ink: ink,
          ),
          const SizedBox(height: 10),
          // 3. Doping & Sağlık İzni (Zorunlu)
          Container(
            padding: const EdgeInsets.all(12),
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
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: kTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            size: 18,
                            color: kTeal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doping Kontrolü ve Sağlık Kurulu İzni',
                              style: SwanType.bodySm(ink, w: FontWeight.w700),
                            ),
                            Text(
                              'Türkiye Dopingle Mücadele Komisyonu & Kulüp Hekimi',
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
                        'Yasal Zorunlu',
                        style: SwanType.caption(kTeal, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kulüp Sağlık Heyeti Raporu: Tam Uygun (#SGK-092)',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                    Text(
                      'Onaylı',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 4. Servis & Ulaşım İzni
          _buildPermissionTile(
            icon: Icons.airport_shuttle_rounded,
            title: 'Sporcu Servis ve Ulaşım İzni',
            description:
                'Maslak Tesisler - Levent güzergahı lisanslı kulüp servis aracı kullanımı',
            value: _transportConsent,
            onChanged: (v) => setState(() => _transportConsent = v),
            isDark: isDark,
            surf: surf,
            ink: ink,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? pdfName,
    required bool isDark,
    required Color surf,
    required Color ink,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: kTeal),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: kTeal,
              ),
            ],
          ),
          if (pdfName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.description_rounded,
                        size: 16,
                        color: kTeal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pdfName,
                        style: SwanType.caption(ink, w: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    'Belgeyi Gör',
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKvkkDataPreferences(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KVKK & Veri Güvenliği', style: SwanType.h3(ink)),
                  Text(
                    '6698 sayılı Kanun kapsamındaki veli tercihleri',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              const Icon(Icons.policy_rounded, size: 20, color: kTeal),
            ],
          ),
          const SizedBox(height: 14),
          // 1. Biyometrik SwanBand
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_outline_rounded,
                      size: 20,
                      color: kTeal,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Biyometrik Veri İşleme (SwanBand)',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          Text(
                            'Kalp ritmi, telemetri, laktat ve yorgunluk indeks takibi',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _biometricConsent,
                onChanged: (v) => setState(() => _biometricConsent = v),
                activeThumbColor: kTeal,
              ),
            ],
          ),
          const Divider(height: 20),
          // 2. Sponsor ve Burs Veri Paylaşımı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.corporate_fare_rounded,
                      size: 20,
                      color: SwanColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sponsor ve Burs Sağlayıcılarla Veri Paylaşımı',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          Text(
                            'Potansiyel sporcu bursu ve kurumsal sponsorluk eşleşmeleri',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _sponsorConsent,
                onChanged: (v) => setState(() => _sponsorConsent = v),
                activeThumbColor: kTeal,
              ),
            ],
          ),
          const Divider(height: 20),
          // 3. Mali Bilgi Maskeleme (Sistem Kilidi)
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
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, size: 20, color: kTeal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mali Bilgi Maskeleme (KVKK Seviye-3)',
                              style: SwanType.bodySm(ink, w: FontWeight.w700),
                            ),
                            Text(
                              'Aidat, burs ve banka verileri antrenör ve idari personelden gizlenir.',
                              style: SwanType.caption(SwanColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sistem Kilidi',
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalSignatureLog(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(20),
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
                    Icons.history_edu_rounded,
                    size: 16,
                    color: kTeal,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Son Geçerli Dijital Muvafakat',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Text(
                'TS-88491-TR',
                style: SwanType.caption(ink, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '15 Şubat 2025 • 14:32',
                style: SwanType.bodySm(ink, w: FontWeight.w700),
              ),
              Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 16, color: kTeal),
                  const SizedBox(width: 4),
                  Text(
                    'Mobil İmza (BTK Onaylı)',
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Muvafakat metni 5070 sayılı Elektronik İmza Kanunu uyarınca ıslak imza ile eşdeğer hukuki geçerliliğe sahiptir.',
            style: SwanType.caption(SwanColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
