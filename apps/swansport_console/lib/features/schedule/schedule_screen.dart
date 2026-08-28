import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import 'attendance_providers.dart';
import 'series_dialog.dart';

/// Haftalık takvim.
///
/// Yedi günü yan yana koymak masaüstünün doğal kazancı: antrenmanların
/// haftaya nasıl dağıldığı — hangi gün boş, hangi gün üst üste — tek bakışta
/// görünüyor. Mobilde bu ancak gün gün gezilerek anlaşılıyor.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final week = ref.watch(attendanceWeekProvider);
    final events = ref.watch(attendanceEventsProvider);

    return Column(
      children: [
        _Toolbar(week: week),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: events.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ConsoleDensity.xxl),
                child: SelectableText('Takvim yüklenemedi: $e',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodySmall),
              ),
            ),
            data: (list) => _WeekGrid(week: week, events: list),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.week});

  final DateTime week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final end = week.add(const Duration(days: 6));

    void shift(int days) {
      ref.read(attendanceWeekProvider.notifier).state =
          week.add(Duration(days: days));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki hafta',
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: () => shift(-7),
          ),
          IconButton(
            tooltip: 'Sonraki hafta',
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: () => shift(7),
          ),
          const SizedBox(width: ConsoleDensity.sm),
          Text(
            '${_d(week)} – ${_d(end)} ${end.year}',
            style:
                t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: ConsoleDensity.md),
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              final monday = now.subtract(Duration(days: now.weekday - 1));
              ref.read(attendanceWeekProvider.notifier).state =
                  DateTime(monday.year, monday.month, monday.day);
            },
            child: const Text('Bu hafta'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => showSeriesDialog(context, ref),
            icon: const Icon(Icons.repeat_rounded, size: 17),
            label: const Text('Tekrarlayan antrenman'),
          ),
        ],
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.week, required this.events});

  final DateTime week;
  final List<EventRow> events;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const dayNames = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) VerticalDivider(width: 1, color: t.colorScheme.outline),
          Expanded(
            child: _DayColumn(
              name: dayNames[i],
              date: week.add(Duration(days: i)),
              isToday: _sameDay(week.add(Duration(days: i)), today),
              events: events
                  .where((e) => _sameDay(e.startsAt, week.add(Duration(days: i))))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.name,
    required this.date,
    required this.isToday,
    required this.events,
  });

  final String name;
  final DateTime date;
  final bool isToday;
  final List<EventRow> events;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 46,
          color: isToday
              ? t.colorScheme.primary.withValues(alpha: .07)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(),
                  style: t.textTheme.labelSmall?.copyWith(
                    color: isToday ? t.colorScheme.primary : null,
                  )),
              Text(
                '${date.day}.${date.month}',
                style: t.textTheme.bodySmall?.copyWith(
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isToday ? t.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: events.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  padding: const EdgeInsets.all(ConsoleDensity.sm),
                  itemCount: events.length,
                  itemBuilder: (_, i) => _EventCard(event: events[i]),
                ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventRow event;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = event.startsAt;

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.sm),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: t.colorScheme.primary.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}',
            style: t.textTheme.labelSmall
                ?.copyWith(color: t.colorScheme.primary),
          ),
          const SizedBox(height: 2),
          Text(event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (event.place != null && event.place!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(event.place!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall),
          ],
          if (event.hasResult) ...[
            const SizedBox(height: ConsoleDensity.xs),
            StatusPill(label: event.scoreLabel, tone: PillTone.info),
          ],
        ],
      ),
    );
  }
}
