import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';
import 'federation_operations_panel.dart';

/// Optional injection callback for referee assignment mutation in tests.
typedef AssignOfficialCallback = Future<void> Function({
  required String matchId,
  required String officialProfileId,
  required MatchOfficialDuty duty,
});

/// Optional injection callback for official match facility allocation in tests.
typedef AllocateOfficialFacilityCallback = Future<void> Function({
  required String matchId,
  required String facilityId,
  required DateTime endsAt,
});

/// Shared official referee assignment screen for SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.canViewRefereeAssignments`.
/// - Assignment mutations and private `declineReason` / `federationLockedReportProvider`
///   visibility restricted to `canAssign` (`access.canAssignOfficialsForFederation`
///   or active MHK/president role for the selected scope).
/// - Provincial representatives (`provincial_rep`) get read-only status visibility
///   without private decline reasons or referee pool / locked report queries.
/// - Facility conflict count `null` is rendered as `'Doğrulanamıyor'`, never `0`.
final class SharedRefereeAssignmentsScreen extends ConsumerStatefulWidget {
  const SharedRefereeAssignmentsScreen({
    this.onAssignOfficial,
    this.onAllocateFacility,
    super.key,
  });

  final AssignOfficialCallback? onAssignOfficial;
  final AllocateOfficialFacilityCallback? onAllocateFacility;

  @override
  ConsumerState<SharedRefereeAssignmentsScreen> createState() =>
      _SharedRefereeAssignmentsScreenState();
}

