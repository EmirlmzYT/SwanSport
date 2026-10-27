import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'federation_operations_panel.dart';

/// Optional injection callback for official match result publication in tests.
typedef PublishOfficialResultCallback = Future<String> Function({
  required String matchId,
  required Map<String, dynamic> protocol,
  required String reason,
  required int expectedVersion,
});

/// Optional injection callback for public disciplinary bulletin publication in tests.
typedef PublishDisciplinaryBulletinCallback = Future<String> Function({
  required String decisionId,
  required String publicSummary,
});

/// Optional injection callback for official match notice publication in tests.
typedef PublishFederationMatchNoticeCallback = Future<String> Function({
  required String matchId,
  required String noticeType,
  required String publicSummary,
});

/// Shared federation public bulletin, official notices, and publishing center
/// screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.canOpenFederationOperations`.
/// - Feature flag check for `FeatureFlags.federationBulletin`.
/// - Displays published immutable public disciplinary summaries and official
///   federation notices.
/// - Provides role-gated publishing actions:
///   1. Official result & revision publication (`publishResult`) strictly for
///      active `FederationDuty.resultPublisher` appointments (`access.canPublishFederationResults`).
///   2. Public disciplinary bulletin summary publication (`publishDisciplinaryBulletin`)
///      strictly for Disciplinary Board members (`access.isDisciplinaryBoardMember`).
///   3. Official match notice publication (`publishMatchNotice`, `match_cancelled` /
///      `match_postponed`) strictly for Federation President or Provincial Rep.
/// - Never leaks private referee report notes, internal disciplinary reasons,
///   or free-text result revision reasons to public projections.
/// - Does not automatically unlock legacy `resultPublisher` write access from
///   federation role labels.
final class SharedFederationBulletinsScreen extends ConsumerWidget {
  const SharedFederationBulletinsScreen({
    this.onPublishResult,
    this.onPublishDisciplinaryBulletin,
    this.onPublishMatchNotice,
    super.key,
  });

