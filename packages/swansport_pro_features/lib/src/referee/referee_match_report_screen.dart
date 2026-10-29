import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../federation/federation_operations_panel.dart';
import '../host/pro_dirty_state.dart';
import '../host/pro_feature_context.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';

/// Shared referee official match report screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.isReferee` and `FeatureFlags.refereeCockpit`.
/// - Match UUID validation (`isPublicMatchId`) before backend queries.
/// - Immutable report contract (`referee_submit_match_report`) and idempotent
///   retry with the exact same `p_operation_id` and payload via
///   `refereeMutationProvider(matchId)`.
/// - Draft preservation on network/submission failure and isolation across
///   `(userId, matchId)` via `refereeReportDraftsProvider`.
/// - Explicit non-qualified electronic signature disclosure.
final class SharedRefereeMatchReportScreen extends ConsumerStatefulWidget {
  const SharedRefereeMatchReportScreen({
    required this.matchId,
    super.key,
  });

  final String matchId;

  @override
  ConsumerState<SharedRefereeMatchReportScreen> createState() =>
      _SharedRefereeMatchReportScreenState();
}

final class _SharedRefereeMatchReportScreenState
    extends ConsumerState<SharedRefereeMatchReportScreen> {
  final TextEditingController _notesController = TextEditingController();
  ProDirtyStateRegistration? _dirtyRegistration;
  String? _hydratedScopeKey;

  @override
  void initState() {
    super.initState();
    _dirtyRegistration = ref
        .read(proDirtyStateCoordinatorProvider)
        .register('referee-report-${widget.matchId}');
  }

  @override
  void dispose() {
    _dirtyRegistration?.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _effectiveUserId(WidgetRef ref) {
    final contextKey = ref.watch(proFeatureContextProvider);
    if (contextKey != null && contextKey.userId.isNotEmpty) {
      return contextKey.userId;
    }
    return ref.watch(authSessionProvider).valueOrNull?.user.id ?? 'local';
  }

  void _syncDraftFromStore(String userId) {
    final scopeKey = '$userId:${widget.matchId}';
    if (_hydratedScopeKey == scopeKey) return;
    _hydratedScopeKey = scopeKey;
    final stored = ref
        .read(refereeReportDraftsProvider)
        .draftFor(userId: userId, matchId: widget.matchId);
    _notesController.text = stored ?? '';
  }

  Future<void> _sign(
    RefereeLiveState state,
    String userId,
    ProFeatureHostScope host,
  ) async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    ref.read(refereeReportDraftsProvider.notifier).saveDraft(
          userId: userId,
          matchId: widget.matchId,
          notes: notes,
        );

    final ok =
        await ref.read(refereeMutationProvider(widget.matchId).notifier).submit(
      'referee_submit_match_report',
      <String, dynamic>{
        'p_match_id': widget.matchId,
        'p_operation_id': refereeOperationId(),
        'p_expected_version': state.version,
        'p_notes': notes,
      },
    );
    if (ok && mounted) {
      _onReportRegistered(userId, host);
    }
  }

  void _onReportRegistered(String userId, ProFeatureHostScope host) {
    ref.read(refereeReportDraftsProvider.notifier).clearDraft(
          userId: userId,
          matchId: widget.matchId,
        );
    _dirtyRegistration?.markClean();
    host.chrome.showMessage(
      context,
      'Resmi maç raporu sunucuda tescil edildi.',
      tone: ProFeatureMessageTone.success,
    );
    host.navigator.openRefereeDuties();
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.isReferee) {
      return host.chrome.buildPage(
        context,
        title: 'Resmi Maç Raporu',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Hakem operasyon yetkisi gerekli',
          body: 'Resmi maç raporu yalnız yetkili hakem hesaplarına açıktır.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    if (flagsAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Resmi Maç Raporu',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (flagsAsync.hasError) {
      return host.chrome.buildPage(
        context,
        title: 'Resmi Maç Raporu',
        body: FederationPanelMessage(
          icon: Icons.error_outline_rounded,
          title: classifyOperationError(flagsAsync.error!).userMessage,
          onRetry: () => ref.invalidate(featureFlagsProvider),
        ),
      );
    }
    final enabled =
        flagsAsync.valueOrNull?.has(FeatureFlags.refereeCockpit) ?? false;
    if (!enabled) {
      return host.chrome.buildPage(
        context,
        title: 'Resmi Maç Raporu',
        body: const FederationPanelMessage(
          icon: Icons.toggle_off_outlined,
          title: 'Hakem kokpiti şu anda devre dışı',
          body: 'Hakem operasyon modülü özellik bayrağı kapalıdır.',
        ),
      );
    }

    if (!isPublicMatchId(widget.matchId)) {
      return host.chrome.buildPage(
        context,
        title: 'Resmi Maç Raporu',
        body: const FederationPanelMessage(
          icon: Icons.warning_amber_rounded,
          title: 'Geçersiz müsabaka kimliği',
          body: 'Maç raporu için geçerli bir müsabaka UUID değeri gereklidir.',
        ),
      );
    }

    final userId = _effectiveUserId(ref);
    _syncDraftFromStore(userId);

    final mutation = ref.watch(refereeMutationProvider(widget.matchId));
    final stateAsync = ref.watch(refereeMatchStateProvider(widget.matchId));
    final hasUnsavedDraft = _notesController.text.trim().isNotEmpty &&
        !(stateAsync.valueOrNull?.isClosed ?? false);
    if (mutation.busy || mutation.pending || hasUnsavedDraft) {
      _dirtyRegistration?.markDirty();
    } else {
      _dirtyRegistration?.markClean();
    }

    return PopScope(
      canPop: !mutation.busy && !mutation.pending,
      child: host.chrome.buildPage(
        context,
        title: 'Resmi Maç Raporu',
        allowBack: !mutation.busy && !mutation.pending,
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () =>
                ref.invalidate(refereeMatchStateProvider(widget.matchId)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        body: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => FederationPanelMessage(
            icon: Icons.error_outline_rounded,
            title: classifyOperationError(err).userMessage,
            onRetry: () =>
                ref.invalidate(refereeMatchStateProvider(widget.matchId)),
          ),
          data: (s) {
            if (s == null) {
              return const FederationPanelMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Çevrimiçi maç kaydı gerekli',
                body: 'Müsabaka raporu durumu şu anda okunamıyor.',
              );
            }

            final validEvents = s.events
                .where((e) => e.kind != 'undo' && !e.undone)
                .toList(growable: false);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.sportCode == 'tenis'
                            ? 'Setler: ${s.sets.map((p) => '${p.home}–${p.away}').join(' · ')}'
                            : 'Sonuç: ${s.homeScore} — ${s.awayScore}',
                        style: TextStyle(
                          color: theme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Olay sürümü ${s.version} · ${validEvents.length} geçerli olay',
                        style: TextStyle(color: theme.inkMuted, fontSize: 12),
                      ),
                      if (s.reportRevisionId != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Tescil (Değişmez Kayıt): ${s.reportRevisionId}',
                          style: TextStyle(
                            color: theme.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (s.reportNotes != null &&
                          s.reportNotes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          s.reportNotes!,
                          style: TextStyle(color: theme.ink, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                if (validEvents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final e in validEvents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${e.elapsedSeconds ~/ 60}′ · ${_reportEventLabel(e)} · ${e.side ?? 'Maç'}',
                        style: TextStyle(color: theme.inkMuted, fontSize: 12),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                if (!s.isClosed)
                  TextField(
                    key: const Key('referee-report-notes-input'),
                    controller: _notesController,
                    maxLines: 5,
                    maxLength: 500,
                    enabled: !mutation.busy && !mutation.pending,
                    decoration: const InputDecoration(
                      labelText:
                          'Hakem gözlem / saha olayları / disiplin sevki',
                      helperText: 'TC, telefon veya tıbbi teşhis yazma.',
                    ),
                    onChanged: (value) {
                      ref.read(refereeReportDraftsProvider.notifier).saveDraft(
                            userId: userId,
                            matchId: widget.matchId,
                            notes: value.trim(),
                          );
                      setState(() {});
                    },
                  ),
                if (mutation.busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (mutation.error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.danger),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mutation.pending
                              ? 'Rapor gönderimi belirsiz — Yazdığın taslak korundu'
                              : 'Rapor gönderilemedi',
                          style: TextStyle(
                            color: theme.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classifyOperationError(mutation.error!).userMessage,
                          style: TextStyle(color: theme.inkMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('referee-report-retry-btn'),
                          onPressed: () async {
                            if (mutation.pending) {
                              final ok = await ref
                                  .read(
                                    refereeMutationProvider(widget.matchId)
                                        .notifier,
                                  )
                                  .retry();
                              if (ok && mounted) {
                                _onReportRegistered(userId, host);
                              }
                            } else {
                              ref.invalidate(
                                refereeMatchStateProvider(widget.matchId),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            mutation.pending
                                ? 'Aynı raporu tekrar dene'
                                : 'Güncel kaydı yükle',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (s.isClosed)
                  FilledButton.icon(
                    key: const Key('referee-report-back-duties-btn'),
                    onPressed: host.navigator.openRefereeDuties,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Görevlere Dön'),
                  )
                else
                  FilledButton.icon(
                    key: const Key('referee-report-submit-btn'),
                    onPressed: mutation.busy ||
                            mutation.pending ||
                            stateAsync.isLoading ||
                            _notesController.text.trim().isEmpty ||
                            s.clockStartedAt != null
                        ? null
                        : () => _sign(s, userId, host),
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text(
                      'Resmi Maç Raporunu İmzala ve Tescil Et',
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Bu işlem oturumunla sunucuya kaydolur; nitelikli elektronik imza değildir. Tescil sonrası hakem raporu değiştirilemez; düzeltme yetkili federasyon revizyonuyla yapılır.',
                  style: TextStyle(color: theme.inkMuted, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _reportEventLabel(RefereeLiveEvent e) => switch (e.kind) {
      'score' => 'Skor +1',
      'card' => switch (e.card) {
          'yellow' => 'Sarı kart',
          'red' => 'Kırmızı kart',
          'two_minutes' => '2 dk cezası',
          _ => 'Teknik faul',
        },
      'substitution' => 'Oyuncu değişikliği',
      'period_end' => 'Periyot / set sonu',
      'clock_start' => 'Süre başladı',
      'clock_pause' => 'Süre durdu',
      'undo' => 'Son olay geri alındı',
      _ => 'Olay',
    };
