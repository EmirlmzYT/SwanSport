import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_models/swansport_models.dart';
import '../domain/facility_management.dart';

class FixtureFacilityRepository {
  final facilities = <Facility>[
    Facility(
      id: const SwanId('facility_caferaga'),
      name: 'Caferağa Spor Salonu',
      type: 'Spor Salonu',
      status: FacilityStatus.active,
      branch: 'Basketbol',
      campus: 'Kadıköy',
      address: 'Caferağa Mah. Kadıköy',
      manager: 'Selin Yılmaz',
      contact: '0216 000 00 00',
      capacity: 500,
      zones: const [
        FacilityZone(
          id: SwanId('facility_caferaga_a'),
          name: 'Salon A',
          type: 'Basketbol Sahası',
          capacity: 30,
          status: ZoneStatus.available,
          openHour: 8,
          closeHour: 23,
        ),
        FacilityZone(
          id: SwanId('facility_caferaga_b'),
          name: 'Salon B',
          type: 'Çok Amaçlı Salon',
          capacity: 24,
          status: ZoneStatus.maintenance,
          openHour: 8,
          closeHour: 22,
        ),
      ],
      reservations: [
        FacilityReservation(
          id: const SwanId('reservation_u16'),
          zoneId: const SwanId('facility_caferaga_a'),
          title: 'U-16 Antrenmanı',
          start: DateTime(2026, 7, 24, 18),
          end: DateTime(2026, 7, 24, 20),
          attendees: 18,
          status: ReservationStatus.approved,
        ),
      ],
      workOrders: [
        WorkOrder(
          id: const SwanId('work_floor'),
          zoneId: const SwanId('facility_caferaga_b'),
          title: 'Zemin Bakımı',
          priority: 'Yüksek',
          status: WorkOrderStatus.inProgress,
          start: DateTime(2026, 7, 23),
          expectedEnd: DateTime(2026, 7, 26),
          assignee: 'Teknik Ekip',
        ),
      ],
      equipment: const [
        FacilityEquipment(
          id: SwanId('equipment_hoop'),
          zoneId: SwanId('facility_caferaga_a'),
          name: 'Basketbol Potası',
          category: 'Saha',
          quantity: 2,
          condition: EquipmentCondition.healthy,
          health: 96,
        ),
      ],
      documents: [
        FacilityDocument(
          id: const SwanId('facility_doc_fire'),
          title: 'Yangın Güvenliği Belgesi',
          type: 'Güvenlik',
          status: FacilityDocumentStatus.expiringSoon,
          owner: 'Tesis Müdürü',
          expiresAt: DateTime(2026, 8, 15),
        ),
      ],
    ),
    const Facility(
      id: SwanId('facility_akatlar'),
      name: 'Akatlar Fitness Merkezi',
      type: 'Fitness',
      status: FacilityStatus.unavailable,
      branch: 'Kondisyon',
      campus: 'Beşiktaş',
      address: 'Akatlar',
      manager: 'Deniz Ak',
      contact: '0212 000 00 00',
      capacity: 80,
      zones: [],
      reservations: [],
      workOrders: [],
      equipment: [],
      documents: [],
    ),
  ];
  List<Facility> list() => List.unmodifiable(facilities);
  Facility? detail(SwanId id) =>
      facilities.where((f) => f.id.value == id.value).firstOrNull;
  void status(Facility f, FacilityStatus status) {
    final i = facilities.indexWhere((x) => x.id.value == f.id.value);
    facilities[i] = f.copyWith(status: status);
  }

