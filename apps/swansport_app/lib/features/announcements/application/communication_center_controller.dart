import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../data/fixtures/communication_center_fixture_data_source.dart';
import '../data/fixtures/fixture_audience_resolver.dart';
import '../data/repositories/fixture_communication_center_repository.dart';
import '../domain/models/acknowledge_communication_command.dart';
import '../domain/models/audience_resolution.dart';
import '../domain/models/communication_center.dart';
import '../domain/models/schedule_communication_command.dart';
import '../domain/repositories/communication_center_repository.dart';
import 'communication_center_state.dart';
import 'communication_composer_draft.dart';

typedef CommunicationClock = DateTime Function();

final communicationCenterFixtureDataSourceProvider =
    Provider<FixtureCommunicationCenterDataSource>(
  (ref) => const FixtureCommunicationCenterDataSource(),
);
final communicationCenterRepositoryProvider =
    Provider<CommunicationCenterRepository>(
  (ref) => FixtureCommunicationCenterRepository(
    ref.watch(communicationCenterFixtureDataSourceProvider),
  ),
);
final communicationCenterControllerProvider = StateNotifierProvider.autoDispose<
    CommunicationCenterController, CommunicationCenterState>(
  (ref) => CommunicationCenterController(
    repository: ref.watch(communicationCenterRepositoryProvider),
    audienceResolver: const FixtureAudienceResolver(),
  ),
);

