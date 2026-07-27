import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

import '../routing/athlete_detail_route_args.dart';
import 'athlete_detail_screen.dart';

class AthleteWorkspaceScreen extends StatefulWidget {
  const AthleteWorkspaceScreen({super.key});

  @override
  State<AthleteWorkspaceScreen> createState() => _AthleteWorkspaceScreenState();
}

class _AthleteWorkspaceScreenState extends State<AthleteWorkspaceScreen> {
  int _navIndex = 2;
  int _selectedFilter = 0;
  int _selectedAthleteIndex = 0;

  final List<Map<String, dynamic>> _athletes = [
    {
      'id': 'athlete_can_yilmaz',
      'initials': 'CY',
      'name': 'Can Yılmaz',
      'info': 'Forma #10  •  U-16 Erkek',
      'privacyNote': '🔒 Veli onaylı',
      'statusLabel': 'Lisans Aktif',
      'statusColor': SwanColors.success,
      'avatarBg': SwanColors.primaryContainer,
      'avatarFg': SwanColors.primary,
      'isChecked': true,
      'jersey': '#10',
    },
    {
      'id': 'athlete_efe_kaya',
      'initials': 'EK',
      'name': 'Efe Kaya',
      'info': 'Forma #07  •  U-16 Erkek',
      'privacyNote': 'Sağlık raporu bekliyor',
      'statusLabel': 'Eksik Evrak',
      'statusColor': SwanColors.warning,
      'avatarBg': const Color(0xFFFFF3E0),
      'avatarFg': SwanColors.warning,
      'isChecked': true,
      'jersey': '#07',
    },
    {
      'id': 'athlete_arda_sen',
      'initials': 'AŞ',
      'name': 'Arda Şen',
      'info': 'Forma #12  •  U-16 Erkek',
      'privacyNote': '🔒 Veli onaylı',
      'statusLabel': 'Lisans Aktif',
      'statusColor': SwanColors.success,
      'avatarBg': const Color(0xFFEDE9FE),
      'avatarFg': const Color(0xFF7C3AED),
      'isChecked': false,
      'jersey': '#12',
    },
  ];

  final List<String> _filters = [
    '⭐  Bugünkü Takım',
    '⚠️  Lisansı Bitecekler',
    '📄  Eksik Evrak',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
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
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
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
                        .withValues(alpha: isDark ? 0.06 : 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              // Bulk Action Banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                constraints: const BoxConstraints(minHeight: 54),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF142426)
                      : SwanColors.primaryContainer,
                  border: Border(
                    bottom: BorderSide(
                      color: SwanColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_box_rounded,
                          color: SwanColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '3 Sporcu Seçildi',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: SwanColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildSmallBtn(context, 'Takıma At', isPrimary: true),
                        const SizedBox(width: 8),
                        _buildSmallBtn(context, 'Dışa Aktar', isPrimary: false),
                      ],
                    ),
                  ],
                ),
              ),

              // Responsive Layout Switcher
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 850;

                    if (isWide) {
                      // Tablet & Desktop Split View (Master - Detail)
                      return Row(
                        children: [
                          // Left Master Pane
                          SizedBox(
                            width: 380,
                            child: _buildAthleteListPane(
                              context,
                              isDark,
                              bottomInset,
                              isWide: true,
                            ),
                          ),
                          // Vertical Split Divider
                          VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: isDark
                                ? const Color(0xFF2E3440)
                                : const Color(0xFFEAEFF2),
                          ),
                          // Right Detail Pane
                          Expanded(
                            child: AthleteDetailScreen(
                              args: AthleteDetailRouteArgs(
                                athleteId: SwanId(
                                  _athletes[_selectedAthleteIndex]['id']
                                      as String,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile Single Column Layout
                    return _buildAthleteListPane(
                      context,
                      isDark,
                      bottomInset,
                      isWide: false,
                    );
                  },
                ),
              ),
            ],
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

  Widget _buildAthleteListPane(
    BuildContext context,
    bool isDark,
    double bottomInset, {
    required bool isWide,
  }) {
    return ListView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 22,
        bottom: 144 + bottomInset,
      ),
      children: [
        // ── WORKSPACE TITLE ───────────────────────────────────
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 12,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPORCU YÖNETİMİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: SwanColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Kadıköy SK',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ),
                Text(
                  'Kadrosu',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.05,
                    color: SwanColors.textSecondary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: SwanColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: SwanColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Column(
                children: [
                  Text(
                    '18',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: SwanColors.primary,
                    ),
                  ),
                  Text(
                    'Sporcu',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: SwanColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── SEARCH FIELD ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? SwanColors.darkSurface : SwanColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Sporcu adı, forma no ara...',
              hintStyle: TextStyle(
                color: isDark
                    ? SwanColors.darkText.withValues(alpha: 0.35)
                    : SwanColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: SwanColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── SAVED FILTER CHIPS ────────────────────────────────
        SingleChildScrollView(
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
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
                                color:
                                    SwanColors.primary.withValues(alpha: 0.25),
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
        ),
        const SizedBox(height: 18),

        // ── SECTION LABEL ─────────────────────────────────────
        const Text(
          'BUGÜNKÜ TAKIMIM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: SwanColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // ── ATHLETE CARDS LIST ────────────────────────────────
        ...List.generate(_athletes.length, (index) {
          final a = _athletes[index];
          final isSelectedInSplit = isWide && _selectedAthleteIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAthleteCard(
              context,
              initials: a['initials'] as String,
              name: a['name'] as String,
              info: a['info'] as String,
              privacyNote: a['privacyNote'] as String,
              statusLabel: a['statusLabel'] as String,
              statusColor: a['statusColor'] as Color,
              avatarBg: a['avatarBg'] as Color,
              avatarFg: a['avatarFg'] as Color,
              isChecked: a['isChecked'] as bool,
              isSelectedInSplit: isSelectedInSplit,
              onTap: () {
                setState(() => _selectedAthleteIndex = index);
                if (!isWide) {
                  Navigator.pushNamed(
                    context,
                    '/athlete-detail',
                    arguments: AthleteDetailRouteArgs(
                      athleteId: SwanId(a['id'] as String),
                    ),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAthleteCard(
    BuildContext context, {
    required String initials,
    required String name,
    required String info,
    required String privacyNote,
    required String statusLabel,
    required Color statusColor,
    required Color avatarBg,
    required Color avatarFg,
    required bool isChecked,
    required bool isSelectedInSplit,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelectedInSplit
              ? (isDark ? const Color(0xFF142426) : SwanColors.primaryContainer)
              : (isDark ? SwanColors.darkSurface : SwanColors.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelectedInSplit
                ? SwanColors.primary
                : (isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2)),
            width: isSelectedInSplit ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                activeColor: SwanColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                side: BorderSide(
                  color: isDark ? const Color(0xFF2E3440) : SwanColors.outline,
                  width: 1.5,
                ),
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: avatarBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarFg,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color:
                                isSelectedInSplit ? SwanColors.primary : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    info,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? SwanColors.darkText.withValues(alpha: 0.5)
                          : SwanColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    privacyNote,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? SwanColors.darkText.withValues(alpha: 0.4)
                          : SwanColors.textSecondary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
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

  Widget _buildSmallBtn(
    BuildContext context,
    String label, {
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? SwanColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(color: SwanColors.primary.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.white : SwanColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
