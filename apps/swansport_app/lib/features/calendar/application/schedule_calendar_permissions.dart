import '../domain/models/calendar_workspace.dart';

class ScheduleCalendarPermissions {
  const ScheduleCalendarPermissions._();

  static CalendarPermissionSet forRole(CalendarRole role) => switch (role) {
        CalendarRole.superAdmin => _allAccess,
        CalendarRole.clubAdmin => _allAccess,
        CalendarRole.headCoach => _coachAccess,
        CalendarRole.assistantCoach => _assistantCoachAccess,
        CalendarRole.medicalStaff => _medicalAccess,
        CalendarRole.athlete => _participantAccess,
        CalendarRole.guardian => _participantAccess,
      };

  static const _allAccess = CalendarPermissionSet(
    canViewAllEvents: true,
    canCreateEvent: true,
    canEditEvent: true,
    canCancelEvent: true,
    canRescheduleEvent: true,
    canViewRSVP: true,
    canSubmitRSVP: false,
    canOpenAttendance: true,
    canOverrideSoftConflict: true,
    canViewMedicalEventDetails: true,
  );

  static const _coachAccess = CalendarPermissionSet(
    canViewAllEvents: true,
    canCreateEvent: true,
    canEditEvent: true,
    canCancelEvent: true,
    canRescheduleEvent: true,
    canViewRSVP: true,
    canSubmitRSVP: false,
    canOpenAttendance: true,
    canOverrideSoftConflict: false,
    canViewMedicalEventDetails: false,
  );

  static const _assistantCoachAccess = CalendarPermissionSet(
    canViewAllEvents: true,
    canCreateEvent: false,
    canEditEvent: false,
    canCancelEvent: false,
    canRescheduleEvent: false,
    canViewRSVP: true,
    canSubmitRSVP: false,
    canOpenAttendance: true,
    canOverrideSoftConflict: false,
    canViewMedicalEventDetails: false,
  );

  static const _medicalAccess = CalendarPermissionSet(
    canViewAllEvents: true,
    canCreateEvent: false,
    canEditEvent: false,
    canCancelEvent: false,
    canRescheduleEvent: false,
    canViewRSVP: false,
    canSubmitRSVP: false,
    canOpenAttendance: false,
    canOverrideSoftConflict: false,
    canViewMedicalEventDetails: true,
  );

  static const _participantAccess = CalendarPermissionSet(
    canViewAllEvents: false,
    canCreateEvent: false,
    canEditEvent: false,
    canCancelEvent: false,
    canRescheduleEvent: false,
    canViewRSVP: false,
    canSubmitRSVP: true,
    canOpenAttendance: false,
    canOverrideSoftConflict: false,
    canViewMedicalEventDetails: false,
  );
}
