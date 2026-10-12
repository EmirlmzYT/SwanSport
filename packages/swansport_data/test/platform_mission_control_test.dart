import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('public config sections and switches round-trip and are deeply immutable', () {
    final map = <String, dynamic>{
      'branding': {'app_name': 'SwanSport', 'logo_url': null},
      'commissions': {'marketplace_rate': 5.0},
      'maintenance': {'enabled': false},
      'broadcast_alert': {'enabled': true, 'severity': 'info'},
      'kill_switches': {'disable_signups': true, 'disable_payments': false},
    };
    final config = PlatformConfig.fromMap(map);
    expect(config.appName, 'SwanSport');
    expect(config.logoUrl, isNull);
    expect(config.maintenanceEnabled, isFalse);
    expect(config.broadcastEnabled, isTrue);
    expect(config.disableSignups, isTrue);
    expect(config.disablePayments, isFalse);
    (map['branding'] as Map)['app_name'] = 'Changed';
    expect(config.appName, 'SwanSport');
    expect(() => config.branding['app_name'] = 'Mutate', throwsUnsupportedError);
  });
  test('plan numeric mapping, unlimited cap, and server-owned timestamps', () {
    final plan = PlatformPlan.fromMap({
      'id': 'plan', 'target': 'club', 'code': 'academy', 'name': 'Kulüp Akademi',
      'price_monthly': '3990.50', 'price_yearly': 0, 'max_athletes': null,
      'features': ['reports', {'nested': ['one']}], 'is_active': false,
      'created_at': '2026-10-12T10:00:00Z',
    });
    expect(plan.priceMonthly, 3990.5);
    expect(plan.maxAthletes, isNull);
    expect(plan.isActive, isFalse);
    expect(plan.toMap().containsKey('created_at'), isFalse);
    expect(plan.toMap()['max_athletes'], isNull);
    expect(() => (plan.features[1] as Map)['nested'] = [], throwsUnsupportedError);
  });
  test('new plan lets database generate id and explicit nullable fields', () {
    final plan = PlatformPlan(target: 'athlete', code: 'athlete_pro', name: 'Pro', priceMonthly: 79);
    expect(plan.toMap().containsKey('id'), isFalse);
    expect(plan.toMap()['badge'], isNull);
    expect(plan.toMap()['features'], isEmpty);
  });
  test('audit nullable actor and deleted state are supported', () {
    final log = PlatformAuditLog.fromMap({'id': 'log', 'actor_id': null,
      'action': 'delete', 'entity_type': 'platform_plans', 'entity_id': 'plan',
      'old_state': {'name': 'Old'}, 'new_state': null,
      'created_at': '2026-10-12T10:00:00Z'});
    expect(log.actorId, isNull);
    expect(log.newState, isNull);
    expect(log.createdAt!.isUtc, isTrue);
    expect(() => log.oldState!['name'] = 'Fake', throwsUnsupportedError);
  });
  test('fixture providers do not manufacture prices or backend calls', () async {
    final container = ProviderContainer(overrides: [
      platformMissionControlServiceProvider.overrideWith((_) => throw StateError('must not read')),
    ]);
    addTearDown(container.dispose);
    expect((await container.read(platformConfigProvider.future)).branding, isEmpty);
    expect(await container.read(platformPlansProvider.future), isEmpty);
    expect(await container.read(platformAuditLogsProvider.future), isEmpty);
  });
  test('ordinary account never subscribes to private audit service', () async {
    final container = ProviderContainer(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      swanAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: false,
        clubRole: 'club_admin', coachLevel: 0, athleteKind: null)),
      platformMissionControlServiceProvider.overrideWith((_) => throw StateError('must not read')),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(platformAuditLogsProvider.future), isEmpty);
  });
  test('setting RPC uses exact signature and invalidates only after success', () async {
    var writes = 0;
    final client = SupabaseClient('https://example.com', 'anon', httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/update_platform_setting');
      expect(jsonDecode(request.body), {'p_key': 'maintenance', 'p_value': {'enabled': true}});
      return http.Response('{"enabled":true}', 200,
        headers: {'content-type': 'application/json'}, request: request);
    }));
    addTearDown(client.dispose);
    await PlatformMissionControlService(client, onWrite: () => writes++)
      .updatePlatformSetting('maintenance', {'enabled': true});
    expect(writes, 1);
  });
  test('failed RPC is not reported as success', () async {
    var writes = 0;
    final client = SupabaseClient('https://example.com', 'anon', httpClient: MockClient((request) async =>
      http.Response('{"code":"42501","message":"denied"}', 403,
        headers: {'content-type': 'application/json'}, request: request)));
    addTearDown(client.dispose);
    await expectLater(PlatformMissionControlService(client, onWrite: () => writes++)
      .updatePlatformSetting('maintenance', {'enabled': true}), throwsA(isA<PostgrestException>()));
    expect(writes, 0);
  });
  test('new plan inserts without silently overwriting a duplicate code', () async {
    var writes = 0;
    final client = SupabaseClient('https://example.com', 'anon', httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/platform_plans');
      expect(request.url.queryParameters.containsKey('on_conflict'), isFalse);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('id'), isFalse);
      expect(body.containsKey('updated_at'), isFalse);
      expect(body['max_athletes'], isNull);
      return http.Response(jsonEncode({...body, 'id': 'new-plan'}), 200,
        headers: {'content-type': 'application/json'}, request: request);
    }));
    addTearDown(client.dispose);
    final saved = await PlatformMissionControlService(client, onWrite: () => writes++)
      .upsertPlatformPlan(PlatformPlan(target: 'club', code: 'academy', name: 'Akademi', priceMonthly: 3990));
    expect(saved.id, 'new-plan');
    expect(writes, 1);
  });
  test('invalid plans and unbounded audit pages reject before HTTP', () async {
    final client = SupabaseClient('https://example.com', 'anon', httpClient: MockClient((_) async =>
      throw StateError('must not call')));
    addTearDown(client.dispose);
    final service = PlatformMissionControlService(client);
    await expectLater(service.upsertPlatformPlan(PlatformPlan(target: 'club', code: 'bad', name: 'Bad', priceMonthly: double.nan)), throwsArgumentError);
    await expectLater(service.auditLogs(limit: 201), throwsArgumentError);
    await expectLater(service.auditLogs(offset: -1), throwsArgumentError);
  });
}
