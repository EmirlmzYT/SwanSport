import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/athlete_detail_controller.dart';
import '../../application/athlete_detail_state.dart';
import '../../domain/models/athlete_detail.dart';
import '../routing/athlete_detail_route_args.dart';

class AthleteDetailScreen extends ConsumerStatefulWidget {
  const AthleteDetailScreen({
    super.key,
    required this.args,
  }) : isInvalidRoute = false;

  const AthleteDetailScreen.invalidRoute({super.key})
      : args = null,
        isInvalidRoute = true;

  final AthleteDetailRouteArgs? args;
  final bool isInvalidRoute;

  @override
  ConsumerState<AthleteDetailScreen> createState() =>
      _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends ConsumerState<AthleteDetailScreen> {
  @override
  Widget build(BuildContext context) {
    if (widget.isInvalidRoute || widget.args == null) {
      return _buildStateScaffold(
        context,
        title: 'Sporcu bulunamadı',
        message: 'Sporcu detayı için geçerli bir sporcu kimliği gereklidir.',
      );
    }

    final state = ref.watch(
      athleteDetailControllerProvider(widget.args!.athleteId),
    );

    return switch (state.status) {
      AthleteDetailStatus.loading => _buildLoadingScaffold(context),
      AthleteDetailStatus.loaded => _buildLoadedScaffold(context, state),
      AthleteDetailStatus.notFound => _buildStateScaffold(
          context,
          title: 'Sporcu bulunamadı',
          message: state.errorMessage ?? 'Bu sporcu kaydı bulunamadı.',
        ),
      AthleteDetailStatus.permissionDenied => _buildStateScaffold(
          context,
          title: 'Erişim izni yok',
          message: state.errorMessage ??
              'Bu sporcu detayını görüntüleme yetkiniz bulunmuyor.',
        ),
      AthleteDetailStatus.error => _buildStateScaffold(
          context,
          title: 'Detay yüklenemedi',
          message: state.errorMessage ??
              'Sporcu detayı yüklenirken beklenmeyen bir sorun oluştu.',
          onRetry: () => ref
              .read(
                athleteDetailControllerProvider(widget.args!.athleteId)
                    .notifier,
              )
              .refresh(),
        ),
    };
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildStateScaffold(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: SwanColors.primary,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SwanColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                if (onRetry != null)
                  SwanButton.secondary(
                    label: 'Tekrar Dene',
                    icon: Icons.refresh_rounded,
                    onPressed: onRetry,
                  )
                else
                  SwanButton.secondary(
                    label: 'Geri Dön',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.maybePop(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedScaffold(BuildContext context, AthleteDetailState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkBackground : SwanColors.background;
    final detail = state.detail!;
    final profile = detail.profile;
    final visibleSections = AthleteDetailSection.values
        .where(state.permissions.canView)
        .toList(growable: false);
    final initialSectionIndex = visibleSections.indexOf(state.selectedSection);
    final safeInitialIndex = initialSectionIndex < 0 ? 0 : initialSectionIndex;

    return Scaffold(
      backgroundColor: bg,
      body: DefaultTabController(
        length: visibleSections.length,
        initialIndex: safeInitialIndex,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [
                      const Color(
                        0xFF008C95,
                      ).withValues(alpha: isDark ? 0.07 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark ? SwanColors.darkSurface : SwanColors.surface,
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
                          tooltip: 'Geri dön',
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
                              Text(
                                profile.athlete.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                'Forma ${profile.jerseyNumber}  •  ${profile.seasonLabel}  •  ${profile.teamName}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? SwanColors.darkText
                                          .withValues(alpha: 0.5)
                                      : SwanColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sporcu işlemleri',
                          icon: const Icon(Icons.more_horiz_rounded, size: 22),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: 40,
                    ),
                    children: [
                      if (state.isOffline || state.isStale) ...[
                        _buildSyncBanner(state),
                        const SizedBox(height: 12),
                      ],
                      _buildProfileHeroCard(context, state),
                      const SizedBox(height: 24),
                      const Text(
                        'PERFORMANS & KATILIM METRİKLERİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: SwanColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cards = [
                            _buildDetailKpiCard(
                              context,
                              label: 'KATILIM ORANI',
                              value: detail.attendance.rateLabel,
                              unit: 'Sezon',
                              badgeText: '🟢 Yüksek',
                              badgeColor: SwanColors.success,
                            ),
                            _buildDetailKpiCard(
                              context,
                              label: 'ANTRENMAN SKORU',
                              value: detail.attendance.scoreLabel,
                              unit: detail.attendance.scoreUnit,
                              badgeText: '⚡ Formda',
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
                      ),
                      const SizedBox(height: 24),
                      _buildMedicalStatusBanner(detail.medical),
                      const SizedBox(height: 24),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? SwanColors.darkSurfaceVariant
                              : SwanColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: TabBar(
                          onTap: (index) {
                            ref
                                .read(
                                  athleteDetailControllerProvider(
                                    state.athleteId,
                                  ).notifier,
                                )
                                .selectSection(visibleSections[index]);
                          },
                          indicator: BoxDecoration(
                            color: isDark
                                ? SwanColors.darkSurface
                                : SwanColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: SwanColors.primary,
                          unselectedLabelColor: isDark
                              ? SwanColors.darkText.withValues(alpha: 0.6)
                              : SwanColors.textSecondary,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          tabs: [
                            for (final section in visibleSections)
                              Tab(text: _sectionLabel(section)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 360,
                        child: TabBarView(
                          children: [
                            for (final section in visibleSections)
                              _buildSectionTab(context, isDark, state, section),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBanner(AthleteDetailState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SwanColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state.isOffline
            ? 'Çevrimdışı önbellek gösteriliyor.'
            : 'Veri güncelliği kontrol edilmeli.',
        style: const TextStyle(
          color: SwanColors.info,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProfileHeroCard(
    BuildContext context,
    AthleteDetailState state,
  ) {
    final detail = state.detail!;
    final profile = detail.profile;

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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    color: SwanColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.athlete.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile.jerseyNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.position}  •  Doğum: ${profile.birthDateLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lisans No: ${profile.licenseNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildHeroActionBtn(
                  icon: Icons.phone_rounded,
                  label: 'Veliyi Ara',
                  onTap: state.permissions.canContactGuardian ? () {} : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Mesaj Gönder',
                  onTap: state.permissions.canContactGuardian ? () {} : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.48 : 1,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailKpiCard(
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

  Widget _buildMedicalStatusBanner(MedicalRestrictionSummary medical) {
    return Container(
      decoration: BoxDecoration(
        color: SwanColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SwanColors.success.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            left: 0,
            right: null,
            child: SizedBox(
              width: 3.5,
              child: ColoredBox(color: SwanColors.success),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medical.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: SwanColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        medical.summary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SwanColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_rounded,
                  color: SwanColors.success,
                  size: 22,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            color: SwanColors.success,
            size: 22,
          ),
        ],
      ),
    );
  }

  String _sectionLabel(AthleteDetailSection section) {
    return switch (section) {
      AthleteDetailSection.activity => 'Aktivite',
      AthleteDetailSection.attendance => 'Yoklama',
      AthleteDetailSection.documents => 'Evraklar',
      AthleteDetailSection.notes => 'Notlar',
    };
  }

  Widget _buildSectionTab(
    BuildContext context,
    bool isDark,
    AthleteDetailState state,
    AthleteDetailSection section,
  ) {
    final sectionError = state.sectionErrors[section];

    if (sectionError != null) {
      return _buildEmptyState(sectionError);
    }

    final detail = state.detail!;

    return switch (section) {
      AthleteDetailSection.activity =>
        _buildActivityTimelineTab(context, isDark, detail),
      AthleteDetailSection.attendance =>
        _buildAttendanceHistoryTab(context, isDark, detail),
      AthleteDetailSection.documents =>
        _buildDocumentsVaultTab(context, isDark, detail),
      AthleteDetailSection.notes =>
        _buildCoachNotesTab(context, isDark, detail),
    };
  }

  Widget _buildActivityTimelineTab(
    BuildContext context,
    bool isDark,
    AthleteDetail detail,
  ) {
    if (detail.timeline.isEmpty) {
      return _buildEmptyState('Henüz aktivite kaydı yok.');
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final item in detail.timeline) ...[
          _buildTimelineItem(
            isDark,
            time: item.timeLabel,
            title: item.title,
            subtitle: item.summary,
            iconColor: _timelineColor(item.type),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildAttendanceHistoryTab(
    BuildContext context,
    bool isDark,
    AthleteDetail detail,
  ) {
    if (detail.attendance.recentItems.isEmpty) {
      return _buildEmptyState('Henüz yoklama geçmişi yok.');
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final item in detail.attendance.recentItems) ...[
          _buildAttendanceHistoryItem(
            context,
            date: item.dateLabel,
            session: item.sessionLabel,
            status: item.statusLabel,
            statusColor: _attendanceStatusColor(item.statusLabel),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildDocumentsVaultTab(
    BuildContext context,
    bool isDark,
    AthleteDetail detail,
  ) {
    if (detail.documents.isEmpty) {
      return _buildEmptyState('Henüz evrak kaydı yok.');
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final document in detail.documents) ...[
          _buildDocumentItem(
            isDark,
            name: document.title,
            status: document.statusLabel,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildCoachNotesTab(
    BuildContext context,
    bool isDark,
    AthleteDetail detail,
  ) {
    if (detail.notes.isEmpty) {
      return _buildEmptyState('Henüz antrenör notu yok.');
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final note in detail.notes) ...[
          _buildNoteTile(
            isDark,
            author: note.authorName,
            date: note.dateLabel,
            note: note.body,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: SwanColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    bool isDark, {
    required String time,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4, right: 12),
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? SwanColors.darkText.withValues(alpha: 0.5)
                        : SwanColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? SwanColors.darkText.withValues(alpha: 0.4)
                  : SwanColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryItem(
    BuildContext context, {
    required String date,
    required String session,
    required String status,
    required Color statusColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? SwanColors.darkText.withValues(alpha: 0.5)
                        : SwanColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    bool isDark, {
    required String name,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_rounded,
            color: SwanColors.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SwanColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: SwanColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(
    bool isDark, {
    required String author,
    required String date,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? SwanColors.darkSurface : SwanColors.surface,
        borderRadius: BorderRadius.circular(16),
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
              Flexible(
                child: Text(
                  author,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: SwanColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? SwanColors.darkText.withValues(alpha: 0.4)
                      : SwanColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Color _timelineColor(AthleteTimelineEntryType type) {
    return switch (type) {
      AthleteTimelineEntryType.attendance => SwanColors.success,
      AthleteTimelineEntryType.document => SwanColors.primary,
      AthleteTimelineEntryType.note => const Color(0xFF7C3AED),
      AthleteTimelineEntryType.medical => SwanColors.success,
    };
  }

  Color _attendanceStatusColor(String statusLabel) {
    return statusLabel == 'Mazeretli' ? SwanColors.warning : SwanColors.success;
  }
}
