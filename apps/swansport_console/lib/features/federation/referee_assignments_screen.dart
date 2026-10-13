import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';
import '../../app/widgets/console_table.dart';
import '../../app/widgets/status_pill.dart';

String federationDate(DateTime? d) {
  if (d == null) return 'Kayıt yok';
  final local = d.toUtc().add(const Duration(hours: 3));
  return '${fmtDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
String officialDuty(String d) => switch (d) {
  'head_referee' => 'Başhakem', 'assistant_referee_1' => 'Yardımcı 1', 'assistant_referee_2' => 'Yardımcı 2',
  'fourth_referee' => 'Dördüncü Hakem', 'table_official' => 'Masa Hakemi', _ => 'Gözlemci'};
Widget officialPill(ConsoleMatchOfficial o) {
  final pill = StatusPill(label: '${officialDuty(o.duty)} · ${o.name ?? 'Hakem'} · ${switch(o.status) {
    'accepted' => 'Kabul', 'declined' => 'Ret', 'assigned' => 'Yanıt bekliyor', _ => 'Değiştirildi'}}',
    tone: switch(o.status) {'accepted' => PillTone.good, 'declined' => PillTone.bad, 'assigned' => PillTone.warning, _ => PillTone.muted});
  return o.declineReason == null ? pill : Tooltip(message: o.declineReason!, child: pill);
}

class RefereeAssignmentsScreen extends StatelessWidget {
  const RefereeAssignmentsScreen({super.key});
  @override
  Widget build(BuildContext context) => const FederationFixtureBoard(assignments: true);
}

