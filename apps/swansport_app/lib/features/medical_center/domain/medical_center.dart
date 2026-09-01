import 'package:swansport_models/swansport_models.dart';
import 'package:swansport_core/swansport_core.dart';

enum MedicalEligibilityStatus {
  eligible,
  temporarilyRestricted,
  rehabilitation,
  suspended,
  clearanceRequired,
}

enum CertificateValidityState {
  valid,
  expiringSoon,
  expired,
  rejected,
}

enum InjurySeverity {
  minor,
  moderate,
  severe,
  critical,
}

enum AlertSeverity {
  information,
  warning,
  critical,
}

enum RehabilitationStage {
  phase1Acute,
  phase2Mobility,
  phase3Conditioning,
  phase4ReturnToPlay,
}

enum MedicalRole {
  clubAdmin,
  doctor,
  physiotherapist,
  coach,
  parent,
  athlete,
}

enum MedicalAppointmentStatus { scheduled, completed, cancelled, noShow }

enum MedicalClearanceStatus {
  draft,
  requested,
  underReview,
  approved,
  approvedWithRestrictions,
  rejected,
  expired,
  revoked,
  renewalRequired,
}

enum InjuryWorkflowStatus {
  reported,
  underAssessment,
  treatmentActive,
  rehabilitation,
  limitedTraining,
  returnToTrainingReview,
  returnToPlayReview,
  cleared,
  closed,
}

class MedicalAppointment {
  const MedicalAppointment({
    required this.id,
    required this.athleteId,
    required this.type,
    required this.professional,
    required this.location,
    required this.start,
    required this.durationMinutes,
    required this.status,
  });
  final SwanId id, athleteId;
  final String type, professional, location;
  final DateTime start;
  final int durationMinutes;
  final MedicalAppointmentStatus status;
}

class MedicalClearance {
  const MedicalClearance({
    required this.id,
    required this.athleteId,
    required this.type,
    required this.issuer,
    required this.validFrom,
    required this.expiresAt,
    required this.status,
    this.restriction,
  });
  final SwanId id, athleteId;
  final String type, issuer;
  final DateTime validFrom, expiresAt;
  final MedicalClearanceStatus status;
  final String? restriction;
}

class MedicalAuditEntry {
  const MedicalAuditEntry({
    required this.actor,
    required this.role,
    required this.action,
    required this.athleteId,
    required this.recordId,
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
    required this.confidentiality,
  });
  final String actor, role, action, recordId, previousValue, newValue;
  final SwanId athleteId;
  final DateTime timestamp;
  final String confidentiality;
}

class MedicalPermissions {
  final bool canViewDoctorNotes;
  final bool canClearEligibility;
  final bool canManageRehab;
  final bool canUploadCerts;
  final bool canEditProfile;

  const MedicalPermissions({
    required this.canViewDoctorNotes,
    required this.canClearEligibility,
    required this.canManageRehab,
    required this.canUploadCerts,
    required this.canEditProfile,
  });
}

MedicalPermissions permissionsForMedicalRole(MedicalRole role) {
  switch (role) {
    case MedicalRole.doctor:
      return const MedicalPermissions(
        canViewDoctorNotes: true,
        canClearEligibility: true,
        canManageRehab: true,
        canUploadCerts: true,
        canEditProfile: true,
      );
    case MedicalRole.physiotherapist:
      return const MedicalPermissions(
        canViewDoctorNotes: false,
        canClearEligibility: false,
        canManageRehab: true,
        canUploadCerts: false,
        canEditProfile: false,
      );
    case MedicalRole.clubAdmin:
      return const MedicalPermissions(
        canViewDoctorNotes: false,
        canClearEligibility: false,
        canManageRehab: false,
        canUploadCerts: true,
        canEditProfile: false,
      );
    case MedicalRole.parent:
      return const MedicalPermissions(
        canViewDoctorNotes: false,
        canClearEligibility: false,
        canManageRehab: false,
        canUploadCerts: true,
        canEditProfile: false,
      );
    case MedicalRole.coach:
    case MedicalRole.athlete:
      return const MedicalPermissions(
        canViewDoctorNotes: false,
        canClearEligibility: false,
        canManageRehab: false,
        canUploadCerts: false,
        canEditProfile: false,
      );
  }
}

class EmergencyContact {
  final String name;
  final String relation;
  final String phone;

  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });
}

class AllergyRecord {
  final String title;
  final String category;
  final bool isCritical;

  const AllergyRecord({
    required this.title,
    required this.category,
    required this.isCritical,
  });
}

class MedicationRecord {
  final String name;
  final String dosage;
  final String duration;
  final String physician;
  final bool isAntiDopingCompliant;

  const MedicationRecord({
    required this.name,
    required this.dosage,
    required this.duration,
    required this.physician,
    required this.isAntiDopingCompliant,
  });
}

