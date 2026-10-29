import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/pro_theme.dart';
import '../../widgets/pro_ui_components.dart';

enum CalendarViewMode { list, month }

class ProCalendarScreen extends ConsumerStatefulWidget {
  const ProCalendarScreen({super.key});

  @override
  ConsumerState<ProCalendarScreen> createState() => _ProCalendarScreenState();
}

class _ProCalendarScreenState extends ConsumerState<ProCalendarScreen> {
  late CalendarMonth _month;
  late DateTime _selectedDay;
  CalendarViewMode _viewMode = CalendarViewMode.list;

  @override
  void initState() {
    super.initState();
    final today = calendarTurkeyTime(DateTime.now());
    _month = CalendarMonth(today.year, today.month);
    _selectedDay = DateTime.utc(today.year, today.month, today.day);
  }

  void _moveMonth(int delta) {
    final next = DateTime.utc(_month.year, _month.month + delta);
    setState(() {
      _month = CalendarMonth(next.year, next.month);
      _selectedDay = DateTime.utc(next.year, next.month, 1);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(unifiedCalendarMonthProvider(_month));
    await ref.read(unifiedCalendarMonthProvider(_month).future);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(unifiedCalendarMonthProvider(_month));
    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _CalendarError(
              message: classifyOperationError(error).userMessage,
              onRetry: _refresh,
            ),
            data: (calendar) => RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                children: [
                  _CalendarHeader(
                    month: _month,
                    viewMode: _viewMode,
                    onViewModeChanged: (mode) =>
                        setState(() => _viewMode = mode),
                    onPrevious: () => _moveMonth(-1),
                    onNext: () => _moveMonth(1),
                    onToday: () {
                      final today = calendarTurkeyTime(DateTime.now());
                      setState(() {
                        _month = CalendarMonth(today.year, today.month);
                        _selectedDay =
                            DateTime.utc(today.year, today.month, today.day);
                      });
                    },
                  ),
                  if (calendar.officialUnavailable ||
                      calendar.clubUnavailable) ...[
                    const SizedBox(height: 14),
                    _PartialDataBanner(
                      officialUnavailable: calendar.officialUnavailable,
                      clubUnavailable: calendar.clubUnavailable,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_viewMode == CalendarViewMode.list)
                    _CalendarListView(
                      month: _month,
                      events: calendar.events,
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 860;
                        final calendarPanel = _MonthGrid(
                          month: _month,
                          events: calendar.events,
                          selectedDay: _selectedDay,
                          onSelectDay: (day) =>
                              setState(() => _selectedDay = day),
                        );
                        final agenda = _Agenda(
                          selectedDay: _selectedDay,
                          events: calendar.events
                              .where((event) => event.occursOn(_selectedDay))
                              .toList(growable: false),
                        );
                        if (!wide) {
                          return Column(
                            children: [
                              calendarPanel,
                              const SizedBox(height: 16),
                              agenda,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 7, child: calendarPanel),
                            const SizedBox(width: 18),
                            Expanded(flex: 4, child: agenda),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final CalendarMonth month;
  final CalendarViewMode viewMode;
  final ValueChanged<CalendarViewMode> onViewModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12314A), ProTheme.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProTheme.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          final titleRow = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ProTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: ProTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_monthName(month.month)} ${month.year}',
                      style: const TextStyle(
                        color: ProTheme.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Kulüp ve resmî federasyon programı',
                      style: TextStyle(color: ProTheme.muted, fontSize: 11.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final viewToggle = SegmentedButton<CalendarViewMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: ProTheme.surfaceRaised,
              selectedBackgroundColor: ProTheme.primary.withValues(alpha: 0.15),
              selectedForegroundColor: ProTheme.primary,
              foregroundColor: ProTheme.muted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            segments: const [
              ButtonSegment(
                value: CalendarViewMode.list,
                label: Text('Liste', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: CalendarViewMode.month,
                label: Text('Ay', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (set) => onViewModeChanged(set.first),
          );

          final navActions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Önceki ay',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(48, 36),
                ),
                child: const Text('Bugün'),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Sonraki ay',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleRow,
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    viewToggle,
                    navActions,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleRow),
              const SizedBox(width: 14),
              viewToggle,
              const SizedBox(width: 10),
              navActions,
            ],
          );
        },
      ),
    );
  }
}

class _CalendarListView extends StatelessWidget {
  const _CalendarListView({
    required this.month,
    required this.events,
  });

  final CalendarMonth month;
  final List<UnifiedCalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const ProEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Bu ay için planlanmış etkinlik yok',
        subtitle:
            'Kulüp veya resmî federasyon takviminde henüz kayıtlı faaliyet bulunmuyor.',
      );
    }

    final sorted = List<UnifiedCalendarEvent>.from(events)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final groups = <DateTime, List<UnifiedCalendarEvent>>{};
    for (final event in sorted) {
      final dayKey = DateTime.utc(
          event.startsAt.year, event.startsAt.month, event.startsAt.day);
      groups.putIfAbsent(dayKey, () => []).add(event);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ProTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entry.key.day} ${_monthName(entry.key.month)} ${_weekdayName(entry.key.weekday)}',
                    style: const TextStyle(
                      color: ProTheme.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${entry.value.length})',
                  style: const TextStyle(
                    color: ProTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          for (final event in entry.value) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AgendaItem(event: event),
            ),
          ],
        ],
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final CalendarMonth month;
  final List<UnifiedCalendarEvent> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime.utc(month.year, month.month);
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProTheme.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in [
                'Pzt',
                'Sal',
                'Çar',
                'Per',
                'Cum',
                'Cmt',
                'Paz'
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ProTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leading + days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final dayNumber = index - leading + 1;
              final day = DateTime.utc(month.year, month.month, dayNumber);
              final dayEvents = events
                  .where((event) => event.occursOn(day))
                  .toList(growable: false);
              final selected = _sameDay(day, selectedDay);
              final today = _sameDay(
                day,
                calendarTurkeyTime(DateTime.now()),
              );
              return Semantics(
                button: true,
                selected: selected,
                label: '$dayNumber ${_monthName(month.month)}, '
                    '${dayEvents.length} etkinlik',
                child: InkWell(
                  key: ValueKey('pro-calendar-day-$dayNumber'),
                  onTap: () => onSelectDay(day),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      color: selected
                          ? ProTheme.primary.withValues(alpha: 0.14)
                          : ProTheme.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? ProTheme.primary
                            : today
                                ? ProTheme.secondary.withValues(alpha: 0.7)
                                : ProTheme.line.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: selected ? ProTheme.primary : ProTheme.ink,
                            fontWeight: selected || today
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        if (dayEvents.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final event in dayEvents.take(3))
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: _eventColor(event.type),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda({required this.selectedDay, required this.events});

  final DateTime selectedDay;
  final List<UnifiedCalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDay.day} ${_monthName(selectedDay.month)} gündemi',
            style: const TextStyle(
              color: ProTheme.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            events.isEmpty ? 'Planlanmış kayıt yok' : '${events.length} kayıt',
            style: const TextStyle(color: ProTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const _EmptyAgenda()
          else
            for (final event in events) ...[
              _AgendaItem(event: event),
              if (event != events.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _AgendaItem extends StatelessWidget {
  const _AgendaItem({required this.event});

  final UnifiedCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final time = calendarTurkeyTime(event.startsAt);
    final accent = _eventColor(event.type);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProTheme.background.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_eventIcon(event.type), color: accent, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')} · '
                  '${_eventLabel(event.type)}',
                  style: const TextStyle(color: ProTheme.muted, fontSize: 11.5),
                ),
                if (event.place != null && event.place!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.place!,
                    style: const TextStyle(color: ProTheme.muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: ProTheme.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProTheme.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_outlined, color: ProTheme.muted, size: 28),
          SizedBox(height: 8),
          Text(
            'Bu gün için operasyon kaydı yok.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ProTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PartialDataBanner extends StatelessWidget {
  const _PartialDataBanner({
    required this.officialUnavailable,
    required this.clubUnavailable,
  });

  final bool officialUnavailable;
  final bool clubUnavailable;

  @override
  Widget build(BuildContext context) {
    final source = officialUnavailable && clubUnavailable
        ? 'Resmî ve kulüp'
        : officialUnavailable
            ? 'Resmî'
            : 'Kulüp';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$source takvim kaynağı şu an alınamadı; görünen kayıtlar eksik olabilir.',
              style: const TextStyle(color: ProTheme.ink, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined,
                color: Color(0xFFF87171), size: 40),
            const SizedBox(height: 12),
            const Text(
              'Takvim yüklenemedi',
              style:
                  TextStyle(color: ProTheme.ink, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ProTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthName(int month) => const [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ][month - 1];

String _weekdayName(int weekday) => const [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ][weekday - 1];

Color _eventColor(CalendarEventType type) => switch (type) {
      CalendarEventType.officialFederation => ProTheme.secondary,
      CalendarEventType.clubTraining => ProTheme.primary,
      CalendarEventType.clubMatch => const Color(0xFFA78BFA),
      CalendarEventType.clubMeeting => const Color(0xFFFBBF24),
      CalendarEventType.clubOther => ProTheme.muted,
    };

IconData _eventIcon(CalendarEventType type) => switch (type) {
      CalendarEventType.officialFederation => Icons.account_balance_outlined,
      CalendarEventType.clubTraining => Icons.fitness_center_rounded,
      CalendarEventType.clubMatch => Icons.sports_score_rounded,
      CalendarEventType.clubMeeting => Icons.groups_2_outlined,
      CalendarEventType.clubOther => Icons.event_note_outlined,
    };

String _eventLabel(CalendarEventType type) => switch (type) {
      CalendarEventType.officialFederation => 'Resmî program',
      CalendarEventType.clubTraining => 'Antrenman',
      CalendarEventType.clubMatch => 'Müsabaka',
      CalendarEventType.clubMeeting => 'Toplantı',
      CalendarEventType.clubOther => 'Kulüp etkinliği',
    };
