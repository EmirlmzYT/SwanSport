import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/widgets/swan_module_app_bar.dart';

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
    return SwanScaffold(
      backgroundColor: c.bg,
      appBar: swanModuleAppBar(context, title: 'Etkinlik Detayı'),
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
                        if (ref.watch(featureEnabledProvider(
                            FeatureFlags.eventPreparation))) ...[
                          const SizedBox(height: SwanSpace.lg),
                          Row(children: [
                            Expanded(
                                child: Text('Hazırlık kartı',
                                    style: SwanType.h3(c.ink))),
                            if (isStaff)
                              IconButton(
                                  tooltip: 'Hazırlığı düzenle',
                                  onPressed: () => _editPreparation(
                                      context, ref, e.id, e.startsAt),
                                  icon: const Icon(Icons.edit_rounded))
                          ]),
                          ref.watch(eventPreparationProvider(e.id)).when(
                                loading: premiumLoading,
                                error: (err, _) => Text(
                                    'Hazırlık bilgisi eklenmemiş.',
                                    style: SwanType.bodySm(c.inkMuted)),
                                data: (p) => Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (p.meetingAt != null)
                                                Text(
                                                    'Buluşma: ${p.meetingAt!.hour.toString().padLeft(2, '0')}:${p.meetingAt!.minute.toString().padLeft(2, '0')}'),
                                              if (p.equipment.isNotEmpty)
                                                Text(
                                                    'Ekipman: ${p.equipment.join(', ')}'),
                                              if (p.kitNote != null)
                                                Text('Kıyafet: ${p.kitNote}'),
                                              if (p.coachNote != null)
                                                Text(p.coachNote!),
                                            ]))),
                              ),
                        ],
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
                                            onTap: e.startsAt.isBefore(
                                                        DateTime.now()) &&
                                                    row.attendance ==
                                                        'present' &&
                                                    ref.watch(
                                                        featureEnabledProvider(
                                                            FeatureFlags
                                                                .teamKudos))
                                                ? () => _sendKudo(context, ref,
                                                    e.id, row.athleteId)
                                                : null,
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

  static Future<void> _editPreparation(BuildContext context, WidgetRef ref,
      String eventId, DateTime startsAt) async {
    final equipment = TextEditingController();
    final kit = TextEditingController();
    final note = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hazırlık kartını düzenle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: equipment,
                decoration: const InputDecoration(
                    labelText: 'Ekipman (virgülle ayır)')),
            TextField(
                controller: kit,
                decoration: const InputDecoration(labelText: 'Kıyafet/forma')),
            TextField(
                controller: note,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Antrenör notu')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (saved == true) {
      await ref.read(swanExperienceServiceProvider).savePreparation(eventId,
          meetingAt: startsAt.subtract(const Duration(minutes: 30)),
          equipment: equipment.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          kitNote: kit.text,
          coachNote: note.text);
      ref.invalidate(eventPreparationProvider(eventId));
    }
    equipment.dispose();
    kit.dispose();
    note.dispose();
  }

  static Future<void> _sendKudo(BuildContext context, WidgetRef ref,
      String eventId, String athleteId) async {
    final badge = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final entry in const {
            'team_player': 'İyi takım arkadaşı',
            'fair_play': 'Fair play',
            'helpful': 'Yardımsever',
            'determined': 'Mücadeleci',
            'motivator': 'Takımı motive etti',
          }.entries)
            ListTile(
                leading: const Icon(Icons.favorite_rounded),
                title: Text(entry.value),
                onTap: () => Navigator.pop(context, entry.key)),
        ]),
      ),
    );
    if (badge == null) return;
    await ref
        .read(swanExperienceServiceProvider)
        .sendKudo(eventId, athleteId, badge);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takım rozeti gönderildi.')));
    }
  }
}
