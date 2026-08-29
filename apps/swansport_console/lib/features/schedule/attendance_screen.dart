import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'attendance_providers.dart';

/// Yoklama durumlarının sırası — hücreye tıklayınca bu döngü ilerler.
const List<String> _cycle = ['present', 'absent', 'late', 'excused'];

const Map<String, String> _statusLabel = {
  'present': 'Katıldı',
  'absent': 'Gelmedi',
  'late': 'Geç geldi',
  'excused': 'İzinli',
};

/// Sporcu × antrenman yoklama ızgarası.
///
/// Konsolun mobil uygulamaya karşı en belirgin kazancı bu ekran: mobilde bir
/// haftanın yoklaması antrenman antrenman, sporcu sporcu giriliyor. Burada
/// haftanın tamamı tek ızgarada; eksik kalmış bir hücre bakışta görünüyor ve
/// geçmişe dönük düzeltme aynı yerden yapılıyor.
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final week = ref.watch(attendanceWeekProvider);
    final events = ref.watch(attendanceEventsProvider);
    final athletes = ref.watch(attendanceAthletesProvider);
    final marks = ref.watch(attendanceMarksProvider);

    return Column(
      children: [
        _WeekBar(week: week),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: switch ((events, athletes)) {
            (AsyncError(:final error), _) => _message(
                t,
                'Antrenmanlar '
                'yüklenemedi: $error'),
            (_, AsyncError(:final error)) =>
              _message(t, 'Sporcular yüklenemedi: $error'),
            (AsyncLoading(), _) ||
            (_, AsyncLoading()) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            _ => _grid(
                context,
                ref,
                events.valueOrNull ?? const [],
                athletes.valueOrNull ?? const [],
                marks.valueOrNull ?? const {},
              ),
          },
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        const _Legend(),
      ],
    );
  }

  Widget _grid(
    BuildContext context,
    WidgetRef ref,
    List<EventRow> events,
    List<AthleteRow> athletes,
    Map<String, String> marks,
  ) {
    final t = Theme.of(context);

    if (events.isEmpty) {
      return _message(
          t,
          'Bu hafta antrenman yok.\nTakvimden antrenman ekleyince yoklama '
          'ızgarası burada oluşur.');
    }
    if (athletes.isEmpty) {
      return _message(t, 'Kulüpte aktif sporcu yok.');
    }

    const nameWidth = 220.0;
    const cellWidth = 110.0;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: nameWidth + cellWidth * events.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sütun başlıkları — antrenmanlar
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    SizedBox(
                      width: nameWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: ConsoleDensity.lg, bottom: ConsoleDensity.sm),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text('SPORCU', style: t.textTheme.labelSmall),
                        ),
                      ),
                    ),
                    for (final e in events)
                      SizedBox(
                        width: cellWidth,
                        child: _EventHeader(
                          event: e,
                          onMarkAll: () =>
                              _markColumn(context, ref, e, athletes, 'present'),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: t.colorScheme.outline),
              Expanded(
                child: ListView.separated(
                  itemCount: athletes.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: t.colorScheme.outline),
                  itemBuilder: (_, i) {
                    final a = athletes[i];
                    return SizedBox(
                      height: ConsoleDensity.rowHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: nameWidth,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: ConsoleDensity.lg),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(a.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.textTheme.bodyMedium),
                              ),
                            ),
                          ),
                          for (final e in events)
                            SizedBox(
                              width: cellWidth,
                              child: _Cell(
                                status: marks['${e.id}/${a.id}'],
                                onTap: () =>
                                    _cycleCell(context, ref, e, a, marks),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cycleCell(
    BuildContext context,
    WidgetRef ref,
    EventRow event,
    AthleteRow athlete,
    Map<String, String> marks,
  ) async {
    final current = marks['${event.id}/${athlete.id}'];
    final next = current == null
        ? _cycle.first
        : _cycle[(_cycle.indexOf(current) + 1) % _cycle.length];

    await _write(
        context,
        ref,
        (svc, clubId) => svc.markAttendance(
              clubId: clubId,
              eventId: event.id,
              athleteId: athlete.id,
              status: next,
            ));
  }

  Future<void> _markColumn(
    BuildContext context,
    WidgetRef ref,
    EventRow event,
    List<AthleteRow> athletes,
    String status,
  ) async {
    await _write(
        context,
        ref,
        (svc, clubId) => svc.markAttendanceBulk(
              clubId: clubId,
              eventId: event.id,
              athleteIds: athletes.map((a) => a.id).toList(),
              status: status,
            ));
  }

  /// Yazma + yenileme + hata bildirimi tek yerde.
  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(ClubDataService svc, String clubId) run,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;

    try {
      await run(ref.read(clubDataServiceProvider), club.id);
      ref.invalidate(attendanceMarksProvider);
      ref.invalidate(attendanceAuditProvider);
    } catch (e) {
      // RLS reddi burada görünür olmalı — sessiz başarısızlık, yoklamayı
      // kaydettiğini sanan bir antrenör demek.
      messenger.showSnackBar(SnackBar(
        content: Text('Kaydedilemedi: $e'),
        backgroundColor: errorColor,
      ));
    }
  }
}

