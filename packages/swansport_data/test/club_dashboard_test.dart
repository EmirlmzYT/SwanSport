import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

class _AthletesFake extends Fake implements SupabaseAthleteService {
  final filters = <String?>[];
  @override
  Future<int> countAthletes(String clubId, {String? search, String? status}) async {
    filters.add(status);
    return status == 'active' ? 30 : 37;
  }
}

class _ClubDataFake extends Fake implements ClubDataService {
  DateTime? from;
  DateTime? to;
  List<String>? eventIds;
  @override
  Future<List<EventRow>> events(String clubId,
      {DateTime? from, DateTime? to, String? kind}) async {
    this.from = from;
    this.to = to;
    return [for (final entry in [('one', 'training'), ('two', 'training'), ('match', 'match')])
      EventRow(id: entry.$1, title: entry.$1, place: null, kind: entry.$2,
          startsAt: from!)];
  }
  @override
  Future<List<AttendanceMark>> attendanceMarksForEvents(String clubId, List<String> ids) async {
    eventIds = ids;
    // Saved before the event day: event coverage must not use taken_at as
    // the date filter, nor count two athletes as two marked sessions.
    return [for (final athlete in ['a', 'b']) AttendanceMark(eventId: 'one',
      athleteId: athlete, status: 'present', takenAt: DateTime.utc(2026, 10, 9))];
  }
}

void main() {
  const staff = SwanAccess(isPlatformAdmin: false, clubRole: 'club_admin',
      coachLevel: 0, athleteKind: null);
  const accountant = SwanAccess(isPlatformAdmin: false, clubRole: null,
      coachLevel: 0, athleteKind: null, accountantClubIds: {'club'});
  const club = ClubRef(id: 'club', name: 'Kulüp');

  test('roster totals do not inherit console table filters', () async {
    final service = _AthletesFake();
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(staff),
      activeClubProvider.overrideWith((_) async => club),
      athleteServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    final result = await container.read(clubRosterCountsProvider.future);
    expect(result!.total, 37);
    expect(result.active, 30);
    expect(service.filters, [null, 'active']);
  });

  test('today uses Turkey day bounds and unique marked training event IDs', () async {
    final service = _ClubDataFake();
    final start = DateTime.utc(2026, 10, 10, 21);
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(staff),
      activeClubProvider.overrideWith((_) async => club),
      clubDashboardDayProvider.overrideWithValue(start),
      clubDataServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    final result = await container.read(clubTodayAttendanceProvider.future);
    expect(service.from, start);
    expect(service.to, start.add(const Duration(days: 1)));
    expect(service.eventIds, ['one', 'two']);
    expect(result!.trainingCount, 2);
    expect(result.markedCount, 1);
  });

  test('accountant cannot start sporting data requests', () async {
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(accountant),
      activeClubProvider.overrideWith((_) async => throw StateError('must not read')),
      athleteServiceProvider.overrideWith((_) => throw StateError('must not read')),
      clubDataServiceProvider.overrideWith((_) => throw StateError('must not read')),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(clubRosterCountsProvider.future), isNull);
    expect(await container.read(clubTodayAttendanceProvider.future), isNull);
  });
}
