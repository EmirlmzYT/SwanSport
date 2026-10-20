import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:swansport_data/swansport_data.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import '../../app/widgets/swan_scaffold.dart';
import '../../app/widgets/swan_module_app_bar.dart';

class TransferRequestsScreen extends ConsumerStatefulWidget {
  const TransferRequestsScreen({super.key});
  @override
  ConsumerState<TransferRequestsScreen> createState() =>
      _TransferRequestsScreenState();
}

class _TransferRequestsScreenState
    extends ConsumerState<TransferRequestsScreen> {
  bool _busy = false;
  String? _error;
  ({String id, String action})? _pending;
  late final _account = ref.read(authSessionProvider).valueOrNull?.user.id;
  bool get _valid =>
      mounted && _account == ref.read(authSessionProvider).valueOrNull?.user.id;
  Future<void> _act(String id, String action) async {
    if (_busy || !_valid) return;
    _pending ??= (id: id, action: action);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(transferRequestServiceProvider)
          .act(_pending!.id, _pending!.action);
      if (_valid) setState(() => _pending = null);
    } catch (e) {
      if (_valid)
        setState(() {
          if (e is PostgrestException &&
              const {'22023', '42501', '55000', 'P0001'}.contains(e.code))
            _pending = null;
          _error = _pending == null
              ? 'İşlem reddedildi. Güncel yetki ve onayları kontrol et.'
              : 'Sonuç doğrulanamadı. Aynı işlemi yeniden dene.';
        });
    } finally {
      if (_valid) {
        setState(() => _busy = false);
        ref.invalidate(transferRequestsProvider);
      }
    }
  }

  Future<void> _confirm(TransferRequest r, String action, String label) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(label),
                content: Text(action == 'finalize'
                    ? 'Mevcut resmî transfer motoru lisans kulübünü değiştirecek. Kulüp kadrosuna etkisi mevcut resmî kurallara göre uygulanır. Devam edilsin mi?'
                    : '${r.fromClub} → ${r.toClub}\n${r.familyName ?? r.athleteReference} · ${r.sport}\nBu talep için "$label" işlemi kaydedilsin mi?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Onayla'))
                ]));
    if (yes == true && _valid) await _act(r.id, action);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    final enabled =
        ref.watch(featureEnabledProvider(FeatureFlags.transferRequests));
    final current = ref.watch(authSessionProvider).valueOrNull?.user.id;
    if (!enabled || !access.canUseTransferRequests || current != _account)
      return SwanScaffold(
          appBar: swanModuleAppBar(context, title: 'Transfer Talepleri'),
          body: const Center(
              child: Text('Transfer talepleri bu hesaba açık değil.')));
    final options = ref.watch(transferRequestOptionsProvider);
    final rows = ref.watch(transferRequestsProvider);
    return SwanScaffold(
        backgroundColor: c.bg,
        appBar: swanModuleAppBar(context, title: 'Transfer Talepleri'),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(transferRequestsProvider);
                          ref.invalidate(transferRequestOptionsProvider);
                          await ref.read(transferRequestsProvider.future);
                        },
                        child: ListView(
                            padding: const EdgeInsets.all(SwanSpace.lg),
                            children: [
                              Text(
                                  'Kulüp kabulü, sporcu/veli onayı ve federasyon tescili ayrı adımlardır.',
                                  style: SwanType.caption(c.inkMuted)),
                              options.when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (_, __) => TextButton(
                                      onPressed: () => ref.invalidate(
                                          transferRequestOptionsProvider),
                                      child: const Text(
                                          'Yeni talep seçeneklerini yeniden yükle')),
                                  data: (o) => o.athletes.isEmpty
                                      ? const SizedBox.shrink()
                                      : Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                              onPressed: _busy || _pending != null
                                                  ? null
                                                  : () => showDialog<void>(
                                                      context: context,
                                                      builder: (_) =>
                                                          _CreateTransferDialog(
                                                              options: o)),
                                              icon: const Icon(Icons.add),
                                              label: const Text(
                                                  'Yeni transfer talebi')))),
                              if (_busy) const LinearProgressIndicator(),
                              if (_error != null)
                                Text(_error!, style: SwanType.bodySm(c.danger)),
                              if (_pending != null && !_busy)
                                TextButton(
                                    onPressed: () =>
                                        _act(_pending!.id, _pending!.action),
                                    child:
                                        const Text('Aynı işlemi tekrar dene')),
                              rows.when(
                                  loading: () => const Center(
                                      child: CircularProgressIndicator()),
                                  error: (_, __) => TextButton(
                                      onPressed: () => ref
                                          .invalidate(transferRequestsProvider),
                                      child: const Text(
                                          'Talepleri yeniden yükle')),
                                  data: (list) => Column(children: [
                                        if (list.isEmpty)
                                          Padding(
                                              padding: const EdgeInsets.all(
                                                  SwanSpace.lg),
                                              child: Text(
                                                  'Henüz ilgili bir transfer talebin yok.',
                                                  style: SwanType.bodySm(
                                                      c.inkMuted))),
                                        for (final r in list)
                                          Container(
                                              margin: const EdgeInsets.only(
                                                  top: SwanSpace.sm),
                                              padding: const EdgeInsets.all(
                                                  SwanSpace.md),
                                              decoration: BoxDecoration(
                                                  color: c.surface,
                                                  border:
                                                      Border.all(color: c.line),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          SwanRadius.md)),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '${r.fromClub} → ${r.toClub}',
                                                        style: SwanType.bodySm(
                                                            c.ink,
                                                            w: FontWeight
                                                                .w700)),
                                                    Text(
                                                        '${r.familyName ?? r.athleteReference} · ${r.sport} · ${switch (r.status) {
                                                          'completed' =>
                                                            'Tescillendi',
                                                          'rejected' =>
                                                            'Reddedildi',
                                                          'cancelled' =>
                                                            'İptal edildi',
                                                          _ => 'Onay bekliyor'
                                                        }}',
                                                        style: SwanType.caption(
                                                            c.inkMuted)),
                                                    const SizedBox(
                                                        height: SwanSpace.xs),
                                                    Text(r.reason,
                                                        style: SwanType.bodySm(
                                                            c.ink)),
                                                    Text(
                                                        'Hedef kulüp: ${r.accepted ? 'Kabul edildi' : 'Bekliyor'} · Sporcu/veli: ${r.consented ? 'Onaylandı' : 'Bekliyor'}',
                                                        style: SwanType.caption(
                                                            c.inkMuted)),
                                                    Wrap(
                                                        spacing: SwanSpace.sm,
                                                        children: [
                                                          for (final action
                                                              in <(
                                                            String,
                                                            String,
                                                            bool
                                                          )>[
                                                            (
                                                              'accept',
                                                              'Kulüp kabulü',
                                                              r.canAccept &&
                                                                  !r.accepted
                                                            ),
                                                            (
                                                              'consent',
                                                              'Onay ver',
                                                              r.canConsent &&
                                                                  !r.consented
                                                            ),
                                                            (
                                                              'finalize',
                                                              'Tescille',
                                                              r.canFinalize &&
                                                                  r.accepted &&
                                                                  r.consented
                                                            ),
                                                            (
                                                              'reject',
                                                              'Reddet',
                                                              r.canReject
                                                            ),
                                                            (
                                                              'cancel',
                                                              'İptal et',
                                                              r.canCancel
                                                            )
                                                          ])
                                                            if (action.$3)
                                                              TextButton(
                                                                  onPressed: _busy ||
                                                                          _pending !=
                                                                              null
                                                                      ? null
                                                                      : () => _confirm(
                                                                          r,
                                                                          action
                                                                              .$1,
                                                                          action
                                                                              .$2),
                                                                  style: TextButton.styleFrom(
                                                                      foregroundColor: action.$1 == 'reject' ||
                                                                              action.$1 ==
                                                                                  'cancel'
                                                                          ? c
                                                                              .inkMuted
                                                                          : c
                                                                              .accent),
                                                                  child: Text(
                                                                      action
                                                                          .$2)),
                                                        ]),
                                                  ])),
                                        if (list.length == 100)
                                          Text('Son 100 talep',
                                              style:
                                                  SwanType.caption(c.inkMuted)),
                                      ])),
                            ]))))));
  }
}

