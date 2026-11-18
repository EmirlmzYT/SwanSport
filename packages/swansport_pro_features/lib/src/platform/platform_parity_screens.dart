import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';

Widget _platformAdminBody(WidgetRef ref, Widget child) =>
    ref.watch(swanAccessProvider).isPlatformAdmin
        ? child
        : const Center(child: Text('Platform yöneticisi yetkisi gerekli'));

final class PlatformRssSourcesScreen extends ConsumerStatefulWidget {
  const PlatformRssSourcesScreen({super.key});

  @override
  ConsumerState<PlatformRssSourcesScreen> createState() =>
      _PlatformRssSourcesScreenState();
}

final class _PlatformRssSourcesScreenState
    extends ConsumerState<PlatformRssSourcesScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!ref.watch(swanAccessProvider).isPlatformAdmin) {
      return host.chrome.buildPage(
        context,
        title: 'RSS Kaynakları',
        body: const Center(child: Text('Platform yöneticisi yetkisi gerekli')),
      );
    }
    return host.chrome.buildPage(
      context,
      title: 'RSS Kaynakları',
      actions: [
        IconButton(
          key: const Key('platform-rss-add'),
          onPressed: _busy || !ref.watch(swanAccessProvider).isPlatformAdmin
              ? null
              : _add,
          icon: const Icon(Icons.add),
          tooltip: 'Kaynak ekle',
        ),
      ],
      body: _platformAdminBody(
        ref,
        ref.watch(platformRssSourcesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                error,
                () => ref.invalidate(platformRssSourcesProvider),
              ),
              data: (sources) => sources.isEmpty
                  ? const Center(child: Text('Kayıtlı RSS kaynağı yok'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.rss_feed),
                            title: Text(source.name),
                            subtitle: Text(source.url),
                            trailing: Wrap(
                              children: [
                                Switch(
                                  value: source.active,
                                  onChanged: _busy
                                      ? null
                                      : (value) => _setActive(source, value),
                                ),
                                IconButton(
                                  onPressed:
                                      _busy ? null : () => _remove(source),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Kaynağı sil',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      ),
    );
  }

  Future<void> _add() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _RssDialog(),
    );
    if (result == null || !mounted) return;
    await _write(
      () => ref.read(newsServiceProvider).addSource(result.$1, result.$2),
    );
  }

  Future<void> _setActive(RssSource source, bool active) async {
    await _write(
      () => ref.read(newsServiceProvider).setActive(source.id, active),
    );
  }

  Future<void> _remove(RssSource source) async {
    final confirmed = await ProFeatureHostScope.of(context).chrome.confirm(
          context,
          title: 'RSS kaynağını sil',
          message: '${source.name} kalıcı olarak silinecek.',
          confirmLabel: 'Sil',
        );
    if (!confirmed || !mounted) return;
    await _write(() => ref.read(newsServiceProvider).removeSource(source.id));
  }

  Future<void> _write(Future<void> Function() action) async {
    final actor = ref.read(authSessionProvider).valueOrNull?.user.id;
    if (actor == null || !ref.read(swanAccessProvider).isPlatformAdmin) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted ||
          actor != ref.read(authSessionProvider).valueOrNull?.user.id ||
          !ref.read(swanAccessProvider).isPlatformAdmin) {
        return;
      }
      ref.invalidate(platformRssSourcesProvider);
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class PlatformProfessionalReviewScreen extends ConsumerStatefulWidget {
  const PlatformProfessionalReviewScreen({super.key});

  @override
  ConsumerState<PlatformProfessionalReviewScreen> createState() =>
      _PlatformProfessionalReviewScreenState();
}

final class _PlatformProfessionalReviewScreenState
    extends ConsumerState<PlatformProfessionalReviewScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!ref.watch(swanAccessProvider).isPlatformAdmin) {
      return host.chrome.buildPage(
        context,
        title: 'Mesleki Belge Başvuruları',
        body: const Center(child: Text('Platform yöneticisi yetkisi gerekli')),
      );
    }
    final credentials = ref.watch(pendingCredentialsProvider);
    final missingSports = ref.watch(sportlessCredentialsProvider);
    return host.chrome.buildPage(
      context,
      title: 'Mesleki Belge Başvuruları',
      body: _platformAdminBody(
        ref,
        RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(pendingCredentialsProvider)
              ..invalidate(sportlessCredentialsProvider);
            await Future.wait([
              ref.read(pendingCredentialsProvider.future),
              ref.read(sportlessCredentialsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Onay bekleyen profesyonel hesaplar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              credentials.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => _ErrorState(
                  error,
                  () => ref.invalidate(pendingCredentialsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const ListTile(title: Text('Bekleyen başvuru yok'))
                    : Column(
                        children: [
                          for (final row in rows)
                            ListTile(
                              key: ValueKey('credential-${row.id}'),
                              title: Text(row.personName ?? 'Kullanıcı'),
                              subtitle: Text(row.label),
                              trailing: const Chip(label: Text('İnceleniyor')),
                              onTap: _busy ? null : () => _openDetail(row),
                            ),
                        ],
                      ),
              ),
              const Divider(),
              const Text(
                'Branş eşlemesi eksik onaylı belgeler',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              missingSports.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => _ErrorState(
                  error,
                  () => ref.invalidate(sportlessCredentialsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const ListTile(title: Text('Eksik eşleme yok'))
                    : Column(
                        children: [
                          for (final row in rows)
                            ListTile(
                              title: Text(row.name),
                              subtitle: Text(
                                '${row.coachLevel ?? '?'} Kademe · branş seçilmemiş',
                              ),
                              trailing: TextButton(
                                onPressed:
                                    _busy ? null : () => _assignSport(row),
                                child: const Text('Branş ata'),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Son kararlar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              ref.watch(reviewLogProvider).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => _ErrorState(
                      error,
                      () => ref.invalidate(reviewLogProvider),
                    ),
                    data: (rows) => rows.isEmpty
                        ? const ListTile(title: Text('Henüz karar verilmemiş'))
                        : Column(
                            children: [
                              for (final row in rows.where((r) => !r.isClub))
                                ListTile(
                                  leading: Icon(
                                    row.approved
                                        ? Icons.check_circle_outline
                                        : Icons.cancel_outlined,
                                  ),
                                  title: Text(row.subject),
                                  subtitle: Text(
                                    [
                                      if (row.detail != null) row.detail!,
                                      if (row.reviewer != null) row.reviewer!,
                                    ].join(' · '),
                                  ),
                                ),
                            ],
                          ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(CredentialRow credential) async {
    setState(() => _busy = true);
    List<({String docType, String url})> documents;
    try {
      documents =
          await ref.read(credentialDocumentsProvider(credential.id).future);
    } catch (error) {
      if (mounted) _showError(context, error);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CredentialReviewDialog(
        credential: credential,
        documents: documents,
        sports: ref.read(sportsProvider).valueOrNull ?? const [],
        onOpenDocument: (document) => _openDocument(document.url),
        onApprove: (coachLevel, sportCode) => _decide(
          dialogContext,
          credential,
          true,
          coachLevel: coachLevel,
          sportCode: sportCode,
        ),
        onReject: (note) => _decide(
          dialogContext,
          credential,
          false,
          note: note,
        ),
      ),
    );
  }

  Future<void> _openDocument(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') {
      _showDocumentOpenError(context);
      return;
    }
    final opened = await ProFeatureHostScope.of(context)
        .navigator
        .openProtectedDocument(uri);
    if (!opened && mounted) {
      _showDocumentOpenError(context);
    }
  }

  Future<void> _assignSport(SportlessCredential credential) async {
    final sports = ref.read(sportsProvider).valueOrNull ?? const <CityRow>[];
    if (sports.isEmpty) {
      _showError(context, StateError('Branş listesi yüklenemedi'));
      return;
    }
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('${credential.name} · branş'),
        children: [
          for (final sport in sports)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, sport.code),
              child: Text(sport.name),
            ),
        ],
      ),
    );
    if (code == null || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(credentialSportAssignmentProvider)(credential.id, code);
      ref
        ..invalidate(sportlessCredentialsProvider)
        ..invalidate(myCredentialsProvider);
      if (mounted) {
        ProFeatureHostScope.of(context).chrome.showMessage(
              context,
              'Branş eşlemesi güncellendi',
              tone: ProFeatureMessageTone.success,
            );
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(
    BuildContext dialogContext,
    CredentialRow credential,
    bool approve, {
    String? note,
    int? coachLevel,
    String? sportCode,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(credentialReviewActionProvider)(
        credential.id,
        approve,
        note: note,
        coachLevel: coachLevel,
        sportCode: sportCode,
      );
      if (!mounted) return;
      ref
        ..invalidate(pendingCredentialsProvider)
        ..invalidate(credentialDocumentsProvider(credential.id))
        ..invalidate(platformStatsProvider)
        ..invalidate(reviewLogProvider)
        ..invalidate(sportlessCredentialsProvider)
        ..invalidate(myCredentialsProvider);
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      ProFeatureHostScope.of(context).chrome.showMessage(
            context,
            approve ? 'Belge onaylandı' : 'Belge reddedildi',
            tone: ProFeatureMessageTone.success,
          );
    } catch (error) {
      if (mounted) {
        _showError(context, error);
        ref
          ..invalidate(pendingCredentialsProvider)
          ..invalidate(reviewLogProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _CredentialReviewDialog extends StatefulWidget {
  const _CredentialReviewDialog({
    required this.credential,
    required this.documents,
    required this.sports,
    required this.onOpenDocument,
    required this.onApprove,
    required this.onReject,
  });

  final CredentialRow credential;
  final List<({String docType, String url})> documents;
  final ValueChanged<({String docType, String url})> onOpenDocument;
  final List<CityRow> sports;
  final void Function(int? coachLevel, String? sportCode) onApprove;
  final ValueChanged<String> onReject;

  @override
  State<_CredentialReviewDialog> createState() =>
      _CredentialReviewDialogState();
}

final class _CredentialReviewDialogState
    extends State<_CredentialReviewDialog> {
  final _note = TextEditingController();
  int? _coachLevel;
  String? _sportCode;

  @override
  void initState() {
    super.initState();
    _coachLevel = widget.credential.coachLevel;
    _sportCode = widget.credential.sportCode;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Başvuru ayrıntısı'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.credential.personName ?? 'Kullanıcı',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(widget.credential.label),
                if (widget.credential.isCoach) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: const Key('credential-coach-level'),
                    initialValue: _coachLevel,
                    decoration: const InputDecoration(labelText: 'Kademe'),
                    items: [
                      for (var level = 1; level <= 5; level++)
                        DropdownMenuItem(
                          value: level,
                          child: Text('$level. Kademe'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _coachLevel = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('credential-sport'),
                    initialValue: widget.sports.any((s) => s.code == _sportCode)
                        ? _sportCode
                        : null,
                    decoration: const InputDecoration(labelText: 'Branş'),
                    items: [
                      for (final sport in widget.sports)
                        DropdownMenuItem(
                          value: sport.code,
                          child: Text(sport.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _sportCode = value),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Belgeler',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (widget.documents.isEmpty)
                  const Text('Bu başvuruya bağlı belge bulunamadı')
                else
                  for (final document in widget.documents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(document.docType),
                      trailing: IconButton(
                        tooltip: 'Belgeyi aç',
                        onPressed: () => widget.onOpenDocument(document),
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ret gerekçesi',
                    helperText: 'Ret için gerekçe zorunludur.',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          OutlinedButton(
            onPressed: () {
              final note = _note.text.trim();
              if (note.isEmpty) return;
              widget.onReject(note);
            },
            child: const Text('Reddet'),
          ),
          FilledButton(
            onPressed: widget.credential.isCoach &&
                    (_coachLevel == null || _sportCode == null)
                ? null
                : () => widget.onApprove(_coachLevel, _sportCode),
            child: const Text('Onayla'),
          ),
        ],
      );
}

final class PlatformAccessReviewScreen extends ConsumerStatefulWidget {
  const PlatformAccessReviewScreen({super.key});

  @override
  ConsumerState<PlatformAccessReviewScreen> createState() =>
      _PlatformAccessReviewScreenState();
}

final class _PlatformAccessReviewScreenState
    extends ConsumerState<PlatformAccessReviewScreen> {
  String _query = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!ref.watch(swanAccessProvider).isPlatformAdmin) {
      return host.chrome.buildPage(
        context,
        title: 'Rol ve Erişim İncelemesi',
        body: const Center(child: Text('Platform yöneticisi yetkisi gerekli')),
      );
    }
    final people = ref.watch(adminPeopleProvider(_query));
    final flags = ref.watch(featureFlagsProvider);
    return host.chrome.buildPage(
      context,
      title: 'Rol ve Erişim İncelemesi',
      body: _platformAdminBody(
        ref,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('platform-access-search'),
              decoration: const InputDecoration(
                labelText: 'Kullanıcı ara',
                prefixIcon: Icon(Icons.search),
              ),
              onFieldSubmitted: (value) =>
                  setState(() => _query = value.trim()),
            ),
            people.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _ErrorState(
                error,
                () => ref.invalidate(adminPeopleProvider(_query)),
              ),
              data: (rows) => Column(
                children: [
                  for (final person in rows)
                    ListTile(
                      title: Text(person.name),
                      subtitle: Text(person.subtitle),
                      trailing: person.isAdmin
                          ? OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _toggleAdmin(person, false),
                              child: const Text('Yetkiyi kaldır'),
                            )
                          : TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _toggleAdmin(person, true),
                              child: const Text('Yönetici yap'),
                            ),
                    ),
                ],
              ),
            ),
            const Divider(),
            const Text(
              'Bu hesap için açık feature flag durumları',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            flags.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _ErrorState(
                error,
                () => ref.invalidate(featureFlagsProvider),
              ),
              data: (value) => value.enabled.isEmpty
                  ? const ListTile(title: Text('Açık feature flag yok'))
                  : Wrap(
                      spacing: 8,
                      children: [
                        for (final flag in value.enabled)
                          Chip(label: Text(flag)),
                      ],
                    ),
            ),
            const Text(
              'Feature flag görünümü salt okunurdur; istemciden flag mutasyonu yapılmaz.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAdmin(AdminPerson person, bool value) async {
    final host = ProFeatureHostScope.of(context);
    final confirmed = await host.chrome.confirm(
      context,
      title: value ? 'Platform yöneticisi yap' : 'Platform yetkisini kaldır',
      message: value
          ? '${person.name} tüm platform yönetim alanlarına erişebilecek.'
          : '${person.name} platform yönetim erişimini kaybedecek.',
      confirmLabel: value ? 'Yetki ver' : 'Yetkiyi kaldır',
    );
    if (!confirmed || !mounted) return;
    final actor = ref.read(authSessionProvider).valueOrNull?.user.id;
    if (actor == null || !ref.read(swanAccessProvider).isPlatformAdmin) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminServiceProvider).setPlatformAdmin(person.id, value);
      if (mounted &&
          actor == ref.read(authSessionProvider).valueOrNull?.user.id) {
        ref.invalidate(adminPeopleProvider(_query));
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class PlatformFederationAuthorityScreen extends ConsumerStatefulWidget {
  const PlatformFederationAuthorityScreen({super.key});

  @override
  ConsumerState<PlatformFederationAuthorityScreen> createState() =>
      _PlatformFederationAuthorityScreenState();
}

final class _PlatformFederationAuthorityScreenState
    extends ConsumerState<PlatformFederationAuthorityScreen> {
  String? _channelId;
  String _query = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    if (!ref.watch(swanAccessProvider).isPlatformAdmin) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Yetkilileri',
        body: const Center(child: Text('Platform yöneticisi yetkisi gerekli')),
      );
    }
    final channels = ref.watch(federationChannelsProvider);
    final staff = _channelId == null
        ? const AsyncValue<List<FederationStaffAssignment>>.data([])
        : ref.watch(federationStaffProvider(_channelId!));
    final people = ref.watch(adminPeopleProvider(_query));
    return host.chrome.buildPage(
      context,
      title: 'Federasyon Yetkilileri',
      body: _platformAdminBody(
        ref,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            channels.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _ErrorState(
                error,
                () => ref.invalidate(federationChannelsProvider),
              ),
              data: (rows) => DropdownButtonFormField<String>(
                key: const Key('federation-authority-channel'),
                initialValue:
                    rows.any((row) => row.id == _channelId) ? _channelId : null,
                decoration: const InputDecoration(labelText: 'Federasyon'),
                items: [
                  for (final row in rows)
                    DropdownMenuItem(value: row.id, child: Text(row.name)),
                ],
                onChanged: (value) => setState(() => _channelId = value),
              ),
            ),
            staff.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _ErrorState(
                error,
                () => ref.invalidate(federationStaffProvider(_channelId!)),
              ),
              data: (rows) => Column(
                children: [
                  for (final assignment in rows)
                    ListTile(
                      title: Text(assignment.name),
                      subtitle: const Text('Federasyon yayın yetkilisi'),
                      trailing: IconButton(
                        onPressed:
                            _busy ? null : () => _setStaff(assignment, false),
                        icon: const Icon(Icons.person_remove_outlined),
                        tooltip: 'Yetkiyi kaldır',
                      ),
                    ),
                ],
              ),
            ),
            if (_channelId != null) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Atanacak kullanıcıyı ara',
                ),
                onFieldSubmitted: (value) =>
                    setState(() => _query = value.trim()),
              ),
              people.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => _ErrorState(
                  error,
                  () => ref.invalidate(adminPeopleProvider(_query)),
                ),
                data: (rows) => Column(
                  children: [
                    for (final person in rows)
                      ListTile(
                        title: Text(person.name),
                        subtitle: Text(person.subtitle),
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _setStaff(
                                    FederationStaffAssignment(
                                      profileId: person.id,
                                      name: person.name,
                                    ),
                                    true,
                                  ),
                          child: const Text('Yetkili yap'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setStaff(
    FederationStaffAssignment assignment,
    bool value,
  ) async {
    final channelId = _channelId;
    if (channelId == null) return;
    final confirmed = await ProFeatureHostScope.of(context).chrome.confirm(
          context,
          title:
              value ? 'Federasyon yetkisi ver' : 'Federasyon yetkisini kaldır',
          message: '${assignment.name} için yayın yetkisi güncellenecek.',
          confirmLabel: value ? 'Yetki ver' : 'Yetkiyi kaldır',
        );
    if (!confirmed || !mounted) return;
    final actor = ref.read(authSessionProvider).valueOrNull?.user.id;
    if (actor == null || !ref.read(swanAccessProvider).isPlatformAdmin) return;
    setState(() => _busy = true);
    try {
      await ref.read(platformAdminParityServiceProvider).setFederationStaff(
            communityId: channelId,
            profileId: assignment.profileId,
            staff: value,
          );
      if (mounted &&
          actor == ref.read(authSessionProvider).valueOrNull?.user.id) {
        ref.invalidate(federationStaffProvider(channelId));
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _RssDialog extends StatefulWidget {
  const _RssDialog();
  @override
  State<_RssDialog> createState() => _RssDialogState();
}

final class _RssDialogState extends State<_RssDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('RSS kaynağı ekle'),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Kaynak adı'),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Kaynak adı gerekli',
              ),
              TextFormField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'HTTPS RSS URL'),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  return uri != null &&
                          uri.scheme == 'https' &&
                          uri.hasAuthority
                      ? null
                      : 'Geçerli bir HTTPS adresi girin';
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(context, (_name.text.trim(), _url.text.trim()));
            },
            child: const Text('Ekle'),
          ),
        ],
      );
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState(this.error, this.retry);
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(classifyOperationError(error).userMessage),
        trailing:
            TextButton(onPressed: retry, child: const Text('Tekrar dene')),
      );
}

void _showError(BuildContext context, Object error) {
  ProFeatureHostScope.of(context).chrome.showMessage(
        context,
        classifyOperationError(error).userMessage,
        tone: ProFeatureMessageTone.danger,
      );
}

void _showDocumentOpenError(BuildContext context) {
  ProFeatureHostScope.of(context).chrome.showMessage(
        context,
        'Belge açılamadı. Tekrar deneyin.',
        tone: ProFeatureMessageTone.danger,
      );
}