Widget _message(ThemeData t, String text) => Center(
      child: Padding(
        padding: const EdgeInsets.all(ConsoleDensity.xxl),
        child: Text(text,
            textAlign: TextAlign.center, style: t.textTheme.bodySmall),
      ),
    );

class _WeekBar extends ConsumerWidget {
  const _WeekBar({required this.week});

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
          Text('${_d(week)} – ${_d(end)}',
              style: t.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
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
        ],
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.event, required this.onMarkAll});

  final EventRow event;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final d = event.startsAt;

    return Tooltip(
      message: '${event.title}\nTıkla: hepsini katıldı işaretle',
      child: InkWell(
        onTap: onMarkAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ConsoleDensity.xs, vertical: ConsoleDensity.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${days[d.weekday - 1]} ${d.day}.${d.month}',
                  style: t.textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(
                '${d.hour.toString().padLeft(2, '0')}:'
                '${d.minute.toString().padLeft(2, '0')}',
                style: t.textTheme.bodySmall,
              ),
              Text(event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.status, required this.onTap});

  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;

    final (color, icon) = switch (status) {
      'present' => (
          dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
          Icons.check_rounded
        ),
      'absent' => (
          dark ? const Color(0xFFFF8189) : const Color(0xFFDC2626),
          Icons.close_rounded
        ),
      'late' => (
          dark ? const Color(0xFFFFB65C) : const Color(0xFFD97706),
          Icons.schedule_rounded
        ),
      'excused' => (
          dark ? const Color(0xFF9AA4B2) : const Color(0xFF6B7280),
          Icons.event_busy_rounded
        ),
      _ => (t.colorScheme.outline, null),
    };

    return Tooltip(
      message: status == null
          ? 'İşaretlenmedi — tıkla'
          : _statusLabel[status] ?? status!,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: icon == null
                  ? Colors.transparent
                  : color.withValues(alpha: dark ? .18 : .12),
              border: Border.all(
                  color: icon == null
                      ? t.colorScheme.outline
                      : color.withValues(alpha: .5)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: icon == null ? null : Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

/// Durumların ne anlama geldiği.
///
/// Hücreler ikon + renk taşıyor; ikisi birlikte, çünkü renk tek başına
/// taşıyıcı olsaydı renk körlüğünde ızgara okunmazdı.
class _Legend extends ConsumerWidget {
  const _Legend();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
                'Hücreye tıkla: katıldı → gelmedi → geç geldi → '
                'izinli. Sütun başlığına tıkla: hepsini katıldı işaretle.',
                style: t.textTheme.bodySmall),
          ),
          TextButton.icon(
            onPressed: () => _showAuditTrail(context),
            icon: const Icon(Icons.history_rounded, size: 17),
            label: const Text('İşlem geçmişi'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAuditTrail(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yoklama işlem geçmişi'),
      content: SizedBox(
        width: 620,
        height: 440,
        child: Consumer(builder: (_, dialogRef, __) {
          final audit = dialogRef.watch(attendanceAuditProvider);
          return audit.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (error, _) => Center(
              child: Text('İşlem geçmişi yüklenemedi: $error'),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(
                  child: Text('Henüz kaydedilmiş yoklama işlemi yok.'),
                );
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  final before = row.previousStatus == null
                      ? 'ilk kayıt'
                      : _statusLabel[row.previousStatus] ?? row.previousStatus!;
                  final after = _statusLabel[row.status] ?? row.status;
                  final when =
                      '${row.createdAt.day.toString().padLeft(2, '0')}.'
                      '${row.createdAt.month.toString().padLeft(2, '0')} '
                      '${row.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${row.createdAt.minute.toString().padLeft(2, '0')}';
                  return ListTile(
                    dense: true,
                    title: Text(row.athleteName ?? 'Silinmiş sporcu'),
                    subtitle: Text('${row.eventTitle} · $before → $after\n'
                        '${row.actorName ?? 'Bilinmeyen kullanıcı'} · $when'),
                    isThreeLine: true,
                    leading: const Icon(Icons.fact_check_outlined),
                  );
                },
              );
            },
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}
