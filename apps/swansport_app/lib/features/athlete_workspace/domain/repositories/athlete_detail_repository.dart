import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../models/athlete_detail.dart';

abstract class AthleteDetailRepository {
  Future<AppResult<AthleteDetail>> getAthleteDetail(SwanId athleteId);
}
