import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_models/swansport_models.dart';
import '../domain/medical_center.dart';

class MedicalCenterState {
  final List<AthleteHealthProfile> profiles;
  final List<MedicalAlert> alerts;
  final HealthDashboardMetrics metrics;
  final MedicalFilter filter;
  final MedicalRole currentRole;
  final bool loading;
  final List<MedicalAppointment> appointments;
  final List<MedicalClearance> clearances;
  final List<MedicalAuditEntry> audit;

  const MedicalCenterState({
    required this.profiles,
    required this.alerts,
    required this.metrics,
    required this.filter,
    required this.currentRole,
    this.loading = false,
    this.appointments = const [],
    this.clearances = const [],
    this.audit = const [],
  });

  MedicalPermissions get permissions => permissionsForMedicalRole(currentRole);

  List<AthleteHealthProfile> get filtered =>
      profiles.where((p) => filter.matches(p)).toList();

  MedicalCenterState copyWith({
    List<AthleteHealthProfile>? profiles,
    List<MedicalAlert>? alerts,
    HealthDashboardMetrics? metrics,
    MedicalFilter? filter,
    MedicalRole? currentRole,
    bool? loading,
    List<MedicalAppointment>? appointments,
    List<MedicalClearance>? clearances,
    List<MedicalAuditEntry>? audit,
  }) {
    return MedicalCenterState(
      profiles: profiles ?? this.profiles,
      alerts: alerts ?? this.alerts,
      metrics: metrics ?? this.metrics,
      filter: filter ?? this.filter,
      currentRole: currentRole ?? this.currentRole,
      loading: loading ?? this.loading,
      appointments: appointments ?? this.appointments,
      clearances: clearances ?? this.clearances,
      audit: audit ?? this.audit,
    );
  }
}

class MedicalController extends StateNotifier<MedicalCenterState> {
  final FixtureMedicalRepository _repository;

  MedicalController(this._repository)
      : super(
          MedicalCenterState(
            profiles: _repository.profiles,
            alerts: _repository.alerts,
            metrics: _repository.metrics,
            filter: const MedicalFilter(),
            currentRole: MedicalRole.doctor,
            appointments: _repository.appointments,
            clearances: _repository.clearances,
            audit: _repository.audit,
          ),
        );

  void search(String query) {
    state = state.copyWith(
      filter: MedicalFilter(
        query: query,
        branch: state.filter.branch,
        eligibility: state.filter.eligibility,
        onlyInjured: state.filter.onlyInjured,
      ),
    );
  }

  void filterBranch(String? branch) {
    state = state.copyWith(
      filter: MedicalFilter(
        query: state.filter.query,
        branch: branch,
        eligibility: state.filter.eligibility,
        onlyInjured: state.filter.onlyInjured,
      ),
    );
  }

  void filterEligibility(MedicalEligibilityStatus? eligibility) {
    state = state.copyWith(
      filter: MedicalFilter(
        query: state.filter.query,
        branch: state.filter.branch,
        eligibility: eligibility,
        onlyInjured: state.filter.onlyInjured,
      ),
    );
  }

  void filterInjuredOnly(bool? injuredOnly) {
    state = state.copyWith(
      filter: MedicalFilter(
        query: state.filter.query,
        branch: state.filter.branch,
        eligibility: state.filter.eligibility,
        onlyInjured: injuredOnly,
      ),
    );
  }

  void changeRole(MedicalRole role) {
    state = state.copyWith(currentRole: role);
  }

  void updateEligibility(SwanId athleteId, MedicalEligibilityStatus status) {
    if (!state.permissions.canClearEligibility) return;
    _repository.updateEligibility(athleteId, status);
    state = state.copyWith(
      profiles: _repository.profiles,
      metrics: _repository.metrics,
      audit: List.unmodifiable(_repository.audit),
    );
  }

  void dismissAlert(SwanId alertId) {
    final updated = state.alerts.where((a) => a.id != alertId).toList();
    state = state.copyWith(alerts: updated);
  }
}

final medicalRepositoryProvider =
    Provider<FixtureMedicalRepository>((ref) => FixtureMedicalRepository());

final medicalControllerProvider =
    StateNotifierProvider<MedicalController, MedicalCenterState>(
  (ref) => MedicalController(ref.watch(medicalRepositoryProvider)),
);
