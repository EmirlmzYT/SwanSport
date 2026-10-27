import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../club/club_operation_card.dart';
import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';

String federationScopeKey(FederationConsoleScope scope) =>
    '${scope.federationId}:${scope.sportCode}:${scope.cityCode ?? 'national'}';

String federationRoleLabel(String role) => switch (role) {
      'president' => 'Başkan',
      'board_member' => 'Yönetim Kurulu',
      'general_secretary' => 'Genel Sekreter',
      'provincial_rep' => 'İl Temsilcisi',
      'referee_committee' => 'MHK Üyesi',
      'disciplinary_board' => 'Disiplin Kurulu',
      'result_publisher' => 'Sonuç Tescil Görevlisi',
      _ => 'Federasyon Görevlisi',
    };

String federationScopeSummary(FederationConsoleScope scope) =>
    '${scope.name} · ${scope.sportCode}'
    '${scope.cityCode == null ? ' · Ulusal' : ' · İl ${scope.cityCode}'}'
    ' · ${federationRoleLabel(scope.role)}';

String federationTurkeyDateTime(DateTime? instant) {
  if (instant == null) return 'Tarih belirtilmedi';
  final local = instant.toUtc().add(const Duration(hours: 3));
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} · $hour:$minute';
}

List<FederationConsoleScope> resolveEffectiveFederationScopes(
  List<FederationConsoleScope> serverScopes, [
  SwanAccess? _,
]) =>
    List<FederationConsoleScope>.unmodifiable(serverScopes);

