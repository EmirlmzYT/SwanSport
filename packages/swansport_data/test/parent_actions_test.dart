import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  const child = GuardianChild(id: 'a', name: 'Ada', clubId: 'c', clubName: 'A');
  final event = GuardianEventAction(
    id: 'e',
    title: 'Antrenman',
    childId: 'a',
    childName: 'Ada',
    clubName: 'A',
    startsAt: DateTime(2026),
    responseAt: '2026-10-07T12:00:00.123456+00:00',
  );
  test('guardian and club roles coexist without sporting privilege escalation',
      () {
    for (final role in ['coach', 'accountant', 'member']) {
      final access = SwanAccess(
        isPlatformAdmin: false,
        clubRole: role,
        coachLevel: 0,
        athleteKind: null,
        guardianAthleteIds: {child.id},
      );
      expect(access.isParent, isTrue);
      expect(access.isClubStaff, role == 'coach');
    }
    expect(SwanAccess.none.isParent, isFalse);
  });
  test('missing backend returns no fabricated tasks or guardian links',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(parentActionsProvider, (_, __) {});
    container.listen(guardianAthleteIdsProvider, (_, __) {});
    expect((await container.read(parentActionsProvider.future)).count, 0);
    expect(await container.read(guardianAthleteIdsProvider.future), isEmpty);
  });
  test('RPC reads real aggregate including exact timestamp', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        expect(r.url.path, '/rest/v1/rpc/my_parent_actions');
        return http.Response(
          jsonEncode({
            'children': [
              {'id': 'a', 'full_name': 'Ada', 'club_id': 'c', 'club_name': 'A'},
            ],
            'events': [
              {
                'id': 'e',
                'title': 'Antrenman',
                'athlete_id': 'a',
                'child_name': 'Ada',
                'club_name': 'A',
                'starts_at': '2026-10-08T12:00:00Z',
                'response_at': event.responseAt,
              }
            ],
            'documents': <Object>[],
            'tickets': <Object>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final actions = await ParentActionService(client).load();
    expect(actions.count, 1);
    expect(actions.children.single.clubId, 'c');
    expect(actions.events.single.responseAt, event.responseAt);
  });
  test(
      'guardian RSVP sends child and expected server timestamp, including null',
      () async {
    final requests = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        expect(r.url.path, '/rest/v1/rpc/set_guardian_event_rsvp');
        requests.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response('', 204, request: r);
      }),
    );
    addTearDown(client.dispose);
    final service = ParentActionService(client);
    await service.respond(event, 'attending');
    await service.respond(
      GuardianEventAction(
        id: 'e2',
        title: 'Maç',
        childId: 'b',
        childName: 'Ece',
        clubName: 'B',
        startsAt: DateTime(2026),
      ),
      'unavailable',
    );
    expect(requests.first, {
      'p_event': 'e',
      'p_athlete': 'a',
      'p_status': 'attending',
      'p_expected': event.responseAt,
    });
    expect(requests.last['p_expected'], isNull);
    expect(requests.last['p_athlete'], 'b');
  });
  test('child vault query ignores active club and constrains owner', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        expect(jsonDecode(r.body), {
          'p_club': 'child-club',
          'p_owner_type': 'athlete',
          'p_owner_id': 'child',
        });
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    expect(
      await VaultService(client)
          .list('child-club', ownerType: 'athlete', ownerId: 'child'),
      isEmpty,
    );
  });
  test('RPC failure remains failure instead of an empty successful list',
      () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient(
        (r) async => http.Response(
          '{"message":"disabled","code":"P0001"}',
          400,
          headers: {'content-type': 'application/json'},
          request: r,
        ),
      ),
    );
    addTearDown(client.dispose);
    await expectLater(
      ParentActionService(client).load(),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      ParentActionService(client).respond(event, 'attending'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
