import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../club/club_operation_card.dart';
import '../host/pro_feature_host.dart';

final class SharedClubStaffOperationsPanel extends ConsumerWidget {
  const SharedClubStaffOperationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final clubAsync = ref.watch(activeClubProvider);
    final flagEnabled = ref.watch(
      featureEnabledProvider(FeatureFlags.clubStaffOperations),
    );
    if (clubAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (clubAsync.hasError) {
      return _Message(
        title: classifyOperationError(clubAsync.error!).userMessage,
        onRetry: () => ref.invalidate(activeClubProvider),
      );
    }
    final club = clubAsync.valueOrNull;
    if (club == null || !flagEnabled) {
      return const _Message(
        title: 'İhtisas operasyonları kullanılamıyor',
        body: 'Aktif kulüp kapsamı ve özellik erişimi gereklidir.',
      );
    }
    final access = ref.watch(swanAccessProvider);
    final cards = <Widget>[
      if (access.canReadClubInventory(club.id))
        ClubOperationCard(
          icon: Icons.inventory_2_outlined,
          title: 'Envanter ve Zimmet',
          detail: 'Stok, takım zimmeti ve hasarlı/eksik kayıtları',
          onTap: host.navigator.openClubInventory,
          theme: host.theme,
        ),
      if (access.canReadClubHealth(club.id))
        ClubOperationCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Sağlık ve İdari Dinlendirme',
          detail: 'Yetki ayrımlı uygunluk ve dinlenme işlemleri',
          onTap: host.navigator.openClubHealthOperations,
          theme: host.theme,
        ),
      if (access.canReadClubPlanning(club.id))
        ClubOperationCard(
          icon: Icons.sports_soccer_outlined,
          title: 'Sportif Kadro Planlama',
          detail: 'Kadro, lisans, yoklama ve tescilli transfer özeti',
          onTap: host.navigator.openClubSportingPlanning,
          theme: host.theme,
        ),
    ];
    if (cards.isEmpty) {
      return const _Message(
        title: 'Kulüp ihtisas yetkisi bulunamadı',
        body: 'Rol etiketi tek başına operasyon verilerini açmaz.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kulüp İhtisas Operasyonları',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(club.name, style: TextStyle(color: host.theme.inkMuted)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
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

final class SharedClubInventoryScreen extends ConsumerStatefulWidget {
  const SharedClubInventoryScreen({super.key});

  @override
  ConsumerState<SharedClubInventoryScreen> createState() =>
      _SharedClubInventoryScreenState();
}

final class _SharedClubInventoryScreenState
    extends ConsumerState<SharedClubInventoryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final club = ref.watch(activeClubProvider).valueOrNull;
    final access = ref.watch(swanAccessProvider);
    final allowed = club != null &&
        ref.watch(featureEnabledProvider(FeatureFlags.clubStaffOperations)) &&
        access.canReadClubInventory(club.id);
    return host.chrome.buildPage(
      context,
      title: 'Envanter ve Zimmet',
      body: !allowed
          ? const _Message(title: 'Envanter okuma yetkisi gerekli')
          : _inventoryBody(context, club, access),
    );
  }

  Widget _inventoryBody(
    BuildContext context,
    ClubRef club,
    SwanAccess access,
  ) {
    final mutation = ref.watch(clubOperationControllerProvider(club.id));
    return ref.watch(clubInventoryBoardProvider(club.id)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            title: classifyOperationError(error).userMessage,
            onRetry: () => ref.invalidate(clubInventoryBoardProvider(club.id)),
          ),
          data: (board) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Stok')),
                  ButtonSegment(value: 1, label: Text('Zimmet')),
                  ButtonSegment(value: 2, label: Text('Hasarlı/Eksik')),
                ],
                selected: {_tab},
                onSelectionChanged: (value) =>
                    setState(() => _tab = value.first),
              ),
              if (mutation.error != null) ...[
                const SizedBox(height: 12),
                _PendingBanner(
                  state: mutation,
                  onRetry: () => ref
                      .read(clubOperationControllerProvider(club.id).notifier)
                      .retry(),
                ),
              ],
              if (access.canManageClubInventory(club.id)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('inventory-add-item'),
                      onPressed: mutation.busy || mutation.pending
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _InventoryWriteDialog(
                                  clubId: club.id,
                                  board: board,
                                  assign: false,
                                ),
                              ),
                      icon: const Icon(Icons.add),
                      label: const Text('Malzeme Ekle'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('inventory-assign-item'),
                      onPressed: mutation.busy ||
                              mutation.pending ||
                              board.items.every((item) => item.available < 1)
                          ? null
                          : () => showDialog<void>(
                                context: context,
                                builder: (_) => _InventoryWriteDialog(
                                  clubId: club.id,
                                  board: board,
                                  assign: true,
                                ),
                              ),
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Zimmet Ver'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (_tab == 0)
                for (final item in board.items)
                  Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.category} · Kullanılabilir ${item.available}/${item.quantity}\n'
                        'Hasarlı ${item.damaged} · Eksik ${item.missing}',
                      ),
                    ),
                  )
              else
                for (final assignment in board.assignments.where(
                  (item) =>
                      _tab == 1 ||
                      item.outcome == 'damaged' ||
                      item.outcome == 'missing',
                ))
                  Card(
                    child: ListTile(
                      title: Text(
                        '${assignment.itemName} · ${assignment.quantity} adet',
                      ),
                      subtitle: Text(
                        '${assignment.targetReference} · ${_date(assignment.assignedAt)} · ${assignment.outcome}',
                      ),
                      trailing: assignment.returnedAt == null &&
                              access.canManageClubInventory(club.id)
                          ? PopupMenuButton<String>(
                              onSelected: (outcome) => _closeAssignment(
                                club.id,
                                assignment,
                                outcome,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'returned',
                                  child: Text('İade Al'),
                                ),
                                PopupMenuItem(
                                  value: 'damaged',
                                  child: Text('Hasarlı'),
                                ),
                                PopupMenuItem(
                                  value: 'missing',
                                  child: Text('Eksik'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
              if (board.items.isEmpty)
                const _Message(title: 'Henüz envanter kaydı yok'),
              const SizedBox(height: 8),
              const Text(
                'Kişi hedefleri özel referansla gösterilir. Hesapsız sporcular için takım zimmeti kullanılır.',
              ),
            ],
          ),
        );
  }

  Future<void> _closeAssignment(
    String clubId,
    ClubInventoryAssignment assignment,
    String outcome,
  ) async {
    final host = ProFeatureHostScope.of(context);
    final confirmed = await host.chrome.confirm(
      context,
      title: 'Zimmeti kapat',
      message: '${assignment.quantity} adet “$outcome” olarak kapanacak.',
      confirmLabel: 'Onayla',
    );
    if (!confirmed || !mounted) return;
    await ref.read(clubOperationControllerProvider(clubId).notifier).submit(
      'inventory_return',
      {'p_assignment': assignment.id, 'p_outcome': outcome},
    );
  }
}