class FederationFixtureBoard extends ConsumerStatefulWidget {
  const FederationFixtureBoard({required this.assignments, super.key});
  final bool assignments;
  @override
  ConsumerState<FederationFixtureBoard> createState() => _FederationFixtureBoardState();
}
class _FederationFixtureBoardState extends ConsumerState<FederationFixtureBoard> {
  ConsoleTableQuery _query = const ConsoleTableQuery();
  String? _city;
  bool _weekOnly = false;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < ConsoleDensity.minSupportedWidth) return const TooNarrowNotice();
    final access = ref.watch(consoleAccessProvider);
    if (!(widget.assignments ? access.canViewRefereeAssignments : access.canViewProvincialLeagues)) {
      return const Center(child: Text('Bu modül için aktif federasyon görevi gerekli.'));
    }
    final scopes = ref.watch(federationConsoleScopesProvider);
    if (scopes.asData == null) return Center(child: scopes.hasError ? TextButton(
      onPressed: () => ref.invalidate(federationConsoleScopesProvider), child: const Text('Yetki kapsamı alınamadı. Tekrar dene')) : const CircularProgressIndicator());
    final s = scopes.asData!.value;
    final cities = ref.watch(citiesProvider).valueOrNull ?? const <CityRow>[];
    final lockedCities = s.where((e) => e.role == 'provincial_rep').map((e) => e.cityCode!).toSet();
    final allCities = access.isFederationPresident || (widget.assignments && access.isRefereeCommitteeMember);
    final options = allCities ? cities.map((e) => e.code).toSet() : lockedCities;
    final city = _city != null && options.contains(_city) ? _city : (!allCities && options.length == 1 ? options.single : null);
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final monday = DateTime.utc(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1, hours: 3));
    final q = FederationMatchQuery(cityCode: city, offset: _query.offset, search: _query.search,
      from: _weekOnly ? monday : null, until: _weekOnly ? monday.add(const Duration(days: 7)) : null);
    final page = ref.watch(federationConsoleMatchesProvider(q));
    return Padding(padding: const EdgeInsets.all(ConsoleDensity.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(widget.assignments ? 'MHK Hakem Atama Matrisi' : 'İl Lig & Müsabaka Yönetimi',
        style: Theme.of(context).textTheme.headlineSmall)),
        IconButton(tooltip: 'Yenile', onPressed: () {ref.invalidate(federationConsoleScopesProvider);ref.invalidate(federationConsoleMatchesProvider);}, icon: const Icon(Icons.refresh))]),
      Text(s.map((e) => '${e.name} · ${e.sportCode}${e.cityCode == null ? '' : ' · İl ${e.cityCode}'}').toSet().join(' / ')),
      const SizedBox(height: ConsoleDensity.md),
      Row(children: [SizedBox(width: ConsoleDensity.sidebarWidth, child: DropdownButtonFormField<String>(value: city,
        decoration: const InputDecoration(labelText: 'İl kapsamı'),
        items: [if (allCities || options.length > 1) const DropdownMenuItem<String>(value: null, child: Text('Yetkili olduğum tüm iller')),
          for (final c in options) DropdownMenuItem(value: c, child: Text('İl $c'))],
        onChanged: !allCities && options.length == 1 ? null : (v) => setState(() {_city = v;_query = const ConsoleTableQuery();}))),
        const SizedBox(width: ConsoleDensity.md),
        Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Lig veya katılımcı ara', prefixIcon: Icon(Icons.search)),
          onSubmitted: (v) => setState(() => _query = ConsoleTableQuery(search: v))))]),
      const SizedBox(height: ConsoleDensity.md),
      Row(children: [Switch(value: _weekOnly, onChanged: (v) => setState(() {_weekOnly = v;_query = ConsoleTableQuery(search: _query.search);})),
        const Text('Yalnız bu hafta (Türkiye saati)')]),
      if (!widget.assignments) const Text('Tesis çakışması kulübün yetkili resmi tahsis kaydından hesaplanır. Bağlantı/süre eksikse “Doğrulanamıyor”; serbest saha metni eşleştirilmez.'),
      Expanded(child: ConsoleTable<FederationConsoleMatch>(query: _query,
        onQueryChanged: (v) => setState(() => _query = v), totalCount: page.asData?.value.total ?? 0,
        rows: page.asData?.value.rows ?? const [], rowId: (m) => m.id, loading: page.isLoading, error: page.error,
        emptyMessage: 'Bu kapsamda resmi müsabaka yok.', columns: [
          ConsoleColumn(label: 'Tarih / Lig', cell: (m) => Text('${federationDate(m.startsAt)}\n${m.program}', maxLines: 2, overflow: TextOverflow.ellipsis)),
          ConsoleColumn(label: 'Branş / İl', cell: (m) => Text('${m.sportCode} · ${m.cityCode ?? 'Ulusal'}')),
          ConsoleColumn(label: 'Müsabaka / Saha', flex: 2, cell: (m) => Text('${m.homeName ?? 'Katılımcı'} — ${m.awayName ?? 'Bireysel'}\n${m.facilityName ?? m.location ?? 'Saha belirlenmedi'}', maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (!widget.assignments) ConsoleColumn(label: 'Tesis uygunluğu', cell: (m) => StatusPill(
            label: m.facilityConflictCount == null ? 'Doğrulanamıyor' : m.facilityConflictCount == 0 ? 'Çakışma yok' : '${m.facilityConflictCount} çakışma',
            tone: m.facilityConflictCount == null ? PillTone.muted : m.facilityConflictCount == 0 ? PillTone.good : PillTone.bad)),
          ConsoleColumn(label: widget.assignments ? 'Görevliler (ayrıntıya tıkla)' : 'Durum', cell: (m) => widget.assignments
            ? Text('${m.officials.length} görevli · ${m.officials.where((e) => e.status == 'accepted').length} kabul')
            : StatusPill(label: switch(m.status) {'played' => 'Tamamlandı', 'cancelled' => 'İptal', 'in_progress' => 'Canlı', _ => 'Planlandı'}, tone: m.status == 'played' ? PillTone.good : PillTone.info)),
        ], onRowTap: widget.assignments ? (m) => showDialog<void>(context: context, builder: (_) => RefereeAssignDialog(
          key: ValueKey('${ref.read(authSessionProvider).valueOrNull?.user.id}:${m.id}'), match: m,
          canAssign: s.any((e) => e.sportCode == m.sportCode && access.canAssignOfficialsForFederation(e.federationId)))) : null)),
    ]));
  }
}

