import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/widgets/swan_page_header.dart';

class EventRosterDetailScreen extends ConsumerWidget {
  const EventRosterDetailScreen(
      {super.key, this.eventId, this.title = 'Etkinlik'});
  final String? eventId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final args = ModalRoute.of(context)?.settings.arguments;
    final id = eventId ??
        (args is String
            ? args
            : args is Map
                ? args['id'] as String?
                : null);
    final events = ref.watch(eventsProvider);
    final isStaff = ref.watch(swanAccessProvider).isClubStaff;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(eventsProvider);
            if (id != null) ref.invalidate(eventRosterProvider(id));
            await ref.read(eventsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
            children: [
              const SwanPageHeader(title: 'Etkinlik Detayı'),
              const SizedBox(height: SwanSpace.md),
              events.when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (events) {
                  EventRow? event;
                  for (final row in events) {
                    if (row.id == id) event = row;
                  }
                  if (event == null)
                    return premiumEmpty(context,
                        icon: Icons.event_busy_outlined,
                        title: 'Etkinlik bulunamadı',
                        subtitle: 'Takvimden erişebildiğin bir etkinliği seç.',
                        actionLabel: 'Takvimi aç',
                        onAction: () => Navigator.pushReplacementNamed(
                            context, '/calendar'));
                  final e = event;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: SwanType.h2(c.ink)),
                        const SizedBox(height: SwanSpace.sm),
                        Text(
                            '${e.startsAt.day}.${e.startsAt.month}.${e.startsAt.year} · ${e.startsAt.hour.toString().padLeft(2, '0')}:${e.startsAt.minute.toString().padLeft(2, '0')}',
                            style: SwanType.bodySm(c.inkMuted)),
                        if (e.place?.isNotEmpty ?? false)
                          Text(e.place!, style: SwanType.bodySm(c.inkMuted)),
                        if (isStaff) ...[
                          const SizedBox(height: SwanSpace.lg),
                          Text('Katılım ve yoklama', style: SwanType.h3(c.ink)),
                          ref.watch(eventRosterProvider(e.id)).when(
                                loading: premiumLoading,
                                error: (err, _) =>
                                    premiumError(context, '$err'),
                                data: (rows) => rows.isEmpty
                                    ? Text('Bu etkinliğin kadrosu boş.',
                                        style: SwanType.bodySm(c.inkMuted))
                                    : Column(children: [
                                        for (final row in rows)
                                          ListTile(
                                            title: Text(row.fullName),
                                            subtitle: Text(
                                                'Yanıt: ${_rsvp(row.rsvp)}'),
                                            trailing: Text(
                                                _attendance(row.attendance)),
                                          )
                                      ]),
                              ),
                        ],
                      ]);
                },
              ),
            ],
          ),
        ),
      ))),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  static String _rsvp(String? status) => switch (status) {
        'attending' => 'Katılacak',
        'uncertain' => 'Belirsiz',
        'unavailable' => 'Katılamayacak',
        _ => 'Yanıt yok',
      };
  static String _attendance(String? status) => switch (status) {
        'present' => 'Katıldı',
        'absent' => 'Katılmadı',
        'late' => 'Geç',
        'excused' => 'İzinli',
        _ => 'Yoklama alınmadı',
      };
}
