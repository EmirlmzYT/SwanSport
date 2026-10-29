import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'federation_operations_panel.dart';

/// Optional injection callback for disciplinary decision recording in tests.
typedef RecordDisciplinaryDecisionCallback = Future<void> Function(
  Map<String, dynamic> payload,
);

/// Shared disciplinary board screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Signed referee report queue access restricted to President, MHK, and
///   Disciplinary Board (`access.isDisciplinaryBoardMember || access.isRefereeCommitteeMember`).
/// - Decision recording restricted to `access.isDisciplinaryBoardMember && report.canDecide`.
/// - Immutable and idempotent decision contract with exact `p_operation_id` retry.
/// - Internal disciplinary reason is never leaked to public bulletins.
final class SharedDisciplinaryBoardScreen extends ConsumerStatefulWidget {
  const SharedDisciplinaryBoardScreen({
    this.onRecordDecision,
    super.key,
  });

  final RecordDisciplinaryDecisionCallback? onRecordDecision;

  @override
  ConsumerState<SharedDisciplinaryBoardScreen> createState() =>
      _SharedDisciplinaryBoardScreenState();
}

final class _SharedDisciplinaryBoardScreenState
    extends ConsumerState<SharedDisciplinaryBoardScreen> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    final canReadSignedReports = access.isDisciplinaryBoardMember ||
        access.isRefereeCommitteeMember ||
        access.isFederationPresident;
    if (!canReadSignedReports) {
      return host.chrome.buildPage(
        context,
        title: 'Disiplin Kurulu',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Disiplin kurulu erişim yetkiniz bulunmuyor',
          body:
              'İmzalı hakem raporları ve disiplin kuyruğu yalnız Federasyon Başkanı, Disiplin Kurulu ve MHK yetkililerine açıktır.',
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

    final query = FederationDisciplinaryQuery(
      federationId: selectedScope?.federationId,
      sportCode: selectedScope?.sportCode,
      offset: _offset,
    );
    final pageAsync =
        ref.watch(federationScopedDisciplinaryReportsProvider(query));
    return host.chrome.buildPage(
      context,
      title: 'Disiplin Kurulu',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () => ref.invalidate(
            federationScopedDisciplinaryReportsProvider(query),
          ),
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
                Text(
                  'İmzalı Hakem Rapor Kuyruğu',
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Özel hakem raporları en eski imzalı sırasıyla listelenir. Kırmızı kart veya rapor notu otomatik ceza değildir; kurul kararı gerekir. İç gerekçe metinleri kamusal bültene sızdırılmaz.',
                  style: TextStyle(
                    color: theme.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          pageAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () => ref.invalidate(
                federationScopedDisciplinaryReportsProvider(query),
              ),
            ),
            data: (page) {
              if (page.rows.isEmpty) {
                return const FederationPanelMessage(
                  icon: Icons.gavel_outlined,
                  title: 'Bu kapsamda imzalı maç raporu yok',
                  body: 'İncelenecek bekleyen imzalı hakem raporu bulunmuyor.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final report in page.rows) ...[
                    _DisciplinaryReportCard(
                      report: report,
                      canDecide: report.canDecide,
                      theme: theme,
                      onRecordDecision: widget.onRecordDecision,
                      onDecided: () => ref.invalidate(
                        federationScopedDisciplinaryReportsProvider(query),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (page.total > 50)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Önceki sayfa',
                          onPressed: _offset == 0
                              ? null
                              : () => setState(() => _offset -= 50),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text(
                          '${_offset + 1}–${_offset + page.rows.length} / ${page.total}',
                          style: TextStyle(color: theme.inkMuted, fontSize: 12),
                        ),
                        IconButton(
                          tooltip: 'Sonraki sayfa',
                          onPressed: _offset + 50 >= page.total
                              ? null
                              : () => setState(() => _offset += 50),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DisciplinaryReportCard extends StatelessWidget {
  const _DisciplinaryReportCard({
    required this.report,
    required this.canDecide,
    required this.theme,
    required this.onDecided,
    this.onRecordDecision,
  });

  final FederationDisciplinaryReport report;
  final bool canDecide;
  final ProFeatureThemeData theme;
  final VoidCallback onDecided;
  final RecordDisciplinaryDecisionCallback? onRecordDecision;

  @override
  Widget build(BuildContext context) {
    final undecidedAthletes = report.athletes
        .where((a) => !report.decisions.any((d) => d.athleteId == a.athleteId))
        .toList(growable: false);

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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${report.program} · ${report.sportCode} · İl ${report.cityCode ?? 'Ulusal'}',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                label: Text('${report.redCardAthleteIds.length} kırmızı kart'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report.notes,
            style: TextStyle(color: theme.ink, fontSize: 13),
          ),
          if (report.decisions.isNotEmpty) ...[
            const Divider(height: 20),
            for (final decision in report.decisions)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_penaltyLabel(decision.penaltyType)}'
                  '${decision.matchBanCount == null ? '' : ' · ${decision.matchBanCount} maç'}'
                  '${decision.months == null ? '' : ' · ${decision.months} ay'}'
                  '${decision.fineAmount == null ? '' : ' · ${fmtMoney(decision.fineAmount!)}'}'
                  ' · ${decision.reason}',
                  style: TextStyle(
                    color: theme.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: Key('disciplinary-decide-btn-${report.matchId}'),
              onPressed: !canDecide || undecidedAthletes.isEmpty
                  ? null
                  : () async {
                      final recorded = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => SharedDisciplinaryDecisionDialog(
                          report: report,
                          onRecordDecision: onRecordDecision,
                        ),
                      );
                      if (recorded == true) {
                        onDecided();
                      }
                    },
              icon: const Icon(Icons.gavel_rounded, size: 18),
              label: const Text('Ceza Kararı Gir'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for recording an immutable, idempotent disciplinary decision.
final class SharedDisciplinaryDecisionDialog extends ConsumerStatefulWidget {
  const SharedDisciplinaryDecisionDialog({
    required this.report,
    this.onRecordDecision,
    super.key,
  });

  final FederationDisciplinaryReport report;
  final RecordDisciplinaryDecisionCallback? onRecordDecision;

  @override
  ConsumerState<SharedDisciplinaryDecisionDialog> createState() =>
      _SharedDisciplinaryDecisionDialogState();
}

final class _SharedDisciplinaryDecisionDialogState
    extends ConsumerState<SharedDisciplinaryDecisionDialog> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _fineCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _athleteId;
  String? _actorId;
  String? _errorMessage;
  String _penaltyKind = 'match_ban';
  int _count = 1;
  bool _busy = false;
  Map<String, dynamic>? _pendingPayload;

  @override
  void initState() {
    super.initState();
    _actorId = ref.read(authSessionProvider).valueOrNull?.user.id;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authSessionProvider).valueOrNull?.user.id;
    final access = ref.watch(swanAccessProvider);
    if (currentUserId != _actorId || !access.isDisciplinaryBoardMember) {
      return const AlertDialog(
        content: Text('Oturum veya yetki değişti. Bu pencereyi kapatın.'),
      );
    }

    final locked = _busy || _pendingPayload != null;
    final eligibleAthletes = widget.report.athletes
        .where(
          (a) =>
              !widget.report.decisions.any((d) => d.athleteId == a.athleteId),
        )
        .toList(growable: false);

    return PopScope(
      canPop: !locked,
      child: AlertDialog(
        title: const Text('Disiplin Kararı'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Karar değiştirilemez (immutable). İç gerekçe metni kamusal bültene sızdırılmaz; para cezası mali deftere otomatik tahakkuk ettirilmez.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Esamedeki sporcu (maskeli kimlik)',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('disciplinary-athlete-dropdown'),
                        value: _athleteId,
                        isExpanded: true,
                        isDense: true,
                        hint: const Text('Sporcu seçin'),
                        items: [
                          for (final athlete in eligibleAthletes)
                            DropdownMenuItem(
                              value: athlete.athleteId,
                              child: Text(
                                '${athlete.reference}'
                                '${widget.report.redCardAthleteIds.contains(athlete.athleteId) ? ' · Kırmızı kart' : ''}',
                              ),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (val) => setState(() => _athleteId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ceza türü'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('disciplinary-penalty-dropdown'),
                        value: _penaltyKind,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final kind in const [
                            'match_ban',
                            'rights_ban',
                            'warning',
                            'fine',
                          ])
                            DropdownMenuItem(
                              value: kind,
                              child: Text(_penaltyLabel(kind)),
                            ),
                        ],
                        onChanged: locked
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _penaltyKind = val;
                                    _count = 1;
                                  });
                                }
                              },
                      ),
                    ),
                  ),
                  if (_penaltyKind == 'match_ban' ||
                      _penaltyKind == 'rights_ban') ...[
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: _penaltyKind == 'match_ban'
                            ? 'Maç sayısı'
                            : 'Ay sayısı',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _count,
                          isExpanded: true,
                          isDense: true,
                          items: [
                            for (var i = 1;
                                i <= (_penaltyKind == 'match_ban' ? 10 : 12);
                                i++)
                              DropdownMenuItem(value: i, child: Text('$i')),
                          ],
                          onChanged: locked
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() => _count = val);
                                  }
                                },
                        ),
                      ),
                    ),
                  ],
                  if (_penaltyKind == 'fine') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _fineCtrl,
                      enabled: !locked,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Para cezası (₺)',
                      ),
                      validator: (v) {
                        final parsed = double.tryParse(
                          (v ?? '').replaceAll(',', '.'),
                        );
                        return parsed == null || !parsed.isFinite || parsed <= 0
                            ? 'Pozitif tutar girin'
                            : null;
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('disciplinary-reason-input'),
                    controller: _reasonCtrl,
                    enabled: !locked,
                    maxLength: 1000,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Gerekçeli karar (iç kurul kaydı)',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Gerekçe zorunlu' : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: locked ? null : () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('disciplinary-submit-btn'),
            onPressed: _busy ? null : _submit,
            child: Text(
              _pendingPayload == null
                  ? 'Kararı Kaydet'
                  : 'Aynı İşlemi Tekrar Dene',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_pendingPayload == null) {
      if (_athleteId == null) {
        setState(() => _errorMessage = 'Lütfen esamedeki sporcuyu seçin.');
        return;
      }
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _pendingPayload = <String, dynamic>{
        'p_match_id': widget.report.matchId,
        'p_athlete_id': _athleteId,
        'p_operation_id': refereeOperationId(),
        'p_penalty_type': _penaltyKind,
        'p_reason': _reasonCtrl.text.trim(),
        'p_match_ban_count': _penaltyKind == 'match_ban' ? _count : null,
        'p_months': _penaltyKind == 'rights_ban' ? _count : null,
        'p_fine_amount': _penaltyKind == 'fine'
            ? double.parse(_fineCtrl.text.replaceAll(',', '.'))
            : null,
      };
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final callback = widget.onRecordDecision;
      final payloadSnapshot = Map<String, dynamic>.unmodifiable(
        _pendingPayload!,
      );
      if (callback != null) {
        await callback(payloadSnapshot);
      } else {
        final service = ref.read(federationConsoleServiceProvider);
        if (service == null) {
          _pendingPayload = null;
          throw StateError('Federasyon servisi kullanılamıyor.');
        }
        await service.recordDecision(payloadSnapshot);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      final safeError = classifyOperationError(error);
      // Definitive validation or authorization errors unlock the form;
      // uncertain network/conflict/unknown errors keep the exact operation ID & payload.
      if (safeError.kind == OperationErrorKind.validation ||
          safeError.kind == OperationErrorKind.unauthorized) {
        _pendingPayload = null;
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = _pendingPayload == null
            ? safeError.userMessage
            : 'Sonuç belirsiz. Aynı işlem kimliğiyle tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

String _penaltyLabel(String kind) {
  switch (kind) {
    case 'match_ban':
      return 'Maç Men Cezası';
    case 'rights_ban':
      return 'Hak Mahrumiyeti';
    case 'fine':
      return 'Para Cezası';
    default:
      return 'İhtar';
  }
}