final class SharedClubHealthOperationsScreen extends ConsumerWidget {
  const SharedClubHealthOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final club = ref.watch(activeClubProvider).valueOrNull;
    final access = ref.watch(swanAccessProvider);
    final allowed = club != null &&
        ref.watch(featureEnabledProvider(FeatureFlags.clubStaffOperations)) &&
        access.canReadClubHealth(club.id);
    return host.chrome.buildPage(
      context,
      title: 'Sağlık ve İdari Dinlendirme',
      body: !allowed
          ? const _Message(title: 'Sağlık operasyonu okuma yetkisi gerekli')
          : ref.watch(clubHealthOperationsProvider(club.id)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _Message(
                  title: classifyOperationError(error).userMessage,
                  onRetry: () =>
                      ref.invalidate(clubHealthOperationsProvider(club.id)),
                ),
                data: (rows) => _healthBody(context, ref, club, access, rows),
              ),
    );
  }

  Widget _healthBody(
    BuildContext context,
    WidgetRef ref,
    ClubRef club,
    SwanAccess access,
    List<ClubHealthOperation> rows,
  ) {
    final mutation = ref.watch(clubOperationControllerProvider(club.id));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Bu ekranda teşhis veya klinik not tutulmaz. İdari dinlenmeyi kaldırmak tıbbi kilidi kaldırmaz.',
        ),
        if (mutation.error != null)
          _PendingBanner(
            state: mutation,
            onRetry: () => ref
                .read(clubOperationControllerProvider(club.id).notifier)
                .retry(),
          ),
        for (final row in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.reference,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(row.reason),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (access.canManageAdministrativeStatus(club.id))
                        OutlinedButton(
                          onPressed: mutation.busy || mutation.pending
                              ? null
                              : () => _submitHealth(
                                    ref,
                                    club.id,
                                    'set_club_athlete_rest',
                                    {
                                      'p_athlete': row.athleteId,
                                      'p_status': row.restStatus == null
                                          ? 'rested'
                                          : 'eligible',
                                      'p_ends_at': null,
                                    },
                                  ),
                          child: Text(
                            row.restStatus == null
                                ? 'İdari Dinlendir'
                                : 'İdari Dinlenmeyi Kaldır',
                          ),
                        ),
                      if (access.hasMedicalAuthorityForClub(club.id))
                        FilledButton.tonal(
                          onPressed: mutation.busy || mutation.pending
                              ? null
                              : () =>
                                  _medicalAction(context, ref, club.id, row),
                          child: Text(
                            row.restrictionId == null
                                ? 'Tıbbi Kısıt Ekle'
                                : 'Tıbbi Kısıtı Kaldır',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (rows.isEmpty) const _Message(title: 'Aktif sağlık operasyonu yok'),
      ],
    );
  }

  Future<void> _medicalAction(
    BuildContext context,
    WidgetRef ref,
    String clubId,
    ClubHealthOperation row,
  ) async {
    final host = ProFeatureHostScope.of(context);
    final confirmed = await host.chrome.confirm(
      context,
      title: 'Yetkili sağlık işlemi',
      message: 'Yalnız gerçek sağlık otoritesi bu işlemi tamamlayabilir.',
      confirmLabel: 'Doğrula',
    );
    if (!confirmed || !context.mounted) return;
    await _submitHealth(
      ref,
      clubId,
      row.restrictionId == null
          ? 'open_health_restriction'
          : 'clear_health_restriction',
      row.restrictionId == null
          ? {
              'p_athlete': row.athleteId,
              'p_status': 'restricted',
              'p_reevaluation': null,
              'p_evidence': null,
            }
          : {
              'p_restriction': row.restrictionId,
              'p_note': 'Yetkili sağlık görevlisi doğrulaması',
            },
    );
  }

  Future<void> _submitHealth(
    WidgetRef ref,
    String clubId,
    String rpc,
    Map<String, dynamic> payload,
  ) =>
      ref.read(clubOperationControllerProvider(clubId).notifier).submit(
            rpc,
            payload,
          );
}