class RefereeAssignDialog extends ConsumerStatefulWidget {
  const RefereeAssignDialog({required this.match, required this.canAssign, super.key});
  final FederationConsoleMatch match;
  final bool canAssign;
  @override
  ConsumerState<RefereeAssignDialog> createState() => _RefereeAssignDialogState();
}
class _RefereeAssignDialogState extends ConsumerState<RefereeAssignDialog> {
  String? _profile, _city;
  MatchOfficialDuty _duty = MatchOfficialDuty.headReferee;
  bool _busy = false;
  String? _error, _actor;
  @override
  void initState() {super.initState();_actor = ref.read(authSessionProvider).valueOrNull?.user.id;}
  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(authSessionProvider).valueOrNull?.user.id;
    final access = ref.watch(consoleAccessProvider);
    if (actor != _actor || !access.canViewRefereeAssignments) return const AlertDialog(content: Text('Oturum/yetki değişti. Bu pencereyi kapatın.'));
    final scopes = ref.watch(federationConsoleScopesProvider).asData?.value;
    final canAssign = widget.canAssign && scopes != null && scopes.any((s) => s.sportCode == widget.match.sportCode && access.canAssignOfficialsForFederation(s.federationId));
    final data = canAssign ? ref.watch(federationAvailableRefereesProvider(widget.match.id)) : const AsyncData<List<AvailableReferee>>([]);
    final rows = data.asData?.value ?? const <AvailableReferee>[];
    final candidates = rows.where((r) => _city == null || r.cityCode == _city).toList();
    return PopScope(canPop: !_busy, child: AlertDialog(title: Text('${widget.match.homeName ?? 'Maç'} · Hakemler'),
      content: SizedBox(width: ConsoleDensity.loginCardWidth, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final o in widget.match.officials) Padding(padding: const EdgeInsets.only(bottom: ConsoleDensity.sm), child: officialPill(
          canAssign ? o : ConsoleMatchOfficial(id: o.id, duty: o.duty, status: o.status, name: o.name))),
        if (!canAssign) const Text('Salt okunur il temsilciliği görünümü. Özel mazeret notları paylaşılmaz.'),
        if (canAssign) ...[
          if (widget.match.status == 'played') ref.watch(federationLockedReportProvider(widget.match.id)).when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => TextButton(onPressed: () => ref.invalidate(federationLockedReportProvider(widget.match.id)), child: const Text('Rapor alınamadı. Tekrar dene')),
            data: (r) => r == null ? const Text('Bu maç için erişilebilir hakem raporu yok.') : ExpansionTile(
              title: const Text('İmzalı Hakem Raporu'), subtitle: Text('${r.homeScore ?? '—'} — ${r.awayScore ?? '—'} · ${r.redCardCount} kırmızı kart'),
              children: [Text(r.notes), Text('Tescil: ${r.revisionId}')],)),
          if (data.isLoading) const LinearProgressIndicator(),
          if (data.hasError) TextButton(onPressed: () => ref.invalidate(federationAvailableRefereesProvider(widget.match.id)), child: const Text('Hakemler alınamadı. Tekrar dene')),
          DropdownButtonFormField<String>(value: _city, decoration: const InputDecoration(labelText: 'Hakem ili'), items: [
            const DropdownMenuItem<String>(value: null, child: Text('Tüm iller')),
            for (final c in rows.map((r) => r.cityCode).toSet()) DropdownMenuItem(value: c, child: Text('İl $c'))],
            onChanged: _busy ? null : (v) => setState(() {_city = v;_profile = null;})),
          DropdownButtonFormField<String>(value: candidates.any((r) => r.profileId == _profile) ? _profile : null,
            isExpanded: true, decoration: const InputDecoration(labelText: 'Aktif lisanslı hakem'),
            items: [for (final r in candidates) DropdownMenuItem(value: r.profileId, child: Text('${r.name} · ${r.badgeTier}', overflow: TextOverflow.ellipsis))],
            onChanged: _busy ? null : (v) => setState(() => _profile = v)),
          if (_profile != null && candidates.any((r) => r.profileId == _profile)) Text('Son tamamlanan maç: ${federationDate(candidates.firstWhere((r) => r.profileId == _profile).lastMatchAt)}'),
          DropdownButtonFormField<MatchOfficialDuty>(value: _duty, decoration: const InputDecoration(labelText: 'Görev'),
            items: [for (final d in MatchOfficialDuty.values) DropdownMenuItem(value: d, child: Text(officialDuty(d.wireName)))],
            onChanged: _busy ? null : (v) => setState(() => _duty = v!)),
          if (_error != null) Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
      ]))), actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Kapat')),
        if (canAssign && widget.match.status == 'scheduled') FilledButton(onPressed: _busy || !candidates.any((r) => r.profileId == _profile) ? null : _assign,
          child: _busy ? const CircularProgressIndicator() : const Text('Ata'))]));
  }
  Future<void> _assign() async {
    setState(() {_busy = true;_error = null;});
    try {
      final service = ref.read(federationConsoleServiceProvider);
      if (service == null) throw StateError('Backend bağlantısı gerekli.');
      await service.assignMatchOfficial(widget.match.id, _profile!, _duty);
      if (!mounted || ref.read(authSessionProvider).valueOrNull?.user.id != _actor) return;
      ref.invalidate(federationConsoleMatchesProvider);Navigator.pop(context);
    } catch (_) {if (mounted) setState(() => _error = 'Atama tamamlanamadı. Güncel durumu yenileyip tekrar deneyin.');}
    finally {if (mounted) setState(() => _busy = false);}
  }
}
