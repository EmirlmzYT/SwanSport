import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/schedule_calendar_controller.dart';
import '../../application/schedule_calendar_state.dart';
import '../../domain/models/calendar_workspace.dart';

class ScheduleCalendarScreen extends ConsumerWidget {
  const ScheduleCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleCalendarControllerProvider);
    final controller = ref.read(scheduleCalendarControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? SwanColors.darkBackground : SwanColors.background,
      appBar: SwanAppBar(
        clubName: 'Kadıköy SK',
        roleName: 'Antrenör',
        actions: state.permissions.canCreateEvent
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? SwanColors.darkSurfaceVariant
                        : SwanColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_task_rounded, size: 20),
                    onPressed: () {},
                  ),
                ),
              ]
            : const [],
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
              final content = _CalendarContent(
                state: state,
                isDark: isDark,
                onViewModeChanged: controller.switchViewMode,
                onDateSelected: controller.selectDate,
                onEventSelected: controller.selectEvent,
                onAttendanceTap: () =>
                    Navigator.pushNamed(context, '/attendance'),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 900 ? 32 : 20,
                  24,
                  constraints.maxWidth >= 900 ? 32 : 20,
                  144 + bottomInset,
                ),
                child: content,
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SwanFloatingNavigationBar(
        selectedIndex: 1,
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
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/dashboard');
            case 2:
              Navigator.pushNamed(context, '/athletes');
            case 3:
              Navigator.pushNamed(context, '/announcements');
          }
        },
      ),
    );
  }
}

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.state,
    required this.isDark,
    required this.onViewModeChanged,
    required this.onDateSelected,
    required this.onEventSelected,
    required this.onAttendanceTap,
  });

  final ScheduleCalendarState state;
  final bool isDark;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<CalendarEvent> onEventSelected;
  final VoidCallback onAttendanceTap;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditorialHeader(selectedDate: state.selectedDate, isDark: isDark),
        const SizedBox(height: 20),
        _WorkloadHero(
          analytics: state.analytics,
          failure: state.sectionFailures['analytics'],
        ),
        const SizedBox(height: 20),
        _ViewModeSwitcher(
          selected: state.selectedViewMode,
          onChanged: onViewModeChanged,
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _DaySelector(
          selectedDate: state.selectedDate,
          onSelected: onDateSelected,
          isDark: isDark,
        ),
      ],
    );
    final events = _EventSection(
      state: state,
      isDark: isDark,
      onEventSelected: onEventSelected,
      onAttendanceTap: onAttendanceTap,
    );
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [controls, const SizedBox(height: 24), events],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: controls),
        const SizedBox(width: 32),
        Expanded(child: events),
      ],
    );
  }
}

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader({required this.selectedDate, required this.isDark});

  final DateTime selectedDate;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEMMUZ 2026 • HAFTA 30 • 2025-2026 SEZONU',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? SwanColors.darkText.withValues(alpha: .45)
                  : SwanColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Takvim & Program',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
              height: 1.1,
            ),
          ),
          const Text(
            'Yönetimi',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.05,
              color: SwanColors.textSecondary,
            ),
          ),
        ],
      );
}

class _WorkloadHero extends StatelessWidget {
  const _WorkloadHero({required this.analytics, required this.failure});

  final WorkloadAnalytics? analytics;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final data = analytics;
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
            color: const Color(0xFF008C95).withValues(alpha: .3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: data == null
          ? Text(
              failure ?? 'Analitik verileri yükleniyor…',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: _HeroPill(label: 'WORKLOAD & FACILITY ANALYTICS'),
                    ),
                    SizedBox(width: 12),
                    Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Bu Hafta ${data.weeklyEventCount} Etkinlik',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.trainingCount} Antrenman Seansı  •  ${data.matchCount} Lig Maçı  •  %${data.facilityLoadPercent} Tesis Yükü',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: .75),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _HeroStat('${data.weeklyLoadHours} Sa', 'Haftalık Yük'),
                    _HeroStat('%${data.facilityLoadPercent}', 'Caferağa Yükü'),
                    _HeroStat(
                      '${data.matchCount}:${data.trainingCount}',
                      'Maç/Antrenman',
                    ),
                    _HeroStat(data.recoveryStatus, 'Dinlenme'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: .8,
          ),
        ),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: .65),
            ),
          ),
        ],
      );
}

