import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_dirty_state.dart';
import '../host/pro_feature_context.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'accounting_operations_panel.dart';

typedef ApproveAdjustmentCallback = Future<void> Function({
  required String clubId,
  required String operationId,
  required String adjustmentId,
  required bool approve,
  String? note,
});

typedef CreateAdjustmentCallback = Future<String> Function({
  required String clubId,
  required String operationId,
  required String targetKind,
  String? targetId,
  required num amount,
  required String reason,
});

typedef ClosePeriodCallback = Future<void> Function({
  required String clubId,
  required String operationId,
  required String periodId,
  String? note,
});

typedef ReopenPeriodCallback = Future<void> Function({
  required String clubId,
  required String operationId,
  required String periodId,
  required String reason,
});

@immutable
final class PeriodClosingWriteCallbacks {
  const PeriodClosingWriteCallbacks({
    this.onApproveAdjustment,
    this.onCreateAdjustment,
    this.onClosePeriod,
    this.onReopenPeriod,
  });

  final ApproveAdjustmentCallback? onApproveAdjustment;
  final CreateAdjustmentCallback? onCreateAdjustment;
  final ClosePeriodCallback? onClosePeriod;
  final ReopenPeriodCallback? onReopenPeriod;
}

final class SharedPeriodClosingScreen extends ConsumerWidget {
  const SharedPeriodClosingScreen({
    this.writeCallbacks = const PeriodClosingWriteCallbacks(),
    super.key,
  });

  final PeriodClosingWriteCallbacks writeCallbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Dönem Kapanışı & Ters Kayıt',
      body: _PeriodClosingBody(writeCallbacks: writeCallbacks),
    );
  }
}

final class _PeriodClosingBody extends ConsumerStatefulWidget {
  const _PeriodClosingBody({required this.writeCallbacks});

  final PeriodClosingWriteCallbacks writeCallbacks;

  @override
  ConsumerState<_PeriodClosingBody> createState() => _PeriodClosingBodyState();
}

