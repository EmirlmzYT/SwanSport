import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/pro_theme.dart';

class ProCalendarScreen extends ConsumerStatefulWidget {
  const ProCalendarScreen({super.key});

  @override
  ConsumerState<ProCalendarScreen> createState() => _ProCalendarScreenState();
}

class _ProCalendarScreenState extends ConsumerState<ProCalendarScreen> {
  late CalendarMonth _month;
  late DateTime _selectedDay;

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
      _selectedDay = DateTime.utc(next.year, next.month);
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
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                children: [
                  _CalendarHeader(
                    month: _month,
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
                  const SizedBox(height: 18),
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
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final CalendarMonth month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12314A), ProTheme.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProTheme.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ProTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: ProTheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthName(month.month)} ${month.year}',
                      style: const TextStyle(
                        color: ProTheme.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Kulüp ve resmî federasyon programı',
                      style: TextStyle(color: ProTheme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Önceki ay',
              ),
              TextButton(onPressed: onToday, child: const Text('Bugün')),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Sonraki ay',
              ),
            ],
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.all(14),
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ProTheme.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 0.9,
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
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: selected
                          ? ProTheme.primary.withValues(alpha: 0.14)
                          : ProTheme.background.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
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
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: selected ? ProTheme.primary : ProTheme.ink,
                            fontWeight: selected || today
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        if (dayEvents.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final event in dayEvents.take(3))
                                Container(
                                  width: 5,
                                  height: 5,
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            events.isEmpty ? 'Planlanmış kayıt yok' : '${events.length} kayıt',
            style: const TextStyle(color: ProTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            const _EmptyAgenda()
          else
            for (final event in events) ...[
              _AgendaItem(event: event),
              if (event != events.last) const SizedBox(height: 9),
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
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')} · '
                  '${_eventLabel(event.type)}',
                  style: const TextStyle(color: ProTheme.muted, fontSize: 11),
                ),
                if (event.place != null && event.place!.isNotEmpty) ...[
                  const SizedBox(height: 3),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: ProTheme.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProTheme.line),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_outlined, color: ProTheme.muted, size: 30),
          SizedBox(height: 9),
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
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24)),
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
                color: Color(0xFFF87171), size: 42),
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
              style: const TextStyle(color: ProTheme.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
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
