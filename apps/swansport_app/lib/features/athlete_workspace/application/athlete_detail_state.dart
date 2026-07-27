import 'package:swansport_models/swansport_models.dart';

import '../domain/models/athlete_detail.dart';
import 'athlete_detail_permissions.dart';

enum AthleteDetailStatus {
  loading,
  loaded,
  notFound,
  permissionDenied,
  error,
}

class AthleteDetailState {
  const AthleteDetailState({
    required this.status,
    required this.athleteId,
    required this.selectedSection,
    required this.permissions,
    this.detail,
    this.errorMessage,
    this.sectionErrors = const {},
    this.isOffline = false,
    this.isStale = false,
    this.lastSyncedLabel,
  });

  factory AthleteDetailState.loading({
    required SwanId athleteId,
    AthleteDetailRole role = AthleteDetailRole.coach,
  }) {
    return AthleteDetailState(
      status: AthleteDetailStatus.loading,
      athleteId: athleteId,
      selectedSection: AthleteDetailSection.activity,
      permissions: AthleteDetailPermissions.forRole(role),
    );
  }

  final AthleteDetailStatus status;
  final SwanId athleteId;
  final AthleteDetail? detail;
  final AthleteDetailSection selectedSection;
  final AthleteDetailPermissions permissions;
  final String? errorMessage;
  final Map<AthleteDetailSection, String> sectionErrors;
  final bool isOffline;
  final bool isStale;
  final String? lastSyncedLabel;

  bool get hasVisibleSelectedSection => permissions.canView(selectedSection);

  AthleteDetailState copyWith({
    AthleteDetailStatus? status,
    AthleteDetail? detail,
    AthleteDetailSection? selectedSection,
    AthleteDetailPermissions? permissions,
    String? errorMessage,
    Map<AthleteDetailSection, String>? sectionErrors,
    bool? isOffline,
    bool? isStale,
    String? lastSyncedLabel,
  }) {
    return AthleteDetailState(
      status: status ?? this.status,
      athleteId: athleteId,
      detail: detail ?? this.detail,
      selectedSection: selectedSection ?? this.selectedSection,
      permissions: permissions ?? this.permissions,
      errorMessage: errorMessage ?? this.errorMessage,
      sectionErrors: sectionErrors ?? this.sectionErrors,
      isOffline: isOffline ?? this.isOffline,
      isStale: isStale ?? this.isStale,
      lastSyncedLabel: lastSyncedLabel ?? this.lastSyncedLabel,
    );
  }
}
