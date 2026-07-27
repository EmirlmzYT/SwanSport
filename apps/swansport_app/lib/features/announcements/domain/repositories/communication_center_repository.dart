import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';
import '../models/acknowledge_communication_command.dart';
import '../models/communication_center.dart';
import '../models/schedule_communication_command.dart';

enum CommunicationFixtureScenario {
  normal,
  empty,
  error,
  offline,
  stale,
  analyticsFailure,
  feedFailure,
  scheduleFailure,
  acknowledgementFailure,
}

abstract class CommunicationCenterRepository {
  Future<AppResult<CommunicationWorkspace>> loadWorkspace({
    required CommunicationFilterState filters,
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  });
  Future<AppResult<CommunicationItem>> getDetail(
    SwanId id, {
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  });
  Future<AppResult<CommunicationItem>> publish(
    CommunicationItem draft, {
    required CommunicationRole role,
  });
  Future<AppResult<CommunicationItem>> schedule(
    ScheduleCommunicationCommand command, {
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  });
  Future<AppResult<CommunicationAcknowledgementResult>> acknowledge(
    AcknowledgeCommunicationCommand command, {
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  });
}
