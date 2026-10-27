import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_dirty_state.dart';
import '../host/pro_feature_context.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'accounting_operations_panel.dart';

/// Optional set of expense IDs known to be created by the active user in the
/// current session or context, used to enforce the UI self-approval lock even
/// if an own expense row reaches the client list.
final selfEnteredExpenseIdsProvider = Provider<Set<String>>(
  (ref) => const <String>{},
);

typedef RecordOccurrenceCallback = Future<String> Function({
  required String clubId,
  required String operationId,
  required String occurrenceId,
  required num amount,
});

typedef DecideExpenseApprovalCallback = Future<String> Function({
  required String clubId,
  required String operationId,
  required String expenseId,
  required bool approve,
  String? reason,
});

typedef CreateDraftExpenseCallback = Future<String> Function({
  required String clubId,
  required String operationId,
  required num amount,
  String? note,
});

@immutable
final class FinanceCommitmentsWriteCallbacks {
  const FinanceCommitmentsWriteCallbacks({
    this.onRecordOccurrence,
    this.onDecideApproval,
    this.onCreateDraftExpense,
  });

  final RecordOccurrenceCallback? onRecordOccurrence;
  final DecideExpenseApprovalCallback? onDecideApproval;
  final CreateDraftExpenseCallback? onCreateDraftExpense;
}

final class SharedFinanceCommitmentsScreen extends ConsumerWidget {
  const SharedFinanceCommitmentsScreen({
    this.writeCallbacks = const FinanceCommitmentsWriteCallbacks(),
    super.key,
  });

  final FinanceCommitmentsWriteCallbacks writeCallbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Taahhütler & Gider Onayları',
      body: _FinanceCommitmentsBody(writeCallbacks: writeCallbacks),
    );
  }
}

final class _FinanceCommitmentsBody extends ConsumerStatefulWidget {
  const _FinanceCommitmentsBody({required this.writeCallbacks});

  final FinanceCommitmentsWriteCallbacks writeCallbacks;

  @override
  ConsumerState<_FinanceCommitmentsBody> createState() =>
      _FinanceCommitmentsBodyState();
}

