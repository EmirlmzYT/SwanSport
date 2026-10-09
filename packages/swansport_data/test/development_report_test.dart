import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

Map<String, dynamic> payload() => {
      'athlete': {
        'id': 'private-id',
        'full_name': 'Ada Gizli',
        'club_name': 'Özel Kulüp',
      },
      'from': '2026-09-01',
      'to': '2026-09-30',
      'generated_at': '2026-10-07T22:00:00Z',
      'fingerprint': 'f',
      'attendance': {
        'present': 0,
        'late': 0,
        'absent': 0,
        'excused': 0,
        'unlinked': 2,
        'rate': null,
      },
      'metrics': <Object>[],
      'goals': <Object>[],
    };
ReportMetric metric({
  num first = 10,
  num last = 9,
  int count = 2,
  bool lower = true,
}) =>
    ReportMetric(
      name: 'Sprint',
      category: 'Sürat',
      unit: 'sn',
      lowerIsBetter: lower,
      count: count,
      first: first,
      last: last,
      firstDate: DateTime(2026, 9, 1),
      lastDate: DateTime(2026, 9, 30),
    );
void main() {
  test('empty records retain unknown rate and explicit gaps', () {
    final report = DevelopmentReport.fromMap(payload());
    expect(report.attendance.rate, isNull);
    expect(report.text(), contains('Devam oranı: Hesaplanamıyor'));
    expect(report.text(), isNot(contains('Devam oranı: 0%')));
    expect(report.gaps.join(' '), contains('2 etkinliksiz'));
    expect(report.gaps.join(' '), contains('ölçüm kaydı yok'));
  });
  test(
      'identity omitted by default and only explicit opt-in includes name/club',
      () {
    final report = DevelopmentReport.fromMap(payload());
    expect(report.text(), isNot(contains('Ada Gizli')));
    expect(report.text(), isNot(contains('Özel Kulüp')));
    expect(
      report.text(includeIdentity: true),
      contains('Ada Gizli · Özel Kulüp'),
    );
    expect(report.text(includeIdentity: true), isNot(contains('private-id')));
    expect(report.text(), contains('Oluşturma: 08.10.2026'));
  });
  test('incomplete server payload is an error rather than fabricated report',
      () {
    final data = payload()..remove('attendance');
    expect(() => DevelopmentReport.fromMap(data), throwsA(isA<TypeError>()));
  });
  test('measurement direction and raw difference govern trend', () {
    expect(metric().trend, contains('lehte'));
    expect(metric().percent, -10);
    expect(metric(lower: false).trend, contains('aleyhte'));
    expect(metric(last: 10).trend, 'Değişim yok');
    expect(metric(count: 1).change, isNull);
    expect(metric(count: 1).summary, contains('ikinci ölçüm yok'));
  });
  test('zero and negative baselines never produce fabricated percentages', () {
    for (final first in [0, -10]) {
      expect(metric(first: first, last: 5).percent, isNull);
      expect(metric(first: first, last: 5).summary, isNot(contains('%')));
      expect(metric(first: first, last: 5).change, 5 - first);
    }
  });
  test('current goal state is expressly not historical progress', () {
    final data = payload();
    data['goals'] = [
      {
        'title': 'Güncel hedef',
        'progress': 95,
        'status': 'active',
        'measured': false,
        'created_on': '2026-01-01',
        'target_date': '2026-10-10',
      }
    ];
    final report = DevelopmentReport.fromMap(data);
    expect(report.text(), contains('Geçmiş ilerleme yüzdesi değildir.'));
    expect(report.text(), contains('Sürüyor · %95 · elle takip'));
  });
  test('civil dates and Turkish decimal formatting do not shift or truncate',
      () {
    expect(reportIsoDate(DateTime(2026, 9, 1, 23)), '2026-09-01');
    for (final entry in {
      0: '0',
      10: '10',
      100: '100',
      12.5: '12,5',
      -10.25: '-10,25',
    }.entries) {
      expect(reportNumber(entry.key), entry.value);
    }
  });
  test(
      'RPC passes actual named date/search/page parameters and parses response',
      () async {
    final bodies = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        final candidate = r.url.path.endsWith('development_report_athletes');
        expect(
          r.url.path,
          candidate
              ? '/rest/v1/rpc/development_report_athletes'
              : '/rest/v1/rpc/athlete_development_report',
        );
        return http.Response(
          jsonEncode(
            candidate
                ? {
                    'athletes': [payload()['athlete']],
                    'has_more': true,
                  }
                : payload(),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    addTearDown(client.dispose);
    final service = DevelopmentReportService(client);
    expect((await service.athletes(query: 'Işık', offset: 40)).hasMore, isTrue);
    expect(
      (await service.load(
        (
          athleteId: 'a',
          from: DateTime(2026, 9, 1, 23),
          to: DateTime(2026, 9, 30)
        ),
      ))
          .fingerprint,
      'f',
    );
    expect(bodies, [
      {'p_query': 'Işık', 'p_offset': 40},
      {'p_athlete': 'a', 'p_from': '2026-09-01', 'p_to': '2026-09-30'},
    ]);
  });
  test('disabled backend cannot fabricate a development report', () async {
    final container = ProviderContainer(
      overrides: [isSupabaseEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    final provider = developmentReportProvider(
      (athleteId: 'a', from: DateTime(2026, 9), to: DateTime(2026, 9, 30)),
    );
    container.listen(provider, (_, __) {});
    await expectLater(container.read(provider.future), throwsStateError);
  });
}
