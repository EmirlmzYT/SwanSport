import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class TeamRosterDirectoryScreen extends StatefulWidget {
  const TeamRosterDirectoryScreen({super.key});

  @override
  State<TeamRosterDirectoryScreen> createState() =>
      _TeamRosterDirectoryScreenState();
}

class _TeamRosterDirectoryScreenState extends State<TeamRosterDirectoryScreen> {
  int _navIndex = 2;
  int _selectedFilter = 0;

  final List<String> _filters = [
    'Tümü (3)',
    '🏀 U-16 Erkek',
    '🏀 U-18 Erkek',
    '⚡ U-14 Gelişim',
  ];

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
              icon: const Icon(Icons.group_add_rounded, size: 20),
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
                // Desktop 2-Column Grid
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
                      // Left Column: Header, Hero & Filters
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditorialHeader(isDark),
                            const SizedBox(height: 24),
                            _buildHeroBranchCard(),
                            const SizedBox(height: 24),
                            _buildFilterChips(isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),

                      // Right Column: Teams List
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildSectionHeader('AKTİF KADROLAR'),
                            const SizedBox(height: 12),
                            _buildTeamCard(
                              context,
                              teamName: 'U-16 Erkek Basketbol Takımı',
                              coachName: 'Ahmet Koç (Başantrenör)',
                              athleteCount: '18 Sporcu',
                              attendanceRate: '%94 Katılım',
                              statusBadge: '🟢 Tam Kadro',
                              statusColor: SwanColors.success,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/athletes'),
                            ),
                            const SizedBox(height: 14),
                            _buildTeamCard(
                              context,
                              teamName: 'U-18 Erkek Basketbol Takımı',
                              coachName: 'Mehmet Can (Başantrenör)',
                              athleteCount: '16 Sporcu',
                              attendanceRate: '%91 Katılım',
                              statusBadge: '⚡ Maç Haftası',
                              statusColor: SwanColors.primary,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/athletes'),
                            ),
                            const SizedBox(height: 14),
                            _buildTeamCard(
                              context,
                              teamName: 'U-14 Gelişim Takımı',
                              coachName: 'Selin Yılmaz (Antrenör)',
                              athleteCount: '14 Sporcu',
                              attendanceRate: '%88 Katılım',
                              statusBadge: '📄 2 Eksik Evrak',
                              statusColor: SwanColors.warning,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/athletes'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mobile Layout
              return ListView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 144 + bottomInset,
                ),
                children: [
                  _buildEditorialHeader(isDark),
                  const SizedBox(height: 22),
                  _buildHeroBranchCard(),
                  const SizedBox(height: 24),
                  _buildFilterChips(isDark),
                  const SizedBox(height: 28),
                  _buildSectionHeader('AKTİF KADROLAR'),
                  const SizedBox(height: 12),
                  _buildTeamCard(
                    context,
                    teamName: 'U-16 Erkek Basketbol Takımı',
                    coachName: 'Ahmet Koç (Başantrenör)',
                    athleteCount: '18 Sporcu',
                    attendanceRate: '%94 Katılım',
                    statusBadge: '🟢 Tam Kadro',
                    statusColor: SwanColors.success,
                    onTap: () => Navigator.pushNamed(context, '/athletes'),
                  ),
                  const SizedBox(height: 14),
                  _buildTeamCard(
                    context,
                    teamName: 'U-18 Erkek Basketbol Takımı',
                    coachName: 'Mehmet Can (Başantrenör)',
                    athleteCount: '16 Sporcu',
                    attendanceRate: '%91 Katılım',
                    statusBadge: '⚡ Maç Haftası',
                    statusColor: SwanColors.primary,
                    onTap: () => Navigator.pushNamed(context, '/athletes'),
                  ),
                  const SizedBox(height: 14),
                  _buildTeamCard(
                    context,
                    teamName: 'U-14 Gelişim Takımı',
                    coachName: 'Selin Yılmaz (Antrenör)',
                    athleteCount: '14 Sporcu',
                    attendanceRate: '%88 Katılım',
                    statusBadge: '📄 2 Eksik Evrak',
                    statusColor: SwanColors.warning,
                    onTap: () => Navigator.pushNamed(context, '/athletes'),
                  ),
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
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/calendar');
          if (index == 3) Navigator.pushNamed(context, '/announcements');
        },
      ),
    );
  }

  Widget _buildEditorialHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KULÜP KADROLARI • 2025-2026 SEZONU',
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
          'Takım & Yaş Grubu',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const Text(
          'Yönetimi',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.05,
            color: SwanColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBranchCard() {
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
                child: const Text(
                  'BASKETBOL ŞUBESİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(
                Icons.sports_basketball_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '48 Lisanslı Sporcu',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '3 Yaş Grubu Takımı  •  4 Antrenör',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilter == index;
          return Padding(
            padding:
                EdgeInsets.only(right: index < _filters.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? SwanColors.primary
                      : (isDark
                          ? SwanColors.darkSurfaceVariant
                          : SwanColors.surfaceVariant),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? SwanColors.primary
                        : (isDark
                            ? const Color(0xFF2E3440)
                            : SwanColors.outline.withValues(alpha: 0.5)),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: SwanColors.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? SwanColors.darkText.withValues(alpha: 0.6)
                            : SwanColors.textSecondary),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
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

  Widget _buildTeamCard(
    BuildContext context, {
    required String teamName,
    required String coachName,
    required String athleteCount,
    required String attendanceRate,
    required String statusBadge,
    required Color statusColor,
    required VoidCallback onTap,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                athleteCount,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SwanColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            teamName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$coachName  •  $attendanceRate',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? SwanColors.darkText.withValues(alpha: 0.5)
                  : SwanColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Kadroya Git',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? SwanColors.darkSurfaceVariant
                    : SwanColors.surfaceVariant,
                foregroundColor:
                    isDark ? SwanColors.darkText : SwanColors.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