final class SharedClubSportingPlanningScreen extends ConsumerWidget {
  const SharedClubSportingPlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final club = ref.watch(activeClubProvider).valueOrNull;
    final access = ref.watch(swanAccessProvider);
    final allowed = club != null &&
        ref.watch(featureEnabledProvider(FeatureFlags.clubStaffOperations)) &&
        access.canReadClubPlanning(club.id);
    return host.chrome.buildPage(
      context,
      title: 'Sportif Kadro Planlama',
      body: !allowed
          ? const _Message(title: 'Sportif planlama okuma yetkisi gerekli')
          : ref.watch(clubSportingOverviewProvider(club.id)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _Message(
                  title: classifyOperationError(error).userMessage,
                  onRetry: () =>
                      ref.invalidate(clubSportingOverviewProvider(club.id)),
                ),
                data: (overview) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(
                      title: 'Kadro ve lisans',
                      body:
                          '${overview.athletes} sporcu · 30 gün içinde ${overview.expiringLicenses} lisans vizesi',
                    ),
                    for (final team in overview.teams)
                      _SummaryCard(
                        title: team.name,
                        body: '${team.athleteCount} sporcu',
                      ),
                    _SummaryCard(
                      title: 'Son 30 gün',
                      body:
                          '${overview.lockedLineups} kilitli esame · ${overview.completedTransfers} tamamlanmış transfer\n'
                          'Yoklama: ${overview.attendanceRate == null ? 'Veri yok' : '%${overview.attendanceRate!.toStringAsFixed(1)}'} · ${overview.excused} izinli',
                    ),
                    for (final license in overview.licenses)
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(license.reference),
                        subtitle: Text(
                          '${license.sportCode} · ${_date(license.expiresOn)}',
                        ),
                      ),
                    if (ref.watch(
                      featureEnabledProvider(FeatureFlags.developmentReport),
                    ))
                      OutlinedButton.icon(
                        onPressed: host.navigator.openDevelopmentReport,
                        icon: const Icon(Icons.insights_outlined),
                        label: const Text('Dönem Gelişim Raporu'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Transfer talebi motoru bulunmadığından bekleyen transfer kuyruğu üretilmez; yalnız tamamlanmış tesciller gösterilir.',
                    ),
                  ],
                ),
              ),
    );
  }
}

