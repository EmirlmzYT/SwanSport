import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';

import '../data/fixtures/schedule_calendar_fixture_data_source.dart';
import '../data/repositories/fixture_schedule_calendar_repository.dart';
import '../domain/models/calendar_workspace.dart';
import '../domain/repositories/schedule_calendar_repository.dart';
import 'schedule_calendar_state.dart';

final scheduleCalendarFixtureDataSourceProvider =
    Provider<FixtureScheduleCalendarDataSource>(
  (ref) => const FixtureScheduleCalendarDataSource(),
);

final scheduleCalendarRepositoryProvider = Provider<ScheduleCalendarRepository>(
  (ref) => FixtureScheduleCalendarRepository(
    ref.watch(scheduleCalendarFixtureDataSourceProvider),
  ),
);

final scheduleCalendarControllerProvider = StateNotifierProvider.autoDispose<
    ScheduleCalendarController, ScheduleCalendarState>(
  (ref) => ScheduleCalendarController(
    repository: ref.watch(scheduleCalendarRepositoryProvider),
  ),
);

class ScheduleCalendarController extends StateNotifier<ScheduleCalendarState> {
  ScheduleCalendarController({
    required ScheduleCalendarRepository repository,
    CalendarRole role = CalendarRole.headCoach,
    ScheduleCalendarFixtureScenario scenario =
        ScheduleCalendarFixtureScenario.normal,
  })  : _repository = repository,
        _scenario = scenario,
        super(ScheduleCalendarState.loading(role: role)) {
    load();
  }

  final ScheduleCalendarRepository _repository;
  final ScheduleCalendarFixtureScenario _scenario;

  Future<void> load() async {
    final result = await _repository.loadWorkspace(
      dateRange: state.dateRange,
      filters: state.activeFilters,
      role: state.role,
      scenario: _scenario,
    );
    switch (result) {
      case AppSuccess<ScheduleCalendarWorkspace>(value: final workspace):
        final status = workspace.events.isEmpty
            ? ScheduleCalendarStatus.empty
            : ScheduleCalendarStatus.loaded;
        state = state.copyWith(
          status: status,
          visibleEvents: workspace.events,
          analytics: workspace.analytics,
          clearAnalytics: workspace.analytics == null,
          permissions: workspace.permissions,
          sectionFailures: workspace.sectionFailures,
          isOffline: workspace.isOffline,
          isStale: workspace.isStale,
          lastSyncedAt: workspace.lastSyncedAt,
          errorMessage: null,
        );
      case AppError<ScheduleCalendarWorkspace>(failure: final failure):
        state = state.copyWith(
          status: ScheduleCalendarStatus.error,
          errorMessage: failure.message,
        );
    }
  }

  Future<void> switchViewMode(CalendarViewMode viewMode) async {
    state = state.copyWith(
      selectedViewMode: viewMode,
      dateRange: CalendarDateRange.forView(state.selectedDate, viewMode),
    );
    await load();
  }

  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(
      selectedDate: date,
      dateRange: CalendarDateRange.forView(date, state.selectedViewMode),
    );
    await load();
  }

  Future<void> applyFilters(CalendarFilterState filters) async {
    state = state.copyWith(activeFilters: filters);
    await load();
  }

  void selectEvent(CalendarEvent event) =>
      state = state.copyWith(selectedEvent: event);

  Future<void> refresh() => load();
}
