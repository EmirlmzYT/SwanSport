import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'federation_operations_panel.dart';
import 'referee_assignments_screen.dart';

final class SharedFederationMatchesScreen extends ConsumerStatefulWidget {
  const SharedFederationMatchesScreen({
    this.onAllocateFacility,
    super.key,
  });

  final AllocateOfficialFacilityCallback? onAllocateFacility;

  @override
  ConsumerState<SharedFederationMatchesScreen> createState() =>
      _SharedFederationMatchesScreenState();
}

final class _SharedFederationMatchesScreenState
    extends ConsumerState<SharedFederationMatchesScreen> {
  static const int _pageSize = 50;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _city;
  bool _weekOnly = false;
  int _offset = 0;
  String? _lastScopeKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.canOpenFederationOperations) {
      return host.chrome.buildPage(
        context,
        title: 'Resmî Müsabakalar & Takvim',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Federasyon operasyon yetkisi gerekli',
          body: 'Bu modül için aktif federasyon görevi gereklidir.',
        ),
      );
    }

    final scopesAsync = ref.watch(federationConsoleScopesProvider);
    if (scopesAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Resmî Müsabakalar & Takvim',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (scopesAsync.hasError) {
      return host.chrome.buildPage(
        context,
        title: 'Resmî Müsabakalar & Takvim',
        body: FederationPanelMessage(
          icon: Icons.error_outline_rounded,
          title: classifyOperationError(scopesAsync.error!).userMessage,
          onRetry: () => ref.invalidate(federationConsoleScopesProvider),
        ),
      );
    }

    final scopes = resolveEffectiveFederationScopes(
      scopesAsync.valueOrNull ?? const [],
      access,
    );
    if (scopes.isEmpty) {
      return host.chrome.buildPage(
        context,
        title: 'Resmî Müsabakalar & Takvim',
        body: const FederationPanelMessage(
          icon: Icons.account_balance_outlined,
          title: 'Aktif federasyon veya branş kapsamı bulunamadı',
        ),
      );
    }

    final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
    final selectedScope = scopes
            .where((item) => federationScopeKey(item) == selectedKey)
            .firstOrNull ??
        scopes.first;
    final effectiveScopeKey = federationScopeKey(selectedScope);
    if (_lastScopeKey != effectiveScopeKey) {
      _lastScopeKey = effectiveScopeKey;
      _offset = 0;
      _city = selectedScope.cityCode;
    }

    final cities = ref.watch(citiesProvider).valueOrNull ?? const <CityRow>[];
    final lockedCities = scopes
        .where((e) => e.role == 'provincial_rep' && e.cityCode != null)
        .map((e) => e.cityCode!)
        .toSet();
    final allCities = access.isFederationPresident;
    final cityOptions = allCities
        ? <String>{
            ...cities.map((c) => c.code),
            if (selectedScope.cityCode != null) selectedScope.cityCode!,
          }
        : lockedCities;
    final activeCity = _city != null && cityOptions.contains(_city)
        ? _city
        : (!allCities && cityOptions.length == 1 ? cityOptions.single : null);

    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final monday = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1, hours: 3));
    final query = FederationMatchQuery(
      federationId: selectedScope.federationId,
      sportCode: selectedScope.sportCode,
      cityCode: activeCity,
      offset: _offset,
      search: _search,
      from: _weekOnly ? monday : null,
      until: _weekOnly ? monday.add(const Duration(days: 7)) : null,
    );
    final pageAsync = ref.watch(federationConsoleMatchesProvider(query));
    return host.chrome.buildPage(
      context,
      title: 'Resmî Müsabakalar & Takvim',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(federationConsoleScopesProvider);
            ref.invalidate(federationConsoleMatchesProvider(query));
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scopes.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FederationScopeSelector(
                      scopes: scopes,
                      selectedScope: selectedScope,
                      theme: theme,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      federationScopeSummary(selectedScope),
                      style: TextStyle(color: theme.inkMuted),
                    ),
                  ),
                TextField(
                  key: const Key('federation-matches-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: theme.ink),
                  decoration: InputDecoration(
                    labelText: 'Lig veya katılımcı ara',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _offset = 0;
                              });
                            },
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _search = value.trim();
                      _offset = 0;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (cityOptions.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'İl kapsamı',
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              key: const Key('federation-matches-city-filter'),
                              value: activeCity,
                              isExpanded: true,
                              isDense: true,
                              items: [
                                if (allCities || cityOptions.length > 1)
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      'Yetkili olduğum tüm iller',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                for (final code in cityOptions)
                                  DropdownMenuItem<String?>(
                                    value: code,
                                    child: Text('İl $code'),
                                  ),
                              ],
                              onChanged: !allCities && cityOptions.length == 1
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _city = value;
                                        _offset = 0;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ),
                    FilterChip(
                      key: const Key('federation-matches-week-switch'),
                      label: const Text('Yalnız bu hafta (TSİ)'),
                      selected: _weekOnly,
                      onSelected: (value) {
                        setState(() {
                          _weekOnly = value;
                          _offset = 0;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tesis çakışması kulübün yetkili resmî tahsis kaydından hesaplanır. '
                  'Kesin tahsis veya süre yoksa “Doğrulanamıyor” olarak kalır.',
                  style: TextStyle(color: theme.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => FederationPanelMessage(
                icon: Icons.error_outline_rounded,
                title: classifyOperationError(error).userMessage,
                onRetry: () =>
                    ref.invalidate(federationConsoleMatchesProvider(query)),
              ),
              data: (page) {
                if (page.rows.isEmpty) {
                  return const FederationPanelMessage(
                    icon: Icons.event_busy_outlined,
                    title: 'Bu kapsamda resmî müsabaka yok.',
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: page.rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final match = page.rows[index];
                          return _FederationMatchCard(
                            match: match,
                            theme: theme,
                            canAllocateFacility: match.canAllocateFacility ||
                                widget.onAllocateFacility != null,
                            onAllocateFacility: widget.onAllocateFacility,
                            onAllocated: () => ref.invalidate(
                              federationConsoleMatchesProvider(query),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              '${_offset + 1}–${_offset + page.rows.length} / ${page.total}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.inkMuted),
                            ),
                          ),
                          IconButton(
                            key: const Key('federation-matches-prev-page'),
                            tooltip: 'Önceki sayfa',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _offset == 0
                                ? null
                                : () => setState(() {
                                      _offset = (_offset - _pageSize)
                                          .clamp(0, page.total);
                                    }),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          IconButton(
                            key: const Key('federation-matches-next-page'),
                            tooltip: 'Sonraki sayfa',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: _offset + _pageSize >= page.total
                                ? null
                                : () => setState(() => _offset += _pageSize),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _FederationMatchCard extends StatelessWidget {
  const _FederationMatchCard({
    required this.match,
    required this.theme,
    required this.canAllocateFacility,
    required this.onAllocated,
    this.onAllocateFacility,
  });

  final FederationConsoleMatch match;
  final ProFeatureThemeData theme;
  final bool canAllocateFacility;
  final VoidCallback onAllocated;
  final AllocateOfficialFacilityCallback? onAllocateFacility;

  @override
  Widget build(BuildContext context) {
    final conflictCount = match.facilityConflictCount;
    final conflictLabel = conflictCount == null
        ? 'Doğrulanamıyor'
        : conflictCount == 0
            ? 'Çakışma yok'
            : '$conflictCount çakışma';
    final conflictColor = conflictCount == null
        ? theme.inkMuted
        : conflictCount == 0
            ? theme.success
            : theme.danger;

    final statusLabel = switch (match.status) {
      'played' => 'Tamamlandı',
      'cancelled' => 'İptal',
      'in_progress' => 'Canlı',
      _ => 'Planlandı',
    };

    final acceptedCount =
        match.officials.where((o) => o.status == 'accepted').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                '${match.program} · ${match.sportCode}'
                '${match.cityCode == null ? ' · Ulusal' : ' · İl ${match.cityCode}'}',
                style: TextStyle(color: theme.inkMuted, fontSize: 13),
              ),
              _Badge(label: statusLabel, color: theme.accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${match.homeName ?? 'Katılımcı'} — ${match.awayName ?? 'Bireysel'}',
            style: TextStyle(
              color: theme.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${federationTurkeyDateTime(match.startsAt)} · '
            '${match.facilityName ?? match.location ?? 'Saha belirlenmedi'}',
            style: TextStyle(color: theme.inkMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Badge(label: conflictLabel, color: conflictColor),
              _Badge(
                label:
                    '${match.officials.length} görevli · $acceptedCount kabul',
                color: theme.inkMuted,
              ),
              if (canAllocateFacility && match.status == 'scheduled')
                OutlinedButton.icon(
                  key: Key('federation-match-allocate-facility-${match.id}'),
                  onPressed: () async {
                    final allocated = await showDialog<bool>(
                      context: context,
                      builder: (_) => SharedOfficialFacilityAllocationDialog(
                        match: match,
                        onAllocateFacility: onAllocateFacility,
                      ),
                    );
                    if (allocated == true) {
                      onAllocated();
                    }
                  },
                  icon: const Icon(Icons.stadium_outlined, size: 16),
                  label: const Text('Tesis Tahsis Et'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
