import '../../../app/widgets/action_gate.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_page_header.dart';
import '../../courts/presentation/claim_sheet.dart';
import '../../turf/presentation/turf_field_detail_screen.dart';

class SahaOperationsScreen extends ConsumerStatefulWidget {
  const SahaOperationsScreen({super.key});
  @override
  ConsumerState<SahaOperationsScreen> createState() =>
      _SahaOperationsScreenState();
}

class _SahaOperationsScreenState extends ConsumerState<SahaOperationsScreen> {
  final _code = TextEditingController();
  bool _busy = false, _sessionChanged = false;
  int _offset = 0;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(courtWaitlistProvider);
    ref.invalidate(turfDutiesProvider(_offset));
    ref.invalidate(delegatedTurfFieldIdsProvider);
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    if (_busy || _sessionChanged) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted || _sessionChanged) return;
      _refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (mounted && !_sessionChanged) {
        _refresh();
        setState(
          () => _error =
              'İşlem tamamlanamadı. Güncel durumu kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted && !_sessionChanged) setState(() => _busy = false);
    }
  }

  Future<void> _accept(CourtWaitEntry wait) async {
    if (_busy || _sessionChanged) return;
    if (!await requireSwanAction(context, ref, SwanAction.reservation) ||
        !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final courts = await ref.read(courtServiceProvider).courts();
      final court = courts.where((c) => c.id == wait.courtId).firstOrNull;
      if (court == null) throw StateError('Court unavailable');
      if (!mounted || _sessionChanged) return;
      final choice = await showModalBottomSheet<ClaimResult>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ClaimSheet(court: court, startsAt: wait.startsAt),
      );
      if (choice == null || !mounted || _sessionChanged) return;
      await ref.read(sahaOperationsServiceProvider).acceptWait(
            wait.id,
            guests: choice.guests,
            needed: choice.needed,
          );
      if (!mounted || _sessionChanged) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kort sıran alındı. Korta varınca onayla.'),
        ),
      );
    } catch (_) {
      if (mounted && !_sessionChanged) {
        _refresh();
        setState(
          () => _error =
              'İşlem tamamlanamadı. Güncel durumu kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted && !_sessionChanged) setState(() => _busy = false);
    }
  }

  Future<void> _open(TurfDuty duty) async {
    await _act(
      () async {
        ref.invalidate(delegatedTurfFieldIdsProvider);
        final allowed = await ref.read(delegatedTurfFieldIdsProvider.future);
        if (!allowed.contains(duty.fieldId)) throw StateError('Duty ended');
        final fields = await ref.read(turfServiceProvider).fields();
        final field = fields.where((f) => f.id == duty.fieldId).firstOrNull;
        if (field == null) throw StateError('Field closed');
        if (!mounted || _sessionChanged) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => TurfFieldDetailScreen(field: field),
          ),
        );
      },
      'Saha görevin güncellendi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final queue = ref.watch(featureEnabledProvider(FeatureFlags.courtWaitlist));
    final duty = ref.watch(featureEnabledProvider(FeatureFlags.turfDelegation));
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.hasValue == true &&
          next.hasValue &&
          previous!.valueOrNull?.user.id != next.valueOrNull?.user.id) {
        setState(() => _sessionChanged = true);
        _code.clear();
      }
    });
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                SwanPageHeader(
                  title: 'Saha İşlemlerim',
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: (!queue && !duty) || _sessionChanged
                      ? Center(
                          child: Text(
                            _sessionChanged
                                ? 'Oturum değişti. Bu ekranı yeniden aç.'
                                : 'Bu özellikler şu anda hesabına açık değil.',
                            style: SwanType.body(c.inkMuted),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(SwanSpace.lg),
                          children: [
                            Text(
                              'Tüm saatler Türkiye saati.',
                              style: SwanType.caption(c.inkMuted),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _refresh,
                              child: const Text('Yenile'),
                            ),
                            if (_error != null)
                              Text(
                                _error!,
                                style: SwanType.bodySm(c.danger),
                              ),
                            if (_busy) const LinearProgressIndicator(),
                            if (queue) ...[
                              Text(
                                'Kort bekleme listen',
                                style: SwanType.h3(c.ink),
                              ),
                              Text(
                                'Fırsat otomatik rezervasyon değildir. Saati aldıktan sonra korta varınca mevcut konum onayını yap.',
                                style: SwanType.bodySm(c.inkMuted),
                              ),
                              ref.watch(courtWaitlistProvider).when(
                                    skipLoadingOnRefresh: false,
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) => _retry(
                                      'Bekleme listen yüklenemedi.',
                                      () => ref.invalidate(
                                        courtWaitlistProvider,
                                      ),
                                    ),
                                    data: (items) => Column(
                                      children: [
                                        if (items.isEmpty)
                                          Text(
                                            'Bekleme kaydın yok. Dolu gelecek saat için kort detayından katılabilirsin.',
                                            style: SwanType.bodySm(
                                              c.inkMuted,
                                            ),
                                          ),
                                        for (final w in items)
                                          _card(c, [
                                            Text(
                                              w.courtName,
                                              style: SwanType.h3(
                                                c.ink,
                                              ),
                                            ),
                                            Text(
                                              '${sahaTime(w.startsAt)} · ${w.label}',
                                              style: SwanType.bodySm(
                                                c.ink,
                                              ),
                                            ),
                                            if (w.status == 'waiting')
                                              Text(
                                                'Sıradaki konumun: ${w.position}',
                                                style: SwanType.bodySm(
                                                  c.inkMuted,
                                                ),
                                              ),
                                            if (w.status == 'offered')
                                              Text(
                                                'Son kabul: ${sahaTime(w.offeredUntil!)}',
                                                style: SwanType.bodySm(
                                                  c.inkMuted,
                                                ),
                                              ),
                                            if (w.canAccept)
                                              FilledButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _accept(w),
                                                child: const Text(
                                                  'Saati al',
                                                ),
                                              ),
                                            if (w.canLeave)
                                              TextButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _act(
                                                          () => ref
                                                              .read(
                                                                sahaOperationsServiceProvider,
                                                              )
                                                              .leaveWait(
                                                                w.id,
                                                              ),
                                                          'Bekleme listesinden çıktın.',
                                                        ),
                                                child: const Text(
                                                  'Listeden çık',
                                                ),
                                              ),
                                          ]),
                                      ],
                                    ),
                                  ),
                              TextButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/kortlar',
                                ),
                                child: const Text('Kortları aç'),
                              ),
                            ],
                            if (duty) ...[
                              const SizedBox(height: SwanSpace.lg),
                              Text(
                                'Süreli saha görevleri',
                                style: SwanType.h3(c.ink),
                              ),
                              Text(
                                'Davet süresi görevin oluşturulduğu anda başlar. Yalnız doluluk düzenleme; kalıcı yönetici rolü değişmez.',
                                style: SwanType.bodySm(c.inkMuted),
                              ),
                              TextField(
                                controller: _code,
                                maxLength: 36,
                                enabled: !_busy,
                                decoration: const InputDecoration(
                                  labelText: 'Özel görev davet kodu',
                                ),
                              ),
                              FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        if (!RegExp(
                                          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                                        ).hasMatch(
                                          _code.text.trim(),
                                        )) {
                                          setState(
                                            () => _error =
                                                'Geçerli görev davet kodunu yaz.',
                                          );
                                          return;
                                        }
                                        final code = _code.text;
                                        _act(
                                          () async {
                                            await ref
                                                .read(
                                                  sahaOperationsServiceProvider,
                                                )
                                                .redeemDuty(code);
                                            if (mounted && !_sessionChanged) {
                                              _code.clear();
                                              setState(
                                                () => _offset = 0,
                                              );
                                            }
                                          },
                                          'Saha görevi kabul edildi.',
                                        );
                                      },
                                child: const Text('Görevi kabul et'),
                              ),
                              ref.watch(turfDutiesProvider(_offset)).when(
                                    skipLoadingOnRefresh: false,
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    error: (_, __) => _retry(
                                      'Görevlerin yüklenemedi.',
                                      () => ref.invalidate(
                                        turfDutiesProvider(
                                          _offset,
                                        ),
                                      ),
                                    ),
                                    data: (page) => Column(
                                      children: [
                                        if (page.items.isEmpty)
                                          Text(
                                            'Bu sayfada saha görevi yok.',
                                            style: SwanType.bodySm(
                                              c.inkMuted,
                                            ),
                                          ),
                                        for (final d in page.items)
                                          _card(c, [
                                            Text(
                                              '${d.venueName} · ${d.fieldName}',
                                              style: SwanType.h3(
                                                c.ink,
                                              ),
                                            ),
                                            Text(
                                              '${d.issuer ? 'Verdiğin görev' : 'Aldığın görev'} · ${d.label}',
                                              style: SwanType.bodySm(
                                                c.ink,
                                              ),
                                            ),
                                            Text(
                                              'Görev bitişi: ${sahaTime(d.validUntil)}',
                                              style: SwanType.bodySm(
                                                c.inkMuted,
                                              ),
                                            ),
                                            if (d.status == 'invited')
                                              Text(
                                                'Son davet kabulü: ${sahaTime(d.inviteUntil)}',
                                                style: SwanType.caption(
                                                  c.inkMuted,
                                                ),
                                              ),
                                            if (d.live &&
                                                !d.issuer &&
                                                d.status == 'active')
                                              FilledButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _open(
                                                          d,
                                                        ),
                                                child: const Text(
                                                  'Sahayı aç',
                                                ),
                                              ),
                                            if (d.live)
                                              TextButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _act(
                                                          () => ref
                                                              .read(
                                                                sahaOperationsServiceProvider,
                                                              )
                                                              .revokeDuty(
                                                                d.id,
                                                              ),
                                                          'Saha görevi sona erdi.',
                                                        ),
                                                child: Text(
                                                  d.issuer
                                                      ? 'Görevi geri al'
                                                      : 'Görevi bırak',
                                                ),
                                              ),
                                          ]),
                                        Wrap(
                                          children: [
                                            if (_offset > 0)
                                              TextButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => setState(
                                                          () => _offset -= 40,
                                                        ),
                                                child: const Text(
                                                  'Önceki görevler',
                                                ),
                                              ),
                                            if (page.hasMore)
                                              TextButton(
                                                onPressed: _busy
                                                    ? null
                                                    : () => setState(
                                                          () => _offset += 40,
                                                        ),
                                                child: const Text(
                                                  'Sonraki görevler',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _retry(String message, VoidCallback retry) => Column(
        children: [
          Text(message),
          TextButton(onPressed: retry, child: const Text('Tekrar dene')),
        ],
      );
  Widget _card(SwanPalette c, List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}
