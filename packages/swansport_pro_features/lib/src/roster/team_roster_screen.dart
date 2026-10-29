import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';

String _searchText(String value) =>
    value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

class SharedTeamRosterScreen extends ConsumerStatefulWidget {
  const SharedTeamRosterScreen({required this.target, super.key});
  final TeamRouteTarget target;

  @override
  ConsumerState<SharedTeamRosterScreen> createState() =>
      _SharedTeamRosterScreenState();
}

class _SharedTeamRosterScreenState
    extends ConsumerState<SharedTeamRosterScreen> {
  late TeamRouteTarget _target;
  String _query = '';
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _target = widget.target;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (error) {
      if (mounted) {
        setState(() => _message = classifyOperationError(error).userMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref
      ..invalidate(teamRosterProvider(_target.teamId))
      ..invalidate(clubAthletesProvider)
      ..invalidate(officialTeamRostersProvider(_target.teamId));
  }

  Future<void> _linkAthlete(String clubId, String athleteId) async {
    final candidates =
        await ref.read(clubMemberCandidatesProvider(clubId).future);
    if (!mounted) return;
    final profileId = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Hesapla eşleştir')),
            if (candidates.isEmpty)
              const ListTile(
                title: Text('Eşleştirilebilecek kulüp üyesi yok.'),
              ),
            for (final candidate in candidates)
              ListTile(
                title: Text(candidate.displayName),
                onTap: () => Navigator.pop(sheetContext, candidate.profileId),
              ),
          ],
        ),
      ),
    );
    if (profileId == null) return;
    await _run(
      () async {
        await ref.read(athleteLinkCommandProvider)(athleteId, profileId);
        ref
          ..invalidate(unlinkedAthletesProvider(clubId))
          ..invalidate(clubMemberCandidatesProvider(clubId));
      },
      'Sporcu hesabı eşleştirildi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final colors = host.theme;
    if (_target.teamId.trim().isEmpty) {
      return host.chrome.buildPage(
        context,
        title: 'Takım Kadrosu',
        body: const Center(child: Text('Geçerli bir takım seçilmedi.')),
      );
    }
    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage = club != null &&
        club.isActive &&
        const {'club_admin', 'coach'}.contains(club.role);
    final teams = ref.watch(teamsProvider).valueOrNull ?? const <TeamRow>[];
    final roster = ref.watch(teamRosterProvider(_target.teamId));
    final unlinked = club == null
        ? const <UnlinkedAthlete>[]
        : ref.watch(unlinkedAthletesProvider(club.id)).valueOrNull ??
            const <UnlinkedAthlete>[];
    final unlinkedIds = unlinked.map((item) => item.athleteId).toSet();

    return host.chrome.buildPage(
      context,
      title: 'Takım Kadrosu',
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                if (teams.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final team in teams)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(team.name),
                              selected: team.id == _target.teamId,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(() {
                                        _target = TeamRouteTarget(
                                          teamId: team.id,
                                          teamName: team.name,
                                        );
                                        _query = '';
                                        _message = null;
                                      }),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _target.teamName,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        roster.when(
                          loading: () => const Text('Kadro yükleniyor'),
                          error: (error, _) => Text(
                            classifyOperationError(error).userMessage,
                          ),
                          data: (items) => Text('${items.length} sporcu'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SharedOfficialTeamRosters(teamId: _target.teamId),
                TextField(
                  key: const Key('roster-search'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Sporcu adı veya forma no ile ara',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _message!,
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ),
                const SizedBox(height: 8),
                roster.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(classifyOperationError(error).userMessage),
                  ),
                  data: (items) {
                    final filtered = items
                        .where(
                          (item) => _searchText(
                            '${item.name} ${item.jersey ?? ''}',
                          ).contains(_searchText(_query)),
                        )
                        .toList();
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          canManage
                              ? 'Kadro boş. Kulüp sporcularından ekleyebilirsin.'
                              : 'Bu takıma henüz sporcu atanmamış.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Aramayla eşleşen sporcu yok.'),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in filtered)
                          Card(
                            key: Key('roster-member-${item.athleteId}'),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  item.name.isEmpty
                                      ? '?'
                                      : item.name[0].toUpperCase(),
                                ),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                [
                                  if (item.jersey?.isNotEmpty ?? false)
                                    'Forma: ${item.jersey}',
                                  if (unlinkedIds.contains(item.athleteId))
                                    'Hesaba bağlı değil',
                                ].join(' · '),
                              ),
                              onTap: () => host.navigator.openAthleteProfile(
                                athleteId: item.athleteId,
                                athleteName: item.name,
                              ),
                              trailing: canManage
                                  ? PopupMenuButton<String>(
                                      enabled: !_busy,
                                      onSelected: (action) {
                                        if (action == 'link') {
                                          _linkAthlete(club.id, item.athleteId);
                                        } else if (action == 'remove') {
                                          _run(
                                            () async {
                                              await ref.read(
                                                teamRosterRemoveCommandProvider,
                                              )(item.id);
                                              _refresh();
                                            },
                                            'Sporcu takımdan çıkarıldı.',
                                          );
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        if (unlinkedIds
                                            .contains(item.athleteId))
                                          const PopupMenuItem(
                                            value: 'link',
                                            child: Text('Hesapla eşleştir'),
                                          ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Takımdan çıkar'),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (canManage) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Kulüp Sporcuları',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  _AvailableAthletes(
                    club: club,
                    teamId: _target.teamId,
                    roster: roster.valueOrNull ?? const [],
                    busy: _busy,
                    run: _run,
                    refresh: _refresh,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailableAthletes extends ConsumerWidget {
  const _AvailableAthletes({
    required this.club,
    required this.teamId,
    required this.roster,
    required this.busy,
    required this.run,
    required this.refresh,
  });
  final ClubRef club;
  final String teamId;
  final List<({String id, String athleteId, String name, String? jersey})>
      roster;
  final bool busy;
  final Future<void> Function(Future<void> Function(), String) run;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inTeam = roster.map((item) => item.athleteId).toSet();
    final athletes = ref.watch(clubAthletesProvider).valueOrNull ?? const [];
    final free = athletes.where((item) => !inTeam.contains(item.id)).toList();
    final candidates =
        ref.watch(clubMemberCandidatesProvider(club.id)).valueOrNull ??
            const [];
    if (free.isEmpty && candidates.isEmpty) {
      return const Text('Kulüpte eklenebilecek sporcu bulunmuyor.');
    }
    return Column(
      children: [
        for (final athlete in free)
          ListTile(
            title: Text(athlete.fullName),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: busy
                ? null
                : () => run(
                      () async {
                        await ref.read(teamRosterAddCommandProvider)(
                          teamId,
                          athlete.id,
                        );
                        refresh();
                      },
                      'Sporcu takıma eklendi.',
                    ),
          ),
        for (final candidate in candidates)
          ListTile(
            key: Key('member-candidate-${candidate.profileId}'),
            title: Text(candidate.displayName),
            subtitle: const Text('Onaylı kulüp üyesi · kadro kaydı yok'),
            trailing: const Icon(Icons.person_add_alt_1),
            onTap: busy
                ? null
                : () => run(
                      () async {
                        final athleteId =
                            await ref.read(athleteFromMemberCommandProvider)(
                          clubId: club.id,
                          profileId: candidate.profileId,
                        );
                        await ref.read(teamRosterAddCommandProvider)(
                          teamId,
                          athleteId,
                        );
                        ref.invalidate(clubMemberCandidatesProvider(club.id));
                        refresh();
                      },
                      'Üye sporcu kaydı oluşturuldu ve takıma eklendi.',
                    ),
          ),
      ],
    );
  }
}

class SharedOfficialTeamRosters extends ConsumerWidget {
  const SharedOfficialTeamRosters({required this.teamId, super.key});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    if (access.clubRole != 'coach' && !access.isClubAdmin) {
      return const SizedBox.shrink();
    }
    return ref.watch(officialTeamRostersProvider(teamId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => TextButton(
            onPressed: () =>
                ref.invalidate(officialTeamRostersProvider(teamId)),
            child: const Text('Resmi kadrolar yüklenemedi. Yeniden dene'),
          ),
          data: (rosters) => Column(
            children: [
              for (final roster in rosters)
                ListTile(
                  title: Text(roster.name),
                  subtitle: Text(
                    'Resmi esame · Revizyon ${roster.version} · ${roster.athleteIds.length} sporcu',
                  ),
                  trailing: access.isHeadCoachForSport(roster.sportCode)
                      ? TextButton(
                          onPressed: () => _edit(context, ref, roster),
                          child: const Text('Kadroyu kilitle'),
                        )
                      : const Tooltip(
                          message: 'En az 3. Kademe Başantrenör gerekir',
                          child: Icon(Icons.lock_outline),
                        ),
                ),
            ],
          ),
        );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    OfficialTeamRoster roster,
  ) async {
    try {
      final members = await ref.read(teamRosterProvider(teamId).future);
      if (!context.mounted) return;
      final selected = roster.athleteIds.toSet();
      final reason = TextEditingController();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('Resmi maç kadrosunu kilitle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final member in members)
                    CheckboxListTile(
                      value: selected.contains(member.athleteId),
                      title: Text(member.name),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          selected.add(member.athleteId);
                        } else {
                          selected.remove(member.athleteId);
                        }
                      }),
                    ),
                  TextField(
                    key: const Key('official-roster-reason'),
                    controller: reason,
                    maxLength: 500,
                    decoration:
                        const InputDecoration(labelText: 'Revizyon gerekçesi'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(officialRosterPublishCommandProvider)(
                      roster,
                      selected.toList(),
                      reason.text,
                    );
                    ref.invalidate(officialTeamRostersProvider(teamId));
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (error) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content:
                              Text(classifyOperationError(error).userMessage),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Onayla ve kilitle'),
              ),
            ],
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => reason.dispose());
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(classifyOperationError(error).userMessage)),
        );
      }
    }
  }
}
