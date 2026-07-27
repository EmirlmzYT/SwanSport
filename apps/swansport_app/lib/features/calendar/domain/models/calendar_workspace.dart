import 'package:swansport_models/swansport_models.dart';

enum CalendarEventType { training, match, meeting }

enum CalendarEventStatus { planned, attendancePending, cancelled }

enum CalendarViewMode { agenda, day, week, facility }

enum RecurrenceFrequency { weekly, customWeekdays }

enum RecurrenceExceptionType { cancelled, modified, futureSeriesBoundary }

enum RSVPStatus { attending, uncertain, unavailable, pending }

enum ConflictSeverity { hardBlocker, softOverlap, advisory }

enum CalendarRole {
  superAdmin,
  clubAdmin,
  headCoach,
  assistantCoach,
  medicalStaff,
  athlete,
  guardian,
}

class CalendarDateRange {
  const CalendarDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    final day = _dateOnly(value);
    return !day.isBefore(_dateOnly(start)) && !day.isAfter(_dateOnly(end));
  }

  static CalendarDateRange forView(DateTime date, CalendarViewMode viewMode) {
    final selected = _dateOnly(date);
    return switch (viewMode) {
      CalendarViewMode.week => CalendarDateRange(
          start: selected.subtract(Duration(days: selected.weekday - 1)),
          end: selected
              .add(Duration(days: DateTime.daysPerWeek - selected.weekday)),
        ),
      _ => CalendarDateRange(start: selected, end: selected),
    };
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class CalendarFilterState {
  const CalendarFilterState({this.eventTypes = const {}, this.facilityId});

  final Set<CalendarEventType> eventTypes;
  final SwanId? facilityId;

  bool matches(CalendarEvent event) {
    final matchesType = eventTypes.isEmpty || eventTypes.contains(event.type);
    final matchesFacility =
        facilityId == null || event.facility.id == facilityId;
    return matchesType && matchesFacility;
  }
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    required this.interval,
    required this.weekdays,
    this.seriesUpdatesFrom,
  });

  final RecurrenceFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final DateTime? seriesUpdatesFrom;

  String get label {
    final days = weekdays.toList()..sort();
    final weekdayLabel = days.map(_weekdayLabel).join(', ');
    return switch (frequency) {
      RecurrenceFrequency.weekly => 'Her hafta $weekdayLabel',
      RecurrenceFrequency.customWeekdays => 'Özel günler: $weekdayLabel',
    };
  }

  static String _weekdayLabel(int weekday) => switch (weekday) {
        DateTime.monday => 'Pazartesi',
        DateTime.tuesday => 'Salı',
        DateTime.wednesday => 'Çarşamba',
        DateTime.thursday => 'Perşembe',
        DateTime.friday => 'Cuma',
        DateTime.saturday => 'Cumartesi',
        _ => 'Pazar',
      };
}

class RecurrenceException {
  const RecurrenceException({
    required this.occurrenceDate,
    required this.type,
    this.modifiedStart,
    this.reason,
  });

  final DateTime occurrenceDate;
  final RecurrenceExceptionType type;
  final DateTime? modifiedStart;
  final String? reason;
}

class RSVPParticipantSummary {
  const RSVPParticipantSummary({
    required this.attending,
    required this.uncertain,
    required this.unavailable,
    required this.pending,
  });

  final int attending;
  final int uncertain;
  final int unavailable;
  final int pending;

  int get total => attending + uncertain + unavailable + pending;

  int countFor(RSVPStatus status) => switch (status) {
        RSVPStatus.attending => attending,
        RSVPStatus.uncertain => uncertain,
        RSVPStatus.unavailable => unavailable,
        RSVPStatus.pending => pending,
      };
}

class ScheduleConflict {
  const ScheduleConflict({
    required this.severity,
    required this.summary,
    required this.isOverridable,
  });

  final ConflictSeverity severity;
  final String summary;
  final bool isOverridable;

  bool get isBlocking => severity == ConflictSeverity.hardBlocker;
}

class FacilitySummary {
  const FacilitySummary({
    required this.id,
    required this.name,
    required this.room,
  });

