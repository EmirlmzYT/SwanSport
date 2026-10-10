import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

class CoachQuickNotesSheet extends ConsumerStatefulWidget {
  const CoachQuickNotesSheet({required this.sessionId, super.key});
  final String sessionId;
  @override
  ConsumerState<CoachQuickNotesSheet> createState() => _CoachQuickNotesState();
}

class _CoachQuickNotesState extends ConsumerState<CoachQuickNotesSheet> {
  final _note = TextEditingController();
  String? _athleteId, _error;
  bool _busy = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(String tag, String text) async {
    if (_busy || text.trim().isEmpty || _athleteId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(trainingSessionServiceProvider)
          .submitCoachDrillNote(
            widget.sessionId,
            _athleteId!,
            text.trim(),
            tag,
          );
      if (!mounted) return;
      _note.clear();
      ref.invalidate(sessionCoachDrillNotesProvider(widget.sessionId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antrenör notu kaydedildi.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Not kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final people = ref.watch(sessionParticipantsProvider(widget.sessionId));
    final session = ref
        .watch(trainingSessionProvider(widget.sessionId))
        .valueOrNull;
    final notes = ref.watch(sessionCoachDrillNotesProvider(widget.sessionId));
    final access = ref.watch(swanAccessProvider);
    if (!access.isClubStaff ||
        session == null ||
        session.isPersonal ||
        !(session.isLive || session.awaitingApproval)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hızlı antrenör notu', style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.md),
          people.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(
              'Katılanlar yüklenemedi: $e',
              style: SwanType.bodySm(c.danger),
            ),
            data: (list) {
              final selected = list.any((p) => p.athleteId == _athleteId)
                  ? _athleteId
                  : null;
              final enabled = !_busy && selected != null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(selected),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Notun ait olduğu sporcu',
                    ),
                    items: [
                      for (final p in list)
                        DropdownMenuItem(
                          value: p.athleteId,
                          child: Text(p.name),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) => setState(() => _athleteId = id),
                  ),
                  if (list.isEmpty)
                    Text(
                      'Not için oturuma katılan sporcu gerekli.',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  const SizedBox(height: SwanSpace.md),
                  Wrap(
                    spacing: SwanSpace.sm,
                    runSpacing: SwanSpace.sm,
                    children: [
                      for (final tag in [
                        'Teknik İyi',
                        'Duruş Bozuk',
                        'Erken Bıraktı',
                        'Mükemmel Açı',
                        'Hızlan',
                      ])
                        ActionChip(
                          label: Text(tag),
                          onPressed: enabled ? () => _send(tag, tag) : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: SwanSpace.md),
                  TextField(
                    controller: _note,
                    enabled: !_busy,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Özel not'),
                  ),
                  OutlinedButton(
                    onPressed: enabled
                        ? () => _send('Özel not', _note.text)
                        : null,
                    child: Text(_busy ? 'Kaydediliyor…' : 'Notu kaydet'),
                  ),
                ],
              );
            },
          ),
          if (_error != null) Text(_error!, style: SwanType.bodySm(c.danger)),
          notes.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text(
              'Not günlüğü yüklenemedi: $e',
              style: SwanType.caption(c.danger),
            ),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in list.take(5))
                  Padding(
                    padding: const EdgeInsets.only(top: SwanSpace.sm),
                    child: Text(
                      '${people.valueOrNull?.where((p) => p.athleteId == note.athleteId).firstOrNull?.name ?? 'Sporcu'} · ${note.note}',
                      style: SwanType.bodySm(c.ink),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
