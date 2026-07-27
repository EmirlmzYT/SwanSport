import '../domain/models/athlete_detail.dart';

enum AthleteDetailRole {
  coach,
  clubAdmin,
  medicalStaff,
  athlete,
  guardian,
}

class AthleteDetailPermissions {
  const AthleteDetailPermissions({
    required this.visibleSections,
    required this.canContactGuardian,
    required this.canEditCoachNotes,
  });

  final Set<AthleteDetailSection> visibleSections;
  final bool canContactGuardian;
  final bool canEditCoachNotes;

  bool canView(AthleteDetailSection section) =>
      visibleSections.contains(section);

  static AthleteDetailPermissions forRole(AthleteDetailRole role) {
    return switch (role) {
      AthleteDetailRole.coach => const AthleteDetailPermissions(
          visibleSections: {
            AthleteDetailSection.activity,
            AthleteDetailSection.attendance,
            AthleteDetailSection.documents,
            AthleteDetailSection.notes,
          },
          canContactGuardian: true,
          canEditCoachNotes: true,
        ),
      AthleteDetailRole.clubAdmin => const AthleteDetailPermissions(
          visibleSections: {
            AthleteDetailSection.activity,
            AthleteDetailSection.attendance,
            AthleteDetailSection.documents,
            AthleteDetailSection.notes,
          },
          canContactGuardian: true,
          canEditCoachNotes: false,
        ),
      AthleteDetailRole.medicalStaff => const AthleteDetailPermissions(
          visibleSections: {
            AthleteDetailSection.activity,
            AthleteDetailSection.attendance,
            AthleteDetailSection.documents,
          },
          canContactGuardian: false,
          canEditCoachNotes: false,
        ),
      AthleteDetailRole.athlete => const AthleteDetailPermissions(
          visibleSections: {
            AthleteDetailSection.activity,
            AthleteDetailSection.attendance,
            AthleteDetailSection.documents,
          },
          canContactGuardian: false,
          canEditCoachNotes: false,
        ),
      AthleteDetailRole.guardian => const AthleteDetailPermissions(
          visibleSections: {
            AthleteDetailSection.activity,
            AthleteDetailSection.attendance,
            AthleteDetailSection.documents,
          },
          canContactGuardian: false,
          canEditCoachNotes: false,
        ),
    };
  }
}
