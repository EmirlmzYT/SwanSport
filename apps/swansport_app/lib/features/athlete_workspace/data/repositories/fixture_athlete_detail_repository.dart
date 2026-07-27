import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../domain/models/athlete_detail.dart';
import '../../domain/repositories/athlete_detail_repository.dart';
import '../fixtures/athlete_detail_fixture_data_source.dart';

class FixtureAthleteDetailRepository implements AthleteDetailRepository {
  const FixtureAthleteDetailRepository(this._dataSource);

  final AthleteDetailFixtureDataSource _dataSource;

  @override
  Future<AppResult<AthleteDetail>> getAthleteDetail(SwanId athleteId) async {
    if (athleteId.isEmpty) {
      return const AppError(
        AppFailure(
          message: 'Athlete id is required.',
          code: 'athlete_id_missing',
        ),
      );
    }

    final detail = _dataSource.findById(athleteId);

    if (detail == null) {
      return const AppError(
        AppFailure(
          message: 'Athlete was not found.',
          code: 'athlete_not_found',
        ),
      );
    }

    return AppSuccess(detail);
  }
}
