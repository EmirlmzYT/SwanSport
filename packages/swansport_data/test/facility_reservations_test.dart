import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final map = <String, dynamic>{
    'id': 'r1',
    'club_id': 'c1',
    'facility_id': 'f1',
    'title': 'Ders',
    'kind': 'private_lesson',
    'starts_at': '2026-10-11T10:00:00Z',
    'ends_at': '2026-10-11T11:00:00Z',
    'status': 'pending',
    'fee': 125.5,
    'reserved_by_name': 'Kişi',
    'reserved_by_phone': '555',
    'reserved_by_profile_id': 'p1',
    'invoice_id': 'i1',
    'notes': 'Not',
    'created_at': '2026-10-10T09:00:00Z',
  };
  test('reservation maps all server fields', () {
    final r = FacilityReservation.fromMap(map);
    expect([
      r.id,
      r.clubId,
      r.facilityId,
      r.title,
      r.kind,
      r.status
    ], [
      'r1',
      'c1',
      'f1',
      'Ders',
      'private_lesson',
      'pending',
    ]);
    expect([
      r.reservedByName,
      r.reservedByPhone,
      r.reservedByProfileId,
      r.invoiceId,
      r.notes,
    ], [
      'Kişi',
      '555',
      'p1',
      'i1',
      'Not',
    ]);
    expect(r.fee, 125.5);
    expect(r.startsAt.toUtc(), DateTime.utc(2026, 10, 11, 10));
    expect(r.endsAt.toUtc(), DateTime.utc(2026, 10, 11, 11));
    expect(r.createdAt!.toUtc(), DateTime.utc(2026, 10, 10, 9));
  });
  test('optional reservation fields have backward compatible defaults', () {
    final r = FacilityReservation.fromMap({
      'id': 'r1',
      'starts_at': map['starts_at'],
      'ends_at': map['ends_at'],
    });
    expect(r.kind, 'rental');
    expect(r.status, 'confirmed');
    expect(r.fee, 0);
    expect(r.createdAt, isNull);
    expect(r.reservedByName, isNull);
  });
  test('conflicts map source while schedule remains compatible', () {
    for (final source in ['event', 'reservation']) {
      final slot = FacilitySlot.fromMap({
        ...map,
        'conflict_source': source,
        'team_name': 'Takım',
      });
      expect(slot.conflictSource, source);
      expect(slot.teamName, 'Takım');
      expect(slot.title, 'Ders');
      expect(slot.kind, 'private_lesson');
      expect(slot.startsAt.toUtc(), DateTime.utc(2026, 10, 11, 10));
      expect(slot.endsAt.toUtc(), DateTime.utc(2026, 10, 11, 11));
    }
    expect(FacilitySlot.fromMap(map).conflictSource, isNull);
  });

  test('narrow reservation query columns exclude all PII and sensitive fields',
      () {
    const cols = ClubOpsService.facilityPublicReservationColumns;
    final columnList = cols.split(',').map((c) => c.trim()).toSet();

    expect(columnList, {
      'id',
      'facility_id',
      'club_id',
      'title',
      'kind',
      'starts_at',
      'ends_at',
      'status',
    });

    // PII and sensitive fields MUST NOT be present
    expect(cols.contains('reserved_by_phone'), isFalse);
    expect(cols.contains('reserved_by_name'), isFalse);
    expect(cols.contains('reserved_by_profile_id'), isFalse);
    expect(cols.contains('fee'), isFalse);
    expect(cols.contains('notes'), isFalse);
    expect(cols.contains('created_by'), isFalse);
  });
}
