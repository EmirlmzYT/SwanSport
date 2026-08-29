import 'package:swansport_data/swansport_data.dart';
import 'package:test/test.dart';

void main() {
  test('AttendanceAuditRow RPC satırını ve ilk kaydı çözer', () {
    final row = AttendanceAuditRow.fromMap({
      'id': 'audit-1',
      'event_id': 'event-1',
      'event_title': 'Akşam antrenmanı',
      'athlete_id': 'athlete-1',
      'athlete_name': 'Ece Sönmez',
      'previous_status': null,
      'status': 'present',
      'actor_name': 'Antrenör Ada',
      'created_at': '2026-08-29T14:30:00Z',
    });

    expect(row.eventTitle, 'Akşam antrenmanı');
    expect(row.previousStatus, isNull);
    expect(row.status, 'present');
    expect(row.actorName, 'Antrenör Ada');
  });
}
