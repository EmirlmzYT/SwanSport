import 'package:swansport_models/swansport_models.dart';

enum AthleteDetailEntrySource {
  athleteWorkspace,
  attendance,
  globalSearch,
  calendar,
  directLink,
}

class AthleteDetailRouteArgs {
  const AthleteDetailRouteArgs({
    required this.athleteId,
    this.teamId,
    this.seasonId,
    this.source = AthleteDetailEntrySource.athleteWorkspace,
  });

  final SwanId athleteId;
  final SwanId? teamId;
  final SwanId? seasonId;
  final AthleteDetailEntrySource source;
}