class MedicalCertificate {
  final SwanId id;
  final String title;
  final String type;
  final DateTime issueDate;
  final DateTime expirationDate;
  final String issuingAuthority;
  final CertificateValidityState state;

  const MedicalCertificate({
    required this.id,
    required this.title,
    required this.type,
    required this.issueDate,
    required this.expirationDate,
    required this.issuingAuthority,
    required this.state,
  });
}

class RehabilitationPlan {
  final SwanId id;
  final RehabilitationStage stage;
  final int readinessScore;
  final String currentExercise;
  final String nextMilestone;
  final String progressNote;

  const RehabilitationPlan({
    required this.id,
    required this.stage,
    required this.readinessScore,
    required this.currentExercise,
    required this.nextMilestone,
    required this.progressNote,
  });
}

class InjuryRecord {
  final SwanId id;
  final String type;
  final String bodyRegion;
  final InjurySeverity severity;
  final DateTime injuryDate;
  final String estimatedRecovery;
  final String physician;
  final String physiotherapist;
  final DateTime returnToPlayTarget;
  final RehabilitationPlan? rehabPlan;

  const InjuryRecord({
    required this.id,
    required this.type,
    required this.bodyRegion,
    required this.severity,
    required this.injuryDate,
    required this.estimatedRecovery,
    required this.physician,
    required this.physiotherapist,
    required this.returnToPlayTarget,
    this.rehabPlan,
  });
}

class MedicalAlert {
  final SwanId id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final SwanId athleteId;
  final String athleteName;

  const MedicalAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.athleteId,
    required this.athleteName,
  });
}

class AthleteHealthProfile {
  final SwanId id;
  final String athleteName;
  final String branch;
  final String team;
  final String bloodType;
  final double heightCm;
  final double weightKg;
  final String dominantHand;
  final String dominantFoot;
  final MedicalEligibilityStatus eligibility;
  final List<EmergencyContact> emergencyContacts;
  final List<AllergyRecord> allergies;
  final List<MedicationRecord> medications;
  final List<MedicalCertificate> certificates;
  final List<InjuryRecord> injuries;
  final List<String> restrictions;
  final String? confidentialDoctorNotes;

  const AthleteHealthProfile({
    required this.id,
    required this.athleteName,
    required this.branch,
    required this.team,
    required this.bloodType,
    required this.heightCm,
    required this.weightKg,
    required this.dominantHand,
    required this.dominantFoot,
    required this.eligibility,
    required this.emergencyContacts,
    required this.allergies,
    required this.medications,
    required this.certificates,
    required this.injuries,
    required this.restrictions,
    this.confidentialDoctorNotes,
  });

  bool get hasActiveInjury => injuries.any((i) => i.rehabPlan != null);

  bool get hasCriticalAllergy => allergies.any((a) => a.isCritical);

  bool get hasExpiredCertificate =>
      certificates.any((c) => c.state == CertificateValidityState.expired);
}

class MedicalFilter {
  final String query;
  final String? branch;
  final MedicalEligibilityStatus? eligibility;
  final bool? onlyInjured;

  const MedicalFilter({
    this.query = '',
    this.branch,
    this.eligibility,
    this.onlyInjured,
  });

  bool matches(AthleteHealthProfile profile) {
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final matchName = trContains(profile.athleteName, q);
      final matchBranch = trContains(profile.branch, q);
      final matchTeam = trContains(profile.team, q);
      final matchInjury = profile.injuries.any(
        (i) =>
            trContains(i.type, q) ||
            trContains(i.bodyRegion, q),
      );
      if (!matchName && !matchBranch && !matchTeam && !matchInjury) {
        return false;
      }
    }
    if (branch != null && profile.branch != branch) {
      return false;
    }
    if (eligibility != null && profile.eligibility != eligibility) {
      return false;
    }
    if (onlyInjured == true && !profile.hasActiveInjury) {
      return false;
    }
    return true;
  }
}

class HealthDashboardMetrics {
  final int totalAthletes;
  final int healthyAthletes;
  final int injuredAthletes;
  final int rehabCases;
  final int expiringCertificates;
  final int criticalAlerts;
  final int complianceScore;

  const HealthDashboardMetrics({
    required this.totalAthletes,
    required this.healthyAthletes,
    required this.injuredAthletes,
    required this.rehabCases,
    required this.expiringCertificates,
    required this.criticalAlerts,
    required this.complianceScore,
  });
}