final class SharedDevelopmentReportScreen extends ConsumerStatefulWidget {
  const SharedDevelopmentReportScreen({super.key});

  @override
  ConsumerState<SharedDevelopmentReportScreen> createState() =>
      _SharedDevelopmentReportScreenState();
}

final class _SharedDevelopmentReportScreenState
    extends ConsumerState<SharedDevelopmentReportScreen> {
  String? _athleteId;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 90));
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final enabled = ref.watch(
      featureEnabledProvider(FeatureFlags.developmentReport),
    );
    final athletes = ref.watch(
      reportAthletesProvider((query: '', offset: 0)),
    );
    return host.chrome.buildPage(
      context,
      title: 'Dönem Gelişim Raporu',
      body: !enabled
          ? const _Message(title: 'Gelişim raporu özelliği etkin değil')
          : athletes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Message(
                title: classifyOperationError(error).userMessage,
                onRetry: () => ref.invalidate(
                  reportAthletesProvider((query: '', offset: 0)),
                ),
              ),
              data: (page) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('development-report-athlete'),
                    initialValue: page.athletes.any((a) => a.id == _athleteId)
                        ? _athleteId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Sporcu'),
                    items: [
                      for (final athlete in page.athletes)
                        DropdownMenuItem(
                          value: athlete.id,
                          child: Text(
                            athlete.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _athleteId = value),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: true),
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text('Başlangıç ${reportDate(_from)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isFrom: false),
                        icon: const Icon(Icons.event_outlined),
                        label: Text('Bitiş ${reportDate(_to)}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_athleteId == null)
                    const _Message(title: 'Rapor için sporcu seçin')
                  else
                    ref
                        .watch(
                          developmentReportProvider(
                            (
                              athleteId: _athleteId!,
                              from: _from,
                              to: _to,
                            ),
                          ),
                        )
                        .when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => _Message(
                            title: classifyOperationError(error).userMessage,
                            onRetry: () => ref.invalidate(
                              developmentReportProvider(
                                (
                                  athleteId: _athleteId!,
                                  from: _from,
                                  to: _to,
                                ),
                              ),
                            ),
                          ),
                          data: (report) => _DevelopmentReportBody(
                            report: report,
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = selected.isAfter(_to) ? _to : selected;
      } else {
        _to = selected.isBefore(_from) ? _from : selected;
      }
    });
  }
}

final class _DevelopmentReportBody extends StatelessWidget {
  const _DevelopmentReportBody({required this.report});

  final DevelopmentReport report;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(
            title: report.athlete.name,
            body:
                '${reportDate(report.from)} – ${reportDate(report.to)}\nDevam: ${report.attendance.rate == null ? 'Hesaplanamıyor' : '%${reportNumber(report.attendance.rate!)}'}',
          ),
          for (final metric in report.metrics)
            _SummaryCard(title: metric.name, body: metric.summary),
          for (final goal in report.goals)
            _SummaryCard(
              title: goal.title,
              body: '${goal.statusLabel} · %${goal.progress}',
            ),
          if (report.gaps.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Veri sınırları',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final gap in report.gaps) Text('• $gap'),
                  ],
                ),
              ),
            ),
        ],
      );
}

final class _InventoryWriteDialog extends ConsumerStatefulWidget {
  const _InventoryWriteDialog({
    required this.clubId,
    required this.board,
    required this.assign,
  });

  final String clubId;
  final ClubInventoryBoard board;
  final bool assign;

