import 'package:swansport_core/swansport_core.dart';

import '../models/calendar_workspace.dart';

enum ScheduleCalendarFixtureScenario {
  normal,
  empty,
  error,
  offline,
  stale,
  analyticsFailure,
  eventsFailure
}

abstract class ScheduleCalendarRepository {
  Future<AppResult<ScheduleCalendarWorkspace>> loadWorkspace({
    required CalendarDateRange dateRange,
    required CalendarFilterState filters,
    required CalendarRole role,
    ScheduleCalendarFixtureScenario scenario =
        ScheduleCalendarFixtureScenario.normal,
  });
}
