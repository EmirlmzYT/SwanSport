import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final day = DateTime.utc(2026, 10, 9, 12);
  test('other sport max and admin roles give no sport or federation rights',
      () {
    const access = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'club_admin',
      coachLevel: 5,
      athleteKind: null,
      sportCredentials: [
        CredentialRow(
          id: 'swim',
          kind: 'coach',
          status: 'approved',
          coachLevel: 5,
          sportCode: 'yuzme',
        ),
        CredentialRow(
          id: 'tennis',
          kind: 'coach',
          status: 'approved',
          coachLevel: 1,
          sportCode: 'tenis',
        ),
      ],
    );
    expect(access.hasCoachLevel(5), isTrue);
    expect(access.coachLevelForSport('yuzme', at: day), 5);
    expect(access.coachLevelForSport('tenis', at: day), 1);
    expect(access.hasCoachLevelForSport('tenis', 2, at: day), isFalse);
    expect(access.coachLevelForSport('judo', at: day), 0);
    expect(
      access.canWriteFederation(
        'tenis',
        '34',
        FederationDuty.resultPublisher,
        at: day,
      ),
      isFalse,
    );
  });
  test('legacy expiry stays valid; expired and pending credentials excluded',
      () {
    final access = SwanAccess(
      isPlatformAdmin: false,
      clubRole: null,
      coachLevel: 5,
      athleteKind: null,
      sportCredentials: [
        const CredentialRow(
          id: 'old',
          kind: 'coach',
          status: 'approved',
          coachLevel: 2,
          sportCode: 'tenis',
        ),
        CredentialRow(
          id: 'expired',
          kind: 'coach',
          status: 'approved',
          coachLevel: 5,
          sportCode: 'tenis',
          expiresOn: DateTime(2026, 10, 8),
        ),
        const CredentialRow(
          id: 'pending',
          kind: 'coach',
          status: 'pending',
          coachLevel: 5,
          sportCode: 'tenis',
        ),
      ],
    );
    expect(access.coachLevelForSport('tenis', at: day), 2);
    final credential = CredentialRow.fromMap({
      'id': 'x',
      'kind': 'coach',
      'status': 'approved',
      'sport_code': 'tenis',
      'expires_on': '2026-10-09',
    });
    expect(credential.isValidOn(DateTime.utc(2026, 10, 9, 20, 59)), isTrue);
    expect(credential.isValidOn(DateTime.utc(2026, 10, 9, 21)), isFalse);
  });
  test(
      'appointments need correct sport, geography, duty and active Turkey date',
      () {
    final appointment = FederationAppointment(
      id: 'x',
      sportCode: 'tenis',
      cityCode: '34',
      duty: FederationDuty.resultPublisher,
      startsOn: DateTime(2026, 10, 9),
      endsOn: DateTime(2026, 10, 9),
    );
    final access = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'club_admin',
      coachLevel: 5,
      athleteKind: null,
      federationAppointments: [appointment],
    );
    expect(
      access.canWriteFederation(
        'tenis',
        '34',
        FederationDuty.resultPublisher,
        at: day,
      ),
      isTrue,
    );
    expect(
      access.canWriteFederation(
        'yuzme',
        '34',
        FederationDuty.resultPublisher,
        at: day,
      ),
      isFalse,
    );
    expect(
      access.canWriteFederation(
        'tenis',
        '06',
        FederationDuty.resultPublisher,
        at: day,
      ),
      isFalse,
    );
    expect(
      access.canWriteFederation(
        'tenis',
        '34',
        FederationDuty.licenseRegistrar,
        at: day,
      ),
      isFalse,
    );
    expect(
      access.canWriteFederation(
        'tenis',
        null,
        FederationDuty.resultPublisher,
        at: day,
      ),
      isFalse,
    );
    expect(
      access.canWriteFederation(
        'tenis',
        '34',
        FederationDuty.resultPublisher,
        at: DateTime.utc(2026, 10, 9, 21),
      ),
      isFalse,
    );
  });
  test(
      'national assignment spans provinces; revoked and future assignments fail',
      () {
    FederationAppointment make({DateTime? revoked, DateTime? start}) =>
        FederationAppointment(
          id: 'a',
          sportCode: 'tenis',
          cityCode: null,
          duty: FederationDuty.programPublisher,
          startsOn: start ?? DateTime(2026),
          endsOn: DateTime(2027),
          revokedAt: revoked,
        );
    expect(
      make().authorizes('tenis', '06', FederationDuty.programPublisher, day),
      isTrue,
    );
    expect(
      make(revoked: day)
          .authorizes('tenis', '06', FederationDuty.programPublisher, day),
      isFalse,
    );
    expect(
      make(start: DateTime(2026, 10, 10))
          .authorizes('tenis', '06', FederationDuty.programPublisher, day),
      isFalse,
    );
  });
  test('fixture provider returns no fabricated appointments', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(myFederationAppointmentsProvider, (_, __) {});
    expect(
      await container.read(myFederationAppointmentsProvider.future),
      isEmpty,
    );
    expect(container.read(federationRecordsServiceProvider), isNull);
  });
  test('online write sends revision and card retains nullable child name',
      () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('federation_publish_result')) {
          expect(body, {
            'p_match': 'm',
            'p_protocol': {'type': 'score', 'home': 1, 'away': 0},
            'p_reason': 'corrected',
            'p_expected_version': 2,
          });
          return http.Response(
            jsonEncode('revision-id'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(request.url.path, '/rest/v1/rpc/federation_result_card');
        expect(body, {'p_match': 'm'});
        return http.Response(
          jsonEncode({
            'match_id': 'm',
            'sport_code': 'tenis',
            'category': 'U12',
            'version': 3,
            'protocol': {'type': 'score', 'home': 1, 'away': 0},
            'athletes': [
              {'athlete_id': 'a', 'name': null, 'national_id': 'not-retained'},
            ],
            'health': 'not-retained',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final service = FederationRecordsService(client);
    expect(
      await service.publishResult(
        matchId: 'm',
        protocol: {'type': 'score', 'home': 1, 'away': 0},
        reason: 'corrected',
        expectedVersion: 2,
      ),
      'revision-id',
    );
    final card = await service.resultCard('m');
    expect(card.athletes.single, (athleteId: 'a', name: null));
    expect(card.version, 3);
  });
  test('new credential needs expiry before making a backend request', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient:
          MockClient((_) async => throw StateError('unexpected request')),
    );
    addTearDown(client.dispose);
    final service = VerificationService(client);
    await expectLater(
      service.submitCoachCredential(2, sportCode: 'tenis'),
      throwsArgumentError,
    );
    await expectLater(
      service.submitAthleteCredential(sportCode: 'tenis'),
      throwsArgumentError,
    );
  });
}