final class _SharedRefereeAssignmentsScreenState
    extends ConsumerState<SharedRefereeAssignmentsScreen> {
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

    if (!access.canViewRefereeAssignments) {
      return host.chrome.buildPage(
        context,
        title: 'MHK Hakem Atamaları',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Hakem atama yetkiniz bulunmuyor',
          body:
              'Bu ekran yalnız MHK, Federasyon Başkanı ve yetkili il temsilcilerine açıktır.',
        ),
      );
    }

    final scopesAsync = ref.watch(federationConsoleScopesProvider);
    if (scopesAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'MHK Hakem Atamaları',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (scopesAsync.hasError) {
      return host.chrome.buildPage(
        context,
        title: 'MHK Hakem Atamaları',
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
        title: 'MHK Hakem Atamaları',
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

    final canAssign = _canAssignForScope(access, selectedScope);
    final cities = ref.watch(citiesProvider).valueOrNull ?? const <CityRow>[];
    final lockedCities = scopes
        .where((e) => e.role == 'provincial_rep' && e.cityCode != null)
        .map((e) => e.cityCode!)
        .toSet();
    final allCities = access.isFederationPresident || canAssign;
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
      title: 'MHK Hakem Atamaları',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () =>
              ref.invalidate(federationConsoleMatchesProvider(query)),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (scopes.length > 1) ...[
            FederationScopeSelector(
              scopes: scopes,
              selectedScope: selectedScope,
              theme: theme,
            ),
            const SizedBox(height: 12),
          ],
          _buildFilterCard(
            context: context,
            theme: theme,
            scope: selectedScope,
            canAssign: canAssign,
            allCities: allCities,
            cityOptions: cityOptions.toList()..sort(),
            activeCity: activeCity,
          ),
          const SizedBox(height: 12),
          pageAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () =>
                  ref.invalidate(federationConsoleMatchesProvider(query)),
            ),
            data: (page) {
              if (page.rows.isEmpty) {
                return const FederationPanelMessage(
                  icon: Icons.event_busy_outlined,
                  title: 'Kapsama uygun müsabaka bulunamadı',
                  body:
                      'Arama veya filtre kriterlerini değiştirerek tekrar deneyebilirsiniz.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final match in page.rows) ...[
                    _RefereeAssignmentMatchCard(
                      match: match,
                      canAssign: canAssign,
                      canAllocateFacility: match.canAllocateFacility ||
                          widget.onAllocateFacility != null,
                      theme: theme,
                      onAssignOfficial: widget.onAssignOfficial,
                      onAllocateFacility: widget.onAllocateFacility,
                      onAssigned: () => ref.invalidate(
                        federationConsoleMatchesProvider(query),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard({
    required BuildContext context,
    required ProFeatureThemeData theme,
    required FederationConsoleScope scope,
    required bool canAssign,
    required bool allCities,
    required List<String> cityOptions,
    required String? activeCity,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${scope.name} · ${scope.sportCode}',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                label: Text(
                  canAssign
                      ? 'MHK / Atama Yetkisi'
                      : 'Salt Okunur (İl Temsilcisi)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            canAssign
                ? 'Planlanmış müsabakalara kabul edilmiş aktif branş hakemlerini atayabilir ve özel mazeret notlarını inceleyebilirsiniz.'
                : 'İl kapsamındaki müsabakaların hakem kabul/ret durumlarını salt okunur izleyebilirsiniz. Özel mazeret notları gizlidir.',
            style: TextStyle(color: theme.inkMuted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('referee-assignments-search-input'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Müsabaka, takım veya tesis ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Ara',
                onPressed: () {
                  setState(() {
                    _search = _searchController.text.trim();
                    _offset = 0;
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            onSubmitted: (value) {
              setState(() {
                _search = value.trim();
                _offset = 0;
              });
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (cityOptions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'İl kapsamı'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        key: const Key('referee-assignments-city-filter'),
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
                label: const Text('Yalnız bu hafta'),
                selected: _weekOnly,
                onSelected: (selected) {
                  setState(() {
                    _weekOnly = selected;
                    _offset = 0;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canAssignForScope(SwanAccess access, FederationConsoleScope scope) {
    if (access.isPlatformAdmin) return true;
    if (scope.federationId.isNotEmpty &&
        access.canAssignOfficialsForFederation(scope.federationId)) {
      return true;
    }
    return scope.role == 'president' ||
        scope.role == 'referee_committee' ||
        scope.role == 'central_referee_board';
  }
}

class _RefereeAssignmentMatchCard extends ConsumerWidget {
  const _RefereeAssignmentMatchCard({
    required this.match,
    required this.canAssign,
    required this.canAllocateFacility,
    required this.theme,
    required this.onAssigned,
    this.onAssignOfficial,
    this.onAllocateFacility,
  });

  final FederationConsoleMatch match;
  final bool canAssign;
  final bool canAllocateFacility;
  final ProFeatureThemeData theme;
  final VoidCallback onAssigned;
  final AssignOfficialCallback? onAssignOfficial;
  final AllocateOfficialFacilityCallback? onAllocateFacility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only query locked referee report when user has MHK / President assignment privilege.
    final lockedReportAsync = canAssign
        ? ref.watch(federationLockedReportProvider(match.id))
        : const AsyncData<LockedRefereeReport?>(null);

    final conflictCount = match.facilityConflictCount;
    final String facilityLabel;
    if (match.facilityName == null || match.facilityName!.trim().isEmpty) {
      facilityLabel = 'Tesis: Tahsis kaydı yok · Çakışma: Doğrulanamıyor';
    } else if (conflictCount == null) {
      facilityLabel = 'Tesis: ${match.facilityName} · Çakışma: Doğrulanamıyor';
    } else if (conflictCount > 0) {
      facilityLabel =
          'Tesis: ${match.facilityName} · $conflictCount çakışma tespit edildi';
    } else {
      facilityLabel = 'Tesis: ${match.facilityName} · Çakışma yok';
    }

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
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                match.program,
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(label: Text(_matchStatusLabel(match.status))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${match.homeName ?? '-'} vs ${match.awayName ?? '-'}',
            style: TextStyle(
              color: theme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            facilityLabel,
            style: TextStyle(color: theme.inkMuted, fontSize: 12),
          ),
          const Divider(height: 20),
          if (match.officials.isEmpty)
            Text(
              'Henüz hakem ataması yapılmamış.',
              style: TextStyle(color: theme.inkMuted, fontSize: 12),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final official in match.officials)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dutyLabel(official.duty)}: ${official.name ?? 'Hakem'} (${_officialStatusLabel(official.status)})',
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (canAssign &&
                            official.declineReason != null &&
                            official.declineReason!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Özel ret mazereti: ${official.declineReason}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          if (canAssign)
            lockedReportAsync.maybeWhen(
              data: (report) {
                if (report == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İmzalı Hakem Raporu (${report.homeScore ?? '-'}-${report.awayScore ?? '-'} · Kırmızı kart: ${report.redCardCount})',
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (report.notes.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            report.notes,
                            style:
                                TextStyle(color: theme.inkMuted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          if ((canAssign || canAllocateFacility) &&
              match.status == 'scheduled') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (canAllocateFacility)
                  OutlinedButton.icon(
                    key: Key('facility-allocate-btn-${match.id}'),
                    onPressed: () => _openAllocateFacilityDialog(context),
                    icon: const Icon(Icons.stadium_outlined, size: 18),
                    label: const Text('Tesis Tahsis Et'),
                  ),
                if (canAssign)
                  FilledButton.tonalIcon(
                    key: Key('referee-assign-btn-${match.id}'),
                    onPressed: () => _openAssignDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Hakem Ata / Güncelle'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAssignDialog(BuildContext context) async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (_) => SharedRefereeAssignDialog(
        match: match,
        onAssignOfficial: onAssignOfficial,
      ),
    );
    if (assigned == true) {
      onAssigned();
    }
  }

  Future<void> _openAllocateFacilityDialog(BuildContext context) async {
    final allocated = await showDialog<bool>(
      context: context,
      builder: (_) => SharedOfficialFacilityAllocationDialog(
        match: match,
        onAllocateFacility: onAllocateFacility,
      ),
    );
    if (allocated == true) {
      onAssigned();
    }
  }
}

/// Dialog for allocating a club facility and match end time (`endsAt`) for an
/// official scheduled match via `allocate_official_match_facility`.
final class SharedOfficialFacilityAllocationDialog
    extends ConsumerStatefulWidget {
  const SharedOfficialFacilityAllocationDialog({
    required this.match,
    this.onAllocateFacility,
    super.key,
  });

  final FederationConsoleMatch match;
  final AllocateOfficialFacilityCallback? onAllocateFacility;

  @override
  ConsumerState<SharedOfficialFacilityAllocationDialog> createState() =>
      _SharedOfficialFacilityAllocationDialogState();
}

final class _SharedOfficialFacilityAllocationDialogState
    extends ConsumerState<SharedOfficialFacilityAllocationDialog> {
  final TextEditingController _durationCtrl = TextEditingController(
    text: '120',
  );
  String? _selectedFacilityId;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facilitiesAsync = ref.watch(facilitiesProvider);
    final startsAt = widget.match.startsAt;

    return AlertDialog(
      title: Text('${widget.match.program} — Resmî Tesis Tahsisi'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.match.homeName ?? 'Ev Sahibi'} — ${widget.match.awayName ?? 'Deplasman'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Başlangıç: ${federationTurkeyDateTime(startsAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              facilitiesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text(
                  'Kulüp tesis havuzu yüklenemedi.',
                ),
                data: (facilities) {
                  if (facilities.isEmpty) {
                    return const Text(
                      'Kulübünüze kayıtlı tahsis edilebilir tesis bulunamadı.',
                    );
                  }
                  final effectiveId = facilities.any(
                    (f) => f.id == _selectedFacilityId,
                  )
                      ? _selectedFacilityId
                      : facilities.first.id;
                  if (_selectedFacilityId != effectiveId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _selectedFacilityId = effectiveId);
                      }
                    });
                  }
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tahsis edilecek tesis',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('facility-allocate-dropdown'),
                        value: effectiveId,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          for (final f in facilities)
                            DropdownMenuItem<String>(
                              value: f.id,
                              child: Text(
                                '${f.name}${f.kind == null ? '' : ' (${f.kind})'}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedFacilityId = value);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('facility-allocate-duration-input'),
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Müsabaka süresi (dakika, 15–1440)',
                  helperText:
                      'Bitiş zamanı başlangıçtan sonra ve en fazla 24 saat içinde olmalıdır.',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('facility-allocate-submit-btn'),
          onPressed: _submitting ? null : _submit,
          child: const Text('Tahsisi Kaydet'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final facilityId = _selectedFacilityId;
    if (facilityId == null || facilityId.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen tahsis edilecek bir tesis seçin.';
      });
      return;
    }
    final startsAt = widget.match.startsAt;
    if (startsAt == null) {
      setState(() {
        _errorMessage =
            'Müsabaka başlangıç saati belirlenmeden tesis tahsis edilemez.';
      });
      return;
    }
    final minutes = int.tryParse(_durationCtrl.text.trim());
    if (minutes == null || minutes <= 0 || minutes > 1440) {
      setState(() {
        _errorMessage =
            'Geçerli bir müsabaka süresi girin (1–1440 dakika arası).';
      });
      return;
    }
    final endsAt = startsAt.toUtc().add(Duration(minutes: minutes));
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final callback = widget.onAllocateFacility;
      if (callback != null) {
        await callback(
          matchId: widget.match.id,
          facilityId: facilityId,
          endsAt: endsAt,
        );
      } else {
        final service = ref.read(federationConsoleServiceProvider);
        if (service == null) {
          throw StateError('Federasyon servisi kullanılamıyor.');
        }
        await service.allocateOfficialMatchFacility(
          widget.match.id,
          facilityId,
          endsAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = classifyOperationError(error).userMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

/// Dialog for assigning an eligible active referee to a scheduled official match.
final class SharedRefereeAssignDialog extends ConsumerStatefulWidget {
  const SharedRefereeAssignDialog({
    required this.match,
    this.onAssignOfficial,
    super.key,
  });

  final FederationConsoleMatch match;
  final AssignOfficialCallback? onAssignOfficial;

  @override
  ConsumerState<SharedRefereeAssignDialog> createState() =>
      _SharedRefereeAssignDialogState();
}

final class _SharedRefereeAssignDialogState
    extends ConsumerState<SharedRefereeAssignDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  MatchOfficialDuty _duty = MatchOfficialDuty.headReferee;
  String? _selectedProfileId;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refereesAsync = ref.watch(
      federationAvailableRefereesProvider(widget.match.id),
    );
    final filter = _searchCtrl.text.trim().toLowerCase();

    return AlertDialog(
      title: Text('${widget.match.program} — Hakem Ata'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Atama görevi'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MatchOfficialDuty>(
                    key: const Key('referee-assign-duty-dropdown'),
                    value: _duty,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: MatchOfficialDuty.headReferee,
                        child: Text('Başhakem'),
                      ),
                      DropdownMenuItem(
                        value: MatchOfficialDuty.assistantReferee1,
                        child: Text('1. Yardımcı Hakem'),
                      ),
                      DropdownMenuItem(
                        value: MatchOfficialDuty.assistantReferee2,
                        child: Text('2. Yardımcı Hakem'),
                      ),
                      DropdownMenuItem(
                        value: MatchOfficialDuty.fourthReferee,
                        child: Text('4. Hakem'),
                      ),
                      DropdownMenuItem(
                        value: MatchOfficialDuty.tableOfficial,
                        child: Text('Masa Görevlisi'),
                      ),
                      DropdownMenuItem(
                        value: MatchOfficialDuty.observer,
                        child: Text('Gözlemci'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _duty = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Uygun hakem ara',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              refereesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text(
                  'Uygun hakem havuzu şu anda yüklenemedi.',
                ),
                data: (referees) {
                  final filtered = filter.isEmpty
                      ? referees
                      : referees
                          .where(
                            (r) =>
                                r.name.toLowerCase().contains(filter) ||
                                r.cityCode.toLowerCase().contains(filter),
                          )
                          .toList(growable: false);
                  if (filtered.isEmpty) {
                    return const Text(
                      'Bu branşta kabul edilmiş aktif hakem bulunamadı.',
                    );
                  }
                  return Column(
                    children: [
                      for (final referee in filtered)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          selected: _selectedProfileId == referee.profileId,
                          leading: Icon(
                            _selectedProfileId == referee.profileId
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                          ),
                          onTap: () => setState(
                            () => _selectedProfileId = referee.profileId,
                          ),
                          title: Text(referee.name),
                          subtitle: Text(
                            '${referee.badgeTier} · İl ${referee.cityCode}',
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('referee-assign-submit-btn'),
          onPressed: _submitting || _selectedProfileId == null ? null : _submit,
          child: const Text('Atamayı Kaydet'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final profileId = _selectedProfileId;
    if (profileId == null) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final callback = widget.onAssignOfficial;
      if (callback != null) {
        await callback(
          matchId: widget.match.id,
          officialProfileId: profileId,
          duty: _duty,
        );
      } else {
        final service = ref.read(federationConsoleServiceProvider);
        if (service == null) {
          throw StateError('Federasyon servisi kullanılamıyor.');
        }
        await service.assignMatchOfficial(
          widget.match.id,
          profileId,
          _duty,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = classifyOperationError(error).userMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

String _matchStatusLabel(String status) {
  switch (status) {
    case 'scheduled':
      return 'Planlandı';
    case 'live':
      return 'Canlı';
    case 'played':
    case 'completed':
      return 'Tamamlandı';
    case 'postponed':
      return 'Ertelendi';
    case 'cancelled':
      return 'İptal';
    default:
      return status;
  }
}

String _dutyLabel(String duty) {
  switch (duty) {
    case 'head_referee':
    case 'chief_referee':
      return 'Başhakem';
    case 'assistant_referee_1':
      return '1. Yardımcı Hakem';
    case 'assistant_referee_2':
      return '2. Yardımcı Hakem';
    case 'fourth_referee':
    case 'fourth_official':
      return '4. Hakem';
    case 'table_official':
      return 'Masa Görevlisi';
    case 'observer':
      return 'Gözlemci';
    default:
      return duty;
  }
}

String _officialStatusLabel(String status) {
  switch (status) {
    case 'accepted':
      return 'Kabul edildi';
    case 'declined':
      return 'Reddedildi';
    case 'assigned':
    case 'pending':
      return 'Yanıt bekleniyor';
    default:
      return status;
  }
}
