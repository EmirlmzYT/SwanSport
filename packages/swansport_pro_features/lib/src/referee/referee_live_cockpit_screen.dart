import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../federation/federation_operations_panel.dart';
import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_theme.dart';

/// Shared live referee cockpit screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.isReferee` and `FeatureFlags.refereeCockpit`.
/// - Match UUID validation (`isPublicMatchId`) before backend queries.
/// - Supported live protocols (`futbol`, `basketbol`, `tenis`); blocks unsupported
///   individual sports without fabricating team scores.
/// - Append-only events (`referee_append_match_event`), non-destructive `undo`,
///   and idempotent retry using the exact same `p_operation_id` and payload via
///   `refereeMutationProvider(matchId)`.
/// - Clean `Timer.periodic` cancellation in `dispose()` and dirty-state guard
///   registration when a mutation is in flight or uncertain.
final class SharedRefereeLiveCockpitScreen extends ConsumerStatefulWidget {
  const SharedRefereeLiveCockpitScreen({
    required this.matchId,
    super.key,
  });

  final String matchId;

  @override
  ConsumerState<SharedRefereeLiveCockpitScreen> createState() =>
      _SharedRefereeLiveCockpitScreenState();
}

final class _SharedRefereeLiveCockpitScreenState
    extends ConsumerState<SharedRefereeLiveCockpitScreen> {
  Timer? _ticker;
  ProDirtyStateRegistration? _dirtyRegistration;

  @override
  void initState() {
    super.initState();
    _dirtyRegistration = ref
        .read(proDirtyStateCoordinatorProvider)
        .register('referee-live-${widget.matchId}');
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TickerMode.valuesOf(context).enabled) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dirtyRegistration?.dispose();
    super.dispose();
  }

  Future<void> _send(
    RefereeLiveState state,
    String kind, {
    String? side,
    String? athlete,
    String? replacement,
    String? card,
  }) async {
    final mutation = ref.read(refereeMutationProvider(widget.matchId));
    if (mutation.busy || mutation.pending) return;
    unawaited(HapticFeedback.selectionClick());
    await ref.read(refereeMutationProvider(widget.matchId).notifier).submit(
      'referee_append_match_event',
      <String, dynamic>{
        'p_match_id': widget.matchId,
        'p_operation_id': refereeOperationId(),
        'p_expected_version': state.version,
        'p_kind': kind,
        'p_side': side,
        'p_athlete_id': athlete,
        'p_replacement_id': replacement,
        'p_card': card,
      },
    );
  }

  Future<void> _openPlayerActionDialog(
    RefereeLiveState state,
    List<RefereeLineupCandidate> candidates,
    bool substitution,
  ) async {
    final actorId = ref.read(authSessionProvider).valueOrNull?.user.id;
    var side = 'home';
    String? outAthleteId;
    String? intoAthleteId;
    var cardKind = 'yellow';

    String athleteLabel(String id) {
      final found = candidates.where((r) => r.athleteId == id);
      if (found.isEmpty) {
        return '#${id.replaceAll('-', '').substring(0, 6).toUpperCase()}';
      }
      final c = found.first;
      return '${c.jerseyNumber ?? '—'} · ${c.name ?? c.maskedRef}';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          final active = state.squads['active_$side'] ?? const <String>[];
          final bench = state.squads['bench_$side'] ?? const <String>[];
          return _LiveActorGuard(
            actorId: actorId,
            child: AlertDialog(
              title: Text(substitution ? 'Oyuncu Değişikliği' : 'Kart / Faul'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InputDecorator(
                        decoration: const InputDecoration(labelText: 'Takım'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: side,
                            isExpanded: true,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'home',
                                child: Text('Ev Sahibi'),
                              ),
                              DropdownMenuItem(
                                value: 'away',
                                child: Text('Deplasman'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setLocal(() {
                                  side = val;
                                  outAthleteId = null;
                                  intoAthleteId = null;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: substitution ? 'Çıkan sporcu' : 'Sporcu',
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: outAthleteId,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Sporcu seçin'),
                            items: [
                              for (final id in active)
                                DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    athleteLabel(id),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (val) =>
                                setLocal(() => outAthleteId = val),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (substitution)
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Giren sporcu',
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: intoAthleteId,
                              isExpanded: true,
                              isDense: true,
                              hint: const Text('Yedek sporcu seçin'),
                              items: [
                                for (final id in bench)
                                  DropdownMenuItem(
                                    value: id,
                                    child: Text(
                                      athleteLabel(id),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (val) =>
                                  setLocal(() => intoAthleteId = val),
                            ),
                          ),
                        )
                      else
                        InputDecorator(
                          decoration: const InputDecoration(labelText: 'Olay'),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: cardKind,
                              isExpanded: true,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'yellow',
                                  child: Text('Sarı Kart'),
                                ),
                                DropdownMenuItem(
                                  value: 'red',
                                  child: Text('Kırmızı Kart'),
                                ),
                                DropdownMenuItem(
                                  value: 'two_minutes',
                                  child: Text('2 dk Cezası'),
                                ),
                                DropdownMenuItem(
                                  value: 'technical',
                                  child: Text('Teknik Faul'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setLocal(() => cardKind = val);
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: outAthleteId == null ||
                          (substitution && intoAthleteId == null)
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      await _send(
        state,
        substitution ? 'substitution' : 'card',
        side: side,
        athlete: outAthleteId,
        replacement: substitution ? intoAthleteId : null,
        card: substitution ? null : cardKind,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.isReferee) {
      return host.chrome.buildPage(
        context,
        title: 'Canlı Hakem Kokpiti',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Hakem operasyon yetkisi gerekli',
          body: 'Canlı hakem kokpiti yalnız yetkili hakem hesaplarına açıktır.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    final enabled =
        flagsAsync.valueOrNull?.has(FeatureFlags.refereeCockpit) ?? true;
    if (!enabled) {
      return host.chrome.buildPage(
        context,
        title: 'Canlı Hakem Kokpiti',
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
        title: 'Canlı Hakem Kokpiti',
        body: const FederationPanelMessage(
          icon: Icons.warning_amber_rounded,
          title: 'Geçersiz müsabaka kimliği',
          body:
              'Canlı kokpit için geçerli bir müsabaka UUID değeri gereklidir.',
        ),
      );
    }

    final stateAsync = ref.watch(refereeMatchStateProvider(widget.matchId));
    final mutation = ref.watch(refereeMutationProvider(widget.matchId));
    final candidates = ref
            .watch(refereeLineupCandidatesProvider(widget.matchId))
            .asData
            ?.value ??
        const <RefereeLineupCandidate>[];

    if (mutation.busy || mutation.pending) {
      _dirtyRegistration?.markDirty();
    } else {
      _dirtyRegistration?.markClean();
    }

    return PopScope(
      canPop: !mutation.busy && !mutation.pending,
      child: host.chrome.buildPage(
        context,
        title: 'Canlı Hakem Kokpiti',
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
                body: 'Canlı müsabaka durumu şu anda okunamıyor.',
              );
            }

            final seconds = s.secondsAt(DateTime.now());
            final supportsLive = refereeSupportsLive(s.sportCode);
            final blocked = mutation.busy ||
                mutation.pending ||
                s.isClosed ||
                stateAsync.isLoading ||
                !supportsLive;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildScoreboardCard(
                  theme: theme,
                  state: s,
                  seconds: seconds,
                  pendingUnconfirmed: mutation.pending,
                ),
                const SizedBox(height: 12),
                if (mutation.busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (mutation.error != null) ...[
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
                              ? 'Ağ yanıtı belirsiz — Sunucu onayı bekleniyor (Skor henüz kesinleşmedi)'
                              : 'İşlem reddedildi',
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
                          key: const Key('referee-live-retry-btn'),
                          onPressed: () {
                            if (mutation.pending) {
                              ref
                                  .read(
                                    refereeMutationProvider(widget.matchId)
                                        .notifier,
                                  )
                                  .retry();
                            } else {
                              ref.invalidate(
                                refereeMatchStateProvider(widget.matchId),
                              );
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            mutation.pending
                                ? 'Aynı işlemi tekrar dene'
                                : 'Güncel kaydı yükle',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!supportsLive) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.warning),
                    ),
                    child: Text(
                      'Bu branşın canlı sonuç protokolü henüz desteklenmiyor.',
                      style: TextStyle(
                        color: theme.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('referee-live-score-home-btn'),
                      onPressed: blocked
                          ? null
                          : () => _send(s, 'score', side: 'home'),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: Text(
                        s.sportCode == 'tenis'
                            ? 'Ev · Oyun +1'
                            : 'Ev · Skor +1',
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('referee-live-score-away-btn'),
                      onPressed: blocked
                          ? null
                          : () => _send(s, 'score', side: 'away'),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: Text(
                        s.sportCode == 'tenis'
                            ? 'Dep · Oyun +1'
                            : 'Dep · Skor +1',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('referee-live-clock-btn'),
                      onPressed: blocked
                          ? null
                          : () => _send(
                                s,
                                s.clockStartedAt == null
                                    ? 'clock_start'
                                    : 'clock_pause',
                              ),
                      icon: const Icon(Icons.timer_rounded),
                      label: Text(
                        s.clockStartedAt == null
                            ? 'Süreyi Başlat'
                            : 'Süreyi Durdur',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('referee-live-card-btn'),
                      onPressed: blocked || candidates.isEmpty
                          ? null
                          : () => _openPlayerActionDialog(s, candidates, false),
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Kart / Faul'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('referee-live-sub-btn'),
                      onPressed: blocked || candidates.isEmpty
                          ? null
                          : () => _openPlayerActionDialog(s, candidates, true),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Oyuncu Değişikliği'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('referee-live-period-btn'),
                      onPressed: blocked ? null : () => _send(s, 'period_end'),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text(
                        s.sportCode == 'tenis'
                            ? 'Seti Bitir'
                            : 'Periyot / Devre Bitir',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('referee-live-undo-btn'),
                      onPressed: blocked ||
                              !s.events
                                  .any((e) => e.kind != 'undo' && !e.undone)
                          ? null
                          : () => _send(s, 'undo'),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Son Olayı Geri Al'),
                    ),
                    FilledButton.tonalIcon(
                      key: const Key('referee-live-finish-report-btn'),
                      onPressed: mutation.busy ||
                              mutation.pending ||
                              s.clockStartedAt != null
                          ? null
                          : () => host.navigator.openRefereeMatchReport(
                                widget.matchId,
                              ),
                      icon: const Icon(Icons.fact_check_rounded),
                      label: Text(
                        s.isClosed
                            ? 'Tescilli Rapor'
                            : 'Müsabakayı Bitir ve Raporla',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Raporlamadan önce süreyi durdur. Bağlantı belirsizse yeni olay eklemeden aynı işlemi tekrar dene.',
                  style: TextStyle(color: theme.inkMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  'Olay Akışı (Append-Only)',
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in s.events.reversed) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.line),
                    ),
                    child: Text(
                      '${e.elapsedSeconds ~/ 60}′ · ${_liveEventLabel(e)}'
                      '${e.side == null ? '' : ' · ${e.side == 'home' ? 'Ev Sahibi' : 'Deplasman'}'}'
                      '${e.undone ? ' · Geri alındı' : ''}',
                      style: TextStyle(
                        color: e.undone ? theme.inkMuted : theme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreboardCard({
    required ProFeatureThemeData theme,
    required RefereeLiveState state,
    required int seconds,
    required bool pendingUnconfirmed,
  }) {
    final leftScore =
        state.sportCode == 'tenis' ? state.periodHome : state.homeScore;
    final rightScore =
        state.sportCode == 'tenis' ? state.periodAway : state.awayScore;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        children: [
          Text(
            state.sportCode == 'tenis'
                ? 'Set ${state.period} · Oyun'
                : 'Periyot / Devre ${state.period}',
            style: TextStyle(
              color: theme.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$leftScore — $rightScore',
            style: TextStyle(
              color: theme.ink,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (state.sets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Tamamlananlar: ${state.sets.map((p) => '${p.home}–${p.away}').join(' · ')}',
              style: TextStyle(color: theme.inkMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              color: theme.accent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.isClosed
                ? 'Resmi rapor tescilli'
                : (pendingUnconfirmed
                    ? 'Sunucu kaydı · sürüm ${state.version} (Bekleyen işlem doğrulanmadı)'
                    : 'Sunucu kaydı · sürüm ${state.version}'),
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LiveActorGuard extends ConsumerWidget {
  const _LiveActorGuard({
    required this.actorId,
    required this.child,
  });

  final String? actorId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authSessionProvider).valueOrNull?.user.id == actorId) {
      return child;
    }
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && route is PopupRoute<dynamic> && route.isCurrent) {
        navigator.pop(false);
      }
    });
    return const SizedBox.shrink();
  }
}

String _liveEventLabel(RefereeLiveEvent e) => switch (e.kind) {
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
