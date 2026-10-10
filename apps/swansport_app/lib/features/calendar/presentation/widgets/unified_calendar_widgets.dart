import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_tabs.dart';

class UnifiedCalendarFilters extends StatelessWidget {
  const UnifiedCalendarFilters({
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final CalendarEventType? selected;
  final ValueChanged<CalendarEventType?> onSelect;
  @override
  Widget build(BuildContext context) => SwanPillTabs(
        labels: const [
          'Tümü',
          'Kulüp Antrenmanları',
          'Resmi Federasyon Faaliyetleri',
        ],
        selected: selected == null
            ? 0
            : selected == CalendarEventType.clubTraining
                ? 1
                : 2,
        onSelect: (index) => onSelect(
          switch (index) {
            1 => CalendarEventType.clubTraining,
            2 => CalendarEventType.officialFederation,
            _ => null
          },
        ),
      );
}

Color calendarEventColor(SwanPalette c, CalendarEventType type) =>
    switch (type) {
      CalendarEventType.officialFederation => c.accent,
      CalendarEventType.clubTraining => c.success,
      CalendarEventType.clubMatch => c.warning,
      _ => c.inkMuted,
    };

class UnifiedCalendarDays extends StatelessWidget {
  const UnifiedCalendarDays({
    required this.selected,
    required this.types,
    required this.onSelect,
    super.key,
  });
  final DateTime selected;
  final Map<int, Set<CalendarEventType>> types;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final first = DateTime.utc(selected.year, selected.month);
    final count = DateTime.utc(selected.year, selected.month + 1, 0).day;
    final offset = first.weekday - 1;
    return Column(
      children: [
        Row(
          children: [
            for (final name in const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'])
              Expanded(
                child: Center(
                  child: Text(name, style: SwanType.caption(c.inkMuted)),
                ),
              ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        for (var week = 0; week < (count + offset + 6) ~/ 7; week++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                    child: _cell(context, week * 7 + col - offset + 1, count)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int count) {
    if (day < 1 || day > count) return const SizedBox.shrink();
    final c = context.swan;
    final active = selected.day == day;
    return Semantics(
      label: '$day ${selected.month} ${selected.year}',
      selected: active,
      child: InkWell(
        key: ValueKey('calendar-day-$day'),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        onTap: () => onSelect(DateTime(selected.year, selected.month, day)),
        child: Container(
          margin: const EdgeInsets.all(SwanSpace.xs),
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
          decoration: BoxDecoration(
            color: active ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
          child: Column(
            children: [
              Text('$day', style: SwanType.caption(active ? c.accent : c.ink)),
              const SizedBox(height: SwanSpace.xs),
              Wrap(
                spacing: SwanSpace.xs,
                children: [
                  for (final type in CalendarEventType.values)
                    if (types[day]?.contains(type) ?? false)
                      Icon(
                        Icons.circle,
                        key: ValueKey('calendar-dot-$day-${type.name}'),
                        size: SwanSpace.sm,
                        color: calendarEventColor(c, type),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfficialActivityCard extends StatelessWidget {
  const OfficialActivityCard({required this.activity, super.key});
  final FederationActivity activity;
  String get _kind => activity.isMatch
      ? 'Müsabaka'
      : switch (activity.kind) {
          'league' => 'Lig',
          'tournament' => 'Şampiyona',
          'cup' => 'Kupa',
          'camp' => 'Gelişim Kampı',
          _ => 'Faaliyet'
        };
  String _day(DateTime value) {
    final d = calendarTurkeyTime(value);
    return '${d.day}.${d.month}.${d.year}';
  }

  String get _range {
    if (activity.allDay && activity.endsAt != null) {
      return '${_day(activity.startsAt)} – ${_day(activity.endsAt!.subtract(const Duration(microseconds: 1)))}';
    }
    final d = calendarTurkeyTime(activity.startsAt);
    return '${_day(activity.startsAt)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get _status => switch (activity.status) {
        'open' || 'scheduled' => 'Planlandı',
        'running' => 'Devam ediyor',
        'finished' || 'played' => 'Tamamlandı',
        'cancelled' => 'İptal edildi',
        _ => activity.status,
      };
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Card(
      color: c.surface,
      child: ListTile(
        key: ValueKey('official-activity-${activity.isMatch}-${activity.id}'),
        leading: Icon(Icons.verified_outlined, color: c.accent),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resmi Faaliyet / $_kind', style: SwanType.caption(c.accent)),
            Text(activity.title, style: SwanType.bodySm(c.ink)),
          ],
        ),
        subtitle: Text(
          '$_range · ${activity.location ?? 'Yer belirtilmedi'}',
          style: SwanType.caption(c.inkMuted),
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SwanSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    activity.title,
                    style: SwanType.h3(context.swan.ink),
                  ),
                  const SizedBox(height: SwanSpace.lg),
                  for (final line in [
                    activity.federationName,
                    activity.officeName,
                    'Faaliyet yılı: ${activity.seasonLabel}',
                    'Yer: ${activity.location ?? 'Belirtilmedi'}',
                    'Tarih: $_range',
                    'Kategori: ${activity.category ?? 'Belirtilmedi'}',
                    'Durum: $_status',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                      child: Text(
                        line,
                        style: SwanType.bodySm(context.swan.ink),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
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

class CalendarSessionCard extends StatelessWidget {
  const CalendarSessionCard({required this.event, super.key});
  final UnifiedCalendarEvent event;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final time = calendarTurkeyTime(event.startsAt);
    return Card(
      color: c.surface,
      child: ListTile(
        leading: Icon(Icons.sports_outlined, color: c.success),
        title: Text(event.title, style: SwanType.bodySm(c.ink)),
        subtitle: Text(
          'Kulüp Antrenmanı · ${time.day}.${time.month} · '
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · '
          '${switch (event.status) {
            'live' => 'Canlı',
            'completed' => 'Tamamlandı',
            'review' => 'Onay bekliyor',
            'cancelled' => 'İptal edildi',
            _ => 'Planlandı'
          }}',
          style: SwanType.caption(c.inkMuted),
        ),
      ),
    );
  }
}
