import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'accounting_operations_panel.dart';

final class SharedClubBudgetScreen extends ConsumerWidget {
  const SharedClubBudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Bütçe & Nakit Tahmini',
      body: const _ClubBudgetBody(),
    );
  }
}

final class _ClubBudgetBody extends ConsumerWidget {
  const _ClubBudgetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final access = ref.watch(swanAccessProvider);
    if (!access.isAccountant) {
      return const AccountingPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Muhasebe çalışma alanı yetkisi gerekli',
        body:
            'Bütçe ve tahmin ekranı yalnız kulüp muhasebecisi yetkisi olan hesaplara açıktır.',
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
        !flags.has(FeatureFlags.clubBudgeting)) {
      return const AccountingPanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Bütçe ve nakit tahmini kademeli yayında',
        body: 'Bütçe yönetimi modülü hesabın için henüz açılmadı.',
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
            'Aktif bir muhasebe kulüp kapsamı olmadan bütçe ve tahmin sorguları çalıştırılmaz.',
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

    final budgetLinesAsync = ref.watch(budgetLinesProvider);
    final forecastAsync = ref.watch(cashForecastProvider);

    if (budgetLinesAsync.isLoading || forecastAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (budgetLinesAsync.hasError || forecastAsync.hasError) {
      final error = budgetLinesAsync.error ?? forecastAsync.error!;
      return AccountingPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref
            ..invalidate(budgetLinesProvider)
            ..invalidate(cashForecastProvider);
        },
      );
    }

    final lines = budgetLinesAsync.valueOrNull ?? const <BudgetLine>[];
    final forecasts = forecastAsync.valueOrNull ?? const <CashForecast>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AccountantClubSelector(
          clubs: accountantClubs,
          selectedClub: selectedClub,
          theme: host.theme,
        ),
        const SizedBox(height: 16),
        Text(
          '30 / 60 / 90 Gün Nakit Tahminleri (Üç Ayrı Güven Kademesi)',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Belirsiz çıkışlar kesin veya beklenen nakit projeksiyonuna dahil edilmez.',
          style: TextStyle(color: host.theme.inkMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (forecasts.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Bu kulüp için nakit tahmini verisi bulunmuyor.',
              style: TextStyle(color: host.theme.inkMuted),
            ),
          )
        else
          for (final f in forecasts) ...[
            _ForecastCard(forecast: f, theme: host.theme),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        Text(
          'Bütçe ve Gerçekleşen Karşılaştırması (${lines.length})',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (lines.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: host.theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: host.theme.line),
            ),
            child: Text(
              'Tanımlı bütçe kalemi bulunmuyor.',
              style: TextStyle(color: host.theme.inkMuted),
            ),
          )
        else
          for (final line in lines) ...[
            _BudgetLineCard(line: line, theme: host.theme),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

final class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.forecast,
    required this.theme,
  });

  final CashForecast forecast;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: forecast.hasShortfall ? theme.danger : theme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${forecast.horizonDays} Günlük Nakit Projeksiyonu',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (forecast.hasShortfall)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.danger.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Nakit Açığı Riski',
                    style: TextStyle(
                      color: theme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Onaylı Projeksiyon (${forecast.horizonDays} Gün): ${money(forecast.projectedLow)}',
            style: TextStyle(
              color: theme.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Giriş: +${money(forecast.confirmedIn)} · Çıkış: -${money(forecast.confirmedOut)}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Beklenen Projeksiyon (${forecast.horizonDays} Gün): ${money(forecast.projectedHigh)}',
            style: TextStyle(
              color: theme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Beklenen Giriş: +${money(forecast.expectedIn)} · Beklenen Çıkış: -${money(forecast.expectedOut)}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Belirsiz Çıkış (Projeksiyona Katılmaz): ${money(forecast.uncertainOut)}',
            style: TextStyle(
              color: theme.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Bütçelenmiş ancak henüz taahhüt edilmemiş tutarlar kesin veya beklenen projeksiyona katılmaz.',
            style: TextStyle(color: theme.inkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

final class _BudgetLineCard extends StatelessWidget {
  const _BudgetLineCard({
    required this.line,
    required this.theme,
  });

  final BudgetLine line;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) {
    final riskColor = switch (line.risk) {
      'kritik' => theme.danger,
      'dikkat' => theme.warning,
      _ => theme.inkMuted,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: line.isOverrun ? theme.danger : theme.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  line.scopeLabel,
                  style: TextStyle(
                    color: theme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  line.risk.toUpperCase(),
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Kategori: ${line.category}',
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Planlanan: ${money(line.planned)}',
                style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
              ),
              Text(
                'Gerçekleşen: ${money(line.actual)}',
                style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
              ),
              Text(
                'Bağlanan: ${money(line.committed)}',
                style: TextStyle(color: theme.inkMuted),
              ),
              Text(
                'Kalan: ${money(line.remaining)}',
                style: TextStyle(
                  color: line.isOverrun ? theme.danger : theme.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (line.overrunPct != null && line.overrunPct! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Aşım Oranı: %${line.overrunPct!.toStringAsFixed(1)}',
              style: TextStyle(
                color: theme.danger,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
