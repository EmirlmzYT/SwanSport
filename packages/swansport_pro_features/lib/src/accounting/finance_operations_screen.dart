import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'accounting_operations_panel.dart';

final class SharedFinanceOperationsScreen extends ConsumerWidget {
  const SharedFinanceOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Mali Operasyon Özeti',
      body: const _FinanceOperationsBody(),
    );
  }
}

final class _FinanceOperationsBody extends ConsumerWidget {
  const _FinanceOperationsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final access = ref.watch(swanAccessProvider);
    if (!access.isAccountant) {
      return const AccountingPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Muhasebe çalışma alanı yetkisi gerekli',
        body:
            'Bu ekran yalnız yetkili kulüp muhasebecisi hesapları tarafından görüntülenebilir.',
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
            'Aktif bir muhasebe kulüp kapsamı olmadan hiçbir mali sorgu çalıştırılmaz.',
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
    final receivablesAsync = ref.watch(receivablesProvider);

    if (summaryAsync.isLoading ||
        balancesAsync.isLoading ||
        forecastAsync.isLoading ||
        receivablesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summaryAsync.hasError ||
        balancesAsync.hasError ||
        forecastAsync.hasError ||
        receivablesAsync.hasError) {
      final error = summaryAsync.error ??
          balancesAsync.error ??
          forecastAsync.error ??
          receivablesAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref
            ..invalidate(financeOperationsSummaryProvider)
            ..invalidate(accountBalancesProvider)
            ..invalidate(cashForecastProvider)
            ..invalidate(receivablesProvider);
        },
      );
    }

    final summary =
        summaryAsync.valueOrNull ?? const FinanceOperationsSummary.empty();
    final balances = balancesAsync.valueOrNull ?? const <AccountBalance>[];
    final forecasts = forecastAsync.valueOrNull ?? const <CashForecast>[];
    final receivables = receivablesAsync.valueOrNull ?? const <Receivable>[];

    final definiteBalance = balances.fold<num>(0, (sum, b) => sum + b.balance);
    final forecast30 = forecasts.firstOrNull;
    final confirmedProjected = forecast30?.projectedLow ?? definiteBalance;
    final expectedProjected = forecast30?.projectedHigh ?? definiteBalance;
    final uncertainTotal =
        forecast30?.uncertainOut ?? summary.draftExpenseTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccountantClubSelector(
          clubs: accountantClubs,
          selectedClub: selectedClub,
          theme: host.theme,
        ),
        const SizedBox(height: 12),
        _CashTierCard(
          cardKey: const Key('finance-confirmed-cash-card'),
          title: 'Onaylı / Kesin Nakit',
          primaryLabel: 'Kesin Kasa/Banka: ${money(definiteBalance)}',
          secondaryLabel:
              '30 Gün Onaylı Projeksiyon: ${money(confirmedProjected)}'
              '${forecast30 == null ? '' : ' (Giriş: ${money(forecast30.confirmedIn)} · Çıkış: ${money(forecast30.confirmedOut)})'}',
          accent: host.theme.success,
          theme: host.theme,
        ),
        const SizedBox(height: 10),
        _CashTierCard(
          cardKey: const Key('finance-expected-cash-card'),
          title: 'Beklenen Nakit Projeksiyonu',
          primaryLabel:
              '30 Gün Beklenen Projeksiyon: ${money(expectedProjected)}',
          secondaryLabel: forecast30 == null
              ? 'Tahakkuk ve vadesi gelen taahhüt projeksiyonu yok.'
              : 'Beklenen Giriş: ${money(forecast30.expectedIn)} · Beklenen Çıkış: ${money(forecast30.expectedOut)}',
          accent: host.theme.accent,
          theme: host.theme,
        ),
        const SizedBox(height: 10),
        _CashTierCard(
          cardKey: const Key('finance-uncertain-cash-card'),
          title: 'Belirsiz Tutarlar (Kesin Bakiyeye Eklenmez)',
          primaryLabel: 'Belirsiz Çıkış / Taslak: ${money(uncertainTotal)}',
          secondaryLabel:
              'Bütçelenmiş ancak taahhüt edilmemiş veya taslak giderler kesin bakiyeye ve onaylı projeksiyona katılmaz.',
          accent: host.theme.warning,
          theme: host.theme,
        ),
        const SizedBox(height: 16),
        Text(
          'Bekleyen Mali İş Kuyruğu',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (!summary.hasWork)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Bu kulüp kapsamında bekleyen kritik mali işlem yok.',
              style: TextStyle(color: host.theme.inkMuted),
            ),
          )
        else
          for (final item in summary.items) ...[
            _WorkItemTile(
              item: item,
              theme: host.theme,
              onTap: () => _openWorkItemDestination(host.navigator, item.code),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 16),
        Text(
          'Maskeli Aidat Alacak Özeti (Kişi Kimliği İçermez)',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Muhasebeci gizliliği gereği sporcu adı veya kimliği okunmaz; yalnız sabit maskeli referans gösterilir.',
          style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (receivables.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Gecikmiş veya açık aidat alacağı bulunmuyor.',
              style: TextStyle(color: host.theme.inkMuted),
            ),
          )
        else
          for (final rec in receivables) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: host.theme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: host.theme.line),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Referans: ${rec.athleteCode}',
                    style: TextStyle(
                      color: host.theme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${rec.unpaidCount} açık tahakkuk · ${money(rec.total)}'
                    '${rec.oldest == null ? '' : ' · En eski: ${accountingTurkeyDate(rec.oldest)}'}',
                    style: TextStyle(color: host.theme.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  static void _openWorkItemDestination(
    ProFeatureNavigator navigator,
    String code,
  ) {
    switch (code) {
      case 'close_blocker':
        navigator.openPeriodClosing();
      case 'commitment_due':
      case 'pending_approval':
        navigator.openFinanceCommitments();
      case 'bank_unmatched':
        navigator.openBankReconciliation();
      case 'draft_expense':
      case 'unlinked_income':
      case 'unlinked_expense':
      case 'missing_receipt':
      case 'negative_account':
      case 'overdue_invoice':
      case 'pending_payment':
      default:
        navigator.openFinanceLedger();
    }
  }
}

final class _CashTierCard extends StatelessWidget {
  const _CashTierCard({
    required this.cardKey,
    required this.title,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.accent,
    required this.theme,
  });

  final Key cardKey;
  final String title;
  final String primaryLabel;
  final String secondaryLabel;
  final Color accent;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            primaryLabel,
            style: TextStyle(
              color: theme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondaryLabel,
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final class _WorkItemTile extends StatelessWidget {
  const _WorkItemTile({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final FinanceWorkItem item;
  final ProFeatureThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (item.risk) {
      FinanceRisk.critical => theme.danger,
      FinanceRisk.attention => theme.warning,
      FinanceRisk.info => theme.accent,
    };
    return Material(
      color: theme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.circle, size: 10, color: riskColor),
                    Text(
                      '${item.title} (${item.count})',
                      style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.hasTotal)
                      Text(
                        money(item.total),
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.why,
                  style: TextStyle(color: theme.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