class _ViewModeSwitcher extends StatelessWidget {
  const _ViewModeSwitcher({
    required this.selected,
    required this.onChanged,
    required this.isDark,
  });
  final CalendarViewMode selected;
  final ValueChanged<CalendarViewMode> onChanged;
  final bool isDark;
  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark
              ? SwanColors.darkSurfaceVariant
              : SwanColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: CalendarViewMode.values.map((mode) {
            final active = selected == mode;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(mode),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark ? SwanColors.darkSurface : SwanColors.surface)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _viewModeLabel(mode),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                      color: active
                          ? SwanColors.primary
                          : SwanColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedDate,
    required this.onSelected,
    required this.isDark,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final first =
        selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (index) {
          final date = first.add(Duration(days: index));
          final active = _sameDay(date, selectedDate);
          return Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 10),
            child: InkWell(
              onTap: () => onSelected(date),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? SwanColors.primary
                      : (isDark ? SwanColors.darkSurface : SwanColors.surface),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        active ? SwanColors.primary : const Color(0xFFEAEFF2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdayShort(date.weekday),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active
                            ? Colors.white.withValues(alpha: .8)
                            : SwanColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.state,
    required this.isDark,
    required this.onEventSelected,
    required this.onAttendanceTap,
  });
  final ScheduleCalendarState state;
  final bool isDark;
  final ValueChanged<CalendarEvent> onEventSelected;
  final VoidCallback onAttendanceTap;
  @override
  Widget build(BuildContext context) {
    if (state.status == ScheduleCalendarStatus.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (state.status == ScheduleCalendarStatus.error) {
      return _MessageCard(message: state.errorMessage ?? 'Takvim yüklenemedi.');
    }
    if (state.status == ScheduleCalendarStatus.empty) {
      return const _MessageCard(
        message: 'Seçili tarih ve filtreler için etkinlik bulunmuyor.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isOffline || state.isStale)
          _StatusBanner(isOffline: state.isOffline, isStale: state.isStale),
        if (state.sectionFailures['events'] case final message?)
          _MessageCard(message: message),
        Text(
          _sectionTitle(state),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: SwanColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._eventWidgets(context),
      ],
    );
  }

  List<Widget> _eventWidgets(BuildContext context) {
    if (state.selectedViewMode == CalendarViewMode.facility) {
      return _facilityWidgets(context);
    }
    return state.visibleEvents
        .asMap()
        .entries
        .map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == state.visibleEvents.length - 1 ? 0 : 14,
            ),
            child: _EventCard(
              event: entry.value,
              occurrenceDate: state.selectedDate,
              permissions: state.permissions,
              onTap: () => onEventSelected(entry.value),
              onAttendanceTap: state.permissions.canOpenAttendance &&
                      entry.value.status ==
                          CalendarEventStatus.attendancePending
                  ? onAttendanceTap
                  : null,
            ),
          ),
        )
        .toList();
  }

