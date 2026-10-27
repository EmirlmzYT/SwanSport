import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../federation/federation_operations_panel.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_theme.dart';

/// Optional injection callback for lineup verification in tests.
typedef VerifyLineupCallback = Future<void> Function({
  required String matchId,
  required List<String> homeStarters,
  required List<String> awayStarters,
  required List<String> homeSubs,
  required List<String> awaySubs,
});

/// Shared referee digital lineup approval screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.isReferee` and `FeatureFlags.refereeCockpit`.
/// - Match UUID validation (`isPublicMatchId`) before backend queries.
/// - Immutable snapshot contract (`match_lineup_approvals`), server-side
///   `home`/`away` determination, and real approval row IDs.
final class SharedRefereeLineupApprovalScreen extends ConsumerStatefulWidget {
  const SharedRefereeLineupApprovalScreen({
    required this.matchId,
    this.onVerifyLineup,
    super.key,
  });

  final String matchId;
  final VerifyLineupCallback? onVerifyLineup;

  @override
  ConsumerState<SharedRefereeLineupApprovalScreen> createState() =>
      _SharedRefereeLineupApprovalScreenState();
}

final class _SharedRefereeLineupApprovalScreenState
    extends ConsumerState<SharedRefereeLineupApprovalScreen> {
  int _tab = 0;
  bool _busy = false;
  String? _errorMessage;
  final Map<String, String> _selections = <String, String>{};

  Future<void> _lock(
    List<RefereeLineupCandidate> rows,
    ProFeatureHostScope host,
  ) async {
    if (_busy) return;
    final selectedIds = _selections.entries
        .where((e) => e.value != 'unselected')
        .map((e) => e.key)
        .toSet();
    if (selectedIds.any(
      (id) => !rows.any((r) => r.athleteId == id && r.eligible),
    )) {
      setState(() {
        _errorMessage =
            'Seçtiğin kadro veya uygunluk değişti. Taslağı sıfırla ve güncel adayları yeniden seç.';
      });
      return;
    }

    List<String> idsFor(String side, String role) => [
          for (final r in rows)
            if (r.side == side &&
                _selections[r.athleteId] == role &&
                r.eligible)
              r.athleteId,
        ];

    final homeStarters = idsFor('home', 'starter');
    final awayStarters = idsFor('away', 'starter');
    final homeSubs = idsFor('home', 'substitute');
    final awaySubs = idsFor('away', 'substitute');

    if (homeStarters.isEmpty || awayStarters.isEmpty) {
      setState(() {
        _errorMessage = 'İki takım için sahaya çıkanları seç.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final callback = widget.onVerifyLineup;
      if (callback != null) {
        await callback(
          matchId: widget.matchId,
          homeStarters: homeStarters,
          awayStarters: awayStarters,
          homeSubs: homeSubs,
          awaySubs: awaySubs,
        );
      } else {
        final service = ref.read(sportsRolesServiceProvider);
        if (service == null) {
          throw StateError('Çevrimiçi bağlantı gerekli');
        }
        await service.verifyMatchLineup(
          widget.matchId,
          homeStarters,
          awayStarters,
          homeSubs: homeSubs,
          awaySubs: awaySubs,
        );
      }
      ref.invalidate(matchLineupApprovalsProvider(widget.matchId));
      ref.invalidate(refereeLineupCandidatesProvider(widget.matchId));
      if (mounted) {
        host.navigator.openRefereeLiveCockpit(widget.matchId);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = classifyOperationError(error).userMessage;
        });
      }
      ref.invalidate(matchLineupApprovalsProvider(widget.matchId));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
        title: 'Dijital Esame',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Hakem operasyon yetkisi gerekli',
          body: 'Esame görüntüleme ve onaylama yalnız yetkili hakeme açıktır.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    if (flagsAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Dijital Esame',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (flagsAsync.hasError) {
      return host.chrome.buildPage(
        context,
        title: 'Dijital Esame',
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
        title: 'Dijital Esame',
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
        title: 'Dijital Esame',
        body: const FederationPanelMessage(
          icon: Icons.warning_amber_rounded,
          title: 'Geçersiz müsabaka kimliği',
          body:
              'Esame sorgusu için geçerli bir müsabaka UUID değeri gereklidir.',
        ),
      );
    }

    final approvalsAsync =
        ref.watch(matchLineupApprovalsProvider(widget.matchId));
    final candidatesAsync =
        ref.watch(refereeLineupCandidatesProvider(widget.matchId));
    final approvals = approvalsAsync.asData?.value ?? const [];
    final locked = approvals.isNotEmpty;

    return PopScope(
      canPop: !_busy,
      child: host.chrome.buildPage(
        context,
        title: 'Dijital Esame',
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () {
              ref.invalidate(matchLineupApprovalsProvider(widget.matchId));
              ref.invalidate(refereeLineupCandidatesProvider(widget.matchId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  key: const Key('lineup-tab-home'),
                  label: const Text('Ev Sahibi'),
                  selected: _tab == 0,
                  onSelected: (_) => setState(() => _tab = 0),
                ),
                ChoiceChip(
                  key: const Key('lineup-tab-away'),
                  label: const Text('Deplasman'),
                  selected: _tab == 1,
                  onSelected: (_) => setState(() => _tab = 1),
                ),
                if (_selections.isNotEmpty && !locked && !_busy)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selections.clear();
                      _errorMessage = null;
                    }),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Taslağı Sıfırla'),
                  ),
              ],
            ),
            if (locked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Onaylanmış Değişmez Esame Snapshot (Kilitli)',
                      style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final approval in approvals)
                      Text(
                        '${approval.side == MatchLineupSide.home ? 'Ev Sahibi' : 'Deplasman'} · '
                        'Onay ID: ${approval.id} · '
                        'İlk Kadro: ${approval.starterAthleteIds.length} · '
                        'Yedek: ${approval.substituteAthleteIds.length}',
                        style: TextStyle(color: theme.inkMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              FederationPanelMessage(
                icon: Icons.error_outline_rounded,
                title: _errorMessage!,
                onRetry: () {
                  ref.invalidate(matchLineupApprovalsProvider(widget.matchId));
                  ref.invalidate(
                    refereeLineupCandidatesProvider(widget.matchId),
                  );
                },
              ),
            ],
            if (approvalsAsync.hasError) ...[
              const SizedBox(height: 10),
              FederationPanelMessage(
                icon: Icons.error_outline_rounded,
                title:
                    classifyOperationError(approvalsAsync.error!).userMessage,
                onRetry: () => ref.invalidate(
                  matchLineupApprovalsProvider(widget.matchId),
                ),
              ),
            ],
            const SizedBox(height: 12),
            candidatesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => FederationPanelMessage(
                icon: Icons.error_outline_rounded,
                title: classifyOperationError(err).userMessage,
                onRetry: () => ref.invalidate(
                  refereeLineupCandidatesProvider(widget.matchId),
                ),
              ),
              data: (rows) {
                final activeSide = _tab == 0 ? 'home' : 'away';
                final visible = rows
                    .where((r) => r.side == activeSide)
                    .toList(growable: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (visible.isEmpty)
                      const FederationPanelMessage(
                        icon: Icons.groups_outlined,
                        title: 'Bu taraf için aday sporcu bulunamadı',
                        body:
                            'Yalnız ilgili müsabakanın katılımcı kulüp adayları gösterilir.',
                      )
                    else
                      for (final candidate in visible) ...[
                        _buildCandidateCard(
                          theme: theme,
                          candidate: candidate,
                          locked: locked,
                        ),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 12),
                    if (_busy)
                      const Center(child: CircularProgressIndicator())
                    else if (locked)
                      FilledButton.icon(
                        key: const Key('lineup-go-live-btn'),
                        onPressed: () => host.navigator.openRefereeLiveCockpit(
                          widget.matchId,
                        ),
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('Esame Kilitli · Canlı Kokpite Geç'),
                      )
                    else
                      FilledButton.icon(
                        key: const Key('lineup-lock-submit-btn'),
                        onPressed: approvalsAsync.isLoading ||
                                approvalsAsync.hasError ||
                                rows.isEmpty
                            ? null
                            : () => _lock(rows, host),
                        icon: const Icon(Icons.lock_rounded),
                        label: const Text('Esameyi Onayla ve Kilitle'),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Kilit geri alınamaz. Sağlık ve kimlik koşulları sunucuda tekrar denetlenir.',
                      style: TextStyle(color: theme.inkMuted, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateCard({
    required ProFeatureThemeData theme,
    required RefereeLineupCandidate candidate,
    required bool locked,
  }) {
    final eligibilityLabel = switch (candidate.eligibilityStatus) {
      'medical' => 'Oynayamaz · Tıbbi Engel',
      'suspended' => 'Cezalı',
      'rested' => 'Dinlendiriliyor',
      'license' => 'Vize / lisans engeli',
      _ => 'Uygun',
    };
    final tone = candidate.eligibilityStatus == 'rested'
        ? theme.warning
        : (candidate.eligible ? theme.success : theme.danger);
    final currentValue = locked
        ? candidate.selection
        : (_selections[candidate.athleteId] ?? 'unselected');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${candidate.jerseyNumber ?? '—'} · ${candidate.name ?? candidate.maskedRef}',
            style: TextStyle(
              color: theme.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lisans: ${candidate.licenseNumber ?? 'Yok'} · Vize: '
            '${candidate.licenseExpiresOn == null ? 'Yok' : '${candidate.licenseExpiresOn!.day}.${candidate.licenseExpiresOn!.month}.${candidate.licenseExpiresOn!.year}'}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.line),
            ),
            child: Row(
              children: [
                Icon(
                  candidate.eligible
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_rounded,
                  color: tone,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eligibilityLabel,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Esame seçimi'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: Key('lineup-select-${candidate.athleteId}'),
                value: currentValue,
                isExpanded: true,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'unselected',
                    child: Text('Dışarıda'),
                  ),
                  DropdownMenuItem(
                    value: 'starter',
                    child: Text('Sahaya çıkan'),
                  ),
                  DropdownMenuItem(
                    value: 'substitute',
                    child: Text('Yedek'),
                  ),
                ],
                onChanged: locked || _busy || !candidate.eligible
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(
                            () => _selections[candidate.athleteId] = value,
                          );
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