  @override
  ConsumerState<_InventoryWriteDialog> createState() =>
      _InventoryWriteDialogState();
}

final class _InventoryWriteDialogState
    extends ConsumerState<_InventoryWriteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _operationId = refereeOperationId();
  String? _itemId;
  String? _target;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(swanAccessProvider);
    final state = ref.watch(clubOperationControllerProvider(widget.clubId));
    if (!access.canManageClubInventory(widget.clubId)) {
      return const AlertDialog(
        content: Text('Envanter yazma yetkisi kaybedildi.'),
      );
    }
    final locked = state.busy || state.pending;
    return PopScope(
      canPop: !locked,
      child: AlertDialog(
        title: Text(widget.assign ? 'Zimmet Ver' : 'Malzeme Ekle'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.assign) ...[
                  TextFormField(
                    controller: _name,
                    enabled: !locked,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Malzeme adı'),
                    validator: (value) =>
                        value?.trim().isNotEmpty == true ? null : 'Ad gerekli',
                  ),
                  TextFormField(
                    controller: _category,
                    enabled: !locked,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Kategori gerekli',
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _itemId,
                    decoration: const InputDecoration(labelText: 'Malzeme'),
                    items: [
                      for (final item in widget.board.items.where(
                        (item) => item.available > 0 && item.status == 'active',
                      ))
                        DropdownMenuItem(
                          value: item.id,
                          child: Text('${item.name} · ${item.available}'),
                        ),
                    ],
                    onChanged: locked ? null : (value) => _itemId = value,
                    validator: (value) =>
                        value == null ? 'Malzeme seçin' : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _target,
                    decoration: const InputDecoration(labelText: 'Üye / Takım'),
                    items: [
                      for (final target in widget.board.targets)
                        DropdownMenuItem(
                          value: '${target.kind}:${target.id}',
                          child: Text(target.label),
                        ),
                    ],
                    onChanged: locked ? null : (value) => _target = value,
                    validator: (value) => value == null ? 'Hedef seçin' : null,
                  ),
                ],
                TextFormField(
                  controller: _quantity,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Adet'),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    return count == null || count < 1 || count > 1000000
                        ? '1–1.000.000 tam sayı girin'
                        : null;
                  },
                ),
                if (state.error != null) Text(state.error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: locked ? null : () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: state.busy ? null : () => _save(state.pending),
            child: Text(state.pending ? 'Aynı İşlemi Tekrar Dene' : 'Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(bool pending) async {
    if (!pending && !_formKey.currentState!.validate()) return;
    final controller =
        ref.read(clubOperationControllerProvider(widget.clubId).notifier);
    final target = widget.assign ? _target!.split(':') : const <String>[];
    final success = pending
        ? await controller.retry()
        : await controller.submit(
            widget.assign ? 'inventory_assign' : 'inventory_add_item',
            widget.assign
                ? {
                    'p_id': _operationId,
                    'p_item': _itemId,
                    'p_quantity': int.parse(_quantity.text),
                    'p_profile': target.first == 'profile' ? target.last : null,
                    'p_team': target.first == 'team' ? target.last : null,
                    'p_notes': null,
                  }
                : {
                    'p_id': _operationId,
                    'p_club': widget.clubId,
                    'p_name': _name.text.trim(),
                    'p_category': _category.text.trim(),
                    'p_quantity': int.parse(_quantity.text),
                    'p_sport': null,
                  },
          );
    if (success && mounted) Navigator.pop(context);
  }
}

final class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.state, required this.onRetry});

  final ClubOperationState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(state.error ?? 'İşlem bekliyor.'),
              if (state.pending)
                TextButton(
                  onPressed: state.busy ? null : onRetry,
                  child: const Text('Aynı işlemi tekrar dene'),
                ),
            ],
          ),
        ),
      );
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(title), subtitle: Text(body)),
      );
}

final class _Message extends StatelessWidget {
  const _Message({required this.title, this.body, this.onRetry});

  final String title;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 36),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(body!, textAlign: TextAlign.center),
              ],
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Tekrar dene'),
                ),
            ],
          ),
        ),
      );
}

String _date(DateTime date) {
  final local = date.toUtc().add(const Duration(hours: 3));
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
}
