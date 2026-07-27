import 'package:swansport_models/swansport_models.dart';

enum FacilityStatus { active, temporarilyClosed, unavailable, archived }

enum ZoneStatus { available, occupied, maintenance, unavailable, archived }

enum WorkOrderStatus { open, assigned, inProgress, completed, overdue }

enum EquipmentCondition { healthy, damaged, unavailable, underRepair, retired }

enum FacilityDocumentStatus { valid, expiringSoon, expired, missing }

enum ReservationStatus { pending, approved, rejected, cancelled }

enum FacilityRole {
  owner,
  administrator,
  branchManager,
  facilityManager,
  coach,
  medical,
  financial,
  parent,
  athlete,
  readOnly
}

class FacilityPermissionSet {
  const FacilityPermissionSet({
    required this.canView,
    required this.canEdit,
    required this.canReserve,
    required this.canMaintain,
    required this.canArchive,
  });
  final bool canView, canEdit, canReserve, canMaintain, canArchive;
}

class FacilityZone {
  const FacilityZone({
    required this.id,
    required this.name,
    required this.type,
    required this.capacity,
    required this.status,
    required this.openHour,
    required this.closeHour,
  });
  final SwanId id;
  final String name, type;
  final int capacity, openHour, closeHour;
  final ZoneStatus status;
}

class FacilityReservation {
  const FacilityReservation({
    required this.id,
    required this.zoneId,
    required this.title,
    required this.start,
    required this.end,
    required this.attendees,
    required this.status,
    this.recurring = false,
  });
  final SwanId id, zoneId;
  final String title;
  final DateTime start, end;
  final int attendees;
  final ReservationStatus status;
  final bool recurring;
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.zoneId,
    required this.title,
    required this.priority,
    required this.status,
    required this.start,
    required this.expectedEnd,
    required this.assignee,
  });
  final SwanId id, zoneId;
  final String title, priority, assignee;
  final WorkOrderStatus status;
  final DateTime start, expectedEnd;
}

class FacilityEquipment {
  const FacilityEquipment({
    required this.id,
    required this.zoneId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.condition,
    required this.health,
  });
  final SwanId id, zoneId;
  final String name, category;
  final int quantity, health;
  final EquipmentCondition condition;
}

class FacilityDocument {
  const FacilityDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.owner,
    this.expiresAt,
  });
  final SwanId id;
  final String title, type, owner;
  final FacilityDocumentStatus status;
  final DateTime? expiresAt;
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.branch,
    required this.campus,
    required this.address,
    required this.manager,
    required this.contact,
    required this.capacity,
    required this.zones,
    required this.reservations,
    required this.workOrders,
    required this.equipment,
    required this.documents,
  });
  final SwanId id;
  final String name, type, branch, campus, address, manager, contact;
  final FacilityStatus status;
  final int capacity;
  final List<FacilityZone> zones;
  final List<FacilityReservation> reservations;
  final List<WorkOrder> workOrders;
  final List<FacilityEquipment> equipment;
  final List<FacilityDocument> documents;
  int get health {
    var score = 100;
    score -=
        workOrders.where((w) => w.status == WorkOrderStatus.overdue).length *
            15;
    score -= equipment
            .where((e) => e.condition != EquipmentCondition.healthy)
            .length *
        10;
    score -= documents
            .where(
              (d) =>
                  d.status == FacilityDocumentStatus.expired ||
                  d.status == FacilityDocumentStatus.missing,
            )
            .length *
        15;
    score -= zones.where((z) => z.status == ZoneStatus.unavailable).length * 10;
    return score.clamp(0, 100);
  }

  Facility copyWith({FacilityStatus? status}) => Facility(
        id: id,
        name: name,
        type: type,
        status: status ?? this.status,
        branch: branch,
        campus: campus,
        address: address,
        manager: manager,
        contact: contact,
        capacity: capacity,
        zones: zones,
        reservations: reservations,
        workOrders: workOrders,
        equipment: equipment,
        documents: documents,
      );
}

class ReservationConflict {
  const ReservationConflict(this.message);
  final String message;
}

class FacilityFilter {
  const FacilityFilter({this.query = '', this.status, this.type, this.branch});
  final String query;
  final FacilityStatus? status;
  final String? type, branch;
  bool matches(Facility f) {
    final q = query.trim().toLowerCase();
    return (q.isEmpty ||
            '${f.name} ${f.type} ${f.branch} ${f.campus} ${f.manager} ${f.zones.map((z) => z.name).join(" ")}'
                .toLowerCase()
                .contains(q)) &&
        (status == null || f.status == status) &&
        (type == null || f.type == type) &&
        (branch == null || f.branch == branch);
  }
}
