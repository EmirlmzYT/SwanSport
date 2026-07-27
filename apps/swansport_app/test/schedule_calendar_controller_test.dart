import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/application/schedule_calendar_controller.dart';
import 'package:swansport_app/features/calendar/application/schedule_calendar_state.dart';
import 'package:swansport_app/features/calendar/data/fixtures/schedule_calendar_fixture_data_source.dart';
import 'package:swansport_app/features/calendar/data/repositories/fixture_schedule_calendar_repository.dart';
import 'package:swansport_app/features/calendar/domain/models/calendar_workspace.dart';
import 'package:swansport_app/features/calendar/domain/repositories/schedule_calendar_repository.dart';

void main() {
  FixtureScheduleCalendarRepository repository() =>
      const FixtureScheduleCalendarRepository(
        FixtureScheduleCalendarDataSource(),
      );

  test('loads data-driven calendar workspace', () async {
    final controller = ScheduleCalendarController(repository: repository());
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, ScheduleCalendarStatus.loaded);
    expect(controller.state.visibleEvents, isNotEmpty);
    expect(controller.state.analytics?.weeklyEventCount, 4);
  });

  test('preserves selected date and filters while switching view', () async {
    final controller = ScheduleCalendarController(repository: repository());
    await Future<void>.delayed(Duration.zero);
    final selected = DateTime(2026, 7, 22);
    const filters =
        CalendarFilterState(eventTypes: {CalendarEventType.training});
    await controller.applyFilters(filters);
    await controller.selectDate(selected);
    await controller.switchViewMode(CalendarViewMode.week);

    expect(controller.state.selectedDate, selected);
    expect(controller.state.activeFilters.eventTypes, filters.eventTypes);
    expect(controller.state.selectedViewMode, CalendarViewMode.week);
  });

  test('supports empty, error, offline and permission-filtered fixtures',
      () async {
    final empty = ScheduleCalendarController(
      repository: repository(),
      scenario: ScheduleCalendarFixtureScenario.empty,
    );
    await Future<void>.delayed(Duration.zero);
    expect(empty.state.status, ScheduleCalendarStatus.empty);

    final failed = ScheduleCalendarController(
      repository: repository(),
      scenario: ScheduleCalendarFixtureScenario.error,
    );
    await Future<void>.delayed(Duration.zero);
    expect(failed.state.status, ScheduleCalendarStatus.error);

    final athlete = ScheduleCalendarController(
      repository: repository(),
      role: CalendarRole.athlete,
      scenario: ScheduleCalendarFixtureScenario.offline,
    );
    await Future<void>.delayed(Duration.zero);
    expect(athlete.state.isOffline, isTrue);
    expect(athlete.state.permissions.canViewRSVP, isFalse);
    expect(athlete.state.visibleEvents.first.rsvpSummary, isNull);
  });

  test('honors cancelled recurrence occurrences and partial analytics failures',
      () async {
    final recurring = const FixtureScheduleCalendarDataSource().events.first;
    expect(recurring.occursOn(DateTime(2026, 7, 29)), isFalse);
    expect(
      recurring.exceptionFor(DateTime(2026, 8, 5))?.type,
      RecurrenceExceptionType.modified,
    );

    final controller = ScheduleCalendarController(
      repository: repository(),
      scenario: ScheduleCalendarFixtureScenario.analyticsFailure,
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.analytics, isNull);
    expect(controller.state.sectionFailures, contains('analytics'));
  });
}
