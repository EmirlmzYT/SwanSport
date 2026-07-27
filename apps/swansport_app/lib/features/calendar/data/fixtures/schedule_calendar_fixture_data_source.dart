import 'package:swansport_models/swansport_models.dart';

import '../../domain/models/calendar_workspace.dart';

class FixtureScheduleCalendarDataSource {
  const FixtureScheduleCalendarDataSource();

  static const _caferagaA = FacilitySummary(
    id: SwanId('facility_caferaga_a'),
    name: 'Caferağa Spor Salonu',
    room: 'Salon A',
  );
  static const _caferagaB = FacilitySummary(
    id: SwanId('facility_caferaga_b'),
    name: 'Caferağa Spor Salonu',
    room: 'Salon B',
  );

  List<CalendarEvent> get events => [
        CalendarEvent(
          id: const SwanId('event_u16_training'),
          type: CalendarEventType.training,
          status: CalendarEventStatus.attendancePending,
          title: 'U-16 Erkek Basketbol Antrenmanı',
          start: DateTime(2026, 7, 22, 17, 30),
          end: DateTime(2026, 7, 22, 19),
          facility: _caferagaA,
          recurrenceRule: const RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            interval: 1,
            weekdays: {DateTime.wednesday},
          ),
          recurrenceExceptions: [
            RecurrenceException(
              occurrenceDate: DateTime(2026, 7, 29),
              type: RecurrenceExceptionType.cancelled,
              reason: 'Salon bakımda',
            ),
            RecurrenceException(
              occurrenceDate: DateTime(2026, 8, 5),
              type: RecurrenceExceptionType.modified,
              modifiedStart: DateTime(2026, 8, 5, 18),
            ),
            RecurrenceException(
              occurrenceDate: DateTime(2026, 8, 12),
              type: RecurrenceExceptionType.futureSeriesBoundary,
            ),
          ],
          rsvpSummary: const RSVPParticipantSummary(
            attending: 16,
            uncertain: 0,
            unavailable: 2,
            pending: 0,
          ),
          conflicts: const [
            ScheduleConflict(
              severity: ConflictSeverity.advisory,
              summary: 'Kısa toparlanma penceresi izleniyor',
              isOverridable: false,
            ),
          ],
        ),
        CalendarEvent(
          id: const SwanId('event_u18_shooting'),
          type: CalendarEventType.training,
          status: CalendarEventStatus.planned,
          title: 'U-18 Erkek Basketbol Taktik Şut',
          start: DateTime(2026, 7, 22, 19, 30),
          end: DateTime(2026, 7, 22, 21),
          facility: _caferagaB,
          recurrenceRule: const RecurrenceRule(
            frequency: RecurrenceFrequency.customWeekdays,
            interval: 1,
            weekdays: {DateTime.wednesday, DateTime.friday},
          ),
          recurrenceExceptions: const [],
          rsvpSummary: const RSVPParticipantSummary(
            attending: 14,
            uncertain: 1,
            unavailable: 1,
            pending: 2,
          ),
          conflicts: const [
            ScheduleConflict(
              severity: ConflictSeverity.softOverlap,
              summary: 'Çifte antrenör ataması',
              isOverridable: true,
            ),
          ],
        ),
        CalendarEvent(
          id: const SwanId('event_u14_match'),
          type: CalendarEventType.match,
          status: CalendarEventStatus.planned,
          title: 'Kadıköy SK vs. Beşiktaş JK',
          start: DateTime(2026, 7, 25, 15),
          end: DateTime(2026, 7, 25, 17),
          facility: const FacilitySummary(
            id: SwanId('facility_akatlar'),
            name: 'Akatlar Spor Kompleksi',
            room: 'Ana Saha',
          ),
          recurrenceRule: null,
          recurrenceExceptions: const [],
          rsvpSummary: const RSVPParticipantSummary(
            attending: 15,
            uncertain: 1,
            unavailable: 1,
            pending: 1,
          ),
          conflicts: const [
            ScheduleConflict(
              severity: ConflictSeverity.hardBlocker,
              summary: 'Tesis çift rezervasyonu',
              isOverridable: false,
            ),
          ],
        ),
      ];

  WorkloadAnalytics get analytics => const WorkloadAnalytics(
        weeklyEventCount: 4,
        trainingCount: 3,
        matchCount: 1,
        facilityLoadPercent: 88,
        weeklyLoadHours: 3.5,
        recoveryStatus: 'Normal',
      );
}