  ReservationConflict? conflict(Facility f, FacilityReservation r) {
    final zone = f.zones.where((z) => z.id.value == r.zoneId.value).firstOrNull;
    if (f.status != FacilityStatus.active) {
      return const ReservationConflict('Tesis kapalı veya kullanılamıyor.');
    }
    if (zone == null || zone.status != ZoneStatus.available) {
      return const ReservationConflict(
        'Seçilen alan kullanılamıyor veya bakımda.',
      );
    }
    if (r.attendees > zone.capacity) {
      return ReservationConflict('Kapasite ${zone.capacity} kişi ile sınırlı.');
    }
    if (r.start.hour < zone.openHour || r.end.hour > zone.closeHour) {
      return const ReservationConflict('Rezervasyon çalışma saatleri dışında.');
    }
    for (final existing in f.reservations.where(
      (x) =>
          x.zoneId.value == r.zoneId.value &&
          x.status != ReservationStatus.cancelled,
    )) {
      if (r.start.isBefore(existing.end) && r.end.isAfter(existing.start)) {
        return ReservationConflict('${existing.title} ile saat çakışması var.');
      }
    }
    for (final work in f.workOrders.where(
      (w) =>
          w.zoneId.value == r.zoneId.value &&
          w.status != WorkOrderStatus.completed,
    )) {
      if (r.start.isBefore(work.expectedEnd) && r.end.isAfter(work.start)) {
        return ReservationConflict(
          '${work.title} bakım dönemi rezervasyonu engelliyor.',
        );
      }
    }
    return null;
  }
}

FacilityPermissionSet permissionsForFacility(FacilityRole role) =>
    switch (role) {
      FacilityRole.owner ||
      FacilityRole.administrator =>
        const FacilityPermissionSet(
          canView: true,
          canEdit: true,
          canReserve: true,
          canMaintain: true,
          canArchive: true,
        ),
      FacilityRole.branchManager ||
      FacilityRole.facilityManager =>
        const FacilityPermissionSet(
          canView: true,
          canEdit: true,
          canReserve: true,
          canMaintain: true,
          canArchive: false,
        ),
      FacilityRole.coach || FacilityRole.medical => const FacilityPermissionSet(
          canView: true,
          canEdit: false,
          canReserve: true,
          canMaintain: false,
          canArchive: false,
        ),
      _ => const FacilityPermissionSet(
          canView: true,
          canEdit: false,
          canReserve: false,
          canMaintain: false,
          canArchive: false,
        ),
    };

class FacilityState {
  const FacilityState({
    this.loading = true,
    this.facilities = const [],
    this.filter = const FacilityFilter(),
    required this.permissions,
    this.error,
    this.conflict,
  });
  final bool loading;
  final List<Facility> facilities;
  final FacilityFilter filter;
  final FacilityPermissionSet permissions;
  final String? error;
  final ReservationConflict? conflict;
  List<Facility> get filtered => facilities.where(filter.matches).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  FacilityState copyWith({
    bool? loading,
    List<Facility>? facilities,
    FacilityFilter? filter,
    String? error,
    ReservationConflict? conflict,
    bool clearConflict = false,
  }) =>
      FacilityState(
        loading: loading ?? this.loading,
        facilities: facilities ?? this.facilities,
        filter: filter ?? this.filter,
        permissions: permissions,
        error: error ?? this.error,
        conflict: clearConflict ? null : conflict ?? this.conflict,
      );
}

final facilityRepositoryProvider =
    Provider((ref) => FixtureFacilityRepository());
final facilityControllerProvider =
    StateNotifierProvider.autoDispose<FacilityController, FacilityState>(
  (ref) => FacilityController(ref.watch(facilityRepositoryProvider)),
);

class FacilityController extends StateNotifier<FacilityState> {
  FacilityController(
    this.repository, {
    FacilityRole role = FacilityRole.facilityManager,
  }) : super(FacilityState(permissions: permissionsForFacility(role))) {
    load();
  }
  final FixtureFacilityRepository repository;
  void load() =>
      state = state.copyWith(loading: false, facilities: repository.list());
  void search(String q) => state = state.copyWith(
        filter: FacilityFilter(
          query: q,
          status: state.filter.status,
          type: state.filter.type,
          branch: state.filter.branch,
        ),
      );
  void filterStatus(FacilityStatus? s) => state = state.copyWith(
        filter: FacilityFilter(
          query: state.filter.query,
          status: s,
          type: state.filter.type,
          branch: state.filter.branch,
        ),
      );
  void lifecycle(Facility f, FacilityStatus s) {
    if (!state.permissions.canEdit) return;
    repository.status(f, s);
    load();
  }

  bool reserve(Facility f, FacilityReservation r) {
    if (!state.permissions.canReserve) return false;
    final conflict = repository.conflict(f, r);
    if (conflict != null) {
      state = state.copyWith(conflict: conflict);
      return false;
    }
    f.reservations.add(r);
    state = state.copyWith(facilities: repository.list(), clearConflict: true);
    return true;
  }
}
