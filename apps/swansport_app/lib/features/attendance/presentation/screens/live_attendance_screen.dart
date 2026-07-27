import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  State<LiveAttendanceScreen> createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  // 0: Present, 1: Excused, 2: Absent
  int _canStatus = 0;
  int _efeStatus = 1;
  int _ardaStatus = 0;

  int get _presentCount =>
      [_canStatus, _efeStatus, _ardaStatus].where((s) => s == 0).length;
  static const int _totalCount = 3;

  void _markAll() {
    setState(() {
      _canStatus = 0;
      _efeStatus = 0;
      _ardaStatus = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _presentCount / _totalCount;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
      body: Stack(
        children: [
          // Radial Depth Layer
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.1,
                  colors: [
                    const Color(0xFF008C95)
                        .withValues(alpha: isDark ? 0.07 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              // ── APP BAR ───────────────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? SwanColors.darkSurface : SwanColors.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF2E3440)
                            : SwanColors.outline,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'U-16 Erkek Basketbol',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Antrenman Yoklaması  •  17:30',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? SwanColors.darkText.withValues(alpha: 0.5)
                                    : SwanColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: SwanColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: SwanColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'CANLI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: SwanColors.success,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Responsive Body Layout
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;

                    if (isDesktop) {
                      // Desktop 2-Column Split View
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
                            // Left Column: Session Hero Card
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildSessionHeroCard(progress),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),

                            // Right Column: Roster List & Attendance Controls
                            Expanded(
                              flex: 7,
                              child: Column(
                                children: [
                                  _buildToolbar(isDark),
                                  const SizedBox(height: 14),
                                  _buildAttendanceCards(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Mobile Single Column
                    return ListView(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 22,
                        bottom: 144 + bottomInset,
                      ),
                      children: [
                        _buildSessionHeroCard(progress),
                        const SizedBox(height: 28),
                        _buildToolbar(isDark),
                        const SizedBox(height: 14),
                        _buildAttendanceCards(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          // ── STICKY BOTTOM ACTION BAR ──────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? SwanColors.darkSurface : SwanColors.surface,
                border: Border(
                  top: BorderSide(
                    color:
                        isDark ? const Color(0xFF2E3440) : SwanColors.outline,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SwanButton.primary(
                    label: 'Yoklamayı Kaydet & Tamamla',
                    width: double.infinity,
                    height: 52,
                    icon: Icons.check_circle_rounded,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            '✅ Yoklama Başarıyla Kaydedildi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          backgroundColor: SwanColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeroCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF063337), Color(0xFF008C95)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008C95).withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                'Caferağa Spor Salonu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const Icon(
                Icons.sports_basketball_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KATILIM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_presentCount',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        ' / $_totalCount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '%${(progress * 100).round()} Katılım',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'KADRO LİSTESİ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: SwanColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        GestureDetector(
          onTap: _markAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark
                  ? SwanColors.darkSurfaceVariant
                  : SwanColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3440) : SwanColors.outline,
              ),
            ),
            child: const Text(
              '⚡ Tümünü Katıldı Yap',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCards() {
    return Column(
      children: [
        _buildAttendanceCard(
          context,
          initials: 'CY',
          name: 'Can Yılmaz',
          jersey: '#10',
          note: 'Not: Hafif bilek ağrısı var',
          avatarBg: SwanColors.primaryContainer,
          avatarFg: SwanColors.primary,
          status: _canStatus,
          onStatusChange: (s) => setState(() => _canStatus = s),
        ),
        const SizedBox(height: 14),
        _buildAttendanceCard(
          context,
          initials: 'EK',
          name: 'Efe Kaya',
          jersey: '#07',
          note: 'Veli Notu: Doktor randevusu',
          avatarBg: const Color(0xFFFFF3E0),
          avatarFg: SwanColors.warning,
          status: _efeStatus,
          onStatusChange: (s) => setState(() => _efeStatus = s),
        ),
        const SizedBox(height: 14),
        _buildAttendanceCard(
          context,
          initials: 'AŞ',
          name: 'Arda Şen',
          jersey: '#12',
          note: null,
          avatarBg: const Color(0xFFEDE9FE),
          avatarFg: const Color(0xFF7C3AED),
          status: _ardaStatus,
          onStatusChange: (s) => setState(() => _ardaStatus = s),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(
    BuildContext context, {
    required String initials,
    required String name,
    required String jersey,
    required String? note,
    required Color avatarBg,
    required Color avatarFg,
    required int status,
    required ValueChanged<int> onStatusChange,
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
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? SwanColors.darkText.withValues(alpha: 0.5)
                              : SwanColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                jersey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? SwanColors.darkText.withValues(alpha: 0.4)
                      : SwanColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AttendanceButton(
                  label: '🟢 Katıldı',
                  isSelected: status == 0,
                  selectedColor: SwanColors.success,
                  onTap: () => onStatusChange(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttendanceButton(
                  label: '🟡 Mazeret',
                  isSelected: status == 1,
                  selectedColor: SwanColors.warning,
                  onTap: () => onStatusChange(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttendanceButton(
                  label: '🔴 Gelmedi',
                  isSelected: status == 2,
                  selectedColor: SwanColors.error,
                  onTap: () => onStatusChange(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _AttendanceButton({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : (isDark
                  ? SwanColors.darkSurfaceVariant
                  : SwanColors.surfaceVariant),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDark ? const Color(0xFF2E3440) : SwanColors.outline),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? SwanColors.darkText.withValues(alpha: 0.55)
                    : SwanColors.textSecondary),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
