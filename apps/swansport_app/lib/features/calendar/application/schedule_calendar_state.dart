import '../domain/models/calendar_workspace.dart';

enum ScheduleCalendarStatus { loading, loaded, empty, error }

class ScheduleCalendarState {
  const ScheduleCalendarState({
    required this.status,
    required this.role,
    required this.selectedDate,
    required this.selectedViewMode,
    required this.activeFilters,
    required this.dateRange,
    required this.permissions,
    this.visibleEvents = const [],
    this.analytics,
    this.selectedEvent,
    this.errorMessage,
    this.sectionFailures = const {},
    this.isOffline = false,
    this.isStale = false,
    this.lastSyncedAt,
  });

  factory ScheduleCalendarState.loading({
    CalendarRole role = CalendarRole.headCoach,
    DateTime? selectedDate,
  }) {
    final date = selectedDate ?? DateTime(2026, 7, 22);
    return ScheduleCalendarState(
      status: ScheduleCalendarStatus.loading,
      role: role,
      selectedDate: date,
      selectedViewMode: CalendarViewMode.agenda,
      activeFilters: const CalendarFilterState(),
      dateRange: CalendarDateRange.forView(date, CalendarViewMode.agenda),
      permissions: const CalendarPermissionSet(
        canViewAllEvents: false,
        canCreateEvent: false,
        canEditEvent: false,
        canCancelEvent: false,
        canRescheduleEvent: false,
        canViewRSVP: false,
        canSubmitRSVP: false,
        canOpenAttendance: false,
        canOverrideSoftConflict: false,
        canViewMedicalEventDetails: false,
      ),
    );
  }

  final ScheduleCalendarStatus status;
  final CalendarRole role;
  final DateTime selectedDate;
  final CalendarViewMode selectedViewMode;
  final CalendarFilterState activeFilters;
  final CalendarDateRange dateRange;
  final CalendarPermissionSet permissions;
  final List<CalendarEvent> visibleEvents;
  final WorkloadAnalytics? analytics;
  final CalendarEvent? selectedEvent;
  final String? errorMessage;
  final Map<String, String> sectionFailures;
  final bool isOffline;
  final bool isStale;
  final DateTime? lastSyncedAt;

  ScheduleCalendarState copyWith({
    ScheduleCalendarStatus? status,
    DateTime? selectedDate,
    CalendarViewMode? selectedViewMode,
    CalendarFilterState? activeFilters,
    CalendarDateRange? dateRange,
    CalendarPermissionSet? permissions,
    List<CalendarEvent>? visibleEvents,
    WorkloadAnalytics? analytics,
    bool clearAnalytics = false,
    CalendarEvent? selectedEvent,
    String? errorMessage,
    Map<String, String>? sectionFailures,
    bool? isOffline,
    bool? isStale,
    DateTime? lastSyncedAt,
  }) =>
      ScheduleCalendarState(
        status: status ?? this.status,
        role: role,
        selectedDate: selectedDate ?? this.selectedDate,
        selectedViewMode: selectedViewMode ?? this.selectedViewMode,
        activeFilters: activeFilters ?? this.activeFilters,
        dateRange: dateRange ?? this.dateRange,
        permissions: permissions ?? this.permissions,
        visibleEvents: visibleEvents ?? this.visibleEvents,
        analytics: clearAnalytics ? null : analytics ?? this.analytics,
        selectedEvent: selectedEvent ?? this.selectedEvent,
        errorMessage: errorMessage ?? this.errorMessage,
        sectionFailures: sectionFailures ?? this.sectionFailures,
        isOffline: isOffline ?? this.isOffline,
        isStale: isStale ?? this.isStale,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}
