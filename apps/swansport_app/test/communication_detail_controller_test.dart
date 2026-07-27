import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_detail_controller.dart';
import 'package:swansport_app/features/announcements/application/communication_detail_state.dart';
import 'package:swansport_app/features/announcements/application/communication_operational_link_resolver.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_app/features/announcements/presentation/routing/communication_detail_route_args.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  FixtureCommunicationCenterRepository repository() =>
      FixtureCommunicationCenterRepository(
        const FixtureCommunicationCenterDataSource(),
      );

  test('repository performs value-based successful detail lookup', () async {
    final result = await repository().getDetail(
      const SwanId('communication_${'facility'}'),
      role: CommunicationRole.headCoach,
    );
    expect(result, isA<AppSuccess<CommunicationItem>>());
    expect(
      (result as AppSuccess<CommunicationItem>).value.id.value,
      'communication_facility',
    );
  });

  test('repository maps not found, permission, offline and failure', () async {
    final subject = repository();
    final missing = await subject.getDetail(
      const SwanId('missing'),
      role: CommunicationRole.headCoach,
    );
    expect(
      (missing as AppError<CommunicationItem>).failure.code,
      'communication_not_found',
    );
    final denied = await subject.getDetail(
      const SwanId('communication_facility'),
      role: CommunicationRole.guardian,
    );
    expect(
      (denied as AppError<CommunicationItem>).failure.code,
      'communication_detail_permission_denied',
    );
    final offline = await subject.getDetail(
      const SwanId('communication_emergency'),
      role: CommunicationRole.athlete,
      scenario: CommunicationFixtureScenario.offline,
    );
    expect(offline, isA<AppSuccess<CommunicationItem>>());
    final failure = await subject.getDetail(
      const SwanId('communication_emergency'),
      role: CommunicationRole.athlete,
      scenario: CommunicationFixtureScenario.error,
    );
    expect(
      (failure as AppError<CommunicationItem>).failure.code,
      'communication_detail_failure',
    );
  });

  test('controller maps loaded, offline, unavailable and failure states',
      () async {
    CommunicationDetailController create(
      String id, {
      CommunicationRole role = CommunicationRole.headCoach,
      CommunicationFixtureScenario scenario =
          CommunicationFixtureScenario.normal,
    }) =>
        CommunicationDetailController(
          repository: repository(),
          args: CommunicationDetailRouteArgs(
            communicationId: SwanId(id),
            role: role,
          ),
          scenario: scenario,
        );

    final loaded = create('communication_facility');
    await Future<void>.delayed(Duration.zero);
    expect(loaded.state.status, CommunicationDetailStatus.loaded);
    expect(loaded.state.permissions.canViewDelivery, isTrue);

    final offline = create(
      'communication_emergency',
      role: CommunicationRole.athlete,
      scenario: CommunicationFixtureScenario.offline,
    );
    await Future<void>.delayed(Duration.zero);
    expect(offline.state.status, CommunicationDetailStatus.offlineCached);
    expect(offline.state.permissions.canViewDelivery, isFalse);

    final unavailable = create('communication_cancelled');
    await Future<void>.delayed(Duration.zero);
    expect(unavailable.state.status, CommunicationDetailStatus.unavailable);

    final failed = create(
      'communication_emergency',
      scenario: CommunicationFixtureScenario.error,
    );
    await Future<void>.delayed(Duration.zero);
    expect(failed.state.status, CommunicationDetailStatus.failure);
  });

  test('detail acknowledgement reuses mutation and keeps read distinct',
      () async {
    final subject = CommunicationDetailController(
      repository: repository(),
      args: const CommunicationDetailRouteArgs(
        communicationId: SwanId('communication_emergency'),
        role: CommunicationRole.athlete,
      ),
      clock: () => DateTime(2026, 7, 23, 17),
    );
    await Future<void>.delayed(Duration.zero);
    final originalRead = subject.state.item!.delivery.read;
    await subject.acknowledge();
    expect(subject.state.acknowledgementResult!.actingUserAcknowledged, isTrue);
    expect(subject.state.item!.acknowledgement.acknowledged, 43);
    expect(subject.state.item!.delivery.read, originalRead);
  });

  test('operational links are permission and lifecycle filtered', () {
    const resolver = CommunicationOperationalLinkResolver();
    final facility = const FixtureCommunicationCenterDataSource()
        .items
        .singleWhere((item) => item.id.value == 'communication_facility');
    final cancelled = const FixtureCommunicationCenterDataSource()
        .items
        .singleWhere((item) => item.id.value == 'communication_cancelled');

    expect(
      resolver.resolve(item: facility, role: CommunicationRole.headCoach),
      hasLength(1),
    );
    expect(
      resolver.resolve(item: facility, role: CommunicationRole.guardian),
      isEmpty,
    );
    expect(
      resolver.resolve(item: cancelled, role: CommunicationRole.headCoach),
      isEmpty,
    );
  });

  test('linked navigation guard rejects duplicate taps and resets', () async {
    final subject = CommunicationDetailController(
      repository: repository(),
      args: const CommunicationDetailRouteArgs(
        communicationId: SwanId('communication_facility'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final link = subject.operationalLinks.single;

    expect(subject.beginLinkedNavigation(link), isTrue);
    expect(subject.beginLinkedNavigation(link), isFalse);
    subject.completeLinkedNavigation();
    expect(subject.beginLinkedNavigation(link), isTrue);
  });
}
