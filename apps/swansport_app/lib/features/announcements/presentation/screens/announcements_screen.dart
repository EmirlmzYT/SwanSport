import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../application/communication_center_controller.dart';
import '../../application/communication_center_state.dart';
import '../../domain/models/communication_center.dart';
import '../routing/communication_detail_route_args.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communicationCenterControllerProvider);
    final controller = ref.read(communicationCenterControllerProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? SwanColors.darkBackground : SwanColors.background,
      appBar: SwanAppBar(
        clubName: 'Kadıköy SK',
        roleName: 'Antrenör',
        actions: state.permissions.canCompose
            ? [
                IconButton(
                  icon: const Icon(Icons.add_comment_rounded),
                  onPressed: () => _showComposer(context),
                ),
              ]
            : const [],
      ),
      body: _content(context, state, controller, dark),
      bottomNavigationBar: SwanFloatingNavigationBar(
        selectedIndex: 3,
        destinations: const [
          SwanNavigationDestination(
            icon: Icons.grid_view_rounded,
            label: 'Ana Sayfa',
          ),
          SwanNavigationDestination(
            icon: Icons.calendar_month_rounded,
            label: 'Takvim',
          ),
          SwanNavigationDestination(
            icon: Icons.groups_rounded,
            label: 'Takımım',
          ),
          SwanNavigationDestination(
            icon: Icons.campaign_rounded,
            label: 'Duyurular',
          ),
        ],
        onDestinationSelected: (i) {
          if (i == 0) Navigator.pushNamed(context, '/dashboard');
          if (i == 1) Navigator.pushNamed(context, '/calendar');
          if (i == 2) Navigator.pushNamed(context, '/athletes');
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    CommunicationCenterState state,
    CommunicationCenterController controller,
    bool dark,
  ) {
    if (state.status == CommunicationCenterStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == CommunicationCenterStatus.error) {
      return Center(
        child: Text(state.errorMessage ?? 'İletişim merkezi yüklenemedi.'),
      );
    }
    final workspace = state.workspace!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        const Text(
          'KULÜP İLETİŞİM MERKEZİ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: SwanColors.textSecondary,
          ),
        ),
        const Text(
          'Duyurular & Bültenler',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        _analytics(workspace),
        if (workspace.isOffline || workspace.isStale)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Önbellekteki ileti verisi gösteriliyor.',
              style: TextStyle(color: SwanColors.warning),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('communication-search-field'),
          controller: _searchController,
          onChanged: controller.updateSearch,
          decoration: InputDecoration(
            hintText: 'İletilerde ara',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: state.searchQuery.isEmpty
                ? null
                : IconButton(
                    key: const Key('communication-search-clear'),
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      controller.clearSearch();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
        _filters(state, controller),
        const SizedBox(height: 20),
        if (workspace.sectionFailures['feed'] case final failure?)
          Text(failure),
        if (state.status == CommunicationCenterStatus.empty)
          const Text('İleti bulunamadı.')
        else
          ...workspace.items.map(
            (item) => _card(context, item, state, dark, controller),
          ),
      ],
    );
  }

  Widget _analytics(CommunicationWorkspace workspace) {
    final analytics = workspace.analytics;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SwanColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: analytics == null
          ? Text(
              workspace.sectionFailures['analytics'] ??
                  'Analitik kullanılamıyor.',
              style: const TextStyle(color: Colors.white),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERY & READ ANALYTICS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${analytics.activeCount} Aktif Bülten & Duyuru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '%${analytics.readRate} Ortalama Okuma Oranı • ${analytics.pendingAcknowledgements} Onay Bekliyor',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
    );
  }

  Widget _filters(
    CommunicationCenterState state,
    CommunicationCenterController controller,
  ) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: CommunicationType.values
              .map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_label(type)),
                    selected: state.filters.types.contains(type),
                    onSelected: (selected) {
                      final types = {...state.filters.types};
                      selected ? types.add(type) : types.remove(type);
                      controller.applyFilters(
                        CommunicationFilterState(
                          types: types,
                          query: state.filters.query,
                        ),
                      );
                    },
                  ),
                ),
              )
              .toList(),
        ),
      );

  Widget _card(
    BuildContext context,
    CommunicationItem item,
    CommunicationCenterState state,
    bool dark,
    CommunicationCenterController controller,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          onTap: () {
            controller.select(item);
            Navigator.pushNamed(
              context,
              '/communication-detail',
              arguments: CommunicationDetailRouteArgs(
                communicationId: item.id,
                role: state.role,
                actingRecipientId: controller.actingRecipientId,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dark ? SwanColors.darkSurface : SwanColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(item.type),
                  style: const TextStyle(
                    color: SwanColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(item.body),
                if (state.permissions.canViewDelivery)
                  Text(
                    '${item.delivery.read}/${item.recipients.total} Okundu',
                  ),
                if (item.acknowledgement.status !=
                    AcknowledgementStatus.notRequired)
                  Text(
                    state.permissions.canViewDelivery
                        ? '${item.acknowledgement.acknowledged}/${item.acknowledgement.required} Onay'
                        : _acknowledgementLabel(item.acknowledgement.status),
                    key: Key('acknowledgement-status-${item.id.value}'),
                    style: const TextStyle(color: SwanColors.warning),
                  ),
                if (controller.canAcknowledge(item))
                  FilledButton.tonal(
                    key: Key('acknowledge-${item.id.value}'),
                    onPressed: state.acknowledgementOperationStatus ==
                                CommunicationAcknowledgementOperationStatus
                                    .submitting &&
                            state.acknowledgementCommunicationId ==
                                item.id.value
                        ? null
                        : () => controller.acknowledgeCommunication(item.id),
                    child: Text(
                      state.acknowledgementResult?.item.id.value ==
                                  item.id.value &&
                              state
                                  .acknowledgementResult!.actingUserAcknowledged
                          ? 'Onaylandı'
                          : state.acknowledgementOperationStatus ==
                                      CommunicationAcknowledgementOperationStatus
                                          .submitting &&
                                  state.acknowledgementCommunicationId ==
                                      item.id.value
                              ? 'Onaylanıyor…'
                              : 'Okudum ve Onaylıyorum',
                    ),
                  ),
                if (state.acknowledgementCommunicationId == item.id.value &&
                    state.acknowledgementOperationStatus ==
                        CommunicationAcknowledgementOperationStatus.success)
                  const Text(
                    'Onayınız kaydedildi.',
                    key: Key('acknowledgement-success'),
                    style: TextStyle(color: SwanColors.success),
                  ),
                if (state.acknowledgementCommunicationId == item.id.value)
                  if (state.acknowledgementError case final error?)
                    Text(
                      error,
                      key: const Key('acknowledgement-error'),
                      style: const TextStyle(color: SwanColors.warning),
                    ),
                if (item.attachments.isNotEmpty)
                  Text(item.attachments.first.name),
              ],
            ),
          ),
        ),
      );

  void _showComposer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) => _composerContent(context, ref),
      ),
    );
  }

  Widget _composerContent(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communicationCenterControllerProvider);
    final controller = ref.read(communicationCenterControllerProvider.notifier);
    final audience = state.composerDraft.audience;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          key: const Key('composer-scroll'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hedef Kitle',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('composer-title'),
                initialValue: state.composerDraft.title,
                decoration: const InputDecoration(labelText: 'Başlık'),
                onChanged: (value) => controller.updateComposer(
                  state.composerDraft.copyWith(title: value),
                ),
              ),
              TextFormField(
                key: const Key('composer-body'),
                initialValue: state.composerDraft.body,
                decoration: const InputDecoration(labelText: 'İçerik'),
                onChanged: (value) => controller.updateComposer(
                  state.composerDraft.copyWith(body: value),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _audienceChip(
                    'Tüm Kulüp',
                    AudienceSegment.club,
                    const SwanId('club'),
                    audience,
                    controller,
                  ),
                  _audienceChip(
                    'U16 Takımı',
                    AudienceSegment.team,
                    const SwanId('u16'),
                    audience,
                    controller,
                  ),
                  _audienceChip(
                    'Veliler',
                    AudienceSegment.guardian,
                    const SwanId('guardians'),
                    audience,
                    controller,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.audienceResolutionStatus ==
                  AudienceResolutionStatus.resolving)
                const LinearProgressIndicator(
                  key: Key('audience-resolver-loading'),
                ),
              if (state.resolvedAudience case final resolved?)
                Text(
                  '${resolved.totalUniqueRecipients} benzersiz alıcı • '
                  '${resolved.preview.categoryCounts.entries.map((entry) => '${entry.key.name}: ${entry.value}').join(' • ')}',
                  key: const Key('audience-recipient-preview'),
                ),
              if (state.audienceResolutionError case final error?)
                Text(
                  error,
                  key: const Key('audience-resolution-error'),
                  style: const TextStyle(color: SwanColors.warning),
                ),
              TextButton(
                key: const Key('audience-clear'),
                onPressed: () {
                  controller.updateComposer(
                    state.composerDraft.copyWith(
                      audience: const CommunicationAudience(
                        segments: {},
                        recipientIds: {},
                      ),
                    ),
                  );
                },
                child: const Text('Hedef Kitleyi Temizle'),
              ),
              OutlinedButton.icon(
                key: const Key('schedule-date-time'),
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  state.composerDraft.schedule == null
                      ? 'Tarih ve Saat Seç'
                      : _formatSchedule(
                          state.composerDraft.schedule!.publishAt,
                        ),
                ),
                onPressed: () => _chooseSchedule(context, state, controller),
              ),
              if (state.schedulingStatus ==
                  CommunicationSchedulingStatus.scheduling)
                const LinearProgressIndicator(key: Key('schedule-progress')),
              if (state.schedulingError case final error?)
                Text(
                  error,
                  key: const Key('schedule-error'),
                  style: const TextStyle(color: SwanColors.warning),
                ),
              if (state.schedulingStatus ==
                  CommunicationSchedulingStatus.success)
                const Text(
                  'İleti başarıyla planlandı.',
                  key: Key('schedule-success'),
                  style: TextStyle(color: SwanColors.success),
                ),
              FilledButton(
                key: const Key('schedule-submit'),
                onPressed: state.schedulingStatus ==
                        CommunicationSchedulingStatus.scheduling
                    ? null
                    : controller.scheduleCurrentDraft,
                child: const Text('Planla'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audienceChip(
    String label,
    AudienceSegment segment,
    SwanId id,
    CommunicationAudience audience,
    CommunicationCenterController controller,
  ) {
    final selected = audience.segments.contains(segment) &&
        audience.recipientIds.any((selectedId) => selectedId.value == id.value);
    return FilterChip(
      key: Key('audience-${segment.name}'),
      label: Text(label),
      selected: selected,
      onSelected: (enabled) {
        final segments = {...audience.segments};
        final ids = {
          ...audience.recipientIds.where((item) => item.value != id.value),
        };
        enabled ? segments.add(segment) : segments.remove(segment);
        if (enabled) ids.add(id);
        controller.updateDraftAudience(
          CommunicationAudience(
            segments: segments,
            recipientIds: ids,
          ),
        );
        controller.resolveDraftAudience();
      },
    );
  }

  Future<void> _chooseSchedule(
    BuildContext context,
    CommunicationCenterState state,
    CommunicationCenterController controller,
  ) async {
    final initial = state.composerDraft.schedule?.publishAt ??
        DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    controller.updateComposer(
      state.composerDraft.copyWith(
        schedule: CommunicationSchedule(
          publishAt: DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        ),
      ),
    );
  }

  String _formatSchedule(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _label(CommunicationType type) => switch (type) {
      CommunicationType.announcement => 'Duyuru',
      CommunicationType.bulletin => 'Bülten',
      CommunicationType.emergency => 'Acil'
    };

String _acknowledgementLabel(AcknowledgementStatus status) => switch (status) {
      AcknowledgementStatus.pending => 'Onay bekleniyor',
      AcknowledgementStatus.acknowledged => 'Onaylandı',
      AcknowledgementStatus.overdue => 'Onay gecikmiş',
      AcknowledgementStatus.notRequired => 'Onay gerekmiyor',
    };
