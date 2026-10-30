import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';

bool _trainingEnabled(WidgetRef ref) => ref.watch(
      featureEnabledProvider(FeatureFlags.sportTrainingSessions),
    );

Widget _disabled(
  ProFeatureHostScope host,
  BuildContext context,
  String title,
) =>
    host.chrome.buildPage(
      context,
      title: title,
      body: const Center(
        child: Text('Antrenman operasyonları şu anda kullanıma kapalı.'),
      ),
    );

class SharedTrainingListScreen extends ConsumerWidget {
  const SharedTrainingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    if (!_trainingEnabled(ref)) {
      return _disabled(host, context, 'Antrenmanlarım');
    }
    final live = ref.watch(myLiveSessionProvider);
    final history = ref.watch(myTrainingHistoryProvider);
    return host.chrome.buildPage(
      context,
      title: 'Antrenmanlarım',
      actions: [
        IconButton(
          tooltip: 'Şablonlar',
          onPressed: host.navigator.openTrainingProtocols,
          icon: const Icon(Icons.library_books_outlined),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(myLiveSessionProvider)
            ..invalidate(myTrainingHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            live.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                classifyOperationError(error).userMessage,
              ),
              data: (session) => session == null
                  ? const SizedBox.shrink()
                  : Card(
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: Text(session.protocolName),
                        subtitle: Text(
                          '${session.phase.label} · Set ${session.currentSet}/${session.setCount}',
                        ),
                        trailing: const Text('Oturuma dön'),
                        onTap: () => host.navigator.openTrainingSession(
                          sessionId: session.id,
                        ),
                      ),
                    ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _join(context, ref, host),
                  icon: const Icon(Icons.login),
                  label: const Text('Kodla katıl'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: host.navigator.openTrainingProtocols,
                  icon: const Icon(Icons.self_improvement),
                  label: const Text('Şablon seç'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Geçmiş',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text(
                classifyOperationError(error).userMessage,
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Henüz antrenman kaydı yok.'),
                    )
                  : Column(
                      children: [
                        for (final item in items)
                          ListTile(
                            title: Text(item.protocolName),
                            subtitle: Text(
                              '${item.setsDone}/${item.setCount} set · ${item.status}',
                            ),
                            trailing: item.totalScore == null
                                ? null
                                : Text('${item.totalScore}'),
                            onTap: () => host.navigator.openTrainingResult(
                              sessionId: item.sessionId,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    ProFeatureHostScope host,
  ) async {
    final controller = TextEditingController();
    final accepted = await host.chrome.confirm(
      context,
      title: 'Oturuma katıl',
      message: 'Antrenörün verdiği 6 haneli kodu bir sonraki alana yaz.',
      confirmLabel: 'Kodu yaz',
    );
    if (!accepted || !context.mounted) return;
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Katılım kodu'),
        content: TextField(
          key: const Key('training-join-code'),
          controller: controller,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    try {
      final id = await ref.read(trainingOperationCommandsProvider).join(code);
      if (context.mounted) host.navigator.openTrainingSession(sessionId: id);
    } catch (error) {
      if (context.mounted) {
        host.chrome.showMessage(
          context,
          classifyOperationError(error).userMessage,
          tone: ProFeatureMessageTone.danger,
        );
      }
    }
  }
}

class SharedProtocolListScreen extends ConsumerStatefulWidget {
  const SharedProtocolListScreen({super.key});

  @override
  ConsumerState<SharedProtocolListScreen> createState() =>
      _SharedProtocolListScreenState();
}

class _SharedProtocolListScreenState
    extends ConsumerState<SharedProtocolListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!_trainingEnabled(ref)) {
      return _disabled(host, context, 'Antrenman Şablonları');
    }
    final access = ref.watch(swanAccessProvider);
    ref.watch(activeClubProvider);
    final protocols = ref.watch(trainingProtocolsProvider);
    return host.chrome.buildPage(
      context,
      title: 'Antrenman Şablonları',
      actions: [
        if (access.isClubStaff)
          IconButton(
            tooltip: 'Şablon oluştur',
            onPressed: host.navigator.openTrainingBuilder,
            icon: const Icon(Icons.add),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          TextField(
            key: const Key('training-protocol-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Şablon ara',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          protocols.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(
              classifyOperationError(error).userMessage,
            ),
            data: (items) {
              final needle = _query.toLowerCase();
              final filtered = items
                  .where(
                    (item) => '${item.name} ${item.description ?? ''}'
                        .toLowerCase()
                        .contains(needle),
                  )
                  .toList();
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Kullanılabilir şablon bulunamadı.'),
                );
              }
              return Column(
                children: [
                  for (final protocol in filtered)
                    Card(
                      child: ListTile(
                        title: Text(protocol.name),
                        subtitle: Text(
                          '${protocol.sportCode} · ${protocol.config.mode.label} · ${protocol.config.setCount} set',
                        ),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _start(context, protocol),
                          child: const Text('Başlat'),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, TrainingProtocol protocol) async {
    final host = ProFeatureHostScope.of(context);
    final club = ref.read(activeClubProvider).valueOrNull;
    try {
      String id;
      if (ref.read(swanAccessProvider).isClubStaff && club != null) {
        final result = await ref
            .read(trainingOperationCommandsProvider)
            .startClub(clubId: club.id, protocolId: protocol.id);
        id = result.id;
      } else {
        id = await ref
            .read(trainingOperationCommandsProvider)
            .startPersonal(protocolId: protocol.id, clubId: club?.id);
      }
      if (context.mounted) host.navigator.openTrainingSession(sessionId: id);
    } catch (error) {
      if (context.mounted) {
        host.chrome.showMessage(
          context,
          classifyOperationError(error).userMessage,
          tone: ProFeatureMessageTone.danger,
        );
      }
    }
  }
}

class SharedWorkoutBuilderScreen extends ConsumerStatefulWidget {
  const SharedWorkoutBuilderScreen({this.initialTitle = '', super.key});
  final String initialTitle;

  @override
  ConsumerState<SharedWorkoutBuilderScreen> createState() => _BuilderState();
}

class _BuilderState extends ConsumerState<SharedWorkoutBuilderScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _sport = TextEditingController();
  final _sets = TextEditingController(text: '6');
  final _units = TextEditingController(text: '6');
  bool _saving = false;
  late final ProDirtyStateRegistration _dirty;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialTitle);
    _dirty = ref.read(proDirtyStateCoordinatorProvider).register('builder');
  }

  @override
  void dispose() {
    _dirty.dispose();
    _name.dispose();
    _sport.dispose();
    _sets.dispose();
    _units.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!_trainingEnabled(ref)) {
      return _disabled(host, context, 'Antrenman Şablonu Oluştur');
    }
    final club = ref.watch(activeClubProvider).valueOrNull;
    final allowed = club != null && ref.watch(swanAccessProvider).isClubStaff;
    return host.chrome.buildPage(
      context,
      title: 'Antrenman Şablonu Oluştur',
      body: !allowed
          ? const Center(child: Text('Kulüp personeli erişimi gerekli.'))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final field in [
                    (_name, 'Şablon adı', 'training-name'),
                    (_sport, 'Branş kodu', 'training-sport'),
                    (_sets, 'Set sayısı', 'training-sets'),
                    (_units, 'Set başına tekrar', 'training-units'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: Key(field.$3),
                        controller: field.$1,
                        enabled: !_saving,
                        decoration: InputDecoration(labelText: field.$2),
                        onChanged: (_) => _dirty.markDirty(),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Bu alan gerekli.'
                                : null,
                      ),
                    ),
                  FilledButton(
                    key: const Key('training-builder-save'),
                    onPressed: _saving ? null : () => _save(club),
                    child: Text(_saving ? 'Kaydediliyor…' : 'Şablonu kaydet'),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _save(ClubRef club) async {
    if (!_form.currentState!.validate()) return;
    final setCount = int.tryParse(_sets.text);
    final units = int.tryParse(_units.text);
    if (setCount == null || setCount < 1 || units == null || units < 1) return;
    setState(() => _saving = true);
    try {
      await ref.read(trainingOperationCommandsProvider).createProtocol(
            clubId: club.id,
            sportCode: _sport.text.trim(),
            name: _name.text.trim(),
            config: TrainingProtocolConfig(
              setCount: setCount,
              unitsPerSet: units,
              prepSeconds: 10,
              shootSeconds: 120,
              collectSeconds: 60,
              restSeconds: 0,
              maxUnitScore: 10,
              entryMode: ScoreEntryMode.flexible,
              mode: TrainingMode.technique,
              archetype: TrainingArchetype.targetScore,
            ),
          );
      _dirty.markClean();
      ref.invalidate(trainingProtocolsProvider);
      if (mounted) Navigator.maybePop(context);
    } catch (error) {
      if (mounted) {
        ProFeatureHostScope.of(context).chrome.showMessage(
              context,
              classifyOperationError(error).userMessage,
              tone: ProFeatureMessageTone.danger,
            );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class SharedTrainingSessionScreen extends ConsumerStatefulWidget {
  const SharedTrainingSessionScreen({this.sessionId, super.key});
  final String? sessionId;

  @override
  ConsumerState<SharedTrainingSessionScreen> createState() => _SessionState();
}

class _SessionState extends ConsumerState<SharedTrainingSessionScreen> {
  final _score = TextEditingController();
  late final ProDirtyStateRegistration _dirty;

  @override
  void initState() {
    super.initState();
    _dirty = ref.read(proDirtyStateCoordinatorProvider).register('session');
  }

  @override
  void dispose() {
    _dirty.dispose();
    _score.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!_trainingEnabled(ref)) return _disabled(host, context, 'Oturum');
    final live = ref.watch(myLiveSessionProvider);
    final id = widget.sessionId ?? live.valueOrNull?.id;
    if (id == null) {
      return host.chrome.buildPage(
        context,
        title: 'Antrenman Oturumu',
        body: const Center(child: Text('Aktif oturum yok.')),
      );
    }
    final session = ref.watch(trainingSessionProvider(id));
    return host.chrome.buildPage(
      context,
      title: 'Antrenman Oturumu',
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(classifyOperationError(error).userMessage),
        ),
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Oturum bulunamadı.'));
          }
          final coach =
              !value.isPersonal && ref.watch(swanAccessProvider).isClubStaff;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                value.protocolName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${value.phase.label} · Set ${value.currentSet}/${value.setCount}',
              ),
              if (value.joinCode != null)
                Text('Katılım kodu: ${value.joinCode}'),
              const SizedBox(height: 16),
              if (coach) ...[
                FilledButton(
                  onPressed: () => _run(
                    id,
                    () =>
                        ref.read(trainingOperationCommandsProvider).advance(id),
                  ),
                  child: const Text('Aşamayı ilerlet'),
                ),
                OutlinedButton(
                  onPressed: () => _run(
                    id,
                    () => ref
                        .read(trainingOperationCommandsProvider)
                        .pause(id, !value.paused),
                  ),
                  child: Text(value.paused ? 'Devam ettir' : 'Duraklat'),
                ),
              ] else ...[
                TextField(
                  key: const Key('training-score'),
                  controller: _score,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Set toplamı'),
                  onChanged: (_) => _dirty.markDirty(),
                ),
                FilledButton(
                  onPressed: () async {
                    final score = num.tryParse(_score.text);
                    if (score == null) return;
                    await _run(
                      id,
                      () =>
                          ref.read(trainingOperationCommandsProvider).submitSet(
                                sessionId: id,
                                setNo: value.currentSet,
                                total: score,
                              ),
                    );
                    _dirty.markClean();
                  },
                  child: const Text('Seti kaydet'),
                ),
              ],
              TextButton(
                onPressed: () =>
                    host.navigator.openTrainingResult(sessionId: id),
                child: const Text('Sonuçları aç'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    try {
      await action();
      ref
        ..invalidate(trainingSessionProvider(id))
        ..invalidate(mySessionSetsProvider(id));
    } catch (error) {
      if (mounted) {
        ProFeatureHostScope.of(context).chrome.showMessage(
              context,
              classifyOperationError(error).userMessage,
              tone: ProFeatureMessageTone.danger,
            );
      }
    }
  }
}

class SharedSessionResultScreen extends ConsumerWidget {
  const SharedSessionResultScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    if (!_trainingEnabled(ref)) {
      return _disabled(host, context, 'Oturum Sonucu');
    }
    if (sessionId.isEmpty) {
      return host.chrome.buildPage(
        context,
        title: 'Oturum Sonucu',
        body: const Center(child: Text('Geçerli bir oturum seçilmedi.')),
      );
    }
    final overview = ref.watch(sessionOverviewProvider(sessionId));
    final summary = ref.watch(sessionSummaryProvider(sessionId));
    return host.chrome.buildPage(
      context,
      title: 'Oturum Sonucu',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          overview.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) =>
                Text(classifyOperationError(error).userMessage),
            data: (value) => value == null
                ? const Text('Sonuç özeti bulunamadı.')
                : Card(
                    child: ListTile(
                      title: Text(value.protocolName),
                      subtitle: Text(
                        '${value.completedCount}/${value.joinedCount} tamamladı · ${value.unitsRecorded}/${value.unitsExpected} tekrar',
                      ),
                      trailing: value.status == 'review'
                          ? FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(trainingOperationCommandsProvider)
                                    .lock(sessionId);
                                ref
                                  ..invalidate(
                                    sessionOverviewProvider(sessionId),
                                  )
                                  ..invalidate(
                                    sessionSummaryProvider(sessionId),
                                  );
                              },
                              child: const Text('Onayla ve kilitle'),
                            )
                          : null,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Text(classifyOperationError(error).userMessage),
            data: (rows) => rows.isEmpty
                ? const Text('Bu oturuma kimse katılmadı.')
                : Column(
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(row.athleteName),
                          subtitle:
                              Text('${row.setsDone}/${row.setsExpected} set'),
                          trailing: row.totalScore == null
                              ? const Text('Eksik')
                              : Text('${row.totalScore}'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
