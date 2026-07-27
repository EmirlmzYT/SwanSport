import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkBackground : SwanColors.background;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      appBar: SwanAppBar(
        clubName: 'Kadıköy SK',
        roleName: 'Antrenör',
        onContextTap: () {},
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanColors.darkSurfaceVariant
                  : SwanColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Badge(
                label: Text(
                  '3',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: SwanColors.error,
                child: Icon(Icons.notifications_none_rounded, size: 22),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Radial Depth Layer
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF008C95)
                        .withValues(alpha: isDark ? 0.07 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Responsive Layout Builder
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
                // Desktop / Tablet 2-Column Dashboard Grid
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 32,
                    right: 32,
                    top: 28,
                    bottom: 144 + bottomInset,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (Hero & Core Metrics)
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGreetingSection(isDark),
                            const SizedBox(height: 24),
                            _buildHeroCard(context),
                            const SizedBox(height: 28),
                            _buildSectionHeader('TAKIM METRİKLERİ'),
                            const SizedBox(height: 14),
                            _buildKpiGrid(context),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),

                      // Right Column (Alerts & Announcements & Quick Actions)
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              height: 52,
                            ), // Align with hero card top
                            _buildPendingAlert(isDark),
                            const SizedBox(height: 28),
                            _buildAnnouncementsSection(context, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mobile Single-Column Flow
              return ListView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 144 + bottomInset,
                ),
                children: [
                  _buildGreetingSection(isDark),
                  const SizedBox(height: 24),
                  _buildHeroCard(context),
                  const SizedBox(height: 28),
                  _buildSectionHeader('TAKIM METRİKLERİ'),
                  const SizedBox(height: 12),
                  _buildKpiGrid(context),
                  const SizedBox(height: 28),
                  _buildPendingAlert(isDark),
                  const SizedBox(height: 28),
                  _buildAnnouncementsSection(context, isDark),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SwanFloatingNavigationBar(
        selectedIndex: _navIndex,
        destinations: const [
          SwanNavigationDestination(
            icon: Icons.grid_view_rounded,
            label: 'Ana Sayfa',
          ),
          SwanNavigationDestination(
            icon: Icons.calendar_month_rounded,
            label: 'Takvim',
          ),
          SwanNavigationDestination(
            icon: Icons.groups_rounded,
            label: 'Takımım',
          ),
          SwanNavigationDestination(
            icon: Icons.campaign_rounded,
            label: 'Duyurular',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
          if (index == 1) Navigator.pushNamed(context, '/calendar');
          if (index == 2) Navigator.pushNamed(context, '/athletes');
          if (index == 3) Navigator.pushNamed(context, '/announcements');
        },
      ),
    );
  }

  Widget _buildGreetingSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '22 TEMMUZ 2026 • ÇARŞAMBA',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? SwanColors.darkText.withValues(alpha: 0.45)
                : SwanColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'İyi çalışmalar,',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const Text(
          'Ahmet Koç',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.05,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF063337), Color(0xFF008C95)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008C95).withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'YAKLAŞAN ANTRENMAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.sports_basketball_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'U-16 Erkek Basketbol Antrenmanı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '17:30 - 19:00',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Caferağa Spor Salonu',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '16 / 18 Sporcu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '%88 Katılım',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 16 / 18,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/attendance'),
              icon: const Icon(
                Icons.fact_check_rounded,
                color: SwanColors.primary,
                size: 20,
              ),
              label: const Text(
                'Yoklama Al',
                style: TextStyle(
                  color: SwanColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: SwanColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildKpiCard(
            context,
            label: 'AKTİF SPORCU',
            value: '18',
            unit: 'Kadro',
            badgeText: '🟢 Tam Kadro',
            badgeColor: SwanColors.success,
          ),
          _buildKpiCard(
            context,
            label: 'SEZON KATILIMI',
            value: '%89',
            unit: 'Ort.',
            badgeText: '⚡ Yüksek',
            badgeColor: SwanColors.primary,
          ),
        ];

        if (constraints.maxWidth < 350) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 12),
              cards[1],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 14),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required String badgeText,
    required Color badgeColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: SwanColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? SwanColors.darkText.withValues(alpha: 0.5)
                          : SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: SwanColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: const BorderSide(color: SwanColors.warning, width: 3),
          top: BorderSide(color: SwanColors.warning.withValues(alpha: 0.15)),
          right: BorderSide(color: SwanColors.warning.withValues(alpha: 0.15)),
          bottom: BorderSide(color: SwanColors.warning.withValues(alpha: 0.15)),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 Yoklama Bekliyor',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: SwanColors.warning,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'U-16 Erkek dünkü antrenman kaydı onaylanmalı.',
                  style: TextStyle(
                    fontSize: 12,
                    color: SwanColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: SwanColors.warning,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('SON KULÜP DUYURULARI'),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/announcements'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Tümünü Gör',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: SwanColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? SwanColors.darkSurface : SwanColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: const BorderSide(color: SwanColors.primary, width: 3),
              top: BorderSide(
                color:
                    isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
              ),
              right: BorderSide(
                color:
                    isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
              ),
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tesis Bakım Çalışması Hakkında',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Salon B saat 14:00-16:00 arası periyodik bakımdadır.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? SwanColors.darkText.withValues(alpha: 0.6)
                            : SwanColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bugün',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SwanColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
