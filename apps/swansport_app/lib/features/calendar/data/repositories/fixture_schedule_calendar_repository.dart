import 'package:swansport_core/swansport_core.dart';

import '../../application/schedule_calendar_permissions.dart';
import '../../domain/models/calendar_workspace.dart';
import '../../domain/repositories/schedule_calendar_repository.dart';
import '../fixtures/schedule_calendar_fixture_data_source.dart';

class FixtureScheduleCalendarRepository implements ScheduleCalendarRepository {
  const FixtureScheduleCalendarRepository(this._dataSource);

  final FixtureScheduleCalendarDataSource _dataSource;

  @override
  Future<AppResult<ScheduleCalendarWorkspace>> loadWorkspace({
    required CalendarDateRange dateRange,
    required CalendarFilterState filters,
    required CalendarRole role,
    ScheduleCalendarFixtureScenario scenario =
        ScheduleCalendarFixtureScenario.normal,
  }) async {
    if (scenario == ScheduleCalendarFixtureScenario.error) {
      return const AppError(
        AppFailure(
          message: 'Takvim verileri yüklenemedi.',
          code: 'calendar_load_failed',
        ),
      );
    }

    final permissions = ScheduleCalendarPermissions.forRole(role);
    final events = scenario == ScheduleCalendarFixtureScenario.empty
        ? const <CalendarEvent>[]
        : _dataSource.events
            .where((event) => _occursInRange(event, dateRange))
            .where(filters.matches)
            .where(
              (event) =>
                  permissions.canViewAllEvents || event.isVisibleToParticipants,
            )
            .map((event) => permissions.canViewRSVP ? event : event.copyWith())
            .toList(growable: false);

    return AppSuccess(
      ScheduleCalendarWorkspace(
        events: scenario == ScheduleCalendarFixtureScenario.eventsFailure
            ? const []
            : events,
        analytics: scenario == ScheduleCalendarFixtureScenario.analyticsFailure
            ? null
            : _dataSource.analytics,
        permissions: permissions,
        isOffline: scenario == ScheduleCalendarFixtureScenario.offline,
        isStale: scenario == ScheduleCalendarFixtureScenario.stale,
        lastSyncedAt: DateTime(2026, 7, 22, 12),
        sectionFailures: {
          if (scenario == ScheduleCalendarFixtureScenario.analyticsFailure)
            'analytics': 'Analitik verileri şu an kullanılamıyor.',
          if (scenario == ScheduleCalendarFixtureScenario.eventsFailure)
            'events': 'Etkinlikler şu an kullanılamıyor.',
        },
      ),
    );
  }

  bool _occursInRange(CalendarEvent event, CalendarDateRange range) {
    for (var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))) {
      if (range.contains(event.start) || event.occursOn(day)) return true;
    }
    return false;
  }
}
