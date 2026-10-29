import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';

typedef CreateDutyCallback = Future<TurfDutyInvite> Function({
  required String fieldId,
  required int hours,
  required String operationId,
});

typedef RedeemDutyCallback = Future<String> Function(String code);

typedef RevokeDutyCallback = Future<void> Function(String dutyId);

@immutable
final class TurfDutiesWriteCallbacks {
  const TurfDutiesWriteCallbacks({
    this.onCreateDuty,
    this.onRedeemDuty,
    this.onRevokeDuty,
  });

  final CreateDutyCallback? onCreateDuty;
  final RedeemDutyCallback? onRedeemDuty;
  final RevokeDutyCallback? onRevokeDuty;
}

/// Halı saha süreli görev delegasyonu ve nöbet yönetim ekranı.
final class SharedManagedTurfDutiesScreen extends ConsumerWidget {
  const SharedManagedTurfDutiesScreen({
    this.writeCallbacks = const TurfDutiesWriteCallbacks(),
    super.key,
  });

  final TurfDutiesWriteCallbacks writeCallbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Saha Görevleri & Yetkilendirme',
      body: _ManagedTurfDutiesBody(writeCallbacks: writeCallbacks),
    );
  }
}

final class _ManagedTurfDutiesBody extends ConsumerStatefulWidget {
  const _ManagedTurfDutiesBody({required this.writeCallbacks});

  final TurfDutiesWriteCallbacks writeCallbacks;

  @override
  ConsumerState<_ManagedTurfDutiesBody> createState() =>
      _ManagedTurfDutiesBodyState();
}

