import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';
import '../../application/communication_center_permissions.dart';
import '../../domain/models/acknowledge_communication_command.dart';
import '../../domain/models/communication_center.dart';
import '../../domain/models/schedule_communication_command.dart';
import '../../domain/repositories/communication_center_repository.dart';
import '../fixtures/communication_center_fixture_data_source.dart';

class FixtureCommunicationCenterRepository
    implements CommunicationCenterRepository {
  FixtureCommunicationCenterRepository(this.source);
  final FixtureCommunicationCenterDataSource source;
  final List<CommunicationItem> _scheduledItems = [];
  final Map<String, CommunicationItem> _scheduledByKey = {};
  final Map<String, CommunicationItem> _acknowledgementItemOverrides = {};
  final Map<String, Map<String, DateTime>> _acknowledgements = {};

  static const _eligibleAcknowledgementRecipients = {
    'communication_emergency': {
      'athlete_eligible',
      'guardian_eligible',
      'athlete_45',
      'athlete_46',
      'athlete_47',
      'athlete_48',
    },
  };
  @override
  Future<AppResult<CommunicationWorkspace>> loadWorkspace({
    required CommunicationFilterState filters,
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) async {
    if (scenario == CommunicationFixtureScenario.error) {
      return const AppError(
        AppFailure(
          message: 'İletişim merkezi yüklenemedi.',
          code: 'communication_load_failed',
        ),
      );
    }
    final permissions = CommunicationCenterPermissions.forRole(role);
    final items = scenario == CommunicationFixtureScenario.empty
        ? const <CommunicationItem>[]
        : [...source.items, ..._scheduledItems]
            .map(
              (item) => _acknowledgementItemOverrides[item.id.value] ?? item,
            )
            .where((item) => _canViewDetail(item, role))
            .where(filters.matches)
            .map(
              (i) => permissions.canViewDelivery
                  ? i
                  : i.copyWith(
                      delivery: const DeliverySummary(
                        queued: 0,
                        sent: 0,
                        delivered: 0,
                        read: 0,
                        acknowledged: 0,
                        failed: 0,
                      ),
                    ),
            )
            .toList();
    return AppSuccess(
      CommunicationWorkspace(
        items: scenario == CommunicationFixtureScenario.feedFailure
            ? const []
            : items,
        analytics: scenario == CommunicationFixtureScenario.analyticsFailure
            ? null
            : source.analytics,
        permissions: permissions,
        isOffline: scenario == CommunicationFixtureScenario.offline,
        isStale: scenario == CommunicationFixtureScenario.stale,
        sectionFailures: {
          if (scenario == CommunicationFixtureScenario.analyticsFailure)
            'analytics': 'Analitik verileri kullanılamıyor.',
          if (scenario == CommunicationFixtureScenario.feedFailure)
            'feed': 'İleti akışı kullanılamıyor.',
        },
      ),
    );
  }

  @override
  Future<AppResult<CommunicationItem>> getDetail(
    SwanId id, {
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) async {
    if (scenario == CommunicationFixtureScenario.error) {
      return const AppError(
        AppFailure(
          message: 'İleti ayrıntısı şu anda yüklenemedi.',
          code: 'communication_detail_failure',
        ),
      );
    }
    final item = [...source.items, ..._scheduledItems]
        .where((i) => i.id.value == id.value)
        .map((i) => _acknowledgementItemOverrides[i.id.value] ?? i)
        .firstOrNull;
    if (item != null && !_canViewDetail(item, role)) {
      return const AppError(
        AppFailure(
          message: 'Bu iletiyi görüntüleme yetkiniz yok.',
          code: 'communication_detail_permission_denied',
        ),
      );
    }
    return item == null
        ? const AppError(
            AppFailure(
              message: 'İleti bulunamadı.',
              code: 'communication_not_found',
            ),
          )
        : AppSuccess(item);
  }

  bool _canViewDetail(CommunicationItem item, CommunicationRole role) {
    if (role == CommunicationRole.superAdmin ||
        role == CommunicationRole.clubAdmin ||
        role == CommunicationRole.headCoach) {
      return true;
    }
    if (role == CommunicationRole.athlete) {
      return item.audience.segments.contains(AudienceSegment.club) ||
          item.audience.segments.contains(AudienceSegment.team) ||
          item.audience.segments.contains(AudienceSegment.athlete);
    }
    if (role == CommunicationRole.guardian) {
      return item.audience.segments.contains(AudienceSegment.club) ||
          item.audience.segments.contains(AudienceSegment.guardian);
    }
    return false;
  }

  @override
  Future<AppResult<CommunicationItem>> publish(
    CommunicationItem draft, {
    required CommunicationRole role,
  }) async =>
      CommunicationCenterPermissions.forRole(role).canPublish
          ? AppSuccess(draft)
          : const AppError(
              AppFailure(
                message: 'Yayınlama izni yok.',
                code: 'communication_forbidden',
              ),
            );

  @override
  Future<AppResult<CommunicationItem>> schedule(
    ScheduleCommunicationCommand command, {
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) async {
    if (!CommunicationCenterPermissions.forRole(role).canSchedule) {
      return const AppError(
        AppFailure(
          message: 'Bu iletiyi planlama yetkiniz yok.',
          code: 'schedule_permission_denied',
        ),
      );
    }
    if (scenario == CommunicationFixtureScenario.offline) {
      return const AppError(
        AppFailure(
          message: 'Çevrimdışıyken ileti planlanamaz.',
          code: 'schedule_offline',
        ),
      );
    }
    if (scenario == CommunicationFixtureScenario.scheduleFailure) {
      return const AppError(
        AppFailure(
          message: 'İleti şu anda planlanamadı.',
          code: 'schedule_repository_failure',
        ),
      );
    }
    final validationError = command.draft.validationError;
    if (validationError != null) {
      return AppError(
        AppFailure(message: validationError, code: 'schedule_invalid_draft'),
      );
    }
    final schedule = command.draft.schedule;
    if (schedule == null) {
      return const AppError(
        AppFailure(
          message: 'Planlama tarihi ve saati gereklidir.',
          code: 'schedule_time_required',
        ),
      );
    }
    if (!schedule.publishAt.isAfter(command.now)) {
      return const AppError(
        AppFailure(
          message: 'Planlama zamanı gelecekte olmalıdır.',
          code: 'schedule_time_not_future',
        ),
      );
    }
    if (command.resolvedAudience.recipientIds.isEmpty) {
      return const AppError(
        AppFailure(
          message: 'Çözümlenmiş bir hedef kitle gereklidir.',
          code: 'schedule_audience_unresolved',
        ),
      );
    }
    final existing = _scheduledByKey[command.idempotencyKey];
    if (existing != null) return AppSuccess(existing);

    final recipientCount = command.resolvedAudience.totalUniqueRecipients;
    final item = CommunicationItem(
      id: SwanId(
        'scheduled_${(_scheduledItems.length + 1).toString().padLeft(4, '0')}',
      ),
      type: command.type,
      priority: command.draft.priority,
      status: CommunicationStatus.scheduled,
      title: command.draft.title.trim(),
      body: command.draft.body.trim(),
      audience: command.draft.audience,
      recipients: RecipientSummary(
        total: recipientCount,
        resolved: recipientCount,
      ),
      delivery: const DeliverySummary(
        queued: 0,
        sent: 0,
        delivered: 0,
        read: 0,
        acknowledged: 0,
        failed: 0,
      ),
      acknowledgement: AcknowledgementSummary(
        status: command.draft.requiresAcknowledgement
            ? AcknowledgementStatus.pending
            : AcknowledgementStatus.notRequired,
        required: command.draft.requiresAcknowledgement ? recipientCount : 0,
        acknowledged: 0,
      ),
      attachments: command.draft.attachments,
      publishedAt: command.now,
      sender: command.senderId.value,
      schedule: schedule,
    );
    _scheduledItems.add(item);
    _scheduledByKey[command.idempotencyKey] = item;
    return AppSuccess(item);
  }

  @override
  Future<AppResult<CommunicationAcknowledgementResult>> acknowledge(
    AcknowledgeCommunicationCommand command, {
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) async {
    if (!CommunicationCenterPermissions.forRole(command.role).canAcknowledge) {
      return const AppError(
        AppFailure(
          message: 'Bu iletiyi onaylama yetkiniz yok.',
          code: 'acknowledgement_permission_denied',
        ),
      );
    }
    if (scenario == CommunicationFixtureScenario.offline) {
      return const AppError(
        AppFailure(
          message: 'Çevrimdışıyken ileti onaylanamaz.',
          code: 'acknowledgement_offline',
        ),
      );
    }
    if (scenario == CommunicationFixtureScenario.acknowledgementFailure) {
      return const AppError(
        AppFailure(
          message: 'Onay şu anda kaydedilemedi.',
          code: 'acknowledgement_repository_failure',
        ),
      );
    }
    final original = [...source.items, ..._scheduledItems]
        .where((item) => item.id.value == command.communicationId.value)
        .firstOrNull;
    if (original == null) {
      return const AppError(
        AppFailure(
          message: 'İleti bulunamadı.',
          code: 'acknowledgement_not_found',
        ),
      );
    }
    final item = _acknowledgementItemOverrides[original.id.value] ?? original;
    if (item.status != CommunicationStatus.published) {
      return const AppError(
        AppFailure(
          message: 'Bu ileti henüz onaylanabilir durumda değil.',
          code: 'acknowledgement_unavailable',
        ),
      );
    }
    if (item.acknowledgement.status == AcknowledgementStatus.notRequired) {
      return const AppError(
        AppFailure(
          message: 'Bu ileti için onay gerekmiyor.',
          code: 'acknowledgement_not_required',
        ),
      );
    }
    final eligible =
        _eligibleAcknowledgementRecipients[item.id.value] ?? const <String>{};
    if (!eligible.contains(command.recipientId.value) ||
        !_recipientMatchesRole(command.recipientId.value, command.role)) {
      return const AppError(
        AppFailure(
          message: 'Bu ileti için uygun alıcı değilsiniz.',
          code: 'acknowledgement_ineligible',
        ),
      );
    }

    final entries = _acknowledgements.putIfAbsent(
      item.id.value,
      () => <String, DateTime>{},
    );
    final timestamp = entries.putIfAbsent(
      command.recipientId.value,
      () => command.acknowledgedAt,
    );
    final required = item.acknowledgement.required;
    final baseAcknowledged = original.acknowledgement.acknowledged;
    final acknowledged = (baseAcknowledged + entries.length).clamp(0, required);
    final updated = item.copyWith(
      acknowledgement: AcknowledgementSummary(
        status: acknowledged == required
            ? AcknowledgementStatus.acknowledged
            : item.acknowledgement.status == AcknowledgementStatus.overdue
                ? AcknowledgementStatus.overdue
                : AcknowledgementStatus.pending,
        required: required,
        acknowledged: acknowledged,
      ),
    );
    _acknowledgementItemOverrides[item.id.value] = updated;
    return AppSuccess(
      CommunicationAcknowledgementResult(
        item: updated,
        eligibleCount: required,
        acknowledgedCount: acknowledged,
        pendingCount: required - acknowledged,
        overdueCount:
            updated.acknowledgement.status == AcknowledgementStatus.overdue
                ? required - acknowledged
                : 0,
        actingUserAcknowledged: true,
        actingUserAcknowledgedAt: timestamp,
      ),
    );
  }

  bool _recipientMatchesRole(String recipientId, CommunicationRole role) =>
      switch (role) {
        CommunicationRole.athlete => recipientId.startsWith('athlete_'),
        CommunicationRole.guardian => recipientId.startsWith('guardian_'),
        _ => false,
      };
}