class FixtureMedicalRepository {
  final List<MedicalAppointment> appointments = [
    MedicalAppointment(
      id: const SwanId('appointment_followup'),
      athleteId: const SwanId('athlete_2'),
      type: 'Rehabilitasyon Kontrolü',
      professional: 'Fzt. Burak Şahin',
      location: 'Caferağa Sağlık Odası',
      start: DateTime(2026, 7, 25, 14),
      durationMinutes: 45,
      status: MedicalAppointmentStatus.scheduled,
    ),
  ];
  final List<MedicalClearance> clearances = [
    MedicalClearance(
      id: const SwanId('clearance_ece'),
      athleteId: const SwanId('athlete_3'),
      type: 'Sezon Katılım Onayı',
      issuer: 'Dr. Ahmet Kaya',
      validFrom: DateTime(2025, 9, 1),
      expiresAt: DateTime(2026, 6, 1),
      status: MedicalClearanceStatus.expired,
    ),
  ];
  final List<MedicalAuditEntry> audit = [];
  final List<AthleteHealthProfile> _profiles = [
    AthleteHealthProfile(
      id: const SwanId('athlete_1'),
      athleteName: 'Arda Yılmaz',
      branch: 'Futbol',
      team: 'U18 Elite',
      bloodType: 'A Rh+',
      heightCm: 182,
      weightKg: 74,
      dominantHand: 'Sağ',
      dominantFoot: 'Sağ',
      eligibility: MedicalEligibilityStatus.eligible,
      emergencyContacts: [
        const EmergencyContact(
          name: 'Mehmet Yılmaz',
          relation: 'Baba',
          phone: '+90 532 111 2233',
        ),
      ],
      allergies: [
        const AllergyRecord(
          title: 'Penisilin',
          category: 'İlaç',
          isCritical: true,
        ),
      ],
      medications: [
        const MedicationRecord(
          name: 'Salbutamol',
          dosage: '100mcg',
          duration: 'Sezon Boyu',
          physician: 'Dr. Ahmet Kaya',
          isAntiDopingCompliant: true,
        ),
      ],
      certificates: [
        MedicalCertificate(
          id: const SwanId('cert_1'),
          title: 'Sporcu Lisans Sağlık Raporu',
          type: 'Federasyon Raporu',
          issueDate: DateTime(2025, 9, 1),
          expirationDate: DateTime(2026, 9, 1),
          issuingAuthority: 'Kadıköy Devlet Hastanesi',
          state: CertificateValidityState.valid,
        ),
      ],
      injuries: [],
      restrictions: ['Sadece sentetik çimde hafif çalışma'],
      confidentialDoctorNotes:
          'Astım kontrolü sağlandı. Egzersiz öncesi inhaler kullanımı önerilir.',
    ),
    AthleteHealthProfile(
      id: const SwanId('athlete_2'),
      athleteName: 'Caner Erkin',
      branch: 'Futbol',
      team: 'A Takım',
      bloodType: '0 Rh+',
      heightCm: 178,
      weightKg: 76,
      dominantHand: 'Sol',
      dominantFoot: 'Sol',
      eligibility: MedicalEligibilityStatus.rehabilitation,
      emergencyContacts: [
        const EmergencyContact(
          name: 'Zeynep Erkin',
          relation: 'Eş',
          phone: '+90 533 222 3344',
        ),
      ],
      allergies: [
        const AllergyRecord(
          title: 'Fıstık',
          category: 'Gıda',
          isCritical: true,
        ),
      ],
      medications: [],
      certificates: [
        MedicalCertificate(
          id: const SwanId('cert_2'),
          title: 'Yıllık Kardiyoloji Değerlendirmesi',
          type: 'Özel Muayene',
          issueDate: DateTime(2026, 1, 15),
          expirationDate: DateTime(2027, 1, 15),
          issuingAuthority: 'Acıbadem Hastanesi',
          state: CertificateValidityState.valid,
        ),
      ],
      injuries: [
        InjuryRecord(
          id: const SwanId('inj_1'),
          type: 'Ön Çapraz Bağ Yırtığı (ACL)',
          bodyRegion: 'Sol Diz',
          severity: InjurySeverity.severe,
          injuryDate: DateTime(2026, 4, 10),
          estimatedRecovery: '6 Ay',
          physician: 'Prof. Dr. Selim Can',
          physiotherapist: 'Fzt. Burak Şahin',
          returnToPlayTarget: DateTime(2026, 10, 10),
          rehabPlan: const RehabilitationPlan(
            id: SwanId('rehab_1'),
            stage: RehabilitationStage.phase2Mobility,
            readinessScore: 45,
            currentExercise: 'İzometrik Kuadriseps Güçlendirme',
            nextMilestone: 'Düz Bacak Kaldırma (15 Tekrar x 3 Set)',
            progressNote:
                'Ödem azaldı, eklem hareket açıklığı %70 seviyesinde.',
          ),
        ),
      ],
      restrictions: [
        'Maç kadrosuna alınamaz',
        'Sadece fizyoterapist eşliğinde çalışma',
      ],
      confidentialDoctorNotes:
          'Artroskopik ACL rekonstrüksiyonu sonrası 14. hafta. Greft stabil.',
    ),
    AthleteHealthProfile(
      id: const SwanId('athlete_3'),
      athleteName: 'Ece Sönmez',
      branch: 'Basketbol',
      team: 'U16 Kız',
      bloodType: 'B Rh+',
      heightCm: 175,
      weightKg: 62,
      dominantHand: 'Sağ',
      dominantFoot: 'Sağ',
      eligibility: MedicalEligibilityStatus.clearanceRequired,
      emergencyContacts: [
        const EmergencyContact(
          name: 'Ayşe Sönmez',
          relation: 'Anne',
          phone: '+90 535 444 5566',
        ),
      ],
      allergies: [],
      medications: [],
      certificates: [
        MedicalCertificate(
          id: const SwanId('cert_3'),
          title: 'Sağlık Muayene Belgesi',
          type: 'Federasyon Belgesi',
          issueDate: DateTime(2025, 6, 1),
          expirationDate: DateTime(2026, 6, 1),
          issuingAuthority: 'Kızılay Tıp Merkezi',
          state: CertificateValidityState.expired,
        ),
      ],
      injuries: [],
      restrictions: ['Sağlık raporu yenilenene kadar antrenman kısıtlaması'],
    ),
  ];