class _CreateTransferDialog extends ConsumerStatefulWidget {
  const _CreateTransferDialog({required this.options});
  final TransferRequestOptions options;
  @override
  ConsumerState<_CreateTransferDialog> createState() =>
      _CreateTransferDialogState();
}

class _CreateTransferDialogState extends ConsumerState<_CreateTransferDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _id = refereeOperationId();
  late final _account = ref.read(authSessionProvider).valueOrNull?.user.id;
  TransferCandidate? _athlete;
  String? _club, _error;
  bool _busy = false, _pending = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _pending = true;
      _error = null;
    });
    try {
      await ref.read(transferRequestServiceProvider).create(
          id: _id,
          athlete: _athlete!,
          toClub: _club!,
          reason: _reason.text.trim());
      if (!mounted ||
          _account != ref.read(authSessionProvider).valueOrNull?.user.id)
        return;
      ref.invalidate(transferRequestsProvider);
      Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          if (e is PostgrestException &&
              const {'22023', '23505', '42501', 'P0001'}.contains(e.code))
            _pending = false;
          _error = _pending
              ? 'Sonuç belirsiz; aynı talebi yeniden dene.'
              : 'Talep kaydedilemedi. Bekleyen talep, tescil ve yetkileri kontrol et.';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_account != ref.watch(authSessionProvider).valueOrNull?.user.id)
      return const AlertDialog(
          content: Text('Hesap değişti. Pencereyi kapat.'));
    final locked = _busy || _pending;
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
            title: const Text('Yeni transfer talebi'),
            content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                    child: Form(
                        key: _form,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          DropdownButtonFormField<String>(
                              value: _athlete?.key,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Sporcu ve branş'),
                              items: [
                                for (final a in widget.options.athletes)
                                  DropdownMenuItem(
                                      value: a.key,
                                      child: Text(
                                          '${a.name} · ${a.sport} · ${a.clubName}',
                                          overflow: TextOverflow.ellipsis))
                              ],
                              validator: (v) =>
                                  v == null ? 'Sporcu seç.' : null,
                              onChanged: locked
                                  ? null
                                  : (v) => setState(() {
                                        _athlete = widget.options.athletes
                                            .firstWhere((a) => a.key == v);
                                        _club = null;
                                      })),
                          DropdownButtonFormField<String>(
                              value: _club,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Tescilli hedef kulüp'),
                              items: [
                                for (final c in widget.options.clubs.where(
                                    (c) =>
                                        c.sport == _athlete?.sport &&
                                        c.id != _athlete?.clubId))
                                  DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.name,
                                          overflow: TextOverflow.ellipsis))
                              ],
                              validator: (v) =>
                                  v == null ? 'Hedef kulübü seç.' : null,
                              onChanged: locked
                                  ? null
                                  : (v) => setState(() => _club = v)),
                          TextFormField(
                              controller: _reason,
                              enabled: !locked,
                              maxLength: 500,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Talep gerekçesi'),
                              validator: (v) => v?.trim().isNotEmpty == true
                                  ? null
                                  : 'Gerekçe gerekli.'),
                          if (_error != null) Text(_error!),
                        ])))),
            actions: [
              TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(_pending
                      ? 'Kapat (talebi listeden kontrol et)'
                      : 'Vazgeç')),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy
                      ? 'Kaydediliyor…'
                      : _pending
                          ? 'Aynı talebi yeniden dene'
                          : 'Talebi oluştur'))
            ]));
  }
}