  final PublishOfficialResultCallback? onPublishResult;
  final PublishDisciplinaryBulletinCallback? onPublishDisciplinaryBulletin;
  final PublishFederationMatchNoticeCallback? onPublishMatchNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.canOpenFederationOperations) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Bülten & Duyurular',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Federasyon operasyon yetkisi gerekli',
          body:
              'Federasyon bülteni ve duyuru durumları için aktif federasyon görevi gereklidir.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    if (flagsAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Bülten & Duyurular',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (flagsAsync.hasError) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Bülten & Duyurular',
        body: FederationPanelMessage(
          icon: Icons.error_outline_rounded,
          title: classifyOperationError(flagsAsync.error!).userMessage,
          onRetry: () => ref.invalidate(featureFlagsProvider),
        ),
      );
    }
    final bulletinEnabled =
        flagsAsync.valueOrNull?.has(FeatureFlags.federationBulletin) ?? false;
    if (!bulletinEnabled) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Bülten & Duyurular',
        body: const FederationPanelMessage(
          icon: Icons.toggle_off_outlined,
          title: 'Federasyon bülten modülü devre dışı',
          body: 'Bu özellik bayrağı şu anda etkin değil.',
        ),
      );
    }

    final scopesAsync = ref.watch(federationConsoleScopesProvider);
    final scopes = resolveEffectiveFederationScopes(
      scopesAsync.valueOrNull ?? const [],
      access,
    );
    final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
    final selectedScope = scopes
            .where((item) => federationScopeKey(item) == selectedKey)
            .firstOrNull ??
        scopes.firstOrNull;

    final filter = (
      sportCode: selectedScope?.sportCode,
      cityCode: selectedScope?.cityCode,
      offset: 0,
      limit: 50,
    );
    final bulletinAsync = ref.watch(
      federationDisciplinaryBulletinProvider(filter),
    );
    final noticesAsync = ref.watch(federationNoticesProvider(filter));

    final canPublishResults = access.canPublishFederationResults;
    final canPublishDisciplinary = access.isDisciplinaryBoardMember ||
        selectedScope?.role == 'disciplinary_board';
    final canPublishNotices = access.isFederationPresident ||
        selectedScope?.role == 'president' ||
        selectedScope?.role == 'provincial_rep';

    final pendingResultsAsync = canPublishResults
        ? ref.watch(federationPendingResultsProvider(0))
        : const AsyncData<List<FederationPendingMatch>>(
            <FederationPendingMatch>[]);

    return host.chrome.buildPage(
      context,
      title: 'Federasyon Bülten & Duyurular',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(federationDisciplinaryBulletinProvider(filter));
            ref.invalidate(federationNoticesProvider(filter));
            if (canPublishResults) {
              ref.invalidate(federationPendingResultsProvider(0));
            }
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (scopes.length > 1 && selectedScope != null) ...[
            FederationScopeSelector(
              scopes: scopes,
              selectedScope: selectedScope,
              theme: theme,
            ),
            const SizedBox(height: 12),
          ],
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Kamusal Yayın & Bülten Durumu',
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Chip(
                      label: Text(
                        canPublishResults
                            ? 'Resmî Sonuç Yayın Yetkisi Aktif'
                            : 'Salt Okunur Bülten Görünümü',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Kamusal bültende yalnız açıkça yayımlanmış değişmez özetler (public_summary) ve resmî duyurular yer alır. İç disiplin gerekçeleri ve serbest sonuç revizyon notları kamuya sızdırılmaz. Federasyon rol etiketleri eski resultPublisher yetkisini otomatik açmaz.',
                  style: TextStyle(
                    color: theme.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (canPublishDisciplinary || canPublishNotices) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canPublishDisciplinary)
                        FilledButton.tonalIcon(
                          key: const Key(
                            'bulletin-open-publish-disciplinary-btn',
                          ),
                          onPressed: () async {
                            final published = await showDialog<bool>(
                              context: context,
                              builder: (_) =>
                                  SharedPublishDisciplinaryBulletinDialog(
                                sportCode: selectedScope?.sportCode,
                                onPublishDisciplinaryBulletin:
                                    onPublishDisciplinaryBulletin,
                              ),
                            );
                            if (published == true) {
                              ref.invalidate(
                                federationDisciplinaryBulletinProvider(filter),
                              );
                            }
                          },
                          icon: const Icon(Icons.gavel_rounded, size: 18),
                          label: const Text('Kamusal Bülten Özeti Yayımla'),
                        ),
                      if (canPublishNotices)
                        OutlinedButton.icon(
                          key: const Key('bulletin-open-publish-notice-btn'),
                          onPressed: () async {
                            final published = await showDialog<bool>(
                              context: context,
                              builder: (_) => SharedPublishMatchNoticeDialog(
                                scope: selectedScope,
                                onPublishMatchNotice: onPublishMatchNotice,
                              ),
                            );
                            if (published == true) {
                              ref.invalidate(federationNoticesProvider(filter));
                            }
                          },
                          icon: const Icon(Icons.campaign_rounded, size: 18),
                          label: const Text('Resmî Müsabaka Duyurusu Yayımla'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (canPublishResults) ...[
            const SizedBox(height: 14),
            Text(
              'Resmî Sonuç Tescili & Revizyon Kuyruğu',
              style: TextStyle(
                color: theme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            pendingResultsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => FederationPanelMessage(
                icon: Icons.error_outline_rounded,
                title: classifyOperationError(err).userMessage,
                onRetry: () =>
                    ref.invalidate(federationPendingResultsProvider(0)),
              ),
              data: (pendingMatches) {
                final scopedPending = selectedScope == null
                    ? pendingMatches
                    : pendingMatches
                        .where((m) => m.sportCode == selectedScope.sportCode)
                        .toList(growable: false);
                if (scopedPending.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.line),
                    ),
                    child: Text(
                      'Bu kapsamda bekleyen resmî sonuç tescil veya revizyon talebi bulunmuyor.',
                      style: TextStyle(color: theme.inkMuted, fontSize: 12),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final match in scopedPending) ...[
                      _PendingResultPublishCard(
                        match: match,
                        canPublishForMatch: access.canPublishResultFor(
                          sportCode: match.sportCode,
                          cityCode: match.cityCode,
                        ),
                        theme: theme,
                        onPublishResult: onPublishResult,
                        onPublished: () {
                          ref.invalidate(federationPendingResultsProvider(0));
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Yayımlanmış Disiplin Bülteni',
            style: TextStyle(
              color: theme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          bulletinAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () => ref.invalidate(
                federationDisciplinaryBulletinProvider(filter),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.line),
                  ),
                  child: Text(
                    'Bu kapsamda yayımlanmış kamusal disiplin bülteni kaydı bulunmuyor.',
                    style: TextStyle(color: theme.inkMuted, fontSize: 12),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${item.programName} · ${item.clubName}',
                                style: TextStyle(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Chip(label: Text(item.penaltyLabel)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sporcu Referansı: ${item.athleteDisplay} · ${item.matchTitle}',
                            style: TextStyle(
                              color: theme.inkMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.reason,
                              style: TextStyle(color: theme.ink, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Resmî Federasyon Duyuruları',
            style: TextStyle(
              color: theme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          noticesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () => ref.invalidate(federationNoticesProvider(filter)),
            ),
            data: (notices) {
              if (notices.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.line),
                  ),
                  child: Text(
                    'Bu kapsamda yayımlanmış resmî federasyon duyurusu bulunmuyor.',
                    style: TextStyle(color: theme.inkMuted, fontSize: 12),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final notice in notices) ...[
                    Container(
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
                            notice.title,
                            style: TextStyle(
                              color: theme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${notice.programName} · ${notice.sportCode}',
                            style: TextStyle(
                              color: theme.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notice.body,
                            style: TextStyle(color: theme.ink, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingResultPublishCard extends StatelessWidget {
  const _PendingResultPublishCard({
    required this.match,
    required this.canPublishForMatch,
    required this.theme,
    required this.onPublished,
    this.onPublishResult,
  });

  final FederationPendingMatch match;
  final bool canPublishForMatch;
  final ProFeatureThemeData theme;
  final VoidCallback onPublished;
  final PublishOfficialResultCallback? onPublishResult;

  @override
  Widget build(BuildContext context) {
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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${match.name} · ${match.sportCode}',
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(label: Text('Sürüm V${match.version}')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${match.homeName ?? 'Ev Sahibi'} — ${match.awayName ?? 'Deplasman'}',
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (!canPublishForMatch)
            Text(
              'Bu branş/il için aktif Sonuç Tescil Görevlisi (result_publisher) yetkiniz bulunmuyor.',
              style: TextStyle(color: theme.danger, fontSize: 12),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: Key('bulletin-publish-result-btn-${match.id}'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => SharedPublishOfficialResultDialog(
                      match: match,
                      onPublishResult: onPublishResult,
                    ),
                  );
                  if (ok == true) {
                    onPublished();
                  }
                },
                icon: const Icon(Icons.publish_rounded, size: 18),
                label: const Text('Sonucu Tescil Et / Yayımla'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog for publishing or revising an official match result (`publishResult`).
final class SharedPublishOfficialResultDialog extends ConsumerStatefulWidget {
  const SharedPublishOfficialResultDialog({
    required this.match,
    this.onPublishResult,
    super.key,
  });

  final FederationPendingMatch match;
  final PublishOfficialResultCallback? onPublishResult;

  @override
  ConsumerState<SharedPublishOfficialResultDialog> createState() =>
      _SharedPublishOfficialResultDialogState();
}

final class _SharedPublishOfficialResultDialogState
    extends ConsumerState<SharedPublishOfficialResultDialog> {
  final TextEditingController _homeCtrl = TextEditingController();
  final TextEditingController _awayCtrl = TextEditingController();
  late final TextEditingController _reasonCtrl;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController(
      text: widget.match.version == 0
          ? 'Hakem onaylı resmî müsabaka sonucu tescili'
          : 'MHK onaylı resmî sonuç revizyonu',
    );
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSetSport = widget.match.sportCode == 'tenis' ||
        widget.match.sportCode == 'voleybol';
    return AlertDialog(
      title: Text(
        'Resmî Sonuç Tescili (V${widget.match.version + 1})',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.match.homeName ?? 'Ev Sahibi'} — ${widget.match.awayName ?? 'Deplasman'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('publish-result-home-input'),
                      controller: _homeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            isSetSport ? 'Ev (1. Set)' : 'Ev Sahibi Skor',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('publish-result-away-input'),
                      controller: _awayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isSetSport
                            ? 'Deplasman (1. Set)'
                            : 'Deplasman Skor',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('publish-result-reason-input'),
                controller: _reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Tescil / Revizyon Gerekçesi (iç kayıt)',
                  helperText:
                      'Bu gerekçe iç denetim kaydında tutulur; kamusal ekrana ham metin olarak açılmaz.',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('publish-result-submit-btn'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Tescil Et ve Yayımla'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final home = int.tryParse(_homeCtrl.text.trim());
    final away = int.tryParse(_awayCtrl.text.trim());
    final reason = _reasonCtrl.text.trim();
    if (home == null || away == null || home < 0 || away < 0) {
      setState(() {
        _errorMessage = 'Geçerli sayısal skor değerleri girin.';
      });
      return;
    }
    if (reason.isEmpty) {
      setState(() {
        _errorMessage = 'Tescil gerekçesi zorunludur.';
      });
      return;
    }
    final isSetSport = widget.match.sportCode == 'tenis' ||
        widget.match.sportCode == 'voleybol';
    final protocol = isSetSport
        ? <String, dynamic>{
            'type': 'sets',
            'sets': [
              {'home': home, 'away': away},
            ],
          }
        : <String, dynamic>{
            'type': 'score',
            'home': home,
            'away': away,
          };

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final callback = widget.onPublishResult;
      if (callback != null) {
        await callback(
          matchId: widget.match.id,
          protocol: protocol,
          reason: reason,
          expectedVersion: widget.match.version,
        );
      } else {
        final service = ref.read(federationRecordsServiceProvider);
        if (service == null) {
          throw StateError('Federasyon tescil servisi kullanılamıyor.');
        }
        await service.publishResult(
          matchId: widget.match.id,
          protocol: protocol,
          reason: reason,
          expectedVersion: widget.match.version,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = classifyOperationError(error).userMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

/// Dialog for publishing an immutable public disciplinary bulletin summary
/// (`publish_disciplinary_bulletin`).
final class SharedPublishDisciplinaryBulletinDialog
    extends ConsumerStatefulWidget {
  const SharedPublishDisciplinaryBulletinDialog({
    this.sportCode,
    this.onPublishDisciplinaryBulletin,
    super.key,
  });

  final String? sportCode;
  final PublishDisciplinaryBulletinCallback? onPublishDisciplinaryBulletin;

  @override
  ConsumerState<SharedPublishDisciplinaryBulletinDialog> createState() =>
      _SharedPublishDisciplinaryBulletinDialogState();
}

final class _SharedPublishDisciplinaryBulletinDialogState
    extends ConsumerState<SharedPublishDisciplinaryBulletinDialog> {
  final TextEditingController _summaryCtrl = TextEditingController();
  String? _selectedDecisionId;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(federationDisciplinaryReportsProvider(0));

    return AlertDialog(
      title: const Text('Kamusal Disiplin Bülteni Özeti Yayımla'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Disiplin Kurulu iç dosya gerekçesi (reason) gizli kalır. Burada girilen kamusal özet (1–500 karakter) değiştirilemez olarak yayımlanır.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              reportsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text(
                  'Disiplin kararları yüklenemedi.',
                ),
                data: (page) {
                  final decisions = <({
                    String id,
                    String label,
                  })>[
                    for (final r in page.rows)
                      if (widget.sportCode == null ||
                          r.sportCode == widget.sportCode)
                        for (final d in r.decisions)
                          (
                            id: d.id,
                            label: '${r.program} · ${d.penaltyType}',
                          ),
                  ];
                  if (decisions.isEmpty) {
                    return const Text(
                      'Bu kapsamda yayımlanabilecek disiplin kurulu kararı bulunamadı.',
                    );
                  }
                  final effectiveId = decisions.any(
                    (d) => d.id == _selectedDecisionId,
                  )
                      ? _selectedDecisionId
                      : decisions.first.id;
                  if (_selectedDecisionId != effectiveId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _selectedDecisionId = effectiveId);
                      }
                    });
                  }
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Disiplin Kurulu Kararı',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key:
                            const Key('publish-disciplinary-decision-dropdown'),
                        value: effectiveId,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final d in decisions)
                            DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(d.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedDecisionId = value);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('publish-disciplinary-summary-input'),
                controller: _summaryCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Kamusal bülten özeti (public_summary)',
                  hintText:
                      'Örn: Disiplin Kurulu kararıyla 1 müsabakadan men cezası verilmiştir.',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('publish-disciplinary-submit-btn'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Bülteni Yayımla'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final decisionId = _selectedDecisionId;
    final summary = _summaryCtrl.text.trim();
    if (decisionId == null || decisionId.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen yayımlanacak disiplin kararını seçin.';
      });
      return;
    }
    if (summary.isEmpty || summary.length > 500) {
      setState(() {
        _errorMessage = 'Kamusal bülten özeti 1–500 karakter olmalıdır.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final callback = widget.onPublishDisciplinaryBulletin;
      if (callback != null) {
        await callback(
          decisionId: decisionId,
          publicSummary: summary,
        );
      } else {
        await ref
            .read(federationBulletinServiceProvider)
            .publishDisciplinaryBulletin(
              decisionId: decisionId,
              publicSummary: summary,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = classifyOperationError(error).userMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

/// Dialog for publishing an immutable official match notice
/// (`publish_federation_match_notice`).
final class SharedPublishMatchNoticeDialog extends ConsumerStatefulWidget {
  const SharedPublishMatchNoticeDialog({
    this.scope,
    this.onPublishMatchNotice,
    super.key,
  });

  final FederationConsoleScope? scope;
  final PublishFederationMatchNoticeCallback? onPublishMatchNotice;

  @override
  ConsumerState<SharedPublishMatchNoticeDialog> createState() =>
      _SharedPublishMatchNoticeDialogState();
}

final class _SharedPublishMatchNoticeDialogState
    extends ConsumerState<SharedPublishMatchNoticeDialog> {
  final TextEditingController _summaryCtrl = TextEditingController();
  String? _selectedMatchId;
  String _noticeType = 'match_postponed';
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _summaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = FederationMatchQuery(
      federationId: widget.scope?.federationId,
      sportCode: widget.scope?.sportCode,
      cityCode: widget.scope?.cityCode,
    );
    final matchesAsync = ref.watch(federationConsoleMatchesProvider(query));

    return AlertDialog(
      title: const Text('Resmî Müsabaka Duyurusu Yayımla'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              matchesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text('Müsabaka listesi yüklenemedi.'),
                data: (page) {
                  final eligible = page.rows
                      .where(
                        (m) =>
                            m.status == 'cancelled' || m.status == 'postponed',
                      )
                      .toList(growable: false);
                  final candidates = eligible.isNotEmpty ? eligible : page.rows;
                  if (candidates.isEmpty) {
                    return const Text('Kapsamda müsabaka bulunamadı.');
                  }
                  final effectiveId = candidates.any(
                    (m) => m.id == _selectedMatchId,
                  )
                      ? _selectedMatchId
                      : candidates.first.id;
                  if (_selectedMatchId != effectiveId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        final selected = candidates.firstWhere(
                          (m) => m.id == effectiveId,
                        );
                        setState(() {
                          _selectedMatchId = effectiveId;
                          if (selected.status == 'cancelled') {
                            _noticeType = 'match_cancelled';
                          } else if (selected.status == 'postponed') {
                            _noticeType = 'match_postponed';
                          }
                        });
                      }
                    });
                  }
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Müsabaka',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('publish-notice-match-dropdown'),
                        value: effectiveId,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final m in candidates)
                            DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(
                                '${m.program}: ${m.homeName ?? 'Ev'} - ${m.awayName ?? 'Dep'}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedMatchId = value);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Duyuru Türü'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('publish-notice-type-dropdown'),
                    value: _noticeType,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'match_postponed',
                        child: Text('Müsabaka Erteleme (match_postponed)'),
                      ),
                      DropdownMenuItem(
                        value: 'match_cancelled',
                        child: Text('Müsabaka İptali (match_cancelled)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _noticeType = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('publish-notice-summary-input'),
                controller: _summaryCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Kamusal duyuru metni (1–500 karakter)',
                  hintText:
                      'Örn: Hava muhalefeti nedeniyle müsabaka ileri bir tarihe ertelenmiştir.',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('publish-notice-submit-btn'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Duyuruyu Yayımla'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final matchId = _selectedMatchId;
    final summary = _summaryCtrl.text.trim();
    if (matchId == null || matchId.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen duyuru yayımlanacak müsabakayı seçin.';
      });
      return;
    }
    if (summary.isEmpty || summary.length > 500) {
      setState(() {
        _errorMessage = 'Kamusal duyuru özeti 1–500 karakter olmalıdır.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final callback = widget.onPublishMatchNotice;
      if (callback != null) {
        await callback(
          matchId: matchId,
          noticeType: _noticeType,
          publicSummary: summary,
        );
      } else {
        await ref.read(federationBulletinServiceProvider).publishMatchNotice(
              matchId: matchId,
              noticeType: _noticeType,
              publicSummary: summary,
            );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = classifyOperationError(error).userMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
