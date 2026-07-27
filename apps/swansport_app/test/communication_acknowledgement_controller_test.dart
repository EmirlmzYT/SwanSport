import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/application/communication_center_state.dart';
import 'package:swansport_app/features/announcements/application/communication_composer_draft.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/acknowledge_communication_command.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  final timestamp = DateTime(2026, 7, 23, 15);
  const emergencyId = SwanId('communication_emergency');

  CommunicationCenterController controller({
    CommunicationRole role = CommunicationRole.athlete,
    SwanId actingRecipientId = const SwanId('athlete_eligible'),
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    FixtureCommunicationCenterRepository? repository,
  }) =>
      CommunicationCenterController(
        repository: repository ??
            FixtureCommunicationCenterRepository(
              const FixtureCommunicationCenterDataSource(),
            ),
        role: role,
        actingRecipientId: actingRecipientId,
        scenario: scenario,
        clock: () => timestamp,
      );

  test('starts idle, submits, succeeds and refreshes workspace', () async {
    final subject = controller();
    await Future<void>.delayed(Duration.zero);
    expect(
      subject.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.idle,
    );
    final transitions = <CommunicationAcknowledgementOperationStatus>[];
    subject.addListener(
      (value) => transitions.add(value.acknowledgementOperationStatus),
    );
    await subject.acknowledgeCommunication(emergencyId);
    expect(
      transitions,
      contains(CommunicationAcknowledgementOperationStatus.submitting),
    );
    expect(
      subject.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.success,
    );
    expect(subject.state.acknowledgementResult!.actingUserAcknowledged, isTrue);
    final refreshed = subject.state.workspace!.items
        .singleWhere((item) => item.id.value == emergencyId.value);
    expect(refreshed.acknowledgement.acknowledged, 43);
  });

  test('maps missing and not-required validation failures', () async {
    final subject = controller();
    await Future<void>.delayed(Duration.zero);
    await subject.acknowledgeCommunication(const SwanId('missing'));
    expect(
      subject.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.validationFailure,
    );
    await subject.acknowledgeCommunication(
      const SwanId('communication_facility'),
    );
    expect(
      subject.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.validationFailure,
    );
  });

  test('maps permission, eligibility, offline and repository failures',
      () async {
    final denied = controller(role: CommunicationRole.headCoach);
    await Future<void>.delayed(Duration.zero);
    await denied.acknowledgeCommunication(emergencyId);
    expect(
      denied.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.permissionFailure,
    );

    final ineligible = controller(
      actingRecipientId: const SwanId('athlete_other'),
    );
    await Future<void>.delayed(Duration.zero);
    await ineligible.acknowledgeCommunication(emergencyId);
    expect(
      ineligible.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.permissionFailure,
    );

    final offline = controller(
      scenario: CommunicationFixtureScenario.offline,
    );
    await Future<void>.delayed(Duration.zero);
    await offline.acknowledgeCommunication(emergencyId);
    expect(
      offline.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.offlineFailure,
    );

    final failed = controller(
      scenario: CommunicationFixtureScenario.acknowledgementFailure,
    );
    await Future<void>.delayed(Duration.zero);
    await failed.acknowledgeCommunication(emergencyId);
    expect(
      failed.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.repositoryFailure,
    );
  });

  test('preserves search, filters, composer and scheduling state', () async {
    final subject = controller();
    await Future<void>.delayed(Duration.zero);
    await subject.updateSearch('acil');
    await subject.applyFilters(
      const CommunicationFilterState(types: {CommunicationType.emergency}),
    );
    subject.updateComposer(
      const CommunicationComposerDraft(title: 'Korunan Taslak', body: 'İçerik'),
    );
    await subject.acknowledgeCommunication(emergencyId);
    expect(subject.state.searchQuery, 'acil');
    expect(subject.state.filters.types, {CommunicationType.emergency});
    expect(subject.state.composerDraft.title, 'Korunan Taslak');
    expect(
      subject.state.schedulingStatus,
      CommunicationSchedulingStatus.idle,
    );
  });

  test('repeated acknowledgement remains idempotent', () async {
    final subject = controller();
    await Future<void>.delayed(Duration.zero);
    await subject.acknowledgeCommunication(emergencyId);
    final first = subject.state.acknowledgementResult!;
    await subject.acknowledgeCommunication(emergencyId);
    final repeated = subject.state.acknowledgementResult!;
    expect(repeated.acknowledgedCount, first.acknowledgedCount);
    expect(
      repeated.actingUserAcknowledgedAt,
      first.actingUserAcknowledgedAt,
    );
  });

  test('blocks duplicate action and ignores stale response', () async {
    final repository = _DelayedAcknowledgementRepository();
    final subject = controller(repository: repository);
    await Future<void>.delayed(Duration.zero);
    final first = subject.acknowledgeCommunication(emergencyId);
    final duplicate = subject.acknowledgeCommunication(emergencyId);
    expect(repository.calls, 1);
    await duplicate;
    subject.clearAcknowledgementFeedback();
    repository.completer.complete(
      const AppError(
        AppFailure(
          code: 'acknowledgement_repository_failure',
          message: 'Eski yanıt',
        ),
      ),
    );
    await first;
    expect(
      subject.state.acknowledgementOperationStatus,
      CommunicationAcknowledgementOperationStatus.idle,
    );
    expect(subject.state.acknowledgementError, isNull);
  });
}

class _DelayedAcknowledgementRepository
    extends FixtureCommunicationCenterRepository {
  _DelayedAcknowledgementRepository()
      : super(const FixtureCommunicationCenterDataSource());

  int calls = 0;
  final completer = Completer<AppResult<CommunicationAcknowledgementResult>>();

  @override
  Future<AppResult<CommunicationAcknowledgementResult>> acknowledge(
    AcknowledgeCommunicationCommand command, {
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) {
    calls++;
    return completer.future;
  }
}