final class _PeriodClosingBodyState extends ConsumerState<_PeriodClosingBody> {
  ProDirtyStateRegistration? _dirtyRegistration;
  String? _lastClubId;
  String? _activePendingScopeKey;
  String? _statusMessage;
  String _statusFilter = 'all';
  bool _isStatusError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dirtyRegistration = ref
        .read(proDirtyStateCoordinatorProvider)
        .register('period-closing-screen');
  }

  @override
  void dispose() {
    _dirtyRegistration?.dispose();
    super.dispose();
  }

  String _effectiveUserId(WidgetRef ref) {
    final contextKey = ref.watch(proFeatureContextProvider);
    if (contextKey != null && contextKey.userId.isNotEmpty) {
      return contextKey.userId;
    }
    return ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
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

  Future<void> _executeApproveAdjustment({
    required String clubId,
    required String adjustmentId,
    required bool approve,
    required bool isSelfCreated,
  }) async {
    if (_isSubmitting) return;
    if (isSelfCreated && approve) {
      setState(() {
        _statusMessage = 'Kendi açtığın düzeltmeyi onaylayamazsın.';
        _isStatusError = true;
      });
      return;
    }
    if (!_verifyWriteClubScope(clubId)) {
      setState(() {
        _statusMessage =
            'Aktif kulüp kapsamı doğrulaması başarısız oldu. İşlem reddedildi.';
        _isStatusError = true;
      });
      return;
    }

    final scopeKey = '$clubId:adjustment_decision:$adjustmentId';
    final existing =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    final opId = existing?.operationId ?? newOpId();
    final payload = existing?.payload ??
        <String, Object?>{
          'type': 'adjustment_decision',
          'clubId': clubId,
          'adjustmentId': adjustmentId,
          'approve': approve,
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
      final callback = widget.writeCallbacks.onApproveAdjustment;
      final targetAdjustmentId = payload['adjustmentId'] as String;
      final targetApprove = payload['approve'] as bool;
      if (callback != null) {
        await callback(
          clubId: clubId,
          operationId: opId,
          adjustmentId: targetAdjustmentId,
          approve: targetApprove,
        );
      } else {
        await ref.read(financeOpsServiceProvider).approveAdjustment(
              adjustmentId: targetAdjustmentId,
              approve: targetApprove,
            );
      }

      if (!mounted) return;
      ref.read(proPendingOperationsProvider.notifier).clearOperation(scopeKey);
      _dirtyRegistration?.clearPendingOperation();
      ref
        ..invalidate(financeAdjustmentsProvider)
        ..invalidate(financeOperationsSummaryProvider);
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = null;
        _statusMessage =
            targetApprove ? 'Ters işlem onaylandı.' : 'Ters işlem reddedildi.';
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

  Future<void> _executeCreateAdjustment({
    required String clubId,
    required String targetKind,
    String? targetId,
    required num amount,
    required String reason,
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

    final scopeKey = '$clubId:create_adjustment:${targetId ?? 'new'}';
    final existing =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    final opId = existing?.operationId ?? newOpId();
    final payload = existing?.payload ??
        <String, Object?>{
          'type': 'create_adjustment',
          'clubId': clubId,
          'targetKind': targetKind,
          'targetId': targetId,
          'amount': amount,
          'reason': reason,
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
      final callback = widget.writeCallbacks.onCreateAdjustment;
      final tKind = payload['targetKind'] as String;
      final tId = payload['targetId'] as String?;
      final tAmount = payload['amount'] as num;
      final tReason = payload['reason'] as String;

      if (callback != null) {
        await callback(
          clubId: clubId,
          operationId: opId,
          targetKind: tKind,
          targetId: tId,
          amount: tAmount,
          reason: tReason,
        );
      } else {
        await ref.read(financeOpsServiceProvider).createAdjustment(
              clubId: clubId,
              targetKind: tKind,
              targetId: tId,
              amount: tAmount,
              reason: tReason,
            );
      }

      if (!mounted) return;
      ref.read(proPendingOperationsProvider.notifier).clearOperation(scopeKey);
      _dirtyRegistration?.clearPendingOperation();
      ref
        ..invalidate(financeAdjustmentsProvider)
        ..invalidate(financeOperationsSummaryProvider);
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = null;
        _statusMessage = 'Ters kayıt talebi oluşturuldu.';
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
    final type = record.payload['type'] as String?;
    if (type == 'adjustment_decision') {
      await _executeApproveAdjustment(
        clubId: clubId,
        adjustmentId: record.payload['adjustmentId'] as String,
        approve: record.payload['approve'] as bool,
        isSelfCreated: false,
      );
    } else if (type == 'create_adjustment') {
      await _executeCreateAdjustment(
        clubId: clubId,
        targetKind: record.payload['targetKind'] as String,
        targetId: record.payload['targetId'] as String?,
        amount: record.payload['amount'] as num,
        reason: record.payload['reason'] as String,
      );
    }
  }

  void _showNewAdjustmentSheet(BuildContext context, String clubId) {
    final host = ProFeatureHostScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProFeatureHostScope(
        navigator: host.navigator,
        chrome: host.chrome,
        theme: host.theme,
        child: _NewAdjustmentSheet(
          clubId: clubId,
          onSubmit: (targetKind, targetId, amount, reason) =>
              _executeCreateAdjustment(
            clubId: clubId,
            targetKind: targetKind,
            targetId: targetId,
            amount: amount,
            reason: reason,
          ),
        ),
      ),
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
            'Dönem kapanışı ve ters kayıtlar yalnız kulüp muhasebecisi yetkisi olan hesaplara açıktır.',
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
        !flags.has(FeatureFlags.periodClosing)) {
      return const AccountingPanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Dönem kapanışı kademeli yayında',
        body:
            'Dönem kapanışı ve ters kayıt modülü hesabın için henüz açılmadı.',
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
            'Aktif bir muhasebe kulüp kapsamı olmadan dönem kapanışı sorguları çalıştırılmaz.',
      );
    }

    final selectedId = ref.watch(selectedAccountantClubIdProvider);
    final selectedClub =
        accountantClubs.where((club) => club.id == selectedId).firstOrNull ??
            accountantClubs.first;

    if (_lastClubId != selectedClub.id) {
      _lastClubId = selectedClub.id;
      _activePendingScopeKey = null;
      _statusMessage = null;
      _statusFilter = 'all';
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

    final periodsAsync = ref.watch(financePeriodsProvider);
    final adjustmentsAsync = ref.watch(financeAdjustmentsProvider);

    if (adjustmentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (adjustmentsAsync.hasError) {
      final error = adjustmentsAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref.invalidate(financeAdjustmentsProvider);
        },
      );
    }

    final periods = periodsAsync.valueOrNull ?? const <FinancePeriod>[];
    final adjustments =
        adjustmentsAsync.valueOrNull ?? const <FinanceAdjustment>[];
    final currentUserId = _effectiveUserId(ref);

    final visibleAdjustments = adjustments.where((adj) {
      if (_statusFilter == 'all') return true;
      return adj.status == _statusFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(financeAdjustmentsProvider)
          ..invalidate(financePeriodsProvider);
        await ref.read(financeAdjustmentsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AccountantClubSelector(
            clubs: accountantClubs,
            selectedClub: selectedClub,
            theme: host.theme,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Kapalı dönem kayıtları doğrudan düzenlenemez veya silinemez; hatalı işlemler cari döneme ters kayıt (offsetting adjustment) açılarak denetlenir.',
              style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            _PeriodStatusBanner(
              message: _statusMessage!,
              isError: _isStatusError,
              pendingRecord: activePendingRecord,
              onRetry: activePendingRecord == null
                  ? null
                  : () => _retryPendingOperation(selectedClub.id),
              theme: host.theme,
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Ters İşlemler ve Düzeltmeler (${adjustments.length})',
                style: TextStyle(
                  color: host.theme.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const Key('open-new-adjustment-sheet-btn'),
                  onPressed: () =>
                      _showNewAdjustmentSheet(context, selectedClub.id),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni Ters İşlem'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterTab(
                key: const Key('closing-filter-all'),
                label: 'Tümü (${adjustments.length})',
                selected: _statusFilter == 'all',
                onTap: () => setState(() => _statusFilter = 'all'),
                theme: host.theme,
              ),
              _FilterTab(
                key: const Key('closing-filter-pending'),
                label:
                    'Onay Bekleyen (${adjustments.where((a) => a.status == 'pending').length})',
                selected: _statusFilter == 'pending',
                onTap: () => setState(() => _statusFilter = 'pending'),
                theme: host.theme,
              ),
              _FilterTab(
                key: const Key('closing-filter-approved'),
                label:
                    'Onaylanan (${adjustments.where((a) => a.status == 'approved').length})',
                selected: _statusFilter == 'approved',
                onTap: () => setState(() => _statusFilter = 'approved'),
                theme: host.theme,
              ),
              _FilterTab(
                key: const Key('closing-filter-rejected'),
                label:
                    'Reddedilen (${adjustments.where((a) => a.status == 'rejected').length})',
                selected: _statusFilter == 'rejected',
                onTap: () => setState(() => _statusFilter = 'rejected'),
                theme: host.theme,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visibleAdjustments.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: host.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: host.theme.line),
              ),
              child: Text(
                _statusFilter == 'all'
                    ? 'Kayıtlı ters işlem veya düzeltme bulunmuyor.'
                    : 'Bu duruma uygun ters işlem bulunamadı.',
                style: TextStyle(color: host.theme.inkMuted),
              ),
            )
          else
            for (final adj in visibleAdjustments) ...[
              _AdjustmentCard(
                adjustment: adj,
                isSelfCreated: adj.createdBy != null &&
                    adj.createdBy!.isNotEmpty &&
                    adj.createdBy == currentUserId,
                isSubmitting: _isSubmitting,
                theme: host.theme,
                onApprove: () => _executeApproveAdjustment(
                  clubId: selectedClub.id,
                  adjustmentId: adj.id,
                  approve: true,
                  isSelfCreated: adj.createdBy != null &&
                      adj.createdBy!.isNotEmpty &&
                      adj.createdBy == currentUserId,
                ),
                onReject: () => _executeApproveAdjustment(
                  clubId: selectedClub.id,
                  adjustmentId: adj.id,
                  approve: false,
                  isSelfCreated: adj.createdBy != null &&
                      adj.createdBy!.isNotEmpty &&
                      adj.createdBy == currentUserId,
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 16),
          Text(
            'Mali Dönemler (${periods.length})',
            style: TextStyle(
              color: host.theme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (periods.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: host.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: host.theme.line),
              ),
              child: Text(
                'Tanımlı mali dönem bulunmuyor.',
                style: TextStyle(color: host.theme.inkMuted),
              ),
            )
          else
            for (final per in periods) ...[
              _PeriodCard(period: per, theme: host.theme),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

final class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: theme.accent.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: selected ? theme.accent : theme.ink,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

final class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard({
    required this.adjustment,
    required this.isSelfCreated,
    required this.isSubmitting,
    required this.theme,
    required this.onApprove,
    required this.onReject,
  });

  final FinanceAdjustment adjustment;
  final bool isSelfCreated;
  final bool isSubmitting;
  final ProFeatureThemeData theme;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final isPending = adjustment.status == 'pending';
    final canApprove = isPending && !isSelfCreated && !isSubmitting;
    final canReject = isPending && !isSubmitting;

    final statusColor = switch (adjustment.status) {
      'approved' => theme.success,
      'rejected' => theme.danger,
      _ => theme.warning,
    };

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${adjustment.targetKindLabel} · ${money(adjustment.amount)}',
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  adjustment.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Gerekçe: ${adjustment.reason}',
            style: TextStyle(color: theme.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'Tarih: ${accountingTurkeyDate(adjustment.createdAt)}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          if (isPending) ...[
            if (isSelfCreated) ...[
              const SizedBox(height: 6),
              Text(
                'Kendi açtığın düzeltmeyi onaylayamazsın. Başka bir yetkili incelemelidir.',
                style: TextStyle(
                  color: theme.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    key: Key('approve-adjustment-btn-${adjustment.id}'),
                    onPressed: canApprove ? onApprove : null,
                    child: const Text('Onayla'),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: Key('reject-adjustment-btn-${adjustment.id}'),
                    onPressed: canReject ? onReject : null,
                    child: const Text('Reddet'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.theme,
  });

  final FinancePeriod period;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${accountingTurkeyDate(period.periodFrom)} - ${accountingTurkeyDate(period.periodTo)}',
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            period.statusLabel,
            style: TextStyle(
              color: period.isClosed ? theme.inkMuted : theme.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

final class _NewAdjustmentSheet extends ConsumerStatefulWidget {
  const _NewAdjustmentSheet({
    required this.clubId,
    required this.onSubmit,
  });

  final String clubId;
  final void Function(
    String targetKind,
    String? targetId,
    num amount,
    String reason,
  ) onSubmit;

  @override
  ConsumerState<_NewAdjustmentSheet> createState() =>
      _NewAdjustmentSheetState();
}

final class _NewAdjustmentSheetState
    extends ConsumerState<_NewAdjustmentSheet> {
  String? _kindFilter;
  int _offset = 0;
  String _searchQuery = '';
  String? _selectedEntryId;
  ClosedPeriodCandidateEntry? _selectedEntry;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  static const int _pageSize = 50;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String? newKind) {
    setState(() {
      _kindFilter = newKind;
      _offset = 0;
      if (_selectedEntry != null &&
          newKind != null &&
          _selectedEntry!.targetKind != newKind) {
        _selectedEntryId = null;
        _selectedEntry = null;
        _amountController.clear();
        _reasonController.clear();
      }
    });
  }

  String _targetKindLabel(String kind) => switch (kind) {
        'expense' => 'Gider',
        'payment' => 'Tahsilat',
        'donation' => 'Bağış',
        _ => 'İşlem',
      };

  @override
  Widget build(BuildContext context) {
    final theme = ProFeatureHostScope.of(context).theme;
    final candidatesAsync = ref.watch(
      closedPeriodCandidatesPageProvider(
        (
          targetKind: _kindFilter,
          limit: _pageSize,
          offset: _offset,
          query: _searchQuery.isEmpty ? null : _searchQuery,
        ),
      ),
    );

    final page = candidatesAsync.valueOrNull ??
        const ClosedPeriodCandidatesPage(entries: [], totalCount: 0);
    final totalPages = (page.totalCount / _pageSize).ceil().clamp(1, 9999);
    final currentPage = (_offset / _pageSize).floor() + 1;

    final displayItems = List<ClosedPeriodCandidateEntry>.from(page.entries);
    if (_selectedEntry != null &&
        (_kindFilter == null || _selectedEntry!.targetKind == _kindFilter) &&
        !displayItems.any((e) => e.entryId == _selectedEntry!.entryId)) {
      displayItems.insert(0, _selectedEntry!);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Yeni Ters İşlem',
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _kindFilter == null,
                  onSelected: (_) => _onFilterChanged(null),
                ),
                ChoiceChip(
                  label: const Text('Giderler'),
                  selected: _kindFilter == 'expense',
                  onSelected: (_) => _onFilterChanged('expense'),
                ),
                ChoiceChip(
                  label: const Text('Tahsilatlar'),
                  selected: _kindFilter == 'payment',
                  onSelected: (_) => _onFilterChanged('payment'),
                ),
                ChoiceChip(
                  label: const Text('Bağışlar'),
                  selected: _kindFilter == 'donation',
                  onSelected: (_) => _onFilterChanged('donation'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Hedef kayıtlarda ara…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _offset = 0;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toplam ${page.totalCount} kayıt (Sayfa $currentPage / $totalPages)',
                  style: TextStyle(color: theme.inkMuted, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _offset > 0
                          ? () => setState(() => _offset -= _pageSize)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _offset + _pageSize < page.totalCount
                          ? () => setState(() => _offset += _pageSize)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('target-$_selectedEntryId-$_kindFilter'),
              isExpanded: true,
              initialValue:
                  displayItems.any((e) => e.entryId == _selectedEntryId)
                      ? _selectedEntryId
                      : null,
              hint: const Text('Hedef kaydı seçin'),
              items: [
                for (final e in displayItems)
                  DropdownMenuItem(
                    value: e.entryId,
                    child: Text(
                      '[${_targetKindLabel(e.targetKind)}] ${e.label} • ₺${e.amount} (Kalan: ₺${e.remainingAmount})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedEntryId = val;
                  _selectedEntry =
                      displayItems.where((e) => e.entryId == val).firstOrNull;
                  if (_selectedEntry != null) {
                    _amountController.text =
                        _selectedEntry!.remainingAmount.toString();
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Düzeltme Tutarı (TL)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Düzeltme Gerekçesi (Zorunlu)',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  final amount = num.tryParse(_amountController.text) ?? 0;
                  final reason = _reasonController.text.trim();
                  if (amount <= 0 || reason.isEmpty) return;
                  widget.onSubmit(
                    _selectedEntry?.targetKind ?? _kindFilter ?? 'expense',
                    _selectedEntryId,
                    amount,
                    reason,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Ters İşlem Talebi Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PeriodStatusBanner extends StatelessWidget {
  const _PeriodStatusBanner({
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
              'Ağ sonucu belirsiz. Aynı işlem kimliği (${pendingRecord!.operationId}) korunuyor.',
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