class CommunicationCenterController
    extends StateNotifier<CommunicationCenterState> {
  CommunicationCenterController({
    required CommunicationCenterRepository repository,
    AudienceResolver audienceResolver = const FixtureAudienceResolver(),
    CommunicationRole role = CommunicationRole.headCoach,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    CommunicationClock clock = DateTime.now,
    SwanId actingRecipientId = const SwanId('athlete_eligible'),
  })  : _repository = repository,
        _scenario = scenario,
        _audienceResolver = audienceResolver,
        _clock = clock,
        _actingRecipientId = actingRecipientId,
        super(CommunicationCenterState.loading(role: role)) {
    load();
  }
  final CommunicationCenterRepository _repository;
  final CommunicationFixtureScenario _scenario;
  final AudienceResolver _audienceResolver;
  final CommunicationClock _clock;
  final SwanId _actingRecipientId;
  SwanId get actingRecipientId => _actingRecipientId;
  int _audienceResolutionRequest = 0;
  int _scheduleRequest = 0;
  int _acknowledgementRequest = 0;
  Future<void> load() async {
    final result = await _repository.loadWorkspace(
      filters: state.filters,
      role: state.role,
      scenario: _scenario,
    );
    switch (result) {
      case AppSuccess<CommunicationWorkspace>(value: final workspace):
        state = state.copyWith(
          status: workspace.items.isEmpty && workspace.sectionFailures.isEmpty
              ? CommunicationCenterStatus.empty
              : CommunicationCenterStatus.loaded,
          workspace: workspace,
          permissions: workspace.permissions,
        );
      case AppError<CommunicationWorkspace>(failure: final failure):
        state = state.copyWith(
          status: CommunicationCenterStatus.error,
          errorMessage: failure.message,
        );
    }
  }

  Future<void> applyFilters(CommunicationFilterState filters) async {
    state = state.copyWith(
      filters: CommunicationFilterState(
        types: filters.types,
        query: state.searchQuery,
      ),
    );
    await load();
  }

  Future<void> updateSearch(String query) async {
    state = state.copyWith(
      searchQuery: query,
      filters: CommunicationFilterState(
        types: state.filters.types,
        query: query,
      ),
    );
    await load();
  }

  Future<void> clearSearch() => updateSearch('');

  void select(CommunicationItem item) => state = state.copyWith(selected: item);
  void updateComposer(CommunicationComposerDraft draft) {
    final audienceChanged =
        !_sameAudience(state.composerDraft.audience, draft.audience);
    if (audienceChanged) _audienceResolutionRequest++;
    _scheduleRequest++;
    state = state.copyWith(
      composerDraft: draft,
      audienceResolutionStatus: audienceChanged
          ? AudienceResolutionStatus.idle
          : state.audienceResolutionStatus,
      clearAudienceResolution: audienceChanged,
      schedulingStatus: CommunicationSchedulingStatus.idle,
      clearSchedulingResult: true,
    );
  }

  void updateDraftAudience(CommunicationAudience audience) =>
      updateComposer(state.composerDraft.copyWith(audience: audience));

  Future<void> resolveDraftAudience() async {
    final request = ++_audienceResolutionRequest;
    state = state.copyWith(
      audienceResolutionStatus: AudienceResolutionStatus.resolving,
      clearAudienceResolution: true,
    );
    final result = await _audienceResolver.resolve(
      state.composerDraft.audience,
      role: state.role,
    );
    if (request != _audienceResolutionRequest) return;
    switch (result) {
      case AppSuccess<ResolvedAudience>(value: final audience):
        state = state.copyWith(
          audienceResolutionStatus: AudienceResolutionStatus.resolved,
          resolvedAudience: audience,
          clearAudienceResolution: true,
        );
      case AppError<ResolvedAudience>(failure: final failure):
        final status = switch (failure.code) {
          'audience_empty' ||
          'audience_unsupported' =>
            AudienceResolutionStatus.validationFailure,
          'audience_permission_denied' =>
            AudienceResolutionStatus.permissionFailure,
          _ => AudienceResolutionStatus.repositoryFailure,
        };
        state = state.copyWith(
          audienceResolutionStatus: status,
          audienceResolutionError: failure.message,
          clearAudienceResolution: true,
        );
    }
  }

  Future<void> refreshAudiencePreview() => resolveDraftAudience();

  void clearAudiencePreview() {
    _audienceResolutionRequest++;
    state = state.copyWith(
      audienceResolutionStatus: AudienceResolutionStatus.idle,
      clearAudienceResolution: true,
    );
  }

  Future<void> scheduleCurrentDraft() async {
    if (state.schedulingStatus == CommunicationSchedulingStatus.scheduling) {
      return;
    }
    final request = ++_scheduleRequest;
    final draft = state.composerDraft;
    state = state.copyWith(
      schedulingStatus: CommunicationSchedulingStatus.validating,
      clearSchedulingResult: true,
    );
    if (!state.permissions.canSchedule) {
      state = state.copyWith(
        schedulingStatus: CommunicationSchedulingStatus.permissionFailure,
        schedulingError: 'Bu iletiyi planlama yetkiniz yok.',
      );
      return;
    }
    if (_scenario == CommunicationFixtureScenario.offline) {
      state = state.copyWith(
        schedulingStatus: CommunicationSchedulingStatus.offlineFailure,
        schedulingError: 'Çevrimdışıyken ileti planlanamaz.',
      );
      return;
    }
    final validationError = draft.validationError;
    if (validationError != null) {
      state = state.copyWith(
        schedulingStatus: CommunicationSchedulingStatus.validationFailure,
        schedulingError: validationError,
      );
      return;
    }
    final schedule = draft.schedule;
    if (schedule == null) {
      state = state.copyWith(
        schedulingStatus: CommunicationSchedulingStatus.validationFailure,
        schedulingError: 'Planlama tarihi ve saati gereklidir.',
      );
      return;
    }
    final now = _clock();
    if (!schedule.publishAt.isAfter(now)) {
      state = state.copyWith(
        schedulingStatus: CommunicationSchedulingStatus.validationFailure,
        schedulingError: 'Planlama zamanı gelecekte olmalıdır.',
      );
      return;
    }
    final resolved = state.resolvedAudience;
    if (state.audienceResolutionStatus != AudienceResolutionStatus.resolved ||
        resolved == null ||
        resolved.recipientIds.isEmpty) {
      state = state.copyWith(
        schedulingStatus: CommunicationSchedulingStatus.validationFailure,
        schedulingError: 'Hedef kitle planlamadan önce çözümlenmelidir.',
      );
      return;
    }

    state = state.copyWith(
      schedulingStatus: CommunicationSchedulingStatus.scheduling,
    );
    final result = await _repository.schedule(
      ScheduleCommunicationCommand(
        draft: draft,
        resolvedAudience: resolved,
        type: draft.type,
        senderId: SwanId('sender_${state.role.name}'),
        now: now,
        idempotencyKey: _scheduleKey(draft, resolved),
      ),
      role: state.role,
      scenario: _scenario,
    );
    if (request != _scheduleRequest) return;
    switch (result) {
      case AppSuccess<CommunicationItem>(value: final item):
        state = state.copyWith(
          composerDraft: const CommunicationComposerDraft(),
          schedulingStatus: CommunicationSchedulingStatus.success,
          scheduledItem: item,
          clearAudienceResolution: true,
        );
        await load();
      case AppError<CommunicationItem>(failure: final failure):
        final status = switch (failure.code) {
          'schedule_permission_denied' =>
            CommunicationSchedulingStatus.permissionFailure,
          'schedule_offline' => CommunicationSchedulingStatus.offlineFailure,
          'schedule_invalid_draft' ||
          'schedule_time_required' ||
          'schedule_time_not_future' ||
          'schedule_audience_unresolved' =>
            CommunicationSchedulingStatus.validationFailure,
          _ => CommunicationSchedulingStatus.repositoryFailure,
        };
        state = state.copyWith(
          schedulingStatus: status,
          schedulingError: failure.message,
        );
    }
  }

  String _scheduleKey(
    CommunicationComposerDraft draft,
    ResolvedAudience audience,
  ) =>
      [
        draft.title.trim(),
        draft.body.trim(),
        draft.schedule?.publishAt.toIso8601String(),
        ...audience.recipientIds.map((id) => id.value),
      ].join('|');

  bool _sameAudience(
    CommunicationAudience first,
    CommunicationAudience second,
  ) {
    final firstIds = first.recipientIds.map((id) => id.value).toSet();
    final secondIds = second.recipientIds.map((id) => id.value).toSet();
    return first.segments.length == second.segments.length &&
        first.segments.containsAll(second.segments) &&
        firstIds.length == secondIds.length &&
        firstIds.containsAll(secondIds);
  }

  bool canAcknowledge(CommunicationItem item) =>
      state.permissions.canAcknowledge &&
      item.status == CommunicationStatus.published &&
      item.acknowledgement.status != AcknowledgementStatus.notRequired;

  Future<void> acknowledgeCommunication(SwanId communicationId) async {
    if (state.acknowledgementOperationStatus ==
            CommunicationAcknowledgementOperationStatus.submitting &&
        state.acknowledgementCommunicationId == communicationId.value) {
      return;
    }
    final request = ++_acknowledgementRequest;
    state = state.copyWith(
      acknowledgementOperationStatus:
          CommunicationAcknowledgementOperationStatus.submitting,
      acknowledgementCommunicationId: communicationId.value,
      clearAcknowledgementOperation: true,
    );
    final item = state.workspace?.items
        .where((entry) => entry.id.value == communicationId.value)
        .firstOrNull;
    if (item == null) {
      state = state.copyWith(
        acknowledgementOperationStatus:
            CommunicationAcknowledgementOperationStatus.validationFailure,
        acknowledgementError: 'İleti bulunamadı.',
        acknowledgementCommunicationId: communicationId.value,
      );
      return;
    }
    if (!state.permissions.canAcknowledge) {
      state = state.copyWith(
        acknowledgementOperationStatus:
            CommunicationAcknowledgementOperationStatus.permissionFailure,
        acknowledgementError: 'Bu iletiyi onaylama yetkiniz yok.',
        acknowledgementCommunicationId: communicationId.value,
      );
      return;
    }
    if (_scenario == CommunicationFixtureScenario.offline) {
      state = state.copyWith(
        acknowledgementOperationStatus:
            CommunicationAcknowledgementOperationStatus.offlineFailure,
        acknowledgementError: 'Çevrimdışıyken ileti onaylanamaz.',
        acknowledgementCommunicationId: communicationId.value,
      );
      return;
    }
    if (item.acknowledgement.status == AcknowledgementStatus.notRequired ||
        item.status != CommunicationStatus.published) {
      state = state.copyWith(
        acknowledgementOperationStatus:
            CommunicationAcknowledgementOperationStatus.validationFailure,
        acknowledgementError: item.status != CommunicationStatus.published
            ? 'Bu ileti henüz onaylanabilir durumda değil.'
            : 'Bu ileti için onay gerekmiyor.',
        acknowledgementCommunicationId: communicationId.value,
      );
      return;
    }

    final result = await _repository.acknowledge(
      AcknowledgeCommunicationCommand(
        communicationId: communicationId,
        recipientId: _actingRecipientId,
        role: state.role,
        acknowledgedAt: _clock(),
      ),
      scenario: _scenario,
    );
    if (request != _acknowledgementRequest) return;
    switch (result) {
      case AppSuccess<CommunicationAcknowledgementResult>(
          value: final acknowledgement,
        ):
        await load();
        if (request != _acknowledgementRequest) return;
        state = state.copyWith(
          acknowledgementOperationStatus:
              CommunicationAcknowledgementOperationStatus.success,
          acknowledgementResult: acknowledgement,
          acknowledgementCommunicationId: communicationId.value,
          clearAcknowledgementOperation: true,
        );
      case AppError<CommunicationAcknowledgementResult>(
          failure: final failure,
        ):
        final status = switch (failure.code) {
          'acknowledgement_permission_denied' ||
          'acknowledgement_ineligible' =>
            CommunicationAcknowledgementOperationStatus.permissionFailure,
          'acknowledgement_offline' =>
            CommunicationAcknowledgementOperationStatus.offlineFailure,
          'acknowledgement_not_found' ||
          'acknowledgement_unavailable' ||
          'acknowledgement_not_required' =>
            CommunicationAcknowledgementOperationStatus.validationFailure,
          _ => CommunicationAcknowledgementOperationStatus.repositoryFailure,
        };
        state = state.copyWith(
          acknowledgementOperationStatus: status,
          acknowledgementError: failure.message,
          acknowledgementCommunicationId: communicationId.value,
        );
    }
  }

  void clearAcknowledgementFeedback() {
    _acknowledgementRequest++;
    state = state.copyWith(
      acknowledgementOperationStatus:
          CommunicationAcknowledgementOperationStatus.idle,
      clearAcknowledgementOperation: true,
    );
  }

  Future<void> refresh() => load();
}