final class _ManagedTurfDutiesBodyState
    extends ConsumerState<_ManagedTurfDutiesBody> {
  final TextEditingController _codeController = TextEditingController();
  final int _offset = 0;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isStatusError = false;
  String? _activePendingScopeKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(turfDutiesProvider(_offset));
    ref.invalidate(delegatedTurfFieldIdsProvider);
  }

  bool _verifyFieldScope(String expectedFieldId) {
    final currentScope = ref.read(selectedFacilityScopeIdProvider);
    if (currentScope == null || currentScope != expectedFieldId) {
      return false;
    }
    return true;
  }

  Future<void> _handleCreateDuty({
    required String fieldId,
    required int hours,
  }) async {
    if (_isSubmitting) return;
    if (!_verifyFieldScope(fieldId)) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Tesis kapsamı değişti. İşlem güvenlik nedeniyle iptal edildi.';
        _isStatusError = true;
      });
      return;
    }

    final scopeKey = '$fieldId:create_duty';
    final existing =
        ref.read(proPendingOperationsProvider).operationFor(scopeKey);
    final opId = existing?.operationId ?? newOpId();
    final payload = existing?.payload ??
        <String, Object?>{
          'fieldId': fieldId,
          'hours': hours,
        };

    ref.read(proPendingOperationsProvider.notifier).saveOperation(
          scopeKey: scopeKey,
          operationId: opId,
          payload: payload,
        );

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _activePendingScopeKey = scopeKey;
    });

    try {
      final callback = widget.writeCallbacks.onCreateDuty;
      TurfDutyInvite invite;
      if (callback != null) {
        invite = await callback(
          fieldId: fieldId,
          hours: hours,
          operationId: opId,
        );
      } else {
        invite = await ref
            .read(sahaOperationsServiceProvider)
            .createDuty(fieldId, hours, opId);
      }

      ref.read(proPendingOperationsProvider.notifier).clearOperation(scopeKey);
      _refresh();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _activePendingScopeKey = null;
        _statusMessage = 'Görev daveti oluşturuldu! Davet Kodu: ${invite.code}';
        _isStatusError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage =
            'Ağ sonucu belirsiz veya işlem başarısız oldu. Aynı işlem kimliğiyle yeniden deneyebilirsiniz: $e';
        _isStatusError = true;
      });
    }
  }

  Future<void> _handleRedeemDuty(String code) async {
    final trimmed = code.trim();
    if (_isSubmitting || trimmed.isEmpty) return;

    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!regex.hasMatch(trimmed)) {
      setState(() {
        _statusMessage = 'Geçerli bir UUID görev davet kodu giriniz.';
        _isStatusError = true;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final callback = widget.writeCallbacks.onRedeemDuty;
      if (callback != null) {
        await callback(trimmed);
      } else {
        await ref.read(sahaOperationsServiceProvider).redeemDuty(trimmed);
      }

      _codeController.clear();
      _refresh();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage = 'Saha görevi başarıyla kabul edildi.';
        _isStatusError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage = 'Davet kabul edilemedi: $e';
        _isStatusError = true;
      });
    }
  }

  Future<void> _handleRevokeDuty(TurfDuty duty) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final callback = widget.writeCallbacks.onRevokeDuty;
      if (callback != null) {
        await callback(duty.id);
      } else {
        await ref.read(sahaOperationsServiceProvider).revokeDuty(duty.id);
      }

      _refresh();

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage =
            duty.issuer ? 'Saha görevi geri alındı.' : 'Saha görevi bırakıldı.';
        _isStatusError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _statusMessage = 'Görev geri alınamadı: $e';
        _isStatusError = true;
      });
    }
  }

  void _showCreateDutyDialog(BuildContext context, String fieldId) {
    int selectedHours = 24;
    final theme = ProFeatureHostScope.of(context).theme;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.surface,
            title: Text(
              'Yeni Görev Daveti Oluştur',
              style: TextStyle(
                color: theme.ink,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Görevli personelin saha doluluğunu işaretleyebileceği yetki süresini seçiniz (1–168 saat):',
                  style: TextStyle(color: theme.inkMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedHours,
                  decoration: InputDecoration(
                    labelText: 'Yetki Süresi',
                    filled: true,
                    fillColor: theme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 Saat')),
                    DropdownMenuItem(value: 4, child: Text('4 Saat')),
                    DropdownMenuItem(value: 8, child: Text('8 Saat')),
                    DropdownMenuItem(value: 12, child: Text('12 Saat')),
                    DropdownMenuItem(value: 24, child: Text('24 Saat (1 Gün)')),
                    DropdownMenuItem(value: 48, child: Text('48 Saat (2 Gün)')),
                    DropdownMenuItem(
                      value: 168,
                      child: Text('168 Saat (1 Hafta)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedHours = val);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text('Vazgeç', style: TextStyle(color: theme.inkMuted)),
              ),
              FilledButton(
                key: const Key('submit-create-duty-btn'),
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  _handleCreateDuty(
                    fieldId: fieldId,
                    hours: selectedHours,
                  );
                },
                child: const Text('Davet Oluştur'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);

    // Listen to scope changes and refresh duties
    ref.listen(selectedFacilityScopeIdProvider, (prev, next) {
      if (prev != next) {
        _refresh();
      }
    });

    if (!access.canOpenTurfCenter) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'Tesis Yetkisi Yok',
          style: TextStyle(color: theme.ink, fontWeight: FontWeight.w700),
        ),
      );
    }

    final flags = flagsAsync.valueOrNull;
    final isFlagsDisabled = flags == null ||
        !flags.has(FeatureFlags.turfFields) ||
        !flags.has(FeatureFlags.turfDelegation);

    if (isFlagsDisabled) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.danger.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Tesis operasyonları özelliği etkin değil.',
          style: TextStyle(
            color: theme.danger,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final activeFieldId = ref.watch(selectedFacilityScopeIdProvider);
    final isManager =
        activeFieldId != null && access.isTurfManagerOf(activeFieldId);

    final dutiesAsync = ref.watch(turfDutiesProvider(_offset));
    final pendingRecord = _activePendingScopeKey != null
        ? ref
            .watch(proPendingOperationsProvider)
            .operationFor(_activePendingScopeKey!)
        : null;

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isStatusError
                    ? theme.danger.withValues(alpha: 0.1)
                    : theme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isStatusError ? theme.danger : theme.accent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _isStatusError ? theme.danger : theme.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (pendingRecord != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const Key('retry-pending-duty-op-btn'),
                        onPressed: () {
                          final hours =
                              pendingRecord.payload['hours'] as int? ?? 24;
                          _handleCreateDuty(
                            fieldId: activeFieldId!,
                            hours: hours,
                          );
                        },
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Aynı işlemle yeniden dene'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Manager Write Action: Yeni Görev Daveti (ONLY RENDERED FOR MANAGERS, HIDDEN FOR DELEGATES)
          if (isManager) ...[
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('create-duty-invite-btn'),
                onPressed: _isSubmitting
                    ? null
                    : () => _showCreateDutyDialog(context, activeFieldId),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Yeni Görev Daveti Oluştur'),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Redeem duty code card
          _buildRedeemCard(theme),
          const SizedBox(height: 20),

          // Duty list header
          Text(
            'Tanımlı Saha Görevleri',
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          dutiesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.danger),
              ),
              child: Text(
                'Görevler yüklenirken hata oluştu: $err',
                style: TextStyle(color: theme.danger),
              ),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'Tanımlı saha görevi bulunmuyor.',
                    style: TextStyle(color: theme.inkMuted, fontSize: 14),
                  ),
                );
              }

              return Column(
                children: page.items
                    .map(
                      (duty) => _buildDutyCard(
                        theme: theme,
                        duty: duty,
                        access: access,
                        isManager: isManager,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemCard(ProFeatureThemeData theme) {
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
          Text(
            'Görev Kodu Kabul Et (Redeem)',
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('redeem-duty-code-input'),
            controller: _codeController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Davet Kodu (UUID)',
              hintText: '12345678-1234-1234-1234-123456789abc',
              filled: true,
              fillColor: theme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.tonal(
              key: const Key('submit-redeem-duty-btn'),
              onPressed: _isSubmitting
                  ? null
                  : () => _handleRedeemDuty(_codeController.text),
              child: const Text('Görevi Kabul Et'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyCard({
    required ProFeatureThemeData theme,
    required TurfDuty duty,
    required SwanAccess access,
    required bool isManager,
  }) {
    // Server status takes precedence as source of truth
    final statusLabel = switch (duty.status) {
      'active' => 'Aktif görev',
      'invited' => 'Davet bekliyor',
      'revoked' => 'Geri alındı',
      _ => 'Süresi doldu',
    };

    final isServerLive = duty.status == 'active' || duty.status == 'invited';
    final isDeviceExpired = duty.validUntil.isBefore(DateTime.now());
    final isReallyLive = isServerLive && !isDeviceExpired;

    final badgeColor = switch (duty.status) {
      'active' => theme.accent,
      'invited' => theme.warning,
      'revoked' => theme.inkMuted,
      _ => theme.danger,
    };

    // Manager can revoke duties they issued on their managed turf.
    // Delegate can release/leave their own assigned active duty.
    // Expired or revoked duties never show actions (fail-closed).
    final canRevoke = isReallyLive &&
        ((duty.issuer && access.isTurfManagerOf(duty.fieldId)) ||
            (!duty.issuer &&
                duty.status == 'active' &&
                access.delegatedTurfFieldIds.contains(duty.fieldId)));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
            children: [
              Expanded(
                child: Text(
                  duty.fieldName.isNotEmpty
                      ? duty.fieldName
                      : 'Saha ${duty.fieldId}',
                  style: TextStyle(
                    color: theme.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (duty.venueName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              duty.venueName,
              style: TextStyle(color: theme.inkMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            duty.issuer ? 'Verilen Görev (Yönetici)' : 'Alınan Görev (Delege)',
            style: TextStyle(
              color: theme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bitiş Tarihi: ${duty.validUntil.toLocal()}',
            style: TextStyle(color: theme.inkMuted, fontSize: 11),
          ),
          if (canRevoke) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: Key('revoke-duty-btn-${duty.id}'),
                onPressed: _isSubmitting ? null : () => _handleRevokeDuty(duty),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: Text(duty.issuer ? 'Görevi geri al' : 'Görevi bırak'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.danger,
                  side: BorderSide(color: theme.danger.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
