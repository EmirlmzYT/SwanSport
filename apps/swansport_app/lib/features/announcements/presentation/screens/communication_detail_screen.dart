import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import '../../application/communication_center_state.dart';
import '../../application/communication_detail_controller.dart';
import '../../application/communication_detail_state.dart';
import '../../domain/models/communication_center.dart';
import '../../domain/repositories/communication_center_repository.dart';
import '../routing/communication_detail_route_args.dart';

class CommunicationDetailScreen extends ConsumerStatefulWidget {
  const CommunicationDetailScreen({
    required this.args,
    this.scenario = CommunicationFixtureScenario.normal,
    super.key,
  }) : invalidRoute = false;

  const CommunicationDetailScreen.invalidRoute({super.key})
      : args = null,
        scenario = CommunicationFixtureScenario.normal,
        invalidRoute = true;

  final CommunicationDetailRouteArgs? args;
  final CommunicationFixtureScenario scenario;
  final bool invalidRoute;

  @override
  ConsumerState<CommunicationDetailScreen> createState() =>
      _CommunicationDetailScreenState();
}

class _CommunicationDetailScreenState
    extends ConsumerState<CommunicationDetailScreen> {
  CommunicationDetailRequest? _request;

  @override
  void initState() {
    super.initState();
    if (!widget.invalidRoute) {
      _request = CommunicationDetailRequest(
        args: widget.args!,
        scenario: widget.scenario,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.invalidRoute) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Geçersiz ileti bağlantısı.',
            key: Key('communication-detail-invalid-route'),
          ),
        ),
      );
    }
    final state = ref.watch(communicationDetailControllerProvider(_request!));
    final controller = ref.read(
      communicationDetailControllerProvider(_request!).notifier,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('İleti Ayrıntısı')),
      body: _body(state, controller),
    );
  }

  Widget _body(
    CommunicationDetailState state,
    CommunicationDetailController controller,
  ) {
    if (state.status == CommunicationDetailStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('communication-detail-loading'),
        ),
      );
    }
    if (state.status == CommunicationDetailStatus.notFound) {
      return const Center(
        child: Text(
          'İleti bulunamadı.',
          key: Key('communication-detail-not-found'),
        ),
      );
    }
    if (state.status == CommunicationDetailStatus.permissionDenied) {
      return const Center(
        child: Text(
          'Bu iletiyi görüntüleme yetkiniz yok.',
          key: Key('communication-detail-permission-denied'),
        ),
      );
    }
    if (state.status == CommunicationDetailStatus.failure) {
      return Center(
        child: Text(
          state.errorMessage ?? 'İleti ayrıntısı yüklenemedi.',
          key: const Key('communication-detail-failure'),
        ),
      );
    }

    final item = state.item!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            if (state.status == CommunicationDetailStatus.offlineCached)
              const _StatusBanner(
                key: Key('communication-detail-offline'),
                text: 'Önbellekteki ileti ayrıntısı gösteriliyor.',
              ),
            if (state.status == CommunicationDetailStatus.unavailable)
              const _StatusBanner(
                key: Key('communication-detail-unavailable'),
                text: 'Bu ileti artık kullanılamıyor.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(_typeLabel(item.type))),
                Chip(label: Text(_statusLabel(item.status))),
                if (item.isPinned)
                  const Chip(
                    avatar: Icon(Icons.push_pin_rounded, size: 18),
                    label: Text('Sabitlendi'),
                  ),
                if (item.priority == CommunicationPriority.emergency)
                  const Chip(
                    avatar: Icon(Icons.warning_rounded, size: 18),
                    label: Text('Acil'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              key: const Key('communication-detail-title'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.sender.isEmpty ? 'Gönderen belirtilmedi' : item.sender,
              key: const Key('communication-detail-sender'),
              style: const TextStyle(color: SwanColors.textSecondary),
            ),
            Text(
              _dateLabel(item),
              key: const Key('communication-detail-date'),
              style: const TextStyle(color: SwanColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(
              item.body,
              key: const Key('communication-detail-body'),
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Hedef kitle: ${item.audience.segments.map((segment) => segment.name).join(', ')}',
              key: const Key('communication-detail-audience'),
            ),
            if (item.attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Ekler',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              ...item.attachments.map(
                (attachment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file_rounded),
                  title: Text(attachment.name),
                ),
              ),
            ],
            if (controller.operationalLinks.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Bağlantılı Kayıtlar',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              ...controller.operationalLinks.map(
                (link) => Semantics(
                  button: true,
                  label: link.label,
                  child: ListTile(
                    key: Key(
                      'communication-operational-link-${link.targetId.value}',
                    ),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(link.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    enabled: !state.isLinkedNavigationPending,
                    onTap: state.isLinkedNavigationPending
                        ? null
                        : () => _openOperationalLink(controller, link),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (state.permissions.canViewDelivery)
              Text(
                '${item.delivery.read}/${item.recipients.total} Okundu',
                key: const Key('communication-detail-read-progress'),
              ),
            if (item.acknowledgement.status !=
                AcknowledgementStatus.notRequired)
              Text(
                state.permissions.canViewDelivery
                    ? '${item.acknowledgement.acknowledged}/${item.acknowledgement.required} Onay'
                    : _acknowledgementLabel(item.acknowledgement.status),
                key: const Key('communication-detail-acknowledgement'),
                style: const TextStyle(color: SwanColors.warning),
              ),
            if (controller.canAcknowledge) ...[
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'İletiyi okudum ve onaylıyorum',
                child: FilledButton(
                  key: const Key('communication-detail-acknowledge'),
                  onPressed: state.acknowledgementOperationStatus ==
                          CommunicationAcknowledgementOperationStatus.submitting
                      ? null
                      : controller.acknowledge,
                  child: Text(
                    state.acknowledgementResult?.actingUserAcknowledged == true
                        ? 'Onaylandı'
                        : state.acknowledgementOperationStatus ==
                                CommunicationAcknowledgementOperationStatus
                                    .submitting
                            ? 'Onaylanıyor…'
                            : 'Okudum ve Onaylıyorum',
                  ),
                ),
              ),
            ],
            if (state.acknowledgementOperationStatus ==
                CommunicationAcknowledgementOperationStatus.success)
              const Text(
                'Onayınız kaydedildi.',
                key: Key('communication-detail-acknowledgement-success'),
                style: TextStyle(color: SwanColors.success),
              ),
            if (state.acknowledgementError case final error?)
              Text(
                error,
                key: const Key('communication-detail-acknowledgement-error'),
                style: const TextStyle(color: SwanColors.warning),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOperationalLink(
    CommunicationDetailController controller,
    CommunicationOperationalLink link,
  ) async {
    if (!controller.beginLinkedNavigation(link)) return;
    try {
      switch (link.type) {
        case CommunicationOperationalLinkType.athleteProfile:
          await Navigator.of(context).pushNamed(
            '/athlete-detail',
            arguments: AthleteDetailRouteArgs(
              athleteId: link.targetId,
              teamId: link.teamId,
              seasonId: link.seasonId,
              source: AthleteDetailEntrySource.directLink,
            ),
          );
      }
    } finally {
      if (mounted) controller.completeLinkedNavigation();
    }
  }

  String _dateLabel(CommunicationItem item) {
    final date = item.schedule?.publishAt ?? item.publishedAt;
    final prefix = item.status == CommunicationStatus.scheduled
        ? 'Planlanan'
        : 'Yayınlanan';
    return '$prefix: ${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SwanColors.warning.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      );
}

String _typeLabel(CommunicationType type) => switch (type) {
      CommunicationType.announcement => 'Duyuru',
      CommunicationType.bulletin => 'Bülten',
      CommunicationType.emergency => 'Acil İleti',
    };

String _statusLabel(CommunicationStatus status) => switch (status) {
      CommunicationStatus.draft => 'Taslak',
      CommunicationStatus.scheduled => 'Planlandı',
      CommunicationStatus.published => 'Yayınlandı',
      CommunicationStatus.cancelled => 'İptal Edildi',
      CommunicationStatus.archived => 'Arşivlendi',
    };

String _acknowledgementLabel(AcknowledgementStatus status) => switch (status) {
      AcknowledgementStatus.pending => 'Onay bekleniyor',
      AcknowledgementStatus.acknowledged => 'Onaylandı',
      AcknowledgementStatus.overdue => 'Onay gecikmiş',
      AcknowledgementStatus.notRequired => 'Onay gerekmiyor',
    };