final class _FinanceCommitmentsBodyState
    extends ConsumerState<_FinanceCommitmentsBody> {
  ProDirtyStateRegistration? _dirtyRegistration;
  String? _lastClubId;
  String? _activePendingScopeKey;
  String? _statusMessage;
  bool _isStatusError = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dirtyRegistration = ref
        .read(proDirtyStateCoordinatorProvider)
        .register('finance-commitments-screen');
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

  bool _isSelfCreatedExpense({
    required ExpenseRow expense,
    required String currentUserId,
    required Set<String> selfEnteredIds,
    required List<RecurringExpense> recurringExpenses,
  }) {
    if (selfEnteredIds.contains(expense.id)) return true;
    if (currentUserId.isEmpty) return false;
    for (final recurring in recurringExpenses) {
      if (recurring.ownerId == currentUserId) {
        if (expense.note != null &&
            expense.note!.trim().isNotEmpty &&
            expense.note!.trim() == recurring.title.trim()) {
          return true;
        }
        if (recurring.vendorId != null &&
            recurring.vendorId == expense.vendorId &&
            recurring.amount == expense.amount) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _executeOccurrenceRecord({
    required String clubId,
    required String occurrenceId,
    required num amount,
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

    final scopeKey = '$clubId:occurrence:$occurrenceId';
    final existing =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    final opId = existing?.operationId ?? newOpId();
    final payload = existing?.payload ??
        <String, Object?>{
          'type': 'occurrence',
          'clubId': clubId,
          'occurrenceId': occurrenceId,
          'amount': amount,
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
      final callback = widget.writeCallbacks.onRecordOccurrence;
      final targetOccurrenceId = payload['occurrenceId'] as String;
      final targetAmount = payload['amount'] as num;
      if (callback != null) {
        await callback(
          clubId: clubId,
          operationId: opId,
          occurrenceId: targetOccurrenceId,
          amount: targetAmount,
        );
      } else {
        await ref
            .read(financeOpsServiceProvider)
            .recordOccurrence(targetOccurrenceId, amount: targetAmount);
      }

      if (!mounted) return;
      ref.read(proPendingOperationsProvider.notifier).clearOperation(scopeKey);
      _dirtyRegistration?.clearPendingOperation();
      ref
        ..invalidate(upcomingOccurrencesProvider)
        ..invalidate(pendingApprovalsProvider)
        ..invalidate(recurringExpensesProvider)
        ..invalidate(financeOperationsSummaryProvider);
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = null;
        _statusMessage = 'Taahhüt vadesi gider olarak kaydedildi.';
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

  Future<void> _executeApprovalDecision({
    required String clubId,
    required String expenseId,
    required bool approve,
    required bool isSelfCreated,
  }) async {
    if (_isSubmitting) return;
    if (isSelfCreated) {
      setState(() {
        _statusMessage = 'Kendi oluşturduğun gideri onaylayamazsın.';
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

    final scopeKey = '$clubId:approval:$expenseId';
    final existing =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    final opId = existing?.operationId ?? newOpId();
    final payload = existing?.payload ??
        <String, Object?>{
          'type': 'approval',
          'clubId': clubId,
          'expenseId': expenseId,
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
      final callback = widget.writeCallbacks.onDecideApproval;
      final targetExpenseId = payload['expenseId'] as String;
      final targetApprove = payload['approve'] as bool;
      if (callback != null) {
        await callback(
          clubId: clubId,
          operationId: opId,
          expenseId: targetExpenseId,
          approve: targetApprove,
        );
      } else {
        await ref
            .read(financeOpsServiceProvider)
            .decideApproval(targetExpenseId, targetApprove);
      }

      if (!mounted) return;
      ref.read(proPendingOperationsProvider.notifier).clearOperation(scopeKey);
      _dirtyRegistration?.clearPendingOperation();
      ref
        ..invalidate(pendingApprovalsProvider)
        ..invalidate(financeOperationsSummaryProvider);
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = null;
        _statusMessage = targetApprove
            ? 'Gider onayı kaydedildi.'
            : 'Gider reddi kaydedildi.';
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
    if (type == 'occurrence') {
      await _executeOccurrenceRecord(
        clubId: clubId,
        occurrenceId: record.payload['occurrenceId'] as String,
        amount: record.payload['amount'] as num,
      );
    } else if (type == 'approval') {
      await _executeApprovalDecision(
        clubId: clubId,
        expenseId: record.payload['expenseId'] as String,
        approve: record.payload['approve'] as bool,
        isSelfCreated: false,
      );
    }
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
            'Taahhüt ve gider onayları yalnız yetkili kulüp muhasebecisi hesaplarına açıktır.',
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
        !flags.has(FeatureFlags.recurringExpenses)) {
      return const AccountingPanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Taahhüt ve gider onayları kademeli yayında',
        body: 'Bu modül hesabın için henüz etkinleştirilmedi.',
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
            'Aktif bir muhasebe kulüp kapsamı olmadan taahhüt ve onay sorguları çalıştırılmaz.',
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

    final vendorsAsync = ref.watch(vendorsProvider);
    final recurringAsync = ref.watch(recurringExpensesProvider);
    final occurrencesAsync = ref.watch(upcomingOccurrencesProvider);
    final approvalsAsync = ref.watch(pendingApprovalsProvider);

    if (vendorsAsync.isLoading ||
        recurringAsync.isLoading ||
        occurrencesAsync.isLoading ||
        approvalsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vendorsAsync.hasError ||
        recurringAsync.hasError ||
        occurrencesAsync.hasError ||
        approvalsAsync.hasError) {
      final error = vendorsAsync.error ??
          recurringAsync.error ??
          occurrencesAsync.error ??
          approvalsAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref
            ..invalidate(vendorsProvider)
            ..invalidate(recurringExpensesProvider)
            ..invalidate(upcomingOccurrencesProvider)
            ..invalidate(pendingApprovalsProvider);
        },
      );
    }

    final vendors = vendorsAsync.valueOrNull ?? const <Vendor>[];
    final recurringList =
        recurringAsync.valueOrNull ?? const <RecurringExpense>[];
    final occurrences =
        occurrencesAsync.valueOrNull ?? const <RecurringOccurrence>[];
    final pendingApprovals = approvalsAsync.valueOrNull ?? const <ExpenseRow>[];
    final selfEnteredIds = ref.watch(selfEnteredExpenseIdsProvider);
    final currentUserId = _effectiveUserId(ref);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccountantClubSelector(
          clubs: accountantClubs,
          selectedClub: selectedClub,
          theme: host.theme,
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 12),
          _StatusBanner(
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
        Text(
          'Onay Bekleyen Giderler (${pendingApprovals.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Görev ayrılığı kuralı gereği kendi oluşturduğun gider kaydını onaylayamazsın.',
          style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (pendingApprovals.isEmpty)
          _EmptySectionCard(
            text: 'Onay bekleyen gider kaydı bulunmuyor.',
            theme: host.theme,
          )
        else
          for (final expense in pendingApprovals) ...[
            _PendingApprovalCard(
              expense: expense,
              isSelfCreated: _isSelfCreatedExpense(
                expense: expense,
                currentUserId: currentUserId,
                selfEnteredIds: selfEnteredIds,
                recurringExpenses: recurringList,
              ),
              isSubmitting: _isSubmitting,
              theme: host.theme,
              onApprove: () => _executeApprovalDecision(
                clubId: selectedClub.id,
                expenseId: expense.id,
                approve: true,
                isSelfCreated: _isSelfCreatedExpense(
                  expense: expense,
                  currentUserId: currentUserId,
                  selfEnteredIds: selfEnteredIds,
                  recurringExpenses: recurringList,
                ),
              ),
              onReject: () => _executeApprovalDecision(
                clubId: selectedClub.id,
                expenseId: expense.id,
                approve: false,
                isSelfCreated: _isSelfCreatedExpense(
                  expense: expense,
                  currentUserId: currentUserId,
                  selfEnteredIds: selfEnteredIds,
                  recurringExpenses: recurringList,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        Text(
          'Yaklaşan Taahhüt Vadeleri (${occurrences.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (occurrences.isEmpty)
          _EmptySectionCard(
            text: 'Yaklaşan 30 gün içinde bekleyen taahhüt vadesi yok.',
            theme: host.theme,
          )
        else
          for (final occ in occurrences) ...[
            _OccurrenceCard(
              occurrence: occ,
              isSubmitting: _isSubmitting,
              theme: host.theme,
              onRecord: () => _executeOccurrenceRecord(
                clubId: selectedClub.id,
                occurrenceId: occ.id,
                amount: occ.amount,
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        Text(
          'Düzenli Gider Taahhütleri (${recurringList.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (recurringList.isEmpty)
          _EmptySectionCard(
            text: 'Tanımlı düzenli gider taahhüdü bulunmuyor.',
            theme: host.theme,
          )
        else
          for (final rec in recurringList) ...[
            _RecurringExpenseTile(recurring: rec, theme: host.theme),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 16),
        Text(
          'Tedarikçi Özeti (${vendors.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gizlilik sınırı gereği özel banka ve kimlik alanları (vendor_private) muhasebe görünümünde açılmaz.',
          style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (vendors.isEmpty)
          _EmptySectionCard(
            text: 'Kayıtlı tedarikçi bulunmuyor.',
            theme: host.theme,
          )
        else
          for (final vendor in vendors) ...[
            _VendorTile(vendor: vendor, theme: host.theme),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

final class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
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
              'Ağ sonucu belirsiz. Mükerrer kayıt oluşmaması için aynı işlem kimliği (${pendingRecord!.operationId}) korunuyor.',
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

final class _PendingApprovalCard extends StatelessWidget {
  const _PendingApprovalCard({
    required this.expense,
    required this.isSelfCreated,
    required this.isSubmitting,
    required this.theme,
    required this.onApprove,
    required this.onReject,
  });

  final ExpenseRow expense;
  final bool isSelfCreated;
  final bool isSubmitting;
  final ProFeatureThemeData theme;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final canAct = !isSelfCreated && !isSubmitting;
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
                expense.supplier?.isNotEmpty == true
                    ? expense.supplier!
                    : (expense.categoryName ?? 'Gider Kaydı'),
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                money(expense.amount),
                style: TextStyle(
                  color: theme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tarih: ${accountingTurkeyDate(expense.spentOn)}'
            '${expense.categoryName == null ? '' : ' · Kategori: ${expense.categoryName}'}'
            '${expense.accountName == null ? '' : ' · Hesap: ${expense.accountName}'}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          if (expense.note != null && expense.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              expense.note!,
              style: TextStyle(color: theme.ink),
            ),
          ],
          if (isSelfCreated) ...[
            const SizedBox(height: 8),
            Text(
              'Kendi oluşturduğun gideri onaylayamazsın. Başka bir yetkili onaylamalıdır.',
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
                  key: Key('approve-expense-btn-${expense.id}'),
                  onPressed: canAct ? onApprove : null,
                  child: const Text('Onayla'),
                ),
              ),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  key: Key('reject-expense-btn-${expense.id}'),
                  onPressed: canAct ? onReject : null,
                  child: const Text('Reddet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.isSubmitting,
    required this.theme,
    required this.onRecord,
  });

  final RecurringOccurrence occurrence;
  final bool isSubmitting;
  final ProFeatureThemeData theme;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
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
                occurrence.title ?? 'Taahhüt Vadesi',
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                money(occurrence.amount),
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Vade Tarihi: ${accountingTurkeyDate(occurrence.dueOn)}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: Key('record-occurrence-btn-${occurrence.id}'),
              onPressed: isSubmitting ? null : onRecord,
              icon: const Icon(Icons.playlist_add_check_rounded),
              label: const Text('Gider Olarak Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

final class _RecurringExpenseTile extends StatelessWidget {
  const _RecurringExpenseTile({
    required this.recurring,
    required this.theme,
  });

  final RecurringExpense recurring;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${recurring.title} · ${money(recurring.amount)}',
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${freqLabel(recurring.frequency)}'
            '${recurring.vendorName == null ? '' : ' · ${recurring.vendorName}'}'
            '${recurring.needsApproval ? ' · Onay gerekir' : ''}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final class _VendorTile extends StatelessWidget {
  const _VendorTile({
    required this.vendor,
    required this.theme,
  });

  final Vendor vendor;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vendor.name,
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kategori: ${vendor.defaultCategoryName ?? 'Genel'}'
            '${vendor.contactNote == null || vendor.contactNote!.isEmpty ? '' : ' · Not: ${vendor.contactNote}'}'
            ' · ${vendor.expenseCount} işlem (${money(vendor.expenseTotal)})',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.text,
    required this.theme,
  });

  final String text;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.line),
      ),
      child: Text(
        text,
        style: TextStyle(color: theme.inkMuted),
      ),
    );
  }
}
