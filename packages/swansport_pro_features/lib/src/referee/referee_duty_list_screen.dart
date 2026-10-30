import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../federation/federation_operations_panel.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_theme.dart';
import 'referee_operations_panel.dart';

/// Optional injection callback for assignment response in tests.
typedef RespondAssignmentCallback = Future<void> Function({
  required String officialId,
  required bool accept,
  String? reason,
});

/// Shared referee duty list screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.isReferee` and `FeatureFlags.refereeCockpit`.
/// - Accept/decline workflow with private decline reason dialog guarded by actor ID.
/// - Transition to lineup, live cockpit (only for supported protocols: futbol,
///   basketbol, tenis), and match report.
final class SharedRefereeDutyListScreen extends ConsumerStatefulWidget {
  const SharedRefereeDutyListScreen({
    this.onRespondAssignment,
    super.key,
  });

  final RespondAssignmentCallback? onRespondAssignment;

  @override
  ConsumerState<SharedRefereeDutyListScreen> createState() =>
      _SharedRefereeDutyListScreenState();
}

final class _SharedRefereeDutyListScreenState
    extends ConsumerState<SharedRefereeDutyListScreen> {
  int _tab = 0;
  final Set<String> _busyIds = <String>{};
  String? _errorMessage;

  Future<void> _respond(RefereeMatchSummary match, bool accept) async {
    if (_busyIds.contains(match.officialId)) return;
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final actorId = ref.read(authSessionProvider).valueOrNull?.user.id;
    String? reason;
    if (!accept) {
      final controller = TextEditingController();
      try {
        reason = await showDialog<String>(
          context: context,
          builder: (dialogContext) => _RefereeActorDialogGuard(
            actorId: actorId,
            child: AlertDialog(
              title: const Text('Mazeret Bildir'),
              content: TextField(
                key: const Key('referee-decline-reason-input'),
                controller: controller,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText:
                      'Kısa mazeret açıklaması (yalnız MHK/Başkan görür)',
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  key: const Key('referee-decline-submit-btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.danger,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.of(dialogContext).pop(text);
                    }
                  },
                  child: const Text('Bildir'),
                ),
              ],
            ),
          ),
        );
      } finally {
        controller.dispose();
      }
      if (reason == null || !mounted) return;
    }

    setState(() {
      _busyIds.add(match.officialId);
      _errorMessage = null;
    });
    try {
      final callback = widget.onRespondAssignment;
      if (callback != null) {
        await callback(
          officialId: match.officialId,
          accept: accept,
          reason: reason,
        );
      } else {
        final service = ref.read(sportsRolesServiceProvider);
        if (service == null) {
          throw StateError('Çevrimiçi bağlantı gerekli');
        }
        await service.respondMatchAssignment(
          match.officialId,
          accept,
          reason: reason,
        );
      }
      ref.invalidate(myRefereeMatchesProvider);
      ref.invalidate(refereeDutyMatchesProvider);
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = classifyOperationError(error).userMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(match.officialId));
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
        title: 'Hakem Görevleri',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Hakem operasyon yetkisi gerekli',
          body: 'Hakem görev listesi yalnız aktif hakem hesaplarına açıktır.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    if (flagsAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Hakem Görevleri',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (flagsAsync.hasError) {
      return host.chrome.buildPage(
        context,
        title: 'Hakem Görevleri',
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
        title: 'Hakem Görevleri',
        body: const FederationPanelMessage(
          icon: Icons.toggle_off_outlined,
          title: 'Hakem kokpiti şu anda devre dışı',
          body: 'Hakem operasyon modülü özellik bayrağı kapalıdır.',
        ),
      );
    }

    final dutiesAsync = ref.watch(refereeDutyMatchesProvider);
    return host.chrome.buildPage(
      context,
      title: 'Hakem Görevleri',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
          onPressed: () {
            ref.invalidate(myRefereeMatchesProvider);
            ref.invalidate(refereeDutyMatchesProvider);
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
            children: [
              ChoiceChip(
                key: const Key('referee-duties-tab-upcoming'),
                label: const Text('Yaklaşan / Bugün'),
                selected: _tab == 0,
                onSelected: (_) => setState(() => _tab = 0),
              ),
              ChoiceChip(
                key: const Key('referee-duties-tab-completed'),
                label: const Text('Tamamlananlar & Geçmiş'),
                selected: _tab == 1,
                onSelected: (_) => setState(() => _tab = 1),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: _errorMessage!,
              onRetry: () => ref.invalidate(myRefereeMatchesProvider),
            ),
          ],
          const SizedBox(height: 12),
          dutiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () => ref.invalidate(myRefereeMatchesProvider),
            ),
            data: (matches) {
              final filtered = matches.where((m) {
                final active = m.matchStatus == 'scheduled' &&
                    (m.status == MatchOfficialStatus.assigned ||
                        m.status == MatchOfficialStatus.accepted);
                return _tab == 0 ? active : !active;
              }).toList(growable: false);

              if (filtered.isEmpty) {
                return const FederationPanelMessage(
                  icon: Icons.event_busy_outlined,
                  title: 'Bu bölümde maç görevi yok',
                  body: 'Seçili sekmede hakem atamanız bulunmuyor.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final match in filtered) ...[
                    _buildMatchCard(
                      context: context,
                      host: host,
                      theme: theme,
                      match: match,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard({
    required BuildContext context,
    required ProFeatureHostScope host,
    required ProFeatureThemeData theme,
    required RefereeMatchSummary match,
  }) {
    final isBusy = _busyIds.contains(match.officialId);
    final supportsLive = refereeSupportsLive(match.sportCode);
    final isMatchDay = refereeSameDay(match.startsAt, DateTime.now());

    return Container(
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
            '${match.homeClubName ?? 'Ev sahibi'} — ${match.awayClubName ?? 'Deplasman'}',
            style: TextStyle(
              color: theme.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sharedRefereeTime(match.startsAt),
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '${match.sportCode} · ${match.location ?? 'Saha belirtilmedi'}'
            '${match.cityCode == null ? '' : ' · İl ${match.cityCode}'}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${sharedRefereeDutyLabel(match.duty)} · '
            '${sharedRefereeStatusLabel(match.status)} · '
            '${sharedRefereeMatchStatusLabel(match.matchStatus)}',
            style: TextStyle(
              color: theme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (match.declineReason != null &&
              match.declineReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Mazeret notunuz: ${match.declineReason}',
              style: TextStyle(color: theme.inkMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          if (isBusy)
            const Center(child: CircularProgressIndicator())
          else if (match.status == MatchOfficialStatus.assigned &&
              match.matchStatus == 'scheduled')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('referee-duty-accept-${match.officialId}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _respond(match, true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Kabul Et'),
                ),
                OutlinedButton.icon(
                  key: Key('referee-duty-decline-${match.officialId}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _respond(match, false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Mazeret Bildir'),
                ),
              ],
            )
          else if (match.canControl &&
              supportsLive &&
              match.matchStatus == 'scheduled' &&
              isMatchDay)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('referee-duty-lineup-${match.matchId}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () =>
                      host.navigator.openRefereeLineup(match.matchId),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Müsabakayı Yönet (Esame)'),
                ),
                OutlinedButton.icon(
                  key: Key('referee-duty-live-${match.matchId}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () =>
                      host.navigator.openRefereeLiveCockpit(match.matchId),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('Canlı Kokpit'),
                ),
                OutlinedButton.icon(
                  key: Key('referee-duty-report-${match.matchId}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () =>
                      host.navigator.openRefereeMatchReport(match.matchId),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Maç Raporu'),
                ),
              ],
            ),
          if (!supportsLive) ...[
            const SizedBox(height: 6),
            Text(
              'Bu branşın canlı sonuç protokolü henüz açık değil.',
              style: TextStyle(
                color: theme.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefereeActorDialogGuard extends ConsumerWidget {
  const _RefereeActorDialogGuard({
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
        navigator.pop();
      }
    });
    return const SizedBox.shrink();
  }
}
