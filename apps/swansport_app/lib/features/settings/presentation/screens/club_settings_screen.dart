import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/push/push.dart';
import '../../../../app/push/push_service.dart';
import '../../../../app/l10n/app_locale.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../clubs/presentation/club_edit_sheet.dart';
import '../../../demo/demo_role.dart';
import '../../../social/presentation/edit_profile_sheet.dart';

/// SwanSport - Ayarlar & Sporcu Tercihleri (Stitch Screen 28).
///
/// Sensörler, antrenman telemetrisi, gizlilik/topluluk, çevrimdışı haritalar,
/// push bildirimleri, kulüp yönetimi ve oturum kontrolü.
class ClubSettingsScreen extends ConsumerStatefulWidget {
  const ClubSettingsScreen({super.key});

  @override
  ConsumerState<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends ConsumerState<ClubSettingsScreen> {
  // Telemetri ve sensör tercihleri (yerel durum)
  bool _gpsLiveShare = true;
  bool _ghostRunner = true;
  bool _isMetric = true;
  int _visibilityIndex = 1; // 0: Herkes, 1: Kulüp Üyeleri, 2: Yalnızca Ben
  bool _hideBiometrics = false;
  bool _polarPaired = false;
  bool _mapDownloaded = false;
  bool _cacheCleared = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF061424) : SwanPalette.light.bg;
    final surf = isDark ? const Color(0xFF132031) : SwanPalette.light.surface;
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFEAEFF8);
    final borderCol = isDark ? const Color(0xFF293547) : SwanPalette.light.line;
    final textPrimary =
        isDark ? const Color(0xFFD6E3FA) : SwanPalette.light.ink;
    final textMuted =
        isDark ? const Color(0xFF869491) : SwanColors.textSecondary;

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final isAdmin = ref.watch(effectiveIsPlatformAdminProvider);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final me =
        uid == null ? null : ref.watch(socialProfileProvider(uid)).valueOrNull;

    final isStaff = profile?.role == 'club_admin' ||
        profile?.role == 'coach' ||
        profile?.role == 'official';

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
                // 1. Üst Başlık Barı
                _buildHeader(context, textPrimary, textMuted, surf),

                const SizedBox(height: 16),

                // 2. Kullanıcı Profil Kartı (Pro Tier Hero)
                _buildProfileHero(
                  context,
                  profile,
                  club,
                  me,
                  uid,
                  surf,
                  surfHigh,
                  borderCol,
                  textPrimary,
                  textMuted,
                ),

                const SizedBox(height: 24),

                // 3. Sensörler & Ekipmanlar
                _buildSectionHeader(
                  icon: Icons.watch_outlined,
                  title: 'SENSÖRLER & EKİPMANLAR',
                  badge: _polarPaired ? '3 Bağlı' : '2 Bağlı',
                  kTeal: kTeal,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                _buildContainer(
                  surf: surf,
                  borderCol: borderCol,
                  children: [
                    _buildDeviceTile(
                      icon: Icons.watch_rounded,
                      iconColor: kTeal,
                      title: 'Apple Watch Ultra 2',
                      subtitle: 'HealthKit Canlı Senkron',
                      isLive: true,
                      statusWidget: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kTeal.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Bağlandı',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kTeal,
                          ),
                        ),
                      ),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                    ),
                    _buildDivider(borderCol),
                    _buildDeviceTile(
                      icon: Icons.speed_rounded,
                      iconColor: textPrimary,
                      title: 'Garmin Connect™',
                      subtitle: 'Forerunner 965 · VO2Max',
                      statusWidget: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: surfHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Senkronize',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC0C6D9),
                          ),
                        ),
                      ),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                    ),
                    _buildDivider(borderCol),
                    _buildDeviceTile(
                      icon: Icons.monitor_heart_rounded,
                      iconColor: const Color(0xFFFF8C6F),
                      title: 'Polar H10 Nabız Bandı',
                      subtitle: _polarPaired
                          ? 'BLE Bağlandı (138 bpm)'
                          : 'Bluetooth BLE Hazır',
                      statusWidget: GestureDetector(
                        onTap: () {
                          setState(() => _polarPaired = !_polarPaired);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _polarPaired
                                    ? 'Polar H10 BLE ile başarıyla eşlendi'
                                    : 'Polar H10 bağlantısı kesildi',
                              ),
                              backgroundColor: _polarPaired
                                  ? kTeal
                                  : SwanColors.textSecondary,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _polarPaired
                                ? kTeal.withValues(alpha: 0.2)
                                : surfHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _polarPaired ? kTeal : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            _polarPaired ? 'Bağlı' : 'Eşle',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _polarPaired ? kTeal : textPrimary,
                            ),
                          ),
                        ),
                      ),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                    ),
                    _buildDivider(borderCol),
                    _buildDeviceTile(
                      icon: Icons.graphic_eq_rounded,
                      iconColor: const Color(0xFF75F7ED),
                      title: 'Spotify & Apple Music',
                      subtitle: 'BPM Tempolu Çalma Listeleri',
                      statusWidget: Icon(
                        Icons.chevron_right_rounded,
                        color: textMuted,
                        size: 20,
                      ),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'SwanSport Audio Sync: Koşu temponuza göre BPM optimize ediliyor.'),
                            backgroundColor: kTeal,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. Antrenman & Telemetri
                _buildSectionHeader(
                  icon: Icons.health_and_safety_rounded,
                  title: 'ANTRENMAN & TELEMETRİ',
                  kTeal: kTeal,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                _buildContainer(
                  surf: surf,
                  borderCol: borderCol,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.share_location_rounded,
                      iconColor: kTeal,
                      title: 'GPS Canlı Konum Paylaşımı',
                      subtitle: 'Antrenör ve acil temaslılara canlı rota',
                      value: _gpsLiveShare,
                      onChanged: (val) => setState(() => _gpsLiveShare = val),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                    ),
                    _buildDivider(borderCol),
                    _buildSwitchTile(
                      icon: Icons.directions_run_rounded,
                      iconColor: const Color(0xFFFF8C6F),
                      title: 'Ghost Runner & Segment Uyarısı',
                      subtitle: 'Kişisel en iyi dereceye karşı sanal rakip',
                      value: _ghostRunner,
                      onChanged: (val) => setState(() => _ghostRunner = val),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                    ),
                    _buildDivider(borderCol),
                    // Ölçü Birimleri (KM / MI)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: surfHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.straighten_rounded,
                                color: textMuted, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ölçü Birimleri',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  _isMetric
                                      ? 'Metrik (km, kg, dk/km)'
                                      : 'İmparatorluk (mil, lbs, pace)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F1C2D)
                                  : SwanPalette.light.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _isMetric = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _isMetric
                                          ? kTeal
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'KM',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _isMetric
                                            ? const Color(0xFF003734)
                                            : textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _isMetric = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: !_isMetric
                                          ? kTeal
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'MI',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: !_isMetric
                                            ? const Color(0xFF003734)
                                            : textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(borderCol),
                    _buildNavTile(
                      icon: Icons.record_voice_over_rounded,
                      iconColor: const Color(0xFF75F7ED),
                      title: 'Sesli Koç / Tur Uyarıları',
                      subtitle: "Her 1.0 km'de tempo ve nabız bilgisi",
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Sesli koç: 1 km aralıklarla sesli uyarı aktif.'),
                            backgroundColor: kTeal,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 5. Gizlilik & Topluluk
                _buildSectionHeader(
                  icon: Icons.security_rounded,
                  title: 'GİZLİLİK & TOPLULUK',
                  kTeal: kTeal,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                _buildContainer(
                  surf: surf,
                  borderCol: borderCol,
                  children: [
                    // Antrenman Görünürlüğü (3-Way Segmented)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: surfHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.visibility_rounded,
                                    color: textPrimary, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Antrenman Görünürlüğü',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Aktivite özetlerini kimler görüntüleyebilir',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F1C2D)
                                  : SwanPalette.light.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _buildVisibilityTab(
                                    0, 'Herkes', isDark, surfHigh),
                                _buildVisibilityTab(
                                    1, 'Kulüp Üyeleri', isDark, surfHigh),
                                _buildVisibilityTab(
                                    2, 'Yalnızca Ben', isDark, surfHigh),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(borderCol),
                    _buildSwitchTile(
                      icon: Icons.favorite_border_rounded,
                      iconColor: const Color(0xFFFF8C6F),
                      title: 'RPE ve Nabız Verilerini Gizle',
                      subtitle: 'Biyometrik efor verileri akışta gizlenir',
                      value: _hideBiometrics,
                      onChanged: (val) => setState(() => _hideBiometrics = val),
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                    ),
                    _buildDivider(borderCol),
                    _buildNavTile(
                      icon: Icons.verified_user_rounded,
                      iconColor: kTeal,
                      title: 'Lisans & Kimlik Doğrulama',
                      subtitle: 'Antrenör ve sporcu federasyon lisansları',
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () => Navigator.pushNamed(context, '/dogrulama'),
                    ),
                    _buildDivider(borderCol),
                    _buildNavTile(
                      icon: Icons.family_restroom_rounded,
                      iconColor: const Color(0xFF75F7ED),
                      title: 'Veli Bağlantısı',
                      subtitle: 'Davet koduyla sporcu ve veli eşleştirme',
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () => Navigator.pushNamed(context, '/veli-bagla'),
                    ),
                    _buildDivider(borderCol),
                    _buildNavTile(
                      icon: Icons.shield_outlined,
                      iconColor: textMuted,
                      title: 'Gizlilik ve Engellenenler',
                      subtitle: 'Engellenen hesaplar ve veri kontrolü',
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () => Navigator.pushNamed(context, '/gizlilik'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 6. Çevrimdışı Harita Paketleri
                _buildSectionHeader(
                  icon: Icons.download_for_offline_rounded,
                  title: 'ÇEVRİMDÜŞI HARİTA PAKETLERİ',
                  kTeal: kTeal,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.terrain_rounded,
                                color: kTeal, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bebek Sahil & Belgrad Ormanı',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Topografik & Isı Haritası · 24 MB',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _mapDownloaded = !_mapDownloaded);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _mapDownloaded
                                        ? 'Bebek & Belgrad çevrimdışı haritası indirildi.'
                                        : 'Çevrimdışı harita paketi silindi.',
                                  ),
                                  backgroundColor: _mapDownloaded
                                      ? kTeal
                                      : SwanColors.textSecondary,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _mapDownloaded
                                    ? kTeal.withValues(alpha: 0.15)
                                    : surfHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _mapDownloaded
                                        ? Icons.check_rounded
                                        : Icons.download_rounded,
                                    size: 14,
                                    color: _mapDownloaded ? kTeal : textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _mapDownloaded ? 'İndi' : 'İndir',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          _mapDownloaded ? kTeal : textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F1C2D)
                              : SwanPalette.light.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kullanılan Çevrimdışı Bellek',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: textMuted,
                                  ),
                                ),
                                Text(
                                  _mapDownloaded
                                      ? '172 MB / 1.2 GB'
                                      : '148 MB / 1.2 GB',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _mapDownloaded ? 0.26 : 0.22,
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? const Color(0xFF293547)
                                    : Colors.black12,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(kTeal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 7. Uygulama & Bildirimler
                _buildSectionHeader(
                  icon: Icons.tune_rounded,
                  title: 'UYGULAMA & BİLDİRİMLER',
                  kTeal: kTeal,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                _buildContainer(
                  surf: surf,
                  borderCol: borderCol,
                  children: [
                    // Gerçek Push Bildirim Toggle'ı
                    const _PushToggleRow(),
                    _buildDivider(borderCol),
                    _buildNavTile(
                      icon: Icons.notifications_active_rounded,
                      iconColor: textPrimary,
                      title: 'Bildirim Yönetimi',
                      subtitle: 'Topluluk reaksiyonları & antrenman çağrıları',
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () => Navigator.pushNamed(context, '/bildirimler'),
                    ),
                    _buildDivider(borderCol),
                    // Görünüm / Tema Seçici
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: surfHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.dark_mode_rounded,
                                    color: kTeal, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Görünüm Teması',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Athletic Kinetic Obsidian & Light',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (final m in ThemeMode.values)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(themeModeProvider.notifier)
                                        .set(m),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: ref.watch(themeModeProvider) == m
                                            ? kTeal.withValues(alpha: 0.15)
                                            : (isDark
                                                ? const Color(0xFF0F1C2D)
                                                : SwanPalette.light.bg),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              ref.watch(themeModeProvider) == m
                                                  ? kTeal
                                                  : Colors.transparent,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          themeModeLabel(m),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                ref.watch(themeModeProvider) ==
                                                        m
                                                    ? kTeal
                                                    : textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(borderCol),
                    // Uygulama Dili / Language
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: surfHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.language_rounded,
                                    color: kTeal, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Uygulama Dili / Language',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Türkçe ve uluslararası çoklu dil altyapısı',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (final lang in AppLanguage.values)
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => ref
                                        .read(appLocaleProvider.notifier)
                                        .setLanguage(lang),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: ref.watch(appLocaleProvider) ==
                                                lang
                                            ? kTeal.withValues(alpha: 0.15)
                                            : (isDark
                                                ? const Color(0xFF0F1C2D)
                                                : SwanPalette.light.bg),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              ref.watch(appLocaleProvider) ==
                                                      lang
                                                  ? kTeal
                                                  : Colors.transparent,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${lang.flag} ${lang.title}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                ref.watch(appLocaleProvider) ==
                                                        lang
                                                    ? kTeal
                                                    : textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildDivider(borderCol),
                    // Önbelleği Temizle
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: surfHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.cleaning_services_rounded,
                                color: textMuted, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Önbelleği Temizle',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  _cacheCleared
                                      ? 'Bellek temizlendi (0 B)'
                                      : 'Aktivite görsel önbelleği (34.8 MB)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _cacheCleared = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Aktivite önbelleği başarıyla temizlendi.'),
                                  backgroundColor: kTeal,
                                ),
                              );
                            },
                            child: Text(
                              'Temizle',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFF8C6F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 8. Kulüp Yönetimi (Staff ise)
                if (isStaff && club != null) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.sports_rounded,
                    title: 'KULÜP YÖNETİMİ',
                    kTeal: kTeal,
                    textMuted: textMuted,
                  ),
                  const SizedBox(height: 8),
                  _buildContainer(
                    surf: surf,
                    borderCol: borderCol,
                    children: [
                      _buildNavTile(
                        icon: Icons.badge_rounded,
                        iconColor: kTeal,
                        title: 'Kulüp Profili',
                        subtitle: 'Logo, kapak, renk ve iletişim bilgileri',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () => showClubEditSheet(context, club.id),
                      ),
                      _buildDivider(borderCol),
                      _buildNavTile(
                        icon: Icons.visibility_rounded,
                        iconColor: textPrimary,
                        title: 'Kulüp Sayfasını Görüntüle',
                        subtitle: club.name,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () => Navigator.pushNamed(
                            context, '/kulup-profil',
                            arguments: club.id),
                      ),
                      _buildDivider(borderCol),
                      _buildNavTile(
                        icon: Icons.tune_rounded,
                        iconColor: const Color(0xFF75F7ED),
                        title: 'Kulüp Yapılandırması',
                        subtitle: 'Kimlik, roller ve sezon planlaması',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () =>
                            Navigator.pushNamed(context, '/configuration'),
                      ),
                      _buildDivider(borderCol),
                      _buildNavTile(
                        icon: Icons.payments_rounded,
                        iconColor: const Color(0xFFFF8C6F),
                        title: 'Aidat & Tahsilat Merkezi',
                        subtitle: 'Mali defter ve ödeme takibi',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () => Navigator.pushNamed(context, '/finans'),
                      ),
                    ],
                  ),
                ],

                // 9. Platform Yönetimi (Admin ise)
                if (isAdmin) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'PLATFORM YÖNETİMİ',
                    kTeal: kTeal,
                    textMuted: textMuted,
                  ),
                  const SizedBox(height: 8),
                  _buildContainer(
                    surf: surf,
                    borderCol: borderCol,
                    children: [
                      _buildNavTile(
                        icon: Icons.verified_user_rounded,
                        iconColor: kTeal,
                        title: 'Onay & Yetki Paneli',
                        subtitle: 'Lisans, evrak ve kulüp incelemeleri',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () =>
                            Navigator.pushNamed(context, '/onay-paneli'),
                      ),
                      _buildDivider(borderCol),
                      _buildNavTile(
                        icon: Icons.rss_feed_rounded,
                        iconColor: const Color(0xFF75F7ED),
                        title: 'Haber Kaynakları',
                        subtitle: 'RSS ve spor bülteni entegrasyonu',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () =>
                            Navigator.pushNamed(context, '/haber-kaynaklari'),
                      ),
                    ],
                  ),
                ],

                // 10. Yardım & Destek
                const SizedBox(height: 24),
                _buildSectionHeader(
                  icon: Icons.help_outline_rounded,
                  title: 'YARDIM & DESTEK',
                  kTeal: kTeal,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                _buildContainer(
                  surf: surf,
                  borderCol: borderCol,
                  children: [
                    _buildNavTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: kTeal,
                      title: 'Sıkça Sorulan Sorular',
                      subtitle: 'Aidat, bildirim, kort, lisans ve gizlilik',
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () => Navigator.pushNamed(context, '/yardim'),
                    ),
                    _buildDivider(borderCol),
                    _buildNavTile(
                      icon: Icons.support_agent_rounded,
                      iconColor: const Color(0xFF75F7ED),
                      title: 'Destek Talebi Oluştur',
                      subtitle: 'Ekibimiz 7/24 yanınızda',
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfHigh: surfHigh,
                      onTap: () => Navigator.pushNamed(context, '/destek'),
                    ),
                    if (ref.watch(debugToolsEnabledProvider)) ...[
                      _buildDivider(borderCol),
                      _buildNavTile(
                        icon: Icons.theater_comedy_outlined,
                        iconColor: const Color(0xFFFF8C6F),
                        title: 'Demo Rolleri Değiştir',
                        subtitle: 'Geliştirme ve deneme rolleri',
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfHigh: surfHigh,
                        onTap: () => Navigator.pushNamed(context, '/demo-rol'),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 28),

                // 11. Çıkış Yap Butonu
                GestureDetector(
                  onTap: _signOut,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SwanPalette.light.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: SwanPalette.light.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hesaptan Çıkış Yap',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: SwanPalette.light.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 12. Build & Engine Bilgisi
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: kTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SwanSport Athletic Engine',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v2.4.0 (Build 2024.11.08) · Istanbul High-Performance Lab',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color textPrimary,
    Color textMuted,
    Color surf,
  ) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: surf,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ayarlar',
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Sporcu Profili & Sistem',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/yardim'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: surf,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child:
                Icon(Icons.help_outline_rounded, color: textPrimary, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    ProfileInfo? profile,
    ClubRef? club,
    SocialProfile? me,
    String? uid,
    Color surf,
    Color surfHigh,
    Color borderCol,
    Color textPrimary,
    Color textMuted,
  ) {
    final initials = profile?.initials ??
        (me != null && me.name.isNotEmpty ? me.name[0].toUpperCase() : 'EY');
    final fullName = profile?.fullName ?? me?.name ?? 'Emir Yılmaz';
    final username = me?.username ?? 'emirlmz';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: me == null
          ? (uid == null
              ? null
              : () => Navigator.pushNamed(context, '/profil', arguments: uid))
          : () async {
              final saved = await showEditProfileSheet(context, me);
              if (saved == true && uid != null) {
                ref.invalidate(socialProfileProvider(uid));
                ref.invalidate(currentProfileProvider);
              }
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GradientAvatar(
                  initials: initials,
                  size: 60,
                  radius: 30,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: kTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF003734),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: GoogleFonts.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@$username · 84.2 kg · 1.84m',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 12, color: kTeal),
                        const SizedBox(width: 4),
                        Text(
                          'SwanPro Aktif',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: kTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: surfHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: textMuted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? badge,
    required Color kTeal,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: kTeal),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: kTeal,
                ),
              ),
            ],
          ),
          if (badge != null)
            Text(
              badge,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContainer({
    required Color surf,
    required Color borderCol,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(Color borderCol) {
    return Container(
      height: 1,
      width: double.infinity,
      color: borderCol.withValues(alpha: 0.5),
    );
  }

  Widget _buildDeviceTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isLive = false,
    required Widget statusWidget,
    required Color textPrimary,
    required Color textMuted,
    required Color surfHigh,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: surfHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isLive) ...[
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: kTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isLive ? kTeal : textMuted,
                            fontWeight:
                                isLive ? FontWeight.w600 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            statusWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
    required Color textMuted,
    required Color surfHigh,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: surfHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: kTeal,
            activeThumbColor: const Color(0xFF003734),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textMuted,
    required Color surfHigh,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surfHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityTab(
      int index, String label, bool isDark, Color surfHigh) {
    final isSelected = _visibilityIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibilityIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? surfHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? kTeal
                    : (isDark
                        ? const Color(0xFF869491)
                        : SwanColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text(
          'Oturumun kapatılacak. Tekrar giriş yapman gerekecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      await Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }
}

/// Gerçek push anahtarı — tarayıcı aboneliğini ve veritabanı kaydını yönetir.
class _PushToggleRow extends ConsumerWidget {
  const _PushToggleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? const Color(0xFFD6E3FA) : SwanPalette.light.ink;
    final textMuted =
        isDark ? const Color(0xFF869491) : SwanColors.textSecondary;
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFEAEFF8);
    final on = ref.watch(pushEnabledProvider).valueOrNull ?? false;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: surfHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_rounded,
              size: 20,
              color: kTeal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telefon Bildirimleri',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  on
                      ? 'Uygulama kapalıyken de anlık bildirim'
                      : 'Mesaj ve antrenman çağrıları telefonuna düşsün',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: kTeal,
            activeThumbColor: const Color(0xFF003734),
            onChanged: !pushSupported
                ? null
                : (v) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      if (v) {
                        await enablePush(ref);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Bildirimler açıldı'),
                            backgroundColor: kTeal,
                          ),
                        );
                      } else {
                        await disablePush(ref);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Bildirimler kapatıldı'),
                            backgroundColor: SwanColors.textSecondary,
                          ),
                        );
                      }
                    } on PushException catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            switch (e.reason) {
                              PushFailure.denied =>
                                'Bildirim izni reddedilmiş. Tarayıcı ayarlarından izin ver.',
                              PushFailure.unsupported =>
                                'Bu tarayıcı bildirim desteklemiyor.',
                              PushFailure.failed => 'Açılamadı, tekrar dene.',
                            },
                          ),
                          backgroundColor: SwanPalette.light.danger,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
