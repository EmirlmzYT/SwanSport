import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final future = DateTime.now().toUtc().add(const Duration(hours: 2));
  final wait = {
    'id': 'w',
    'court_id': 'c',
    'court_name': 'Kort',
    'starts_at': future.toIso8601String(),
    'status': 'offered',
    'offered_until': future.toIso8601String(),
    'position': 2,
  };
  final duty = {
    'id': 'd',
    'field_id': 'f',
    'field_name': 'Saha',
    'venue_name': 'Tesis',
    'issuer': false,
    'valid_until': future.toIso8601String(),
    'invite_until': future.toIso8601String(),
    'status': 'active',
  };
  test('expired opportunity cannot be presented as accept-ready', () {
    final w = CourtWaitEntry.fromMap({
      ...wait,
      'offered_until':
          DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
    });
    expect(w.canAccept, false);
    expect(w.canLeave, true);
    expect(CourtWaitEntry.fromMap(wait).position, 2);
  });
  test(
      'duty scope never grants permanent manager, club staff or accountant privileges',
      () {
    const a = SwanAccess(
      isPlatformAdmin: false,
      clubRole: 'member',
      coachLevel: 0,
      athleteKind: null,
      delegatedTurfFieldIds: {'f'},
    );
    expect(a.canEditTurfOccupancy('f'), true);
    expect(a.canEditTurfOccupancy('x'), false);
    expect(a.isTurfManagerOf('f'), false);
    expect(a.isClubStaff, false);
    expect(a.isAccountant, false);
  });
  test('ended duty has no live action despite cached active status', () {
    expect(
      TurfDuty.fromMap(
        {...duty, 'valid_until': DateTime(2000).toIso8601String()},
      ).live,
      false,
    );
    expect(TurfDuty.fromMap({...duty, 'status': 'revoked'}).live, false);
  });
  test('server payload must be complete rather than creating fictional records',
      () {
    expect(
      () => CourtWaitEntry.fromMap({...wait, 'offered_until': null}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => TurfDuty.fromMap({'status': 'active'}),
      throwsA(isA<TypeError>()),
    );
  });
  test('zero-row occupancy deletion is an error rather than silent success',
      () async {
    var deleted = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        expect(r.method, 'DELETE');
        expect(r.url.queryParameters['select'], 'id');
        return http.Response(
          jsonEncode(
            deleted
                ? [
                    {'id': 'slot'},
                  ]
                : [],
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final service = TurfService(client);
    await expectLater(
      service.markFree(fieldId: 'f', startsAt: future),
      throwsStateError,
    );
    deleted = true;
    await service.markFree(fieldId: 'f', startsAt: future);
  });
  test('operation dates are Turkey time independent of device locale', () {
    expect(sahaTime(DateTime.utc(2026, 10, 7, 22, 15)), '08.10.2026 01:15');
  });
  test('all mutations use actual RPC names and stable operation ID', () async {
    final requests = <String, Map<String, dynamic>>{};
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        final name = r.url.path.split('/').last;
        requests[name] = (r.body.isEmpty || r.body == 'null')
            ? <String, dynamic>{}
            : jsonDecode(r.body) as Map<String, dynamic>;
        final Object? response = switch (name) {
          'create_turf_duty' => {
              'code': 'code',
              'valid_until': future.toIso8601String(),
              'invite_until': future.toIso8601String(),
            },
          'my_court_waitlist' => [wait],
          'my_turf_duties' => {
              'items': [duty],
              'has_more': true,
            },
          'my_delegated_turf_fields' => ['f'],
          'leave_court_waitlist' || 'revoke_turf_duty' => null,
          _ => 'id'
        };
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final s = SahaOperationsService(client);
    await s.joinWait('c', future);
    await s.acceptWait('w', guests: 1, needed: 2);
    await s.leaveWait('w');
    await s.createDuty('f', 4, 'op');
    await s.redeemDuty('  code  ');
    await s.revokeDuty('d');
    expect((await s.waitlist()).single.courtName, 'Kort');
    expect((await s.duties(offset: 40)).hasMore, true);
    expect(await s.delegatedFields(), {'f'});
    expect(
      requests['join_court_waitlist'],
      {'p_court': 'c', 'p_start': future.toIso8601String()},
    );
    expect(
      requests['accept_court_waitlist'],
      {'p_id': 'w', 'p_guests': 1, 'p_needed': 2},
    );
    expect(
      requests['create_turf_duty'],
      {'p_field': 'f', 'p_hours': 4, 'p_op': 'op'},
    );
    expect(requests['redeem_turf_duty'], {'p_code': 'code'});
    expect(requests['my_turf_duties'], {'p_offset': 40});
  });
  test(
      'backend unavailable leaves actual empty collections and no temporary authority',
      () async {
    final c = ProviderContainer(
      overrides: [isSupabaseEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(c.dispose);
    c.listen(courtWaitlistProvider, (_, __) {});
    c.listen(turfDutiesProvider(0), (_, __) {});
    c.listen(delegatedTurfFieldIdsProvider, (_, __) {});
    expect(await c.read(courtWaitlistProvider.future), isEmpty);
    expect((await c.read(turfDutiesProvider(0).future)).items, isEmpty);
    expect(await c.read(delegatedTurfFieldIdsProvider.future), isEmpty);
  });
}
