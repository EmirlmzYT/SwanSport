import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/application/communication_center_state.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';

void main() {
  FixtureCommunicationCenterRepository repository() =>
      FixtureCommunicationCenterRepository(
        const FixtureCommunicationCenterDataSource(),
      );
  test('loads fixture workspace and capabilities', () async {
    final controller = CommunicationCenterController(repository: repository());
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, CommunicationCenterStatus.loaded);
    expect(controller.state.workspace!.analytics!.activeCount, 14);
    expect(controller.state.permissions.canPublish, isTrue);
    expect(controller.state.searchQuery, isEmpty);
  });
  test('searches supported fields case-insensitively and trims whitespace',
      () async {
    final controller = CommunicationCenterController(repository: repository());
    await Future<void>.delayed(Duration.zero);

    await controller.updateSearch('  SEZON  ');
    expect(
      controller.state.workspace!.items.single.id.value,
      'communication_schedule',
    );

    await controller.updateSearch('güvenlik');
    expect(
      controller.state.workspace!.items.single.id.value,
      'communication_emergency',
    );

    await controller.updateSearch('planlanan');
    expect(
      controller.state.workspace!.items.single.id.value,
      'communication_schedule',
    );
  });
  test('combines search with filters, exposes no results, and clears search',
      () async {
    final controller = CommunicationCenterController(repository: repository());
    await Future<void>.delayed(Duration.zero);
    await controller.applyFilters(
      const CommunicationFilterState(types: {CommunicationType.emergency}),
    );
    await controller.updateSearch('sezon');
    expect(controller.state.status, CommunicationCenterStatus.empty);
    expect(controller.state.workspace!.items, isEmpty);

    await controller.clearSearch();
    expect(controller.state.searchQuery, isEmpty);
    expect(controller.state.filters.query, isEmpty);
    expect(
      controller.state.workspace!.items.single.type,
      CommunicationType.emergency,
    );
  });
  test('filters, selects and maps fixture scenarios', () async {
    final controller = CommunicationCenterController(repository: repository());
    await Future<void>.delayed(Duration.zero);
    await controller.applyFilters(
      const CommunicationFilterState(types: {CommunicationType.emergency}),
    );
    expect(
      controller.state.workspace!.items.single.type,
      CommunicationType.emergency,
    );
    controller.select(controller.state.workspace!.items.single);
    expect(
      controller.state.selected!.priority,
      CommunicationPriority.emergency,
    );
    final offline = CommunicationCenterController(
      repository: repository(),
      scenario: CommunicationFixtureScenario.offline,
      role: CommunicationRole.athlete,
    );
    await Future<void>.delayed(Duration.zero);
    expect(offline.state.workspace!.isOffline, isTrue);
    expect(offline.state.workspace!.items.first.delivery.read, 0);
  });
  test('maps empty, failure and partial failure', () async {
    for (final scenario in [
      CommunicationFixtureScenario.empty,
      CommunicationFixtureScenario.analyticsFailure,
      CommunicationFixtureScenario.feedFailure,
    ]) {
      final c = CommunicationCenterController(
        repository: repository(),
        scenario: scenario,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        c.state.status,
        scenario == CommunicationFixtureScenario.empty
            ? CommunicationCenterStatus.empty
            : CommunicationCenterStatus.loaded,
      );
    }
    final failed = CommunicationCenterController(
      repository: repository(),
      scenario: CommunicationFixtureScenario.error,
    );
    await Future<void>.delayed(Duration.zero);
    expect(failed.state.status, CommunicationCenterStatus.error);
  });
}
