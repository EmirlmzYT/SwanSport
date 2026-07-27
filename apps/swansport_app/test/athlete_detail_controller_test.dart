import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/athlete_workspace/application/athlete_detail_controller.dart';
import 'package:swansport_app/features/athlete_workspace/application/athlete_detail_permissions.dart';
import 'package:swansport_app/features/athlete_workspace/application/athlete_detail_state.dart';
import 'package:swansport_app/features/athlete_workspace/data/fixtures/athlete_detail_fixture_data_source.dart';
import 'package:swansport_app/features/athlete_workspace/data/repositories/fixture_athlete_detail_repository.dart';
import 'package:swansport_app/features/athlete_workspace/domain/models/athlete_detail.dart';
import 'package:swansport_app/features/athlete_workspace/domain/repositories/athlete_detail_repository.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  test('loads fixture athlete detail for a valid athlete id', () async {
    final controller = AthleteDetailController(
      athleteId: const SwanId('athlete_can_yilmaz'),
      repository: const FixtureAthleteDetailRepository(
        AthleteDetailFixtureDataSource(),
      ),
    );

    await controller.load();

    expect(controller.state.status, AthleteDetailStatus.loaded);
    expect(controller.state.detail?.profile.athlete.displayName, 'Can Yılmaz');
    expect(controller.state.detail?.attendance.rateLabel, '%94');

    controller.dispose();
  });

  test('returns not found for an unknown athlete id', () async {
    final controller = AthleteDetailController(
      athleteId: const SwanId('missing_athlete'),
      repository: const FixtureAthleteDetailRepository(
        AthleteDetailFixtureDataSource(),
      ),
    );

    await controller.load();

    expect(controller.state.status, AthleteDetailStatus.notFound);
    expect(controller.state.errorMessage, 'Athlete was not found.');

    controller.dispose();
  });

  test('does not select a hidden section for a restricted role', () async {
    final controller = AthleteDetailController(
      athleteId: const SwanId('athlete_can_yilmaz'),
      repository: const FixtureAthleteDetailRepository(
        AthleteDetailFixtureDataSource(),
      ),
      role: AthleteDetailRole.athlete,
    );

    await controller.load();
    controller.selectSection(AthleteDetailSection.notes);

    expect(controller.state.status, AthleteDetailStatus.loaded);
    expect(controller.state.selectedSection, AthleteDetailSection.activity);
    expect(
      controller.state.permissions.canView(AthleteDetailSection.notes),
      isFalse,
    );

    controller.dispose();
  });

  test('permission filters hidden coach notes from controller result',
      () async {
    final controller = AthleteDetailController(
      athleteId: const SwanId('athlete_can_yilmaz'),
      repository: const FixtureAthleteDetailRepository(
        AthleteDetailFixtureDataSource(),
      ),
      role: AthleteDetailRole.athlete,
    );

    await controller.load();

    expect(controller.state.status, AthleteDetailStatus.loaded);
    expect(controller.state.detail?.notes, isEmpty);
    expect(
      controller.state.detail?.timeline
          .where((entry) => entry.type == AthleteTimelineEntryType.note),
      isEmpty,
    );

    controller.dispose();
  });

  test('maps permission denied failures to permissionDenied state', () async {
    final controller = AthleteDetailController(
      athleteId: const SwanId('athlete_can_yilmaz'),
      repository: const _FailureAthleteDetailRepository(
        AppFailure(
          message: 'Permission denied for athlete detail.',
          code: 'athlete_permission_denied',
        ),
      ),
    );

    await controller.load();

    expect(controller.state.status, AthleteDetailStatus.permissionDenied);
    expect(
      controller.state.errorMessage,
      'Permission denied for athlete detail.',
    );

    controller.dispose();
  });

  test('maps unexpected failures to full error state', () async {
    final controller = AthleteDetailController(
      athleteId: const SwanId('athlete_can_yilmaz'),
      repository: const _FailureAthleteDetailRepository(
        AppFailure(
          message: 'Fixture transport failed.',
          code: 'fixture_transport_failed',
        ),
      ),
    );

    await controller.load();

    expect(controller.state.status, AthleteDetailStatus.error);
    expect(controller.state.errorMessage, 'Fixture transport failed.');

    controller.dispose();
  });
}

class _FailureAthleteDetailRepository implements AthleteDetailRepository {
  const _FailureAthleteDetailRepository(this.failure);

  final AppFailure failure;

  @override
  Future<AppResult<AthleteDetail>> getAthleteDetail(SwanId athleteId) async {
    return AppError(failure);
  }
}