final class SharedFederationOperationsPanel extends ConsumerWidget {
  const SharedFederationOperationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final access = ref.watch(swanAccessProvider);
    if (!access.canOpenFederationOperations) {
      return const FederationPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Federasyon operasyon yetkisi gerekli',
        body:
            'Bu çalışma alanı yalnız aktif federasyon rolü veya resmî görevlendirmesi bulunan hesaplara açıktır.',
      );
    }

    final scopesAsync = ref.watch(federationConsoleScopesProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);
    if (scopesAsync.isLoading || flagsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (scopesAsync.hasError || flagsAsync.hasError) {
      final error = scopesAsync.error ?? flagsAsync.error!;
      return FederationPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
        onRetry: () {
          ref.invalidate(federationConsoleScopesProvider);
          ref.invalidate(featureFlagsProvider);
        },
      );
    }

    final scopes = resolveEffectiveFederationScopes(
      scopesAsync.valueOrNull ?? const [],
      access,
    );
    if (scopes.isEmpty) {
      return const FederationPanelMessage(
        icon: Icons.account_balance_outlined,
        title: 'Aktif federasyon veya branş kapsamı bulunamadı',
        body:
            'Hesabında bu dönem için geçerli bir federasyon veya il temsilciliği kapsamı görünmüyor.',
      );
    }

    final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
    final selectedScope = scopes
            .where((item) => federationScopeKey(item) == selectedKey)
            .firstOrNull ??
        scopes.first;
    final effectiveKey = federationScopeKey(selectedScope);
    if (selectedKey != effectiveKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedFederationScopeKeyProvider.notifier).state =
              effectiveKey;
        }
      });
    }

    final flags = flagsAsync.valueOrNull ?? const FeatureFlags.none();
    final matchQuery = FederationMatchQuery(
      federationId: selectedScope.federationId,
      sportCode: selectedScope.sportCode,
      cityCode: selectedScope.cityCode,
    );
    final matchesAsync =
        ref.watch(federationConsoleMatchesProvider(matchQuery));

    final cards = <Widget>[
      ClubOperationCard(
        icon: Icons.event_note_outlined,
        title: 'Resmî Müsabakalar & Takvim',
        detail: _asyncDetail(
          matchesAsync,
          (page) {
            final scoped = page.rows
                .where((m) => m.sportCode == selectedScope.sportCode)
                .toList(growable: false);
            final count =
                scoped.length == page.rows.length ? page.total : scoped.length;
            return '$count resmî müsabaka kaydı';
          },
        ),
        onTap: host.navigator.openFederationMatches,
        theme: host.theme,
      ),
    ];

    if (access.canViewRefereeAssignments) {
      cards.add(
        ClubOperationCard(
          icon: Icons.assignment_ind_outlined,
          title: 'MHK Hakem Atamaları',
          detail: _asyncDetail(
            matchesAsync,
            (page) {
              final pending = page.rows
                  .where(
                    (m) =>
                        m.sportCode == selectedScope.sportCode &&
                        (m.officials.isEmpty ||
                            m.officials.any((o) => o.status == 'assigned')),
                  )
                  .length;
              return '$pending müsabakada atama / onay bekliyor';
            },
          ),
          onTap: host.navigator.openRefereeAssignments,
          theme: host.theme,
        ),
      );
    }

    if (access.canViewProvincialLeagues &&
        flags.has(FeatureFlags.leagueStandings)) {
      final leaguesAsync = ref.watch(standingsLeaguesProvider);
      cards.add(
        ClubOperationCard(
          icon: Icons.leaderboard_outlined,
          title: 'Lig & Puan Durumu',
          detail: _asyncDetail(
            leaguesAsync,
            (leagues) {
              final count = leagues
                  .where((l) => l.sportCode == selectedScope.sportCode)
                  .length;
              return '$count yayımlanmış resmî lig';
            },
          ),
          onTap: host.navigator.openLeagueStandings,
          theme: host.theme,
        ),
      );
    }

    if (access.isDisciplinaryBoardMember) {
      final reportsAsync = ref.watch(federationDisciplinaryReportsProvider(0));
      cards.add(
        ClubOperationCard(
          icon: Icons.gavel_outlined,
          title: 'Disiplin Kurulu',
          detail: _asyncDetail(
            reportsAsync,
            (page) {
              final scoped = page.rows
                  .where((r) => r.sportCode == selectedScope.sportCode)
                  .toList(growable: false);
              final count = scoped.length == page.rows.length
                  ? page.total
                  : scoped.length;
              return '$count imzalı hakem raporu incelemede';
            },
          ),
          onTap: host.navigator.openDisciplinaryBoard,
          theme: host.theme,
        ),
      );
    }

    if (flags.has(FeatureFlags.federationBulletin)) {
      final bulletinFilter = (
        sportCode: selectedScope.sportCode,
        cityCode: selectedScope.cityCode,
        offset: 0,
        limit: 20,
      );
      final decisionsAsync = ref.watch(
        federationDisciplinaryBulletinProvider(bulletinFilter),
      );
      final noticesAsync = ref.watch(federationNoticesProvider(bulletinFilter));
      cards.add(
        ClubOperationCard(
          icon: Icons.campaign_outlined,
          title: 'Federasyon Bülten & Duyurular',
          detail: decisionsAsync.isLoading || noticesAsync.isLoading
              ? 'Yükleniyor…'
              : '${(decisionsAsync.valueOrNull ?? const []).length} karar · '
                  '${(noticesAsync.valueOrNull ?? const []).length} duyuru',
          onTap: host.navigator.openFederationBulletins,
          theme: host.theme,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Federasyon Operasyonları',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (scopes.length <= 1)
          Text(
            federationScopeSummary(selectedScope),
            style: TextStyle(color: host.theme.inkMuted),
          )
        else
          FederationScopeSelector(
            scopes: scopes,
            selectedScope: selectedScope,
            theme: host.theme,
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

final class FederationScopeSelector extends ConsumerWidget {
  const FederationScopeSelector({
    required this.scopes,
    required this.selectedScope,
    required this.theme,
    super.key,
  });

  final List<FederationConsoleScope> scopes;
  final FederationConsoleScope selectedScope;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final currentKey = federationScopeKey(selectedScope);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('federation-scope-selector'),
          isExpanded: true,
          value: currentKey,
          dropdownColor: theme.surface,
          style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
          items: [
            for (final scope in scopes)
              DropdownMenuItem<String>(
                value: federationScopeKey(scope),
                child: Text(
                  federationScopeSummary(scope),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (nextKey) async {
            if (nextKey == null || nextKey == currentKey) return;
            await ref
                .read(proDirtyStateCoordinatorProvider)
                .runGuardedTransition(
                  confirmDiscard: () => host.chrome.confirm(
                    context,
                    title: 'Kaydedilmemiş değişiklikler var',
                    message:
                        'Federasyon kapsamı değiştirildiğinde kaydedilmemiş işlemler bırakılır.',
                    confirmLabel: 'Kapsamı değiştir',
                  ),
                  invalidate: () => invalidateProFeatureState(ref),
                  transition: () {
                    ref
                        .read(selectedFederationScopeKeyProvider.notifier)
                        .state = nextKey;
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

final class FederationPanelMessage extends StatelessWidget {
  const FederationPanelMessage({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.inkMuted, size: 36),
            const SizedBox(height: 10),
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