  final SwanId id;
  final String name;
  final String room;

  String get displayName => '$name • $room';
}

class WorkloadAnalytics {
  const WorkloadAnalytics({
    required this.weeklyEventCount,
    required this.trainingCount,
    required this.matchCount,
    required this.facilityLoadPercent,
    required this.weeklyLoadHours,
    required this.recoveryStatus,
  });

  final int weeklyEventCount;
  final int trainingCount;
  final int matchCount;
  final int facilityLoadPercent;
  final double weeklyLoadHours;
  final String recoveryStatus;
}

class CalendarPermissionSet {
  const CalendarPermissionSet({
    required this.canViewAllEvents,
    required this.canCreateEvent,
    required this.canEditEvent,
    required this.canCancelEvent,
    required this.canRescheduleEvent,
    required this.canViewRSVP,
    required this.canSubmitRSVP,
    required this.canOpenAttendance,
    required this.canOverrideSoftConflict,
    required this.canViewMedicalEventDetails,
  });

  final bool canViewAllEvents;
  final bool canCreateEvent;
  final bool canEditEvent;
  final bool canCancelEvent;
  final bool canRescheduleEvent;
  final bool canViewRSVP;
  final bool canSubmitRSVP;
  final bool canOpenAttendance;
  final bool canOverrideSoftConflict;
  final bool canViewMedicalEventDetails;
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.start,
    required this.end,
    required this.facility,
    required this.recurrenceRule,
    required this.recurrenceExceptions,
    required this.rsvpSummary,
    required this.conflicts,
    this.isVisibleToParticipants = true,
  });

  final SwanId id;
  final CalendarEventType type;
  final CalendarEventStatus status;
  final String title;
  final DateTime start;
  final DateTime end;
  final FacilitySummary facility;
  final RecurrenceRule? recurrenceRule;
  final List<RecurrenceException> recurrenceExceptions;
  final RSVPParticipantSummary? rsvpSummary;
  final List<ScheduleConflict> conflicts;
  final bool isVisibleToParticipants;

  bool occursOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final isInitialOccurrence =
        DateTime(start.year, start.month, start.day) == day;
    final isRecurringOccurrence =
        recurrenceRule?.weekdays.contains(day.weekday) ?? false;
    return (isInitialOccurrence || isRecurringOccurrence) &&
        exceptionFor(day)?.type != RecurrenceExceptionType.cancelled;
  }

  RecurrenceException? exceptionFor(DateTime date) {
    for (final exception in recurrenceExceptions) {
      if (DateTime(
            exception.occurrenceDate.year,
            exception.occurrenceDate.month,
            exception.occurrenceDate.day,
          ) ==
          DateTime(date.year, date.month, date.day)) {
        return exception;
      }
    }
    return null;
  }

  DateTime startForOccurrence(DateTime date) {
    final exception = exceptionFor(date);
    return exception?.modifiedStart ?? start;
  }

  ScheduleConflict? get highestConflict {
    if (conflicts.isEmpty) return null;
    final ordered = [...conflicts]
      ..sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return ordered.first;
  }

  CalendarEvent copyWith({RSVPParticipantSummary? rsvpSummary}) {
    return CalendarEvent(
      id: id,
      type: type,
      status: status,
      title: title,
      start: start,
      end: end,
      facility: facility,
      recurrenceRule: recurrenceRule,
      recurrenceExceptions: recurrenceExceptions,
      rsvpSummary: rsvpSummary,
      conflicts: conflicts,
      isVisibleToParticipants: isVisibleToParticipants,
    );
  }
}

class ScheduleCalendarWorkspace {
  const ScheduleCalendarWorkspace({
    required this.events,
    required this.analytics,
    required this.permissions,
    this.isOffline = false,
    this.isStale = false,
    this.lastSyncedAt,
    this.sectionFailures = const {},
  });

  final List<CalendarEvent> events;
  final WorkloadAnalytics? analytics;
  final CalendarPermissionSet permissions;
  final bool isOffline;
  final bool isStale;
  final DateTime? lastSyncedAt;
  final Map<String, String> sectionFailures;
}
