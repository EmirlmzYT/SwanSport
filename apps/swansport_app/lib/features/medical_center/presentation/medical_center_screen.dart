import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Medikal & Sağlık Merkezi — Stitch "Calm Athletic Modernism" Klinik Takip Hub.
class MedicalCenterScreen extends ConsumerStatefulWidget {
  const MedicalCenterScreen({super.key});

  @override
  ConsumerState<MedicalCenterScreen> createState() =>
      _MedicalCenterScreenState();
}

class _MedicalCenterScreenState extends ConsumerState<MedicalCenterScreen> {
  String _selectedFilter = 'all'; // all, injury, physio, return, reports

  static const _states = {
    'injured': (
      'Müsabakaya Uygun Değil',
      Color(0xFFBA1A1A),
      Icons.personal_injury_rounded
    ),
    'pending': (
      'Takipte / Kısıtlı',
      Color(0xFFD97706),
      Icons.help_outline_rounded
    ),
    'fit': (
      'Tam Uygun',
      Color(0xFF00666D),
      Icons.check_circle_outline_rounded
    ),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final async = ref.watch(injuriesProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF061424),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(injuriesProvider);
                      await ref.read(injuriesProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 132),
                      children: [
                        // Subtitle & Live Status Strip
                        _buildLiveStatusStrip(),
                        const SizedBox(height: 12),

                        // Bento KPI Grid (Tedavide, Dönüş, Raporlar)
                        _buildKpiGrid(),
                        const SizedBox(height: 14),

                        // Emergency SOS Banner
                        _buildEmergencyActionCard(c),
                        const SizedBox(height: 14),

                        // Filter Pills
                        _buildFilterPills(),
                        const SizedBox(height: 16),

                        // Priority Protocol Hero Bento Card (Merih Demiral)
                        _buildPriorityProtocolCard(),
                        const SizedBox(height: 20),

                        // Active Treatment Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.medical_services_rounded,
                                  size: 18,
                                  color: kTeal,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Aktif Tedavi Programı',
                                  style: SwanType.h3(Colors.white),
                                ),
                              ],
                            ),
                            Text(
                              '3 Sporcu Kayıtlı',
                              style: SwanType.caption(SwanColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Active Treatment Athlete Cards
                        _buildTreatmentAthleteCard(
                          name: 'Arda Güler',
                          number: '#10',
                          diagnosis: 'Kasık Ağrısı (Adduktör Gerginliği)',
                          recoveryPercent: 85,
                          statusLabel: 'Hafif Antrenmanda',
                          statusColor: kTeal,
                          treatmentPlan:
                              'Koruyucu Havuz Çalışması & Medikal Masaj',
                          treatmentIcon: Icons.pool_rounded,
                          statusDotColor: kTeal,
                        ),
                        const SizedBox(height: 10),
                        _buildTreatmentAthleteCard(
                          name: 'Barış Alper Yılmaz',
                          number: '#53',
                          diagnosis: 'Ayak Bileği İnversiyon Burkulması',
                          recoveryPercent: 40,
                          statusLabel: 'Akut İstirahat',
                          statusColor: const Color(0xFFFF5252),
                          treatmentPlan:
                              'Buz Protokolü, Manuel Lenf Drenajı & Kompresyon',
                          treatmentIcon: Icons.ac_unit_rounded,
                          statusDotColor: const Color(0xFFFF5252),
                        ),
                        const SizedBox(height: 10),
                        _buildTreatmentAthleteCard(
                          name: 'Uğurcan Çakır',
                          number: '#1',
                          diagnosis: 'El Bileği Hafif Kontüzyonu',
                          recoveryPercent: 100,
                          statusLabel: 'Maça Uygun (Fit)',
                          statusColor: kTeal,
                          treatmentPlan:
                              'Bandaj Destekli Saha İçi Şut & Tutuş Çalışması',
                          treatmentIcon: Icons.sports_handball_rounded,
                          statusDotColor: kTeal,
                        ),
                        const SizedBox(height: 20),

                        // Database Registered Injuries from Supabase
                        async.when(
                          loading: () => const SizedBox.shrink(),
                          error: (e, _) => const SizedBox.shrink(),
                          data: (list) {
                            if (list.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Veritabanı Kayıtlı Kısıtlar',
                                  style: SwanType.h3(Colors.white),
                                ),
                                const SizedBox(height: 8),
                                for (final r in list) _buildInjuryCard(c, r),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),

                        // TFF Health Visa Periodic Warning
                        _buildTffVisaAlertCard(),
                        const SizedBox(height: 20),

                        // Bottom Actions
                        _buildBottomActionButtons(),
                      ],
                    ),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D).withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF132031),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            'Medikal & Sağlık Merkezi',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: kTeal),
                onPressed: _addRecord,
                tooltip: 'Yeni Kayıt Ekle',
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: kTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: Color(0xFF003734),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusStrip() {
    return Row(
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
            const SizedBox(width: 6),
            Text(
              'CANLI KLİNİK TAKİP HUB',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: kTeal,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2B3C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '28 Ekim 2024',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: SwanColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    return Row(
      children: [
        // KPI 1: Tedavide
        Expanded(
          child: _kpiCard(
            title: 'Tedavide',
            icon: Icons.personal_injury_rounded,
            iconColor: const Color(0xFFFF8C6F),
            count: '4',
            countUnit: 'Sporcu',
            countColor: Colors.white,
            subWidget: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5252),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '1 Kritik · 3 İyileşme',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: SwanColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // KPI 2: Sahaya Dönüş
        Expanded(
          child: _kpiCard(
            title: 'Dönüş',
            icon: Icons.directions_run_rounded,
            iconColor: kTeal,
            count: '2',
            countUnit: 'Bu Hafta',
            countColor: kTeal,
            subWidget: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 10, color: kTeal),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'Son test aşaması',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: kTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // KPI 3: Süresi Dolan Rapor
        Expanded(
          child: _kpiCard(
            title: 'Raporlar',
            icon: Icons.assignment_late_rounded,
            iconColor: const Color(0xFFFF5252),
            count: '3',
            countUnit: 'Vize',
            countColor: const Color(0xFFFF5252),
            subWidget: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  size: 10,
                  color: Color(0xFFFF5252),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'TFF Yenileme',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: const Color(0xFFFF5252),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String count,
    required String countUnit,
    required Color countColor,
    required Widget subWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: SwanColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count,
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: countColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                countUnit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: SwanColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          subWidget,
        ],
      ),
    );
  }

  Widget _buildFilterPills() {
    final filters = [
      ('all', 'Tümü (12)'),
      ('injury', 'Aktif Sakatlık (4)'),
      ('physio', 'Fizyoterapi (3)'),
      ('return', 'Dönüş Etabı (2)'),
      ('reports', 'Sağlık Raporları'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = f.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? kTeal : const Color(0xFF1E2B3C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.$2,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF061424)
                        : const Color(0xFFC0C6D9),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriorityProtocolCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2B3C),
            Color(0xFF132031),
            Color(0xFF0F1C2D),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF8C6F).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notification_important_rounded,
                      size: 16,
                      color: Color(0xFFFF8C6F),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Öncelikli Tedavi Protokolü',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C6F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ACİL TAKİP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF8C6F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Athlete info & circular progress
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF293547),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: Color(0xFF55DBD2),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF020F1F),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#4',
                          style: GoogleFonts.sora(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: kTeal,
                          ),
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
                            'Merih Demiral',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF293547),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'U18',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: SwanColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stoper · A Takım Adayı',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: SwanColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SwanRing(
                  value: 0.65,
                  track: const Color(0xFF293547),
                  progress: kTeal,
                  size: 48,
                  stroke: 5,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '%65',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Rehab',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: kTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Bento Details (Diagnosis & Responsible Specialist)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF020F1F).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Klinik Teşhis',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: SwanColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sağ Hamstring',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Evre 1 Kas Gerilmesi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF8C6F),
                          ),
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
                      color: const Color(0xFF020F1F).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sorumlu Uzman',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: SwanColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Uzm. Fzt. Sinan Kaya',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Klinik Fizyoterapi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: kTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dynamic Loading Stage Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, size: 14, color: kTeal),
                    const SizedBox(width: 4),
                    Text(
                      'Dinamik Yüklenme Etabı',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  '6 Gün Kaldı (3 Kasım)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.65,
                minHeight: 6,
                backgroundColor: Color(0xFF293547),
                valueColor: AlwaysStoppedAnimation(kTeal),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'İstirahat & Akut',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: SwanColors.textSecondary,
                  ),
                ),
                Text(
                  'Kuvvet & Denge',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: kTeal,
                  ),
                ),
                Text(
                  'Takım Antrenmanı',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: SwanColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.description_rounded, size: 15),
                    label: Text(
                      'Raporu İncele',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addRecord,
                    icon: const Icon(Icons.note_add_rounded, size: 15),
                    label: Text(
                      'Tedavi Notu Ekle',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: const Color(0xFF003734),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentAthleteCard({
    required String name,
    required String number,
    required String diagnosis,
    required int recoveryPercent,
    required String statusLabel,
    required Color statusColor,
    required String treatmentPlan,
    required IconData treatmentIcon,
    required Color statusDotColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2B3C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 24,
                          color: Color(0xFFBBC9C7),
                        ),
                      ),
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF020F1F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            number,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: kTeal,
                            ),
                          ),
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
                            name,
                            style: GoogleFonts.sora(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diagnosis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'İyileşme %$recoveryPercent',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1C2D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(treatmentIcon, size: 14, color: kTeal),
                    const SizedBox(width: 6),
                    Text(
                      treatmentPlan,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFFBBC9C7),
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: SwanColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTffVisaAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2B3C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_late_rounded,
                  size: 20,
                  color: Color(0xFFFF5252),
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
                          'TFF Periyodik Sağlık Vizesi',
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF93000A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '3 Bekleyen',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFFDAD6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Önümüzdeki lig müsabakasına katılım için 3 sporcunun kardiyolojik EKG ve kan tetkik raporu yenilenmelidir.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFFBBC9C7),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Athlete Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _visaChip('Kerem Aktürkoğlu', 'Son 2 Gün', const Color(0xFFFF5252)),
              _visaChip('Ferdi Kadıoğlu', 'Son 3 Gün', const Color(0xFFFF5252)),
              _visaChip('Semih Kılıçsoy', 'Son 5 Gün', const Color(0xFFFF8C6F)),
            ],
          ),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sağlık kuruluşuna sevk belgesi oluşturuldu.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.local_hospital_rounded, size: 14),
                  label: Text(
                    'Hastaneye Sevk Et',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Veliye SMS ve bildirim hatırlatması gönderildi.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forward_to_inbox_rounded, size: 14),
                  label: Text(
                    'Veliye Hatırlat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _visaChip(String name, String days, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$name ($days)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _addRecord,
            icon: const Icon(Icons.add_circle_rounded, size: 18),
            label: Text(
              'Yeni Sakatlık / Tedavi Girişi Yap',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: const Color(0xFF003734),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Haftalık Medikal Rapor indiriliyor...'),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(
              'Haftalık Medikal Durum Raporu İndir (PDF)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyActionCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFBA1A1A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBA1A1A).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5252),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AKTİF GÜVENLİK AĞI',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF132031),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Kulüp Poligon Sahası',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: SwanColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _triggerEmergencyAlert(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.emergency_rounded, size: 18),
              label: Text(
                'Acil Durum Bildir & Güvenliği Uyar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:112')),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132031),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.call,
                          size: 16,
                          color: Color(0xFFFF5252),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acil Çağrı',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Hattı: 112',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: SwanColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:02129990112')),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132031),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medical_services_rounded,
                          size: 16,
                          color: kTeal,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kulüp Hekimi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Dr. Selin Kaya',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: SwanColors.textSecondary,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildInjuryCard(SwanPalette c, InjuryRow r) {
    final st = _states[r.status] ?? _states['fit']!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: st.$2.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(st.$3, color: st.$2, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.athleteName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: st.$2.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        st.$1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: st.$2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r.note != null && r.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    r.note!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: SwanColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _triggerEmergencyAlert(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF132031),
        title: Text(
          'Acil Durum Onayı',
          style: GoogleFonts.sora(color: Colors.white),
        ),
        content: Text(
          'Kulüp poligon güvenliği ve acil müdahale ekibi derhal uyarılacaktır. Devam etmek istiyor musunuz?',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFBBC9C7)),
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
                  content: Text('Acil durum bildirimi tüm yetkililere iletildi.'),
                  backgroundColor: Color(0xFFBA1A1A),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Bildirimi Gönder'),
          ),
        ],
      ),
    );
  }

  Future<void> _addRecord() async {
    final name = FormField_('Sporcu Adı', hint: 'Ad Soyad');
    final type = FormField_('Durum / Kısıt', hint: 'Örn: Omuz zorlanması');
    final notes =
        FormField_('Notlar', hint: 'İstirahat önerildi', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Sağlık Kaydı Ekle',
      fields: [name, type, notes],
      onSubmit: () async {},
    );
    if (ok == true) {
      ref.invalidate(injuriesProvider);
    }
  }
}
