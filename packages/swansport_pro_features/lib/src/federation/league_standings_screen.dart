import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'federation_operations_panel.dart';

/// Shared official league standings screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.canOpenFederationOperations`.
/// - Feature flag check for `FeatureFlags.leagueStandings`.
/// - Uses only official `standingsLeaguesProvider` and `leagueStandingsProvider`.
/// - Displays the organization's configured `winPoints`, `drawPoints`, `lossPoints`
///   without assuming hardcoded 3/1/0.
/// - Explicitly discloses that group, bonus, head-to-head tie-breaker, or knockout
///   bracket engines are not active.
final class SharedLeagueStandingsScreen extends ConsumerStatefulWidget {
  const SharedLeagueStandingsScreen({super.key});

  @override
  ConsumerState<SharedLeagueStandingsScreen> createState() =>
      _SharedLeagueStandingsScreenState();
}

final class _SharedLeagueStandingsScreenState
    extends ConsumerState<SharedLeagueStandingsScreen> {
  String? _selectedLeagueId;
  bool _includeLive = false;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.canOpenFederationOperations) {
      return host.chrome.buildPage(
        context,
        title: 'Lig & Puan Durumu',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Federasyon operasyon yetkisi gerekli',
          body:
              'Lig ve puan durumu operasyonları için aktif federasyon görevi gereklidir.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    final standingsEnabled =
        flagsAsync.valueOrNull?.has(FeatureFlags.leagueStandings) ?? true;
    if (!standingsEnabled) {
      return host.chrome.buildPage(
        context,
        title: 'Lig & Puan Durumu',
        body: const FederationPanelMessage(
          icon: Icons.toggle_off_outlined,
          title: 'Lig puan durumu modülü devre dışı',
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

    final leaguesAsync = ref.watch(standingsLeaguesProvider);
    return host.chrome.buildPage(
      context,
      title: 'Lig & Puan Durumu',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(standingsLeaguesProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: leaguesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => FederationPanelMessage(
          icon: Icons.error_outline_rounded,
          title: classifyOperationError(err).userMessage,
          onRetry: () => ref.invalidate(standingsLeaguesProvider),
        ),
        data: (leagues) {
          final scopedLeagues = selectedScope == null
              ? leagues
              : leagues
                  .where(
                    (l) =>
                        l.sportCode == selectedScope.sportCode &&
                        (selectedScope.cityCode == null ||
                            l.cityCode == null ||
                            l.cityCode == selectedScope.cityCode),
                  )
                  .toList(growable: false);

          if (scopedLeagues.isEmpty) {
            return const FederationPanelMessage(
              icon: Icons.leaderboard_outlined,
              title: 'Kapsamda resmî lig bulunamadı',
              body:
                  'Özel, amatör veya kupa müsabakalarından sahte puan tablosu üretilmez.',
            );
          }

          final activeLeague = scopedLeagues
                  .where((l) => l.id == _selectedLeagueId)
                  .firstOrNull ??
              scopedLeagues.first;
          final query = (orgId: activeLeague.id, includeLive: _includeLive);
          final rowsAsync = ref.watch(leagueStandingsProvider(query));

          return ListView(
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
              _buildLeagueHeaderCard(
                theme: theme,
                leagues: scopedLeagues,
                activeLeague: activeLeague,
              ),
              const SizedBox(height: 12),
              rowsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => FederationPanelMessage(
                  icon: Icons.error_outline_rounded,
                  title: classifyOperationError(err).userMessage,
                  onRetry: () => ref.invalidate(leagueStandingsProvider(query)),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const FederationPanelMessage(
                      icon: Icons.table_rows_outlined,
                      title: 'Henüz tescilli puan durumu satırı yok',
                      body:
                          'Bu lig için tamamlanmış resmî müsabaka sonucu bulunmuyor.',
                    );
                  }
                  return _buildStandingsTable(theme: theme, rows: rows);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeagueHeaderCard({
    required ProFeatureThemeData theme,
    required List<StandingsLeague> leagues,
    required StandingsLeague activeLeague,
  }) {
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
          if (leagues.length > 1) ...[
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Resmî Lig Seçimi'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('league-standings-selector'),
                  value: activeLeague.id,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    for (final league in leagues)
                      DropdownMenuItem(
                        value: league.id,
                        child: Text(
                          '${league.name} (${league.sportCode})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (nextId) {
                    if (nextId != null) {
                      setState(() => _selectedLeagueId = nextId);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
          ] else
            Text(
              '${activeLeague.name} · ${activeLeague.sportCode}',
              style: TextStyle(
                color: theme.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Puan Kuralı — Galibiyet: ${activeLeague.winPoints} · Beraberlik: ${activeLeague.drawPoints} · Mağlubiyet: ${activeLeague.lossPoints}',
            style: TextStyle(
              color: theme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Not: Yalnız resmî lig puan projeksiyonu kullanılır. Grup, bonus puan, ikili averaj veya eleme ağacı motoru bu görünümde uygulanmaz.',
            style: TextStyle(color: theme.inkMuted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: const Key('league-standings-live-toggle'),
                label: const Text('Canlı müsabakaları dahil et (Geçici)'),
                selected: _includeLive,
                onSelected: (selected) =>
                    setState(() => _includeLive = selected),
              ),
              if (_includeLive)
                Chip(
                  label: Text(
                    'Geçici Canlı Projeksiyon',
                    style: TextStyle(
                      color: theme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsTable({
    required ProFeatureThemeData theme,
    required List<LeagueStandingsRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${row.rank}.',
                          style: TextStyle(
                            color: theme.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          row.name,
                          style: TextStyle(
                            color: theme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (row.isProvisional) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(Geçici Canlı)',
                          style: TextStyle(
                            color: theme.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      Text(
                        'O:${row.played} G:${row.won} B:${row.drawn} M:${row.lost} Av:${row.goalDiff}',
                        style: TextStyle(color: theme.inkMuted, fontSize: 12),
                      ),
                      Text(
                        '${row.points} P',
                        style: TextStyle(
                          color: theme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (row != rows.last) Divider(color: theme.line, height: 1),
          ],
        ],
      ),
    );
  }
}
