import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';

/// Lisans & Kimlik Doğrulama — Stitch Calm Athletic Modernism.
///
/// Kulüp lisans analitik paneli, öncelikli inceleme kuyruğu ve kişisel başvuru.
class CredentialScreen extends ConsumerStatefulWidget {
  const CredentialScreen({super.key});

  @override
  ConsumerState<CredentialScreen> createState() => _CredentialScreenState();
}

class _CredentialScreenState extends ConsumerState<CredentialScreen> {
  int _mainTab = 0; // 0: Kulüp & Takım Lisansları, 1: Kişisel Belge Başvurusu
  int _rosterFilter =
      0; // 0: Tümü, 1: Onay Bekleyen, 2: Onaylanan, 3: Eksik Evrak
  bool _semihApproved = false;

  // Kişisel başvuru durumu
  int _mode = 0; // 0 antrenör, 1 sporcu
  int _kademe = 2;
  String? _sportCode;
  bool _busy = false;

  final Map<String, ({String fileName, String storagePath})> _docs = {};
  final Set<String> _uploading = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF061424) : SwanPalette.light.bg;
    final surf = isDark ? const Color(0xFF132031) : SwanPalette.light.surface;
    final surfContainer =
        isDark ? const Color(0xFF0F1C2D) : const Color(0xFFF1F5F9);
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFE2E8F0);
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = isDark ? const Color(0xFF293547) : SwanPalette.light.line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final async = ref.watch(myCredentialsProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Top Header (Stitch Screen 27)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line),
                        ),
                        child: Icon(Icons.close_rounded, size: 20, color: ink),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Lisans & Kimlik Doğrulama',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kTeal.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.person_rounded,
                          size: 19, color: Color(0xFF003734)),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Main Section Selector (Takım Lisansları / Kişisel Başvuru)
                SwanSegmentedTabs(
                  labels: const ['Takım Lisans Yönetimi', 'Kişisel Başvuru'],
                  selected: _mainTab,
                  onSelect: (i) => setState(() => _mainTab = i),
                ),

                const SizedBox(height: 16),

                if (_mainTab == 0) ...[
                  // 1. Genel Doğrulama Analitik Paneli (Stitch Screen 27)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: line),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded,
                                    size: 18, color: kTeal),
                                const SizedBox(width: 8),
                                Text(
                                  'Kulüp Lisans Durumu',
                                  style: GoogleFonts.sora(
                                    color: ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kTeal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '2024-25 SEZONU',
                                style: GoogleFonts.plusJakartaSans(
                                  color: kTeal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Progress ring card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 54,
                                height: 54,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: 0.90,
                                      strokeWidth: 4.5,
                                      backgroundColor: surfHigh,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              kTeal),
                                    ),
                                    Text(
                                      '%90',
                                      style: GoogleFonts.sora(
                                        color: ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '58 / 64 Sporcu Lisanslı',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: ink,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Resmi TFF ve Sağlık Kurulu Kayıtlı',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: SwanColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Quick metric breakdown
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfHigh.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF8C6F)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.pending_actions_rounded,
                                          size: 18,
                                          color: Color(0xFFFF8C6F)),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '4',
                                          style: GoogleFonts.sora(
                                            color: const Color(0xFFFF8C6F),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          'Onay Bekleyen',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: SwanColors.textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfHigh.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.warning_rounded,
                                          size: 18, color: Colors.redAccent),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '2',
                                          style: GoogleFonts.sora(
                                            color: Colors.redAccent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          'Eksik / Hatalı',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: SwanColors.textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Segmented filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterPill('Tümü (64)', 0, _rosterFilter,
                                  (i) => setState(() => _rosterFilter = i)),
                              _filterPill(
                                  'Onay Bekleyenler (4)',
                                  1,
                                  _rosterFilter,
                                  (i) => setState(() => _rosterFilter = i)),
                              _filterPill('Onaylananlar (58)', 2, _rosterFilter,
                                  (i) => setState(() => _rosterFilter = i)),
                              _filterPill('Eksik Evrak (2)', 3, _rosterFilter,
                                  (i) => setState(() => _rosterFilter = i)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Öncelikli Doğrulama İncelemesi (Stitch Screen 27)
                  Container(
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
                                const SizedBox(width: 8),
                                Text(
                                  'Öncelikli Doğrulama İncelemesi',
                                  style: GoogleFonts.sora(
                                    color: ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'KUYRUKTA: 1 / 4',
                              style: GoogleFonts.plusJakartaSans(
                                color: kTeal,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surfContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Semih Kılıçsoy',
                                              style: GoogleFonts.sora(
                                                color: ink,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text('#9',
                                                style: GoogleFonts.sora(
                                                    color: kTeal,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                          ],
                                        ),
                                        Text(
                                          '2006 Doğumlu • U18 Forvet',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: SwanColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF8C6F)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Evraklar Tam',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFFF8C6F),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: surfHigh.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Lisans Tipi:',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: SwanColors.textSecondary,
                                                fontSize: 11)),
                                        Text('TFF Amatör Vize (2024-25)',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: ink,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Yüklenen Dosyalar:',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: SwanColors.textSecondary,
                                                fontSize: 11)),
                                        Text('3 Belge Doğrulandı',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: kTeal,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                children: [
                                  _docBadge(Icons.badge_rounded,
                                      'T.C. Kimlik (Ön/Arka)'),
                                  _docBadge(Icons.medical_services_rounded,
                                      'Sağlık Raporu'),
                                  _docBadge(
                                      Icons.draw_rounded, 'Noter Veli İzni'),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Action Buttons
                        GestureDetector(
                          onTap: () {
                            setState(() => _semihApproved = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Semih Kılıçsoy lisansı onaylandı ve TFF portalına iletildi!'),
                                backgroundColor: kTeal,
                              ),
                            );
                          },
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [kTealBright, kTeal]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: kTeal.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_rounded,
                                    size: 16, color: Color(0xFF003734)),
                                const SizedBox(width: 8),
                                Text(
                                  _semihApproved
                                      ? 'ONAYLANDI & İLETİLDİ'
                                      : 'ONAYLA & TFF PORTALINA İLET',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF003734),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Taranmış evraklar açılıyor...'),
                                    backgroundColor: kTeal,
                                  ),
                                ),
                                child: Container(
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: surfHigh,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.visibility_rounded,
                                          size: 15, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Dosyaları İncele',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Eksik belge bildirimi sporcuya iletildi.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                ),
                                child: Container(
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cancel_rounded,
                                          size: 15, color: Colors.redAccent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Düzeltme İste',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.redAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Takım Lisans Listesi (Stitch Screen 27)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Takım Lisans Listesi',
                        style: GoogleFonts.sora(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Son Senkron: 10 Dk Önce',
                        style: GoogleFonts.plusJakartaSans(
                          color: SwanColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Kerem Aktürkoğlu
                  _athleteLicenseCard(
                    name: 'Kerem Aktürkoğlu',
                    number: '#7',
                    role: 'TFF Lisansı Aktif • TFF-340912',
                    status: 'Doğrulandı',
                    statusColor: kTeal,
                    statusIcon: Icons.check_circle_rounded,
                    footerLeft: 'Geçerlilik: Haziran 2025',
                    footerRight: 'E-Devlet Onaylı',
                    avatarUrl:
                        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
                    surf: surf,
                    surfContainer: surfContainer,
                    ink: ink,
                  ),
                  const SizedBox(height: 8),

                  // Arda Güler
                  _athleteLicenseCard(
                    name: 'Arda Güler',
                    number: '#10',
                    role: 'Pasaport & FIFA Transfer Kartı',
                    status: 'Onaylandı',
                    statusColor: kTeal,
                    statusIcon: Icons.verified_rounded,
                    footerLeft: 'Geçerlilik: Ağustos 2026',
                    footerRight: 'TMS Portalı Eşleşti',
                    avatarUrl:
                        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                    surf: surf,
                    surfContainer: surfContainer,
                    ink: ink,
                  ),
                  const SizedBox(height: 8),

                  // Barış Alper Yılmaz (Eksik Evrak)
                  _athleteLicenseCard(
                    name: 'Barış Alper Yılmaz',
                    number: '#53',
                    role: 'Veli Muvafakatnamesi Eksik',
                    status: 'Eksik Belge',
                    statusColor: Colors.redAccent,
                    statusIcon: Icons.error_rounded,
                    footerLeft: 'Son Gün: 3 Gün Kaldı',
                    actionLabel: 'Veliye SMS Gönder',
                    onAction: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Veliye SMS hatırlatma bağlantısı gönderildi!'),
                        backgroundColor: kTeal,
                      ),
                    ),
                    avatarUrl:
                        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
                    surf: surf,
                    surfContainer: surfContainer,
                    ink: ink,
                  ),
                  const SizedBox(height: 8),

                  // Merih Demiral (Sağlık Raporu Bekleniyor)
                  _athleteLicenseCard(
                    name: 'Merih Demiral',
                    number: '#4',
                    role: 'Yıllık EKG & Efor Testi',
                    status: 'Rapor Bekleniyor',
                    statusColor: const Color(0xFFFF8C6F),
                    statusIcon: Icons.hourglass_top_rounded,
                    footerLeft: 'Randevu: Acıbadem Hastanesi',
                    actionLabel: 'Hatırlatma İlet',
                    onAction: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sporcuya bildirim iletildi.'),
                        backgroundColor: kTeal,
                      ),
                    ),
                    avatarUrl:
                        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150',
                    surf: surf,
                    surfContainer: surfContainer,
                    ink: ink,
                  ),

                  const SizedBox(height: 16),

                  // 4. Dijital Belge Tarama & OCR Alanı (Stitch Screen 27)
                  Container(
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
                          children: [
                            const Icon(Icons.document_scanner_rounded,
                                size: 18, color: kTeal),
                            const SizedBox(width: 8),
                            Text(
                              'Hızlı Tarama ve Dijital İmza',
                              style: GoogleFonts.sora(
                                color: ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ocrActionCard(
                          icon: Icons.photo_camera_rounded,
                          title: 'Kimlik / Lisans Tara (OCR)',
                          subtitle:
                              'Kamera veya galeriden otomatik veri ayıklama',
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('OCR Kamera Tarayıcı başlatılıyor...'),
                              backgroundColor: kTeal,
                            ),
                          ),
                          surfContainer: surfContainer,
                          ink: ink,
                        ),
                        const SizedBox(height: 8),
                        _ocrActionCard(
                          icon: Icons.forward_to_inbox_rounded,
                          title: 'Veli Dijital İmzası Gönder',
                          subtitle:
                              'SMS ve e-posta üzerinden yasal onay linki ilet',
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dijital onay daveti hazırlandı.'),
                              backgroundColor: kTeal,
                            ),
                          ),
                          surfContainer: surfContainer,
                          ink: ink,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Sabit Zemin Aksiyon Butonları
                  GestureDetector(
                    onTap: () => setState(() => _mainTab = 1),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [kTealBright, kTeal]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: kTeal.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_rounded,
                              size: 18, color: Color(0xFF003734)),
                          const SizedBox(width: 8),
                          Text(
                            'YENİ SPORCU LİSANS BAŞVURUSU',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF003734),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('PDF / Excel Lisans Listesi oluşturuldu.'),
                        backgroundColor: kTeal,
                      ),
                    ),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded,
                              size: 17, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            'Toplu Lisans Listesi İndir (Excel / PDF)',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Kişisel Başvuru Bölümü (Supabase backend'e bağlı)
                  SwanSegmentedTabs(
                    labels: const ['Antrenör Belgesi', 'Sporcu Lisansı'],
                    selected: _mode,
                    onSelect: (i) => setState(() => _mode = i),
                  ),
                  const SizedBox(height: 16),

                  if (_mode == 0) ...[
                    Text('Antrenör Kademe', style: SwanType.h3(ink)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: alt,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: List.generate(5, (i) => _kademeItem(i + 1)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kademeLabel(_kademe),
                      style: SwanType.caption(SwanColors.textSecondary,
                          w: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text('Branş', style: SwanType.h3(ink)),
                    const SizedBox(height: 8),
                    _sportPicker(isDark, alt, ink),
                    const SizedBox(height: 6),
                    Text(
                      'Belgen hangi branşa aitse onu seç. Platform bu branşta onaylar.',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ] else ...[
                    Text('Sporcu Branşı', style: SwanType.h3(ink)),
                    const SizedBox(height: 8),
                    _sportPicker(isDark, alt, ink),
                    const SizedBox(height: 6),
                    Text(
                      'Lisansın hangi branşa aitse onu seç. Bir kulübe bağlıysan lisanslı, değilsen ferdi sporcu sayılırsın.',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text('Belgeler', style: SwanType.h3(ink)),
                  const SizedBox(height: 8),
                  if (_mode == 0) ...[
                    _uploadTile(isDark, 'kademe_belgesi', 'Kademe Belgesi'),
                    _uploadTile(isDark, 'kimlik', 'Kimlik (TC)'),
                  ] else
                    _uploadTile(isDark, 'federasyon', 'Federasyon Lisansı'),
                  const SizedBox(height: 4),
                  Text(
                    'ⓘ PDF veya fotoğraf (JPG/PNG) yükleyebilirsin.',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _busy ? null : _submit,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [kTealBright, kTeal]),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: kTeal.withValues(alpha: .34),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        _busy ? 'Gönderiliyor…' : 'Doğrulamaya Gönder',
                        style:
                            SwanType.bodySm(Colors.white, w: FontWeight.w800),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Önceki Başvurularım', style: SwanType.h3(ink)),
                  const SizedBox(height: 10),
                  async.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(
                          child: CircularProgressIndicator(color: kTeal)),
                    ),
                    error: (e, _) => Text(
                      'Yüklenemedi: $e',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                    data: (creds) {
                      if (creds.isEmpty) {
                        return Text('Henüz başvuru yok.',
                            style: SwanType.caption(SwanColors.textSecondary));
                      }
                      return Column(
                        children:
                            creds.map((c) => _credRow(isDark, c)).toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterPill(
      String label, int index, int current, ValueChanged<int> onSelect) {
    final on = current == index;
    return GestureDetector(
      onTap: () => onSelect(index),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? kTeal : const Color(0xFF1E2B3C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: on ? const Color(0xFF003734) : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _docBadge(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2B3C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kTeal),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _athleteLicenseCard({
    required String name,
    required String number,
    required String role,
    required String status,
    required Color statusColor,
    required IconData statusIcon,
    required String footerLeft,
    String? footerRight,
    String? actionLabel,
    VoidCallback? onAction,
    required String avatarUrl,
    required Color surf,
    required Color surfContainer,
    required Color ink,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  avatarUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.sora(
                            color: ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(number,
                            style: GoogleFonts.sora(
                                color: kTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Text(
                      role,
                      style: GoogleFonts.plusJakartaSans(
                        color: SwanColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: GoogleFonts.plusJakartaSans(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: surfContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  footerLeft,
                  style: GoogleFonts.plusJakartaSans(
                    color: SwanColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (footerRight != null)
                  Text(
                    footerRight,
                    style: GoogleFonts.plusJakartaSans(
                      color: kTeal,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (actionLabel != null && onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _ocrActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color surfContainer,
    required Color ink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: kTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: SwanColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white60),
          ],
        ),
      ),
    );
  }

  // --- Submissions and helper methods ---
  Widget _sportPicker(bool isDark, Color alt, Color ink) {
    final sports = ref.watch(sportsProvider).valueOrNull ?? const <CityRow>[];
    final selected = sports.where((c) => c.code == _sportCode).firstOrNull;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return GestureDetector(
      onTap: sports.isEmpty ? null : () => _pickSport(sports),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: alt,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.name ?? 'Branş seç',
                style: SwanType.bodySm(
                    selected == null ? SwanColors.textSecondary : ink,
                    w: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                size: 20, color: SwanColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSport(List<CityRow> sports) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final search = TextEditingController();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = search.text.trim().toLowerCase();
          final list = q.isEmpty
              ? sports
              : sports.where((c) => trContains(c.name, q)).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: surf,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Text('Branş seç', style: SwanType.h3(ink)),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  autofocus: true,
                  onChanged: (_) => setSheet(() {}),
                  style: SwanType.bodySm(ink),
                  decoration: InputDecoration(
                    hintText: 'Ara…',
                    hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(
                        list[i].name,
                        style: SwanType.bodySm(ink, w: FontWeight.w600),
                      ),
                      trailing: list[i].code == _sportCode
                          ? const Icon(Icons.check_rounded,
                              color: kTeal, size: 19)
                          : null,
                      onTap: () => Navigator.pop(ctx, list[i].code),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (picked != null && mounted) setState(() => _sportCode = picked);
  }

  Future<void> _submit() async {
    if (_sportCode == null || _sportCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Önce branşını seç'),
          backgroundColor: SwanPalette.light.danger,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final s = ref.read(verificationServiceProvider);
      final credId = _mode == 0
          ? await s.submitCoachCredential(_kademe, sportCode: _sportCode)
          : await s.submitAthleteCredential(sportCode: _sportCode);

      if (_docs.isNotEmpty) {
        await s.attachDocuments(
          ownerType: 'credential',
          ownerId: credId,
          docs: [
            for (final e in _docs.entries)
              (docType: e.key, storagePath: e.value.storagePath),
          ],
        );
      }

      ref.invalidate(myCredentialsProvider);
      if (mounted) {
        setState(_docs.clear);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Başvurun alındı — platform inceleyecek'),
            backgroundColor: kTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _credRow(bool isDark, CredentialRow c) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final (color, icon) = switch (c.status) {
      'approved' => (SwanPalette.light.success, Icons.check_circle_rounded),
      'rejected' => (SwanPalette.light.danger, Icons.cancel_rounded),
      _ => (SwanPalette.light.warning, Icons.schedule_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Text(c.label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
          ),
          PremiumStatusChip(label: c.statusLabel, color: color, icon: icon),
        ],
      ),
    );
  }

  Widget _kademeItem(int n) {
    final on = _kademe == n;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _kademe = n),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: on ? kTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$n',
            style: SwanType.bodySm(on ? Colors.white : SwanColors.textSecondary,
                w: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _uploadTile(bool isDark, String docType, String label) {
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final picked = _docs[docType];
    final uploading = _uploading.contains(docType);
    final done = picked != null;

    final Color borderColor = done ? SwanPalette.light.success : line;

    return GestureDetector(
      onTap: (uploading || _busy) ? null : () => _pickAndUpload(docType),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: done ? SwanPalette.light.success.withValues(alpha: .06) : null,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: done
                    ? SwanPalette.light.success.withValues(alpha: .12)
                    : alt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: uploading
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kTeal,
                      ),
                    )
                  : Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 20,
                      color: done
                          ? SwanPalette.light.success
                          : SwanColors.textSecondary,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                  if (done)
                    Text(
                      picked.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                ],
              ),
            ),
            if (done)
              GestureDetector(
                onTap: () => setState(() => _docs.remove(docType)),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: SwanColors.textSecondary,
                ),
              )
            else if (!uploading)
              Text(
                'Yükle',
                style: SwanType.caption(kTeal, w: FontWeight.w800),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(String docType) async {
    try {
      final f = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() => _uploading.add(docType));
      final path = await ref.read(verificationServiceProvider).uploadDocument(
            docType: docType,
            bytes: bytes,
            fileName: f.name,
          );
      if (mounted) {
        setState(() {
          _docs[docType] = (fileName: f.name, storagePath: path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(docType));
    }
  }

  String _kademeLabel(int n) => switch (n) {
        1 => '1. Kademe — Yardımcı Antrenör',
        2 => '2. Kademe — Antrenör',
        3 => '3. Kademe — Kıdemli Antrenör',
        4 => '4. Kademe — Baş Antrenör',
        _ => '5. Kademe — Teknik Direktör',
      };
}
