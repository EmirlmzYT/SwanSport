import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/reports_controller.dart';
import '../../domain/reports_models.dart';
import '../routing/report_detail_args.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _navIndex = 0;

  void _showCustomReportBuilderSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? SwanColors.darkSurface : SwanColors.surface;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF2E3440) : SwanColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Özel Rapor Oluşturucu (Report Builder)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Veri Etki Alanı Seçimi:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ReportDomainCategory.values
                    .map(
                      (c) => Chip(
                        label: Text(
                          c.displayName,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor:
                            SwanColors.primary.withValues(alpha: 0.08),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. Çıktı Görselleştirme Formatı:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('📊 Kolon / Çizgi Grafiği')),
                  Chip(label: Text('📄 PDF Yönetim Sunumu')),
                  Chip(label: Text('📈 Excel Veri Tablosu')),
                ],
              ),
              const SizedBox(height: 20),
              SwanButton.primary(
                label: 'Raporu Derle & Dışa Aktır',
                width: double.infinity,
                height: 50,
                icon: Icons.analytics_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        '📊 Özel Rapor Başarıyla Derlendi ve Dışa Aktarıldı (PDF/Excel)',
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
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);
    final notifier = ref.read(reportsControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkBackground : SwanColors.background;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      appBar: SwanAppBar(
        clubName: 'Kadıköy SK',
        roleName: 'Kulüp Yöneticisi',
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
              icon: const Icon(Icons.add_chart_rounded, size: 20),
              onPressed: _showCustomReportBuilderSheet,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
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
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditorialHeader(isDark),
                            const SizedBox(height: 20),
                            _buildExecutiveKpiHero(state.kpis),
                            const SizedBox(height: 20),
                            _buildAnomalyAlertsCard(isDark, state.alerts),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _buildSearchAndFilters(isDark, state, notifier),
                            const SizedBox(height: 16),
                            _buildReportCatalog(isDark, state, notifier),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: 144 + bottomInset,
                ),
                children: [
                  _buildEditorialHeader(isDark),
                  const SizedBox(height: 20),
                  _buildExecutiveKpiHero(state.kpis),
                  const SizedBox(height: 20),
                  _buildAnomalyAlertsCard(isDark, state.alerts),
                  const SizedBox(height: 24),
                  _buildSearchAndFilters(isDark, state, notifier),
                  const SizedBox(height: 16),
                  _buildReportCatalog(isDark, state, notifier),
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
          if (index == 2) Navigator.pushNamed(context, '/athletes');
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
          'BUSINESS INTELLIGENCE & DECISION SUPPORT',
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
          'Raporlama &',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.1,
          ),
        ),
        const Text(
          'Karar Destek Merkezi',
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

  Widget _buildExecutiveKpiHero(ExecutiveKpi kpi) {
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
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'EXECUTIVE HEALTH SCORE: %${kpi.clubHealthScore}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${kpi.totalActiveAthletes} Aktif Sporcu (+${kpi.athleteGrowthPercentage}%)',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Genel Yoklama: %${kpi.overallAttendanceRate}  •  Antrenman Tamamlama: %${kpi.trainingCompletionRate}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildKpiStat('%${kpi.facilityOccupancyRate}', 'Saha Doluluk'),
              _buildKpiStat('%${kpi.medicalComplianceScore}', 'Tıbbi Uyum'),
              _buildKpiStat('${kpi.activeInjuriesCount}', 'Aktif Sakat'),
              _buildKpiStat('100%', 'Veri Tamlık'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildAnomalyAlertsCard(bool isDark, List<AnomalyAlert> alerts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: SwanColors.warning,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anomali & Operasyonel Uyarılar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(alert.severity.icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          alert.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : SwanColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    bool isDark,
    ReportsState state,
    ReportsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: notifier.updateSearch,
          decoration: InputDecoration(
            hintText: 'Rapor başlığı, alan veya yetki seviyesi ara...',
            hintStyle: TextStyle(
              color: isDark
                  ? SwanColors.darkText.withValues(alpha: 0.35)
                  : SwanColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: isDark
                ? SwanColors.darkSurfaceVariant
                : SwanColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tümü', style: TextStyle(fontSize: 11)),
                selected: state.selectedCategory == null,
                onSelected: (_) => notifier.selectCategory(null),
              ),
              const SizedBox(width: 8),
              ...ReportDomainCategory.values.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat.displayName,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: state.selectedCategory == cat,
                    onSelected: (_) => notifier.selectCategory(cat),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCatalog(
    bool isDark,
    ReportsState state,
    ReportsNotifier notifier,
  ) {
    final templates = state.filteredTemplates;

    if (templates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              Icons.find_in_page_rounded,
              size: 48,
              color: SwanColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Arama kriterlerine uygun rapor bulunamadı.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : SwanColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: templates.map((report) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? SwanColors.darkSurface : SwanColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SwanColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report.category.displayName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: SwanColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      report.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: report.isFavorite
                          ? Colors.amber
                          : SwanColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => notifier.toggleFavorite(report.id),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                report.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : SwanColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'Yetki: ${report.requiredRole} • ${report.lastGenerated}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : SwanColors.textSecondary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        key: Key('open-report-${report.id}'),
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/report-detail',
                          arguments: ReportDetailArgs(report.id),
                        ),
                        child: const Text('AÇ'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '📄 "${report.title}" PDF Raporu Hazırlandı',
                              ),
                              backgroundColor: SwanColors.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '📈 "${report.title}" Excel Tablosu Hazırlandı',
                              ),
                              backgroundColor: SwanColors.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'EXCEL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
