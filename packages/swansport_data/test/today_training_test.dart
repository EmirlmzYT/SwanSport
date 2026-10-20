import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final raw = <String, dynamic>{
    'server_now': '2026-10-20T14:00:00Z',
    'items': [
      {
        'event_id': 'event',
        'athlete_id': 'child',
        'title': 'Basketbol',
        'club_name': 'Kulüp',
        'is_self': false,
        'child_name': 'Ada',
        'starts_at': '2026-10-20T18:00:00+03:00',
        'ends_at': null,
        'place': null,
        'response': 'attending',
        'response_at': '2026-10-20T13:59:00.123456+00:00'
      }
    ],
  };
  test('RPC parsing preserves exact shared timestamp and real timezone', () {
    final value = TodayTrainingSnapshot.fromMap(raw);
    expect(value.items.single.responseAt, '2026-10-20T13:59:00.123456+00:00');
    expect(value.items.single.startsAt, DateTime.utc(2026, 10, 20, 15));
    expect(value.items.single.endsAt, isNull);
    expect(value.items.single.place, isNull);
    expect(value.items.single.isSelf, isFalse);
  });
  test('load and respond use narrow RPCs without direct table access',
      () async {
    final calls = <String>[];
    final client = SupabaseClient('https://example.supabase.co', 'key',
        httpClient: MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path.endsWith('my_today_training_rsvps')) {
        return http.Response(jsonEncode(raw), 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      expect(jsonDecode(request.body), {
        'p_event': 'event',
        'p_athlete': 'child',
        'p_status': 'unavailable',
        'p_expected': '2026-10-20T13:59:00.123456+00:00',
      });
      return http.Response('', 204, request: request);
    }));
    addTearDown(client.dispose);
    final service = TodayTrainingService(client);
    final data = await service.load();
    await service.respond(data.items.single, 'unavailable');
    expect(calls, [
      '/rest/v1/rpc/my_today_training_rsvps',
      '/rest/v1/rpc/respond_today_training'
    ]);
  });
  test('feature closed, guest or absent backend does not construct service',
      () async {
    for (final access in [
      SwanAccess.none,
      const SwanAccess(
          isPlatformAdmin: false,
          clubRole: 'athlete',
          coachLevel: 0,
          athleteKind: null)
    ]) {
      final container = ProviderContainer(overrides: [
        swanAccessProvider.overrideWithValue(access),
        todayTrainingServiceProvider
            .overrideWith((_) => throw StateError('Must not load')),
      ]);
      expect(await container.read(todayTrainingRsvpsProvider.future), isNull);
      container.dispose();
    }
  });
}
