import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../club/club_operation_card.dart';
import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';

/// Filters [clubs] strictly to those where [access] grants active accountant
/// authority. Non-accountant memberships (e.g. coach/member in another club)
/// are never exposed in the accounting workspace.
List<ClubRef> resolveEffectiveAccountantClubs(
  List<ClubRef> clubs,
  SwanAccess access,
) {
  if (!access.isAccountant) return const <ClubRef>[];
  final authorizedIds = access.accountantClubIds;
  final matched = clubs
      .where((club) => authorizedIds.contains(club.id))
      .toList(growable: false);
  return List<ClubRef>.unmodifiable(matched);
}

String accountingTurkeyDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toUtc().add(const Duration(hours: 3));
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

final class SharedAccountingOperationsPanel extends ConsumerWidget {
  const SharedAccountingOperationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final access = ref.watch(swanAccessProvider);
    if (!access.isAccountant) {
      return const AccountingPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Muhasebe çalışma alanı yetkisi gerekli',
        body:
            'Bu çalışma alanı yalnız kulüp muhasebecisi yetkisi tanımlı hesaplara açıktır.',
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    final clubsAsync = ref.watch(myClubsProvider);
    if (flagsAsync.isLoading || clubsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
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
    if (!flags.has(FeatureFlags.financeOperationsCenter)) {
      return const AccountingPanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Mali operasyonlar kademeli yayında',
        body: 'Muhasebe operasyon merkezi hesabın için henüz açılmadı.',
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
            'Mali sorgular aktif bir kulüp kapsamı olmadan çalıştırılmaz. Yetkili olduğun kulüp kaydını kontrol et.',
      );
    }

    final selectedId = ref.watch(selectedAccountantClubIdProvider);
    final selectedClub =
        accountantClubs.where((club) => club.id == selectedId).firstOrNull ??
            accountantClubs.first;

    if (selectedId != selectedClub.id ||
        ref.watch(selectedClubIdProvider) != selectedClub.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedAccountantClubIdProvider.notifier).state =
              selectedClub.id;
          ref.read(selectedClubIdProvider.notifier).state = selectedClub.id;
        }
      });
    }

    final summaryAsync = ref.watch(financeOperationsSummaryProvider);
    final balancesAsync = ref.watch(accountBalancesProvider);
    final forecastAsync = ref.watch(cashForecastProvider);

    final cards = <Widget>[
      ClubOperationCard(
        icon: Icons.assignment_late_outlined,
        title: 'Mali İş Kuyruğu & Özet',
        detail: _asyncDetail(
          summaryAsync,
          (summary) => summary.hasWork
              ? '${summary.totalCount} bekleyen mali işlem'
              : 'Bekleyen mali işlem yok',
        ),
        onTap: host.navigator.openFinanceOperations,
        theme: host.theme,
      ),
      ClubOperationCard(
        icon: Icons.menu_book_outlined,
        title: 'Gelir / Gider Defteri',
        detail: _asyncDetail(
          balancesAsync,
          (balances) {
            final total = balances.fold<num>(0, (sum, b) => sum + b.balance);
            return '${balances.length} kasa/banka · Kesin: ${money(total)}';
          },
        ),
        onTap: host.navigator.openFinanceLedger,
        theme: host.theme,
      ),
    ];

    if (flags.has(FeatureFlags.recurringExpenses)) {
      cards.add(
        ClubOperationCard(
          icon: Icons.event_repeat_outlined,
          title: 'Taahhütler & Gider Onayları',
          detail: _asyncDetail(
            summaryAsync,
            (summary) =>
                '${summary.commitmentDueCount} yaklaşan vade · ${summary.pendingApprovalCount} onay bekleyen',
          ),
          onTap: host.navigator.openFinanceCommitments,
          theme: host.theme,
        ),
      );
    }

    if (flags.has(FeatureFlags.bankReconciliation)) {
      cards.add(
        ClubOperationCard(
          icon: Icons.account_balance_outlined,
          title: 'Banka Mutabakatı',
          detail: _asyncDetail(
            summaryAsync,
            (summary) =>
                '${summary.bankUnmatchedCount} eşleşmemiş banka hareketi',
          ),
          onTap: host.navigator.openBankReconciliation,
          theme: host.theme,
        ),
      );
    }

    if (flags.has(FeatureFlags.clubBudgeting)) {
      cards.add(
        ClubOperationCard(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Bütçe & Nakit Tahmini',
          detail: _asyncDetail(
            forecastAsync,
            (forecasts) {
              final f30 = forecasts.firstOrNull;
              if (f30 == null) return 'Projeksiyon verisi yok';
              return 'Onaylı: ${money(f30.projectedLow)} · Beklenen: ${money(f30.projectedHigh)}';
            },
          ),
          onTap: host.navigator.openClubBudget,
          theme: host.theme,
        ),
      );
    }

    if (flags.has(FeatureFlags.periodClosing)) {
      cards.add(
        ClubOperationCard(
          icon: Icons.lock_reset_outlined,
          title: 'Dönem Kapanışı & Ters Kayıt',
          detail: _asyncDetail(
            summaryAsync,
            (summary) => summary.closeBlockerCount > 0
                ? '${summary.closeBlockerCount} kapanış engeli var'
                : 'Kapanış kontrolüne hazır',
          ),
          onTap: host.navigator.openPeriodClosing,
          theme: host.theme,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Muhasebe Operasyonları',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        AccountantClubSelector(
          clubs: accountantClubs,
          selectedClub: selectedClub,
          theme: host.theme,
        ),
        const SizedBox(height: 8),
        Text(
          'Sporcu kimliği bu çalışma alanında gösterilmez; aidat hareketleri yalnız maskeli referans koduyla (#A3F91C) izlenir.',
          style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 2 : 1;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}

final class AccountantClubSelector extends ConsumerWidget {
  const AccountantClubSelector({
    required this.clubs,
    required this.selectedClub,
    required this.theme,
    super.key,
  });

  final List<ClubRef> clubs;
  final ClubRef selectedClub;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('accountant-club-selector'),
          isExpanded: true,
          value: selectedClub.id,
          dropdownColor: theme.surface,
          style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
          items: [
            for (final club in clubs)
              DropdownMenuItem<String>(
                value: club.id,
                child: Text(
                  club.city == null || club.city!.isEmpty
                      ? '${club.name} · Muhasebe Kapsamı'
                      : '${club.name} (${club.city}) · Muhasebe Kapsamı',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (nextClubId) async {
            if (nextClubId == null || nextClubId == selectedClub.id) return;
            await ref
                .read(proDirtyStateCoordinatorProvider)
                .runGuardedTransition(
                  confirmDiscard: () => host.chrome.confirm(
                    context,
                    title: 'Kaydedilmemiş veya bekleyen işlem var',
                    message:
                        'Kulüp kapsamı değiştirildiğinde açık taslaklar ve bekleyen işlemler temizlenir.',
                    confirmLabel: 'Kulübü değiştir',
                  ),
                  invalidate: () => invalidateProFeatureState(ref),
                  transition: () {
                    ref.read(selectedAccountantClubIdProvider.notifier).state =
                        nextClubId;
                    ref.read(selectedClubIdProvider.notifier).state =
                        nextClubId;
                  },
                );
          },
        ),
      ),
    );
  }
}

String _asyncDetail<T>(AsyncValue<T> value, String Function(T data) format) {
  return value.when(
    loading: () => 'Yükleniyor…',
    error: (error, _) => classifyOperationError(error).userMessage,
    data: format,
  );
}

final class AccountingPanelMessage extends StatelessWidget {
  const AccountingPanelMessage({
    required this.icon,
    required this.title,
    this.body,
    this.onRetry,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ProFeatureHostScope.of(context).theme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.inkMuted, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.inkMuted),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden yükle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
