import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'accounting_operations_panel.dart';

typedef DecideBankMatchCallback = Future<void> Function({
  required String clubId,
  required String operationId,
  required String txnId,
  required String action,
  String? kind,
  String? entryId,
  String? note,
});

@immutable
final class BankReconciliationWriteCallbacks {
  const BankReconciliationWriteCallbacks({
    this.onDecideMatch,
  });

  final DecideBankMatchCallback? onDecideMatch;
}

final class SharedBankReconciliationScreen extends ConsumerWidget {
  const SharedBankReconciliationScreen({
    this.writeCallbacks = const BankReconciliationWriteCallbacks(),
    super.key,
  });

  final BankReconciliationWriteCallbacks writeCallbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Banka Mutabakatı',
      body: _BankReconciliationBody(writeCallbacks: writeCallbacks),
    );
  }
}

final class _BankReconciliationBody extends ConsumerStatefulWidget {
  const _BankReconciliationBody({required this.writeCallbacks});

  final BankReconciliationWriteCallbacks writeCallbacks;

  @override
  ConsumerState<_BankReconciliationBody> createState() =>
      _BankReconciliationBodyState();
}

final class _BankReconciliationBodyState
    extends ConsumerState<_BankReconciliationBody> {
  ProDirtyStateRegistration? _dirtyRegistration;
  String? _lastClubId;
  String _selectedStatus = 'unmatched';
  String? _activePendingScopeKey;
  String? _statusMessage;
  bool _isStatusError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dirtyRegistration = ref
        .read(proDirtyStateCoordinatorProvider)
        .register('bank-reconciliation-screen');
  }

  @override
  void dispose() {
    _dirtyRegistration?.dispose();
    super.dispose();
  }

  bool _verifyWriteClubScope(String expectedClubId) {
    final latestAccess = ref.read(swanAccessProvider);
    final latestAccountantClubId = ref.read(selectedAccountantClubIdProvider);
    final latestSelectedClubId = ref.read(selectedClubIdProvider);
    if (!latestAccess.isAccountantOf(expectedClubId)) return false;
    if (latestAccountantClubId != expectedClubId) return false;
    if (latestSelectedClubId != null &&
        latestSelectedClubId != expectedClubId) {
      return false;
    }
    return true;
  }

  Future<void> _executeBankDecision({
    required String clubId,
    required String txnId,
    required String action,
    String? kind,
    String? entryId,
    String? note,
  }) async {
    if (_isSubmitting) return;
    if (!_verifyWriteClubScope(clubId)) {
      setState(() {
        _statusMessage =
            'Aktif kulüp kapsamı doğrulaması başarısız oldu. İşlem reddedildi.';
        _isStatusError = true;
      });
      return;
    }

    final scopeKey = '$clubId:bank_match:$txnId';
    final existing =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    final opId = existing?.operationId ?? newOpId();
    final payload = existing?.payload ??
        <String, Object?>{
          'clubId': clubId,
          'txnId': txnId,
          'action': action,
          'kind': kind,
          'entryId': entryId,
          'note': note,
        };

    ref.read(proPendingOperationsProvider.notifier).saveOperation(
          scopeKey: scopeKey,
          operationId: opId,
          payload: payload,
        );
    _dirtyRegistration?.markPendingOperation();

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _isStatusError = false;
    });

    try {
      final callback = widget.writeCallbacks.onDecideMatch;
      final targetTxnId = payload['txnId'] as String;
      final targetAction = payload['action'] as String;
      final targetKind = payload['kind'] as String?;
      final targetEntryId = payload['entryId'] as String?;
      final targetNote = payload['note'] as String?;

      if (callback != null) {
        await callback(
          clubId: clubId,
          operationId: opId,
          txnId: targetTxnId,
          action: targetAction,
          kind: targetKind,
          entryId: targetEntryId,
          note: targetNote,
        );
      } else {
        await ref.read(financeOpsServiceProvider).decideMatch(
              targetTxnId,
              targetAction,
              kind: targetKind,
              entryId: targetEntryId,
              note: targetNote,
            );
      }

      if (!mounted) return;
      ref.read(proPendingOperationsProvider.notifier).clearOperation(scopeKey);
      _dirtyRegistration?.clearPendingOperation();
      ref
        ..invalidate(bankTransactionsProvider(_selectedStatus))
        ..invalidate(bankMatchSuggestionsProvider(targetTxnId))
        ..invalidate(financeOperationsSummaryProvider);
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = null;
        _statusMessage = targetAction == 'match'
            ? 'Banka hareketi defter kaydıyla eşleştirildi.'
            : 'Banka hareketi mutabakat kararı kaydedildi.';
        _isStatusError = false;
      });
    } catch (error) {
      if (!mounted) return;
      final classified = classifyOperationError(error);
      final isUncertain = classified.kind == OperationErrorKind.network ||
          classified.kind == OperationErrorKind.unknown;
      if (!isUncertain) {
        ref
            .read(proPendingOperationsProvider.notifier)
            .clearOperation(scopeKey);
        _dirtyRegistration?.clearPendingOperation();
      }
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = isUncertain ? scopeKey : null;
        _statusMessage = classified.userMessage;
        _isStatusError = true;
      });
    }
  }

  Future<void> _retryPendingOperation(String clubId) async {
    final scopeKey = _activePendingScopeKey;
    if (scopeKey == null) return;
    final record =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    if (record == null) return;
    await _executeBankDecision(
      clubId: clubId,
      txnId: record.payload['txnId'] as String,
      action: record.payload['action'] as String,
      kind: record.payload['kind'] as String?,
      entryId: record.payload['entryId'] as String?,
      note: record.payload['note'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final access = ref.watch(swanAccessProvider);
    if (!access.isAccountant) {
      return const AccountingPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Muhasebe çalışma alanı yetkisi gerekli',
        body:
            'Banka mutabakat ekranı yalnız yetkili kulüp muhasebecisi hesaplarına açıktır.',
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    final clubsAsync = ref.watch(myClubsProvider);
    if (flagsAsync.isLoading || clubsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (flagsAsync.hasError || clubsAsync.hasError) {
      final error = flagsAsync.error ?? clubsAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref
            ..invalidate(featureFlagsProvider)
            ..invalidate(myClubsProvider);
        },
      );
    }

    final flags = flagsAsync.valueOrNull ?? const FeatureFlags.none();
    if (!flags.has(FeatureFlags.financeOperationsCenter) ||
        !flags.has(FeatureFlags.bankReconciliation)) {
      return const AccountingPanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Banka mutabakatı kademeli yayında',
        body: 'Banka mutabakat modülü hesabın için henüz açılmadı.',
      );
    }

    final accountantClubs = resolveEffectiveAccountantClubs(
      clubsAsync.valueOrNull ?? const <ClubRef>[],
      access,
    );
    if (accountantClubs.isEmpty) {
      return const AccountingPanelMessage(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Aktif muhasebe kulüp kapsamı bulunamadı',
        body:
            'Aktif bir muhasebe kulüp kapsamı olmadan banka mutabakat sorguları çalıştırılmaz.',
      );
    }

    final selectedId = ref.watch(selectedAccountantClubIdProvider);
    final selectedClub =
        accountantClubs.where((club) => club.id == selectedId).firstOrNull ??
            accountantClubs.first;

    if (_lastClubId != selectedClub.id) {
      _lastClubId = selectedClub.id;
      _selectedStatus = 'unmatched';
      _activePendingScopeKey = null;
      _statusMessage = null;
      _isStatusError = false;
      _dirtyRegistration?.clearPendingOperation();
      if (selectedId != selectedClub.id ||
          ref.watch(selectedClubIdProvider) != selectedClub.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(selectedAccountantClubIdProvider.notifier).state =
                selectedClub.id;
            ref.read(selectedClubIdProvider.notifier).state = selectedClub.id;
          }
        });
      }
    }

    final pendingStore = ref.watch(proPendingOperationsProvider);
    final activePendingRecord = _activePendingScopeKey == null
        ? null
        : pendingStore.operationFor(_activePendingScopeKey!);

    final importsAsync = ref.watch(bankImportsProvider);
    final txnsAsync = ref.watch(bankTransactionsProvider(_selectedStatus));

    if (importsAsync.isLoading || txnsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (importsAsync.hasError || txnsAsync.hasError) {
      final error = importsAsync.error ?? txnsAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref
            ..invalidate(bankImportsProvider)
            ..invalidate(bankTransactionsProvider(_selectedStatus));
        },
      );
    }

    final imports = importsAsync.valueOrNull ?? const <BankImport>[];
    final txns = txnsAsync.valueOrNull ?? const <BankTransaction>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccountantClubSelector(
          clubs: accountantClubs,
          selectedClub: selectedClub,
          theme: host.theme,
        ),
        const SizedBox(height: 8),
        Text(
          'Banka açıklamalarında IBAN ve uzun rakam dizileri maskelenir; sporcu kimliği yerine yalnız maskeli referans kodu (#A3F91C) gösterilir.',
          style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 12),
          _BankStatusBanner(
            message: _statusMessage!,
            isError: _isStatusError,
            pendingRecord: activePendingRecord,
            onRetry: activePendingRecord == null
                ? null
                : () => _retryPendingOperation(selectedClub.id),
            theme: host.theme,
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusFilterButton(
              label: 'Eşleşmemiş',
              selected: _selectedStatus == 'unmatched',
              onTap: () => setState(() => _selectedStatus = 'unmatched'),
            ),
            _StatusFilterButton(
              label: 'Eşleşmiş',
              selected: _selectedStatus == 'matched',
              onTap: () => setState(() => _selectedStatus = 'matched'),
            ),
            _StatusFilterButton(
              label: 'Yok Sayılan',
              selected: _selectedStatus == 'ignored',
              onTap: () => setState(() => _selectedStatus = 'ignored'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Banka Hareketleri (${txns.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (txns.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Seçili filtrede banka hareketi bulunmuyor.',
              style: TextStyle(color: host.theme.inkMuted),
            ),
          )
        else
          for (final txn in txns) ...[
            _BankTransactionCard(
              txn: txn,
              clubId: selectedClub.id,
              isSubmitting: _isSubmitting,
              theme: host.theme,
              onMatchSuggestion: (suggestion) => _executeBankDecision(
                clubId: selectedClub.id,
                txnId: txn.id,
                action: 'match',
                kind: suggestion.kind,
                entryId: suggestion.entryId,
              ),
              onIgnore: () => _executeBankDecision(
                clubId: selectedClub.id,
                txnId: txn.id,
                action: 'ignore',
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        Text(
          'Yüklenen Ekstreler (${imports.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (imports.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Henüz yüklenmiş banka ekstresi bulunmuyor.',
              style: TextStyle(color: host.theme.inkMuted),
            ),
          )
        else
          for (final imp in imports) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: host.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: host.theme.line),
              ),
              child: Text(
                '${imp.accountName ?? 'Banka Hesabı'} · ${imp.rowCount} hareket · ${accountingTurkeyDate(imp.createdAt)}',
                style: TextStyle(
                  color: host.theme.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

final class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: selected
          ? FilledButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

final class _BankTransactionCard extends ConsumerWidget {
  const _BankTransactionCard({
    required this.txn,
    required this.clubId,
    required this.isSubmitting,
    required this.theme,
    required this.onMatchSuggestion,
    required this.onIgnore,
  });

  final BankTransaction txn;
  final String clubId;
  final bool isSubmitting;
  final ProFeatureThemeData theme;
  final void Function(BankMatchSuggestion suggestion) onMatchSuggestion;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(bankMatchSuggestionsProvider(txn.id));
    final suggestions =
        suggestionsAsync.valueOrNull ?? const <BankMatchSuggestion>[];
    final amountPrefix = txn.isIncoming ? '+' : '-';
    final amountColor = txn.isIncoming ? theme.success : theme.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                '${txn.accountName ?? 'Banka'} · ${accountingTurkeyDate(txn.txnOn)}',
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$amountPrefix${money(txn.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (txn.description != null && txn.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Maskeli Açıklama: ${txn.description}',
              style: TextStyle(color: theme.inkMuted, fontSize: 12),
            ),
          ],
          if (!txn.isMatched) ...[
            const SizedBox(height: 10),
            if (suggestionsAsync.isLoading)
              Text(
                'Eşleşme önerileri kontrol ediliyor…',
                style: TextStyle(color: theme.inkMuted, fontSize: 12),
              )
            else if (suggestions.isNotEmpty)
              for (final s in suggestions) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Öneri: ${s.label} · ${money(s.amount)} (${s.dayGap} gün fark)',
                        style: TextStyle(
                          color: theme.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          key: Key('bank-match-btn-${txn.id}-${s.entryId}'),
                          onPressed:
                              isSubmitting ? null : () => onMatchSuggestion(s),
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Eşleştir'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            SizedBox(
              height: 48,
              child: OutlinedButton(
                key: Key('bank-ignore-btn-${txn.id}'),
                onPressed: isSubmitting ? null : onIgnore,
                child: const Text('Mutabakat Dışı Bırak'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _BankStatusBanner extends StatelessWidget {
  const _BankStatusBanner({
    required this.message,
    required this.isError,
    required this.pendingRecord,
    required this.onRetry,
    required this.theme,
  });

  final String message;
  final bool isError;
  final ProPendingOperationRecord? pendingRecord;
  final VoidCallback? onRetry;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = isError ? theme.danger : theme.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: theme.ink, fontWeight: FontWeight.w700),
          ),
          if (pendingRecord != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ağ sonucu belirsiz. Aynı işlem kimliği (${pendingRecord!.operationId}) ile yeniden deneyebilirsin.',
              style: TextStyle(color: theme.inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('retry-pending-op-btn'),
                onPressed: onRetry,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Aynı işlemle yeniden dene'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