  List<Widget> _facilityWidgets(BuildContext context) {
    final groups = <String, List<CalendarEvent>>{};
    for (final event in state.visibleEvents) {
      (groups[event.facility.displayName] ??= []).add(event);
    }
    return [
      // Screen 11 Facility Management & Health Overview Strip
      Container(
        margin: const EdgeInsets.only(bottom: 16),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TESİS & SALON MERKEZİ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: SwanColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Caferağa Spor Salonu Komuta Panosu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SwanColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🟢 %97 Tesis Sağlığı',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: SwanColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _ZoneChip(label: 'Court A', status: '🟢 Aktif'),
                _ZoneChip(label: 'Court B', status: '🟢 Aktif'),
                _ZoneChip(label: 'Taktik Odası', status: '🟢 Aktif'),
                _ZoneChip(label: 'Fitness', status: '🟡 Bakımda'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: SwanColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'TBF Tescili & İtfaiye Yangın Emniyet Belgesi Güncel • Ekipman: %94',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : SwanColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ...groups.entries.map(
        (group) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      group.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${group.value.length} Etkinlik',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SwanColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ...group.value.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EventCard(
                    event: event,
                    occurrenceDate: state.selectedDate,
                    permissions: state.permissions,
                    compact: true,
                    onTap: () => onEventSelected(event),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SwanColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SwanColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label • $status',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.permissions,
    required this.onTap,
    required this.occurrenceDate,
    this.onAttendanceTap,
    this.compact = false,
  });
  final CalendarEvent event;
  final CalendarPermissionSet permissions;
  final VoidCallback onTap;
  final VoidCallback? onAttendanceTap;
  final DateTime occurrenceDate;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conflict = event.highestConflict;
    final exception = event.exceptionFor(occurrenceDate);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? SwanColors.darkSurface : SwanColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _timeRange(event),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SwanColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: event.status),
              ],
            ),
            if (event.recurrenceRule != null) ...[
              const SizedBox(height: 6),
              Text(
                '↻ ${event.recurrenceRule!.label}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? SwanColors.darkText.withValues(alpha: .45)
                      : SwanColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.facility.displayName,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? SwanColors.darkText.withValues(alpha: .5)
                    : SwanColors.textSecondary,
              ),
            ),
            if (exception != null) ...[
              const SizedBox(height: 10),
              Text(
                _exceptionLabel(exception),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: SwanColors.warning,
                ),
              ),
            ],
            if (permissions.canViewRSVP &&
                event.rsvpSummary != null &&
                !compact) ...[
              const SizedBox(height: 12),
              _RsvpSummary(summary: event.rsvpSummary!),
            ],
            if (conflict != null) ...[
              const SizedBox(height: 10),
              _ConflictLabel(conflict: conflict),
            ],
            if (onAttendanceTap != null && !compact) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onAttendanceTap,
                  icon: const Icon(Icons.fact_check_rounded, size: 18),
                  label: const Text(
                    'Yoklama Al',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwanColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final CalendarEventStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CalendarEventStatus.attendancePending => SwanColors.warning,
      CalendarEventStatus.planned => SwanColors.primary,
      CalendarEventStatus.cancelled => SwanColors.error
    };
    final label = switch (status) {
      CalendarEventStatus.attendancePending => 'Yoklama Bekliyor',
      CalendarEventStatus.planned => 'Planlandı',
      CalendarEventStatus.cancelled => 'İptal'
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _RsvpSummary extends StatelessWidget {
  const _RsvpSummary({required this.summary});
  final RSVPParticipantSummary summary;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: SwanColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Ön RSVP:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            Text(
              '${summary.attending} Katılacak',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: SwanColors.success,
              ),
            ),
            Text(
              '${summary.unavailable} Mazeret',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: SwanColors.warning,
              ),
            ),
            Text(
              '${summary.pending} Bekliyor',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: SwanColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}

class _ConflictLabel extends StatelessWidget {
  const _ConflictLabel({required this.conflict});
  final ScheduleConflict conflict;
  @override
  Widget build(BuildContext context) {
    final color = switch (conflict.severity) {
      ConflictSeverity.hardBlocker => SwanColors.error,
      ConflictSeverity.softOverlap => SwanColors.warning,
      ConflictSeverity.advisory => SwanColors.primary
    };
    return Text(
      conflict.summary,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.isOffline, required this.isStale});
  final bool isOffline;
  final bool isStale;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          isOffline
              ? 'Çevrimdışı önbellek verisi gösteriliyor.'
              : 'Takvim verisi güncel olmayabilir.',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SwanColors.warning,
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: SwanColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

String _viewModeLabel(CalendarViewMode mode) => switch (mode) {
      CalendarViewMode.agenda => 'Ajanda',
      CalendarViewMode.day => 'Günlük',
      CalendarViewMode.week => 'Haftalık',
      CalendarViewMode.facility => 'Tesis Gridi'
    };
String _weekdayShort(int day) =>
    const ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'][day - 1];
String _sectionTitle(ScheduleCalendarState state) =>
    '${_weekdayShort(state.selectedDate.weekday)}, ${state.selectedDate.day} TEMMUZ SEANSLARI';
String _timeRange(CalendarEvent event) =>
    '${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')} - ${event.end.hour.toString().padLeft(2, '0')}:${event.end.minute.toString().padLeft(2, '0')}';
String _exceptionLabel(RecurrenceException exception) =>
    switch (exception.type) {
      RecurrenceExceptionType.cancelled => 'Bu tekrar iptal edildi',
      RecurrenceExceptionType.modified => 'Bu tekrar güncellendi',
      RecurrenceExceptionType.futureSeriesBoundary =>
        'İleri seri güncelleme sınırı'
    };
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
