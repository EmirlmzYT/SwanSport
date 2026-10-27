import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';

class OfficialTeamRosters extends ConsumerWidget {
  const OfficialTeamRosters({super.key, required this.teamId});
  final String teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    if (access.clubRole != 'coach' && !access.isClubAdmin)
      return const SizedBox.shrink();
    return ref.watch(officialTeamRostersProvider(teamId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton(
              onPressed: () =>
                  ref.invalidate(officialTeamRostersProvider(teamId)),
              child: const Text('Resmi kadrolar yüklenemedi. Yeniden dene')),
          data: (rosters) => Column(children: [
            for (final roster in rosters)
              ListTile(
                title:
                    Text(roster.name, style: SwanType.bodySm(context.swan.ink)),
                subtitle: Text(
                    'Resmi esame · Revizyon ${roster.version} · ${roster.athleteIds.length} sporcu',
                    style: SwanType.caption(context.swan.inkMuted)),
                trailing: access.isHeadCoachForSport(roster.sportCode)
                    ? TextButton(
                        onPressed: () => _edit(context, ref, roster),
                        child: const Text('Kadroyu kilitle'))
                    : const Tooltip(
                        message:
                            'Resmi maç kadrosunu kilitlemek için en az 3. Kademe Başantrenör belgesi gereklidir',
                        child: Icon(Icons.lock_outline_rounded)),
              ),
            if (rosters.any((r) => !access.isHeadCoachForSport(r.sportCode)))
              Text(
                  'Resmi maç kadrosunu kilitlemek için en az 3. Kademe Başantrenör belgesi gereklidir.',
                  style: SwanType.caption(context.swan.inkMuted)),
          ]),
        );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, OfficialTeamRoster roster) async {
    try {
      final members = await ref.read(teamRosterProvider(teamId).future);
      if (!context.mounted) return;
      final selected = roster.athleteIds.toSet();
      final reason = TextEditingController();
      bool saving = false;
      String? error;
      await showDialog<void>(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (ctx, update) => AlertDialog(
                    title: const Text('Resmi maç kadrosunu kilitle'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final member in members)
                        CheckboxListTile(
                            value: selected.contains(member.athleteId),
                            title: Text(member.name),
                            onChanged: saving
                                ? null
                                : (value) => update(() {
                                      if (value == true) {
                                        selected.add(member.athleteId);
                                      } else {
                                        selected.remove(member.athleteId);
                                      }
                                    })),
                      for (final id in roster.athleteIds.where(
                          (id) => !members.any((m) => m.athleteId == id)))
                        CheckboxListTile(
                            value: selected.contains(id),
                            title: const Text('Önceki resmi kadro kaydı'),
                            onChanged: saving
                                ? null
                                : (value) => update(() {
                                      if (value == true) {
                                        selected.add(id);
                                      } else {
                                        selected.remove(id);
                                      }
                                    })),
                      TextField(
                          controller: reason,
                          enabled: !saving,
                          maxLength: 500,
                          decoration: const InputDecoration(
                              labelText: 'Revizyon gerekçesi')),
                      if (error != null)
                        Text(error!, style: SwanType.bodySm(ctx.swan.danger)),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!ref
                                      .read(swanAccessProvider)
                                      .isHeadCoachForSport(roster.sportCode))
                                    return;
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await ref
                                        .read(coachGuardianServiceProvider)
                                        .publishRoster(roster,
                                            selected.toList(), reason.text);
                                    ref.invalidate(
                                        officialTeamRostersProvider(teamId));
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted)
                                      update(() {
                                        saving = false;
                                        error = 'Kadro kaydedilemedi: $e';
                                      });
                                  }
                                },
                          child: Text(
                              saving ? 'Kaydediliyor…' : 'Onayla ve kilitle')),
                    ],
                  )));
      WidgetsBinding.instance.addPostFrameCallback((_) => reason.dispose());
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Takım kadrosu yüklenemedi. Yeniden dene.')));
    }
  }
}
