import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

const match = FederationPendingMatch(
    id: 'm', name: 'Lig', sportCode: 'tenis', cityCode: '34', version: 4);
Map<String, dynamic> tennis() => {
      'status': 'finished',
      'best_of': 3,
      'sets': [
        {'home': 6, 'away': 2},
        {'home': 6, 'away': 0}
      ]
    };
void main() {
  test(
      'rich result uses canonical RPC and optimistic version, not direct inserts',
      () async {
    final calls = <http.Request>[];
    final client = SupabaseClient('https://example.supabase.co', 'key',
        httpClient: MockClient((r) async {
      calls.add(r);
      expect(r.url.path, '/rest/v1/rpc/publish_official_match_result');
      final body = jsonDecode(r.body) as Map;
      expect(body['p_expected_version'], 4);
      expect(body['p_reason'], 'Onay');
      expect((body['p_protocol'] as Map)['sport_code'], 'tenis');
      return http.Response(jsonEncode('revision'), 200,
          headers: {'content-type': 'application/json'}, request: r);
    }));
    addTearDown(client.dispose);
    final service = FederationRecordsService(client);
    expect(
        await service.publishOfficialResult(
            match: match, protocol: tennis(), reason: ' Onay '),
        'revision');
    expect(calls.length, 1);
    await expectLater(
        service.publishOfficialResult(
            match: match,
            protocol: {...tennis(), 'status': 'in_progress'},
            reason: 'x'),
        throwsA(anything));
    await expectLater(
        service.publishOfficialResult(
            match: match, protocol: tennis(), reason: '  '),
        throwsFormatException);
    expect(calls.length, 1);
  });
  test('race wire protocol normalizes string time and excludes DQ times', () {
    final p = normalizeOfficialResult('yuzme', {
      'status': 'finished',
      'performances': [
        {
          'athlete_ref': 'a',
          'heat': 1,
          'lane': 1,
          'time': '01:02.34',
          'rank': 1
        },
        {'athlete_ref': 'b', 'heat': 1, 'lane': 2, 'dq': true},
      ]
    });
    final rows = p['performances'] as List;
    expect((rows.first as Map)['time_ms'], 62340);
    expect((rows.first as Map).containsKey('time'), false);
    expect((rows.last as Map).containsKey('rank'), false);
  });
  test(
      'official badge requires provenance, verified true alone is insufficient',
      () {
    final base = {
      'id': 'a',
      'athlete_id': 'child',
      'title': 'Galibiyet',
      'verified': true
    };
    expect(Achievement.fromMap(base).isOfficial, false);
    expect(Achievement.fromMap({...base, 'source': 'manual'}).sourceLabel,
        'Kulüp Beyanı');
    expect(
        Achievement.fromMap({...base, 'source': 'federation_result'})
            .isOfficial,
        false);
    final official = Achievement.fromMap({
      ...base,
      'source': 'federation_result',
      'source_id': 'revision',
      'official_match_id': 'match',
      'sport_code': 'tenis',
      'result_version': 1
    });
    expect(official.isOfficial, true);
    expect(official.resultVersion, 1);
  });
  test('private official CV and source use only allowlisted RPCs', () async {
    final paths = <String>[];
    final client = SupabaseClient('https://example.supabase.co', 'key',
        httpClient: MockClient((r) async {
      paths.add(r.url.path);
      final body = jsonDecode(r.body) as Map;
      if (r.url.path.endsWith('official_athlete_achievements')) {
        expect(body, {'p_athlete': 'athlete'});
        return http.Response(
            jsonEncode([
              {
                'id': 'award',
                'athlete_id': 'athlete',
                'title': 'Maç',
                'source': 'federation_result',
                'source_id': 'r',
                'official_match_id': 'm',
                'result_version': 1
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: r);
      }
      expect(body, {'p_achievement': 'award'});
      return http.Response(
          jsonEncode({
            'match_id': 'm',
            'name': 'Lig',
            'sport_code': 'tenis',
            'version': 1,
            'current_version': 2,
            'result': '6–2',
            'athlete_id': 'must-not-be-retained'
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: r);
    }));
    addTearDown(client.dispose);
    final service = FederationRecordsService(client);
    expect((await service.officialAchievements('athlete')).single.isOfficial,
        true);
    final source = await service.achievementSource('award');
    expect(source.version, 1);
    expect(source.currentVersion, 2);
    expect(paths, [
      '/rest/v1/rpc/official_athlete_achievements',
      '/rest/v1/rpc/official_achievement_source'
    ]);
  });
}
