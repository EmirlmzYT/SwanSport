import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/acknowledge_communication_command.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  final timestamp = DateTime(2026, 7, 23, 14, 30);

  FixtureCommunicationCenterRepository repository() =>
      FixtureCommunicationCenterRepository(
        const FixtureCommunicationCenterDataSource(),
      );

  AcknowledgeCommunicationCommand command(
    String communicationId, {
    String recipientId = 'athlete_eligible',
    CommunicationRole role = CommunicationRole.athlete,
    DateTime? at,
  }) =>
      AcknowledgeCommunicationCommand(
        communicationId: SwanId(communicationId),
        recipientId: SwanId(recipientId),
        role: role,
        acknowledgedAt: at ?? timestamp,
      );

  test('acknowledges deterministically and reload observes aggregate mutation',
      () async {
    final subject = repository();
    final before = (await subject.loadWorkspace(
      filters: const CommunicationFilterState(),
      role: CommunicationRole.headCoach,
    ) as AppSuccess<CommunicationWorkspace>)
        .value
        .items
        .singleWhere((item) => item.id.value == 'communication_emergency');
    final originalRead = before.delivery.read;
    final originalDeliveryAcknowledged = before.delivery.acknowledged;

    final result = await subject.acknowledge(
      command('communication_emergency'),
    );
    final acknowledgement =
        (result as AppSuccess<CommunicationAcknowledgementResult>).value;
    expect(acknowledgement.actingUserAcknowledged, isTrue);
    expect(acknowledgement.actingUserAcknowledgedAt, timestamp);
    expect(acknowledgement.eligibleCount, 48);
    expect(acknowledgement.acknowledgedCount, 43);
    expect(acknowledgement.pendingCount, 5);
    expect(acknowledgement.item.delivery.read, originalRead);
    expect(
      acknowledgement.item.delivery.acknowledged,
      originalDeliveryAcknowledged,
    );

    final reloaded = (await subject.loadWorkspace(
      filters: const CommunicationFilterState(),
      role: CommunicationRole.headCoach,
    ) as AppSuccess<CommunicationWorkspace>)
        .value
        .items
        .singleWhere((item) => item.id.value == 'communication_emergency');
    expect(reloaded.acknowledgement.acknowledged, 43);
    expect(reloaded.delivery.read, originalRead);
  });

  test('repeated acknowledgement is idempotent and preserves timestamp',
      () async {
    final subject = repository();
    final first = await subject.acknowledge(
      command('communication_emergency'),
    );
    final repeated = await subject.acknowledge(
      command(
        'communication_emergency',
        at: timestamp.add(const Duration(hours: 2)),
      ),
    );
    final firstValue =
        (first as AppSuccess<CommunicationAcknowledgementResult>).value;
    final repeatedValue =
        (repeated as AppSuccess<CommunicationAcknowledgementResult>).value;
    expect(repeatedValue.acknowledgedCount, firstValue.acknowledgedCount);
    expect(
      repeatedValue.actingUserAcknowledgedAt,
      firstValue.actingUserAcknowledgedAt,
    );
  });

  test('actual recipient mutations derive partial-to-full status', () async {
    final subject = repository();
    final recipients = [
      ('athlete_eligible', CommunicationRole.athlete),
      ('guardian_eligible', CommunicationRole.guardian),
      ('athlete_45', CommunicationRole.athlete),
      ('athlete_46', CommunicationRole.athlete),
      ('athlete_47', CommunicationRole.athlete),
      ('athlete_48', CommunicationRole.athlete),
    ];
    CommunicationAcknowledgementResult? latest;
    for (final recipient in recipients) {
      latest = (await subject.acknowledge(
        command(
          'communication_emergency',
          recipientId: recipient.$1,
          role: recipient.$2,
        ),
      ) as AppSuccess<CommunicationAcknowledgementResult>)
          .value;
    }
    expect(latest!.acknowledgedCount, 48);
    expect(latest.pendingCount, 0);
    expect(latest.isFullyAcknowledged, isTrue);
    expect(
      latest.item.acknowledgement.status,
      AcknowledgementStatus.acknowledged,
    );
  });

  test('rejects non-required, scheduled, cancelled and missing communication',
      () async {
    final subject = repository();
    for (final id in [
      'communication_facility',
      'communication_schedule',
      'communication_cancelled',
      'missing',
    ]) {
      expect(
        await subject.acknowledge(command(id)),
        isA<AppError<CommunicationAcknowledgementResult>>(),
      );
    }
  });

  test('rejects unauthorized role, ineligible recipient and offline mutation',
      () async {
    final subject = repository();
    final unauthorized = await subject.acknowledge(
      command(
        'communication_emergency',
        role: CommunicationRole.headCoach,
      ),
    );
    expect(
      (unauthorized as AppError<CommunicationAcknowledgementResult>)
          .failure
          .code,
      'acknowledgement_permission_denied',
    );
    final ineligible = await subject.acknowledge(
      command('communication_emergency', recipientId: 'athlete_other'),
    );
    expect(
      (ineligible as AppError<CommunicationAcknowledgementResult>).failure.code,
      'acknowledgement_ineligible',
    );
    final offline = await subject.acknowledge(
      command('communication_emergency'),
      scenario: CommunicationFixtureScenario.offline,
    );
    expect(
      (offline as AppError<CommunicationAcknowledgementResult>).failure.code,
      'acknowledgement_offline',
    );
  });

  test('returns privacy-safe recoverable failure and aggregate result',
      () async {
    final subject = repository();
    final failed = await subject.acknowledge(
      command('communication_emergency'),
      scenario: CommunicationFixtureScenario.acknowledgementFailure,
    );
    expect(
      (failed as AppError<CommunicationAcknowledgementResult>).failure.code,
      'acknowledgement_repository_failure',
    );
    final success = await subject.acknowledge(
      command('communication_emergency'),
    );
    final value =
        (success as AppSuccess<CommunicationAcknowledgementResult>).value;
    expect(value.toString(), isNot(contains('@')));
    expect(value.toString(), isNot(contains('+90')));
    expect(value.overdueCount, 0);
  });
}