  final List<MedicalAlert> _alerts = [
    const MedicalAlert(
      id: SwanId('alert_1'),
      title: 'Tarihi Geçmiş Sağlık Raporu',
      message:
          'Ece Sönmez kullanıcısının sağlık belgesi süresi dolmuştur. Katılım durduruldu.',
      severity: AlertSeverity.critical,
      athleteId: SwanId('athlete_3'),
      athleteName: 'Ece Sönmez',
    ),
    const MedicalAlert(
      id: SwanId('alert_2'),
      title: 'Rehabilitasyon Aşama Dönüm Noktası',
      message: 'Caner Erkin Faz 2 hareketlilik testine girmeye hazır.',
      severity: AlertSeverity.information,
      athleteId: SwanId('athlete_2'),
      athleteName: 'Caner Erkin',
    ),
  ];

  List<AthleteHealthProfile> get profiles => List.unmodifiable(_profiles);
  List<MedicalAlert> get alerts => List.unmodifiable(_alerts);

  HealthDashboardMetrics get metrics {
    final total = _profiles.length;
    final healthy = _profiles
        .where((p) => p.eligibility == MedicalEligibilityStatus.eligible)
        .length;
    final injured = _profiles.where((p) => p.hasActiveInjury).length;
    final rehab = _profiles
        .where((p) => p.eligibility == MedicalEligibilityStatus.rehabilitation)
        .length;
    final expiring = _profiles.where((p) => p.hasExpiredCertificate).length;
    final critical =
        _alerts.where((a) => a.severity == AlertSeverity.critical).length;
    final compliance = ((healthy / total) * 100).round();

    return HealthDashboardMetrics(
      totalAthletes: total,
      healthyAthletes: healthy,
      injuredAthletes: injured,
      rehabCases: rehab,
      expiringCertificates: expiring,
      criticalAlerts: critical,
      complianceScore: compliance,
    );
  }

  AthleteHealthProfile updateEligibility(
    SwanId athleteId,
    MedicalEligibilityStatus newStatus,
  ) {
    final idx = _profiles.indexWhere((p) => p.id == athleteId);
    if (idx == -1) throw ArgumentError('Sporcu bulunamadı.');
    final current = _profiles[idx];
    final updated = AthleteHealthProfile(
      id: current.id,
      athleteName: current.athleteName,
      branch: current.branch,
      team: current.team,
      bloodType: current.bloodType,
      heightCm: current.heightCm,
      weightKg: current.weightKg,
      dominantHand: current.dominantHand,
      dominantFoot: current.dominantFoot,
      eligibility: newStatus,
      emergencyContacts: current.emergencyContacts,
      allergies: current.allergies,
      medications: current.medications,
      certificates: current.certificates,
      injuries: current.injuries,
      restrictions: current.restrictions,
      confidentialDoctorNotes: current.confidentialDoctorNotes,
    );
    _profiles[idx] = updated;
    audit.add(
      MedicalAuditEntry(
        actor: 'Dr. Ahmet Kaya',
        role: 'Doctor',
        action: 'Tıbbi uygunluk güncellendi',
        athleteId: athleteId,
        recordId: athleteId.value,
        previousValue: current.eligibility.name,
        newValue: newStatus.name,
        timestamp: DateTime(2026, 7, 24, 10),
        confidentiality: 'Klinik',
      ),
    );
    return updated;
  }
}
