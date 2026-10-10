import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

SwanAccess access(String tier, {bool admin = false}) => SwanAccess(
    isPlatformAdmin: admin,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    verificationTier: tier);
void main() {
  test(
      'venue action decisions require account then phone/id; admin does not bypass',
      () {
    for (final action in [
      SwanAction.reservation,
      SwanAction.partner,
      SwanAction.courtCheckIn
    ]) {
      expect(SwanAccess.none.decisionFor(action),
          SwanActionDecision.accountRequired);
      for (final tier in ['none', 'location', 'unknown']) {
        expect(
            access(tier).decisionFor(action), SwanActionDecision.phoneRequired);
        expect(access(tier, admin: true).decisionFor(action),
            SwanActionDecision.phoneRequired);
      }
      for (final tier in ['phone', 'id']) {
        expect(access(tier).decisionFor(action), SwanActionDecision.allowed);
      }
    }
    expect(access('none').decisionFor(SwanAction.message),
        SwanActionDecision.allowed);
    expect(access('id').decisionFor(SwanAction.clubApplication),
        SwanActionDecision.identityRequired);
  });
  test('both old venue and partner routes stay guest-readable', () {
    for (final route in [
      '/kortlar',
      '/halisahalar',
      '/partner-ara',
      '/oyuncu-aranan'
    ]) {
      expect(SwanAccess.isGuestRoute(route), isTrue);
    }
    for (final route in ['/sohbet', '/saha-islemlerim', '/dogrulama']) {
      expect(SwanAccess.isGuestRoute(route), isFalse);
    }
  });
  test('guest personal providers never construct a live service', () async {
    final container = ProviderContainer(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      authSessionProvider.overrideWith((_) => Stream.value(null)),
      courtServiceProvider
          .overrideWith((_) => throw StateError('private service'))
    ]);
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    expect(await container.read(mySportInterestsProvider.future), isEmpty);
    expect(await container.read(incomingPartnerPingsProvider.future), isEmpty);
    expect(await container.read(myOpenPartnerRequestProvider.future), isNull);
    expect(
        await container.read(myVenueVerificationTierProvider.future), 'none');
  });
  test('guest reads public partner RPC and typed public metadata', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/public_partner_requests');
      return http.Response(
          jsonEncode([
            {
              'request_id': 'request',
              'sport_code': 'tennis',
              'sport_name': 'Tenis',
              'city_name': 'İstanbul',
              'expires_at': '2026-10-10T14:00:00Z'
            }
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request);
    }));
    addTearDown(client.dispose);
    final result = (await CourtService(client).publicPartnerRequests()).single;
    expect(result.id, 'request');
    expect(result.cityName, 'İstanbul');
  });
  test('public payload rejects wrong required types and impossible date', () {
    final valid = <String, dynamic>{
      'request_id': 'request',
      'sport_code': 'tennis',
      'sport_name': 'Tenis',
      'expires_at': '2026-10-10T14:00:00Z'
    };
    for (final bad in [
      <String, dynamic>{},
      {...valid, 'request_id': 1},
      {...valid, 'sport_name': false},
      {...valid, 'expires_at': 'bad'}
    ]) {
      expect(() => PublicPartnerRequest.fromMap(bad), throwsFormatException);
    }
    expect(PublicPartnerRequest.fromMap({...valid, 'city_name': 1}).cityName,
        isNull);
  });
  test(
      'partner publication defaults private; ping uses exact existing server params',
      () async {
    final requests = <String, Map<String, dynamic>>{};
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      requests[request.url.path] =
          jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
          request.url.path.endsWith('seek_partner') ? '"request"' : 'null', 200,
          request: request);
    }));
    addTearDown(client.dispose);
    final service = CourtService(client);
    await service.seekPartner(sportCode: 'tennis');
    expect(requests['/rest/v1/rpc/seek_partner']?['p_public'], false);
    await service.seekPartner(sportCode: 'tennis', isPublic: true);
    expect(requests['/rest/v1/rpc/seek_partner']?['p_public'], true);
    await service.sendPartnerPing('request');
    expect(
        requests['/rest/v1/rpc/send_partner_ping'], {'p_request': 'request'});
  });
  test(
      'guest verification service cannot request or confirm phone or call tier RPC',
      () async {
    var calls = 0;
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      calls++;
      return http.Response('null', 200, request: request);
    }));
    addTearDown(client.dispose);
    final service = VerificationService(client);
    expect(await service.venueVerificationTier(), 'none');
    await expectLater(
        service.requestPhoneVerification('+905321234567'), throwsStateError);
    await expectLater(
        service.confirmPhoneVerification('+905321234567', '123456'),
        throwsStateError);
    expect(calls, 0);
  });
  test(
      'phone change OTP uses Auth and verified tier is read from server, not profile',
      () async {
    final calls = <http.Request>[];
    final user = <String, dynamic>{
      'id': 'user',
      'aud': 'authenticated',
      'created_at': '2026-10-10T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{}
    };
    final session = <String, dynamic>{
      'access_token': 'test-token',
      'refresh_token': 'refresh',
      'expires_in': 3600,
      'token_type': 'bearer',
      'user': user
    };
    Object? tier = 'phone';
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      calls.add(request);
      Object? response;
      if (request.url.path.endsWith('/token') ||
          request.url.path.endsWith('/verify')) {
        response = session;
      } else if (request.url.path.endsWith('/user')) {
        response = user;
      } else {
        expect(request.url.path, '/rest/v1/rpc/my_venue_verification_tier');
        response = tier;
      }
      return http.Response(jsonEncode(response), 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request);
    }));
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
        email: 'test@example.com', password: 'test-password');
    final service = VerificationService(client);
    final initial = calls.length;
    await expectLater(
        service.requestPhoneVerification('05321234567'), throwsArgumentError);
    await expectLater(service.confirmPhoneVerification('+905321234567', 'bad'),
        throwsArgumentError);
    expect(calls.length, initial);
    await service.requestPhoneVerification('+905321234567');
    expect(calls.last.method, 'PUT');
    expect(jsonDecode(calls.last.body)['phone'], '+905321234567');
    await service.confirmPhoneVerification('+905321234567', '123456');
    expect(jsonDecode(calls.last.body), containsPair('type', 'phone_change'));
    expect(jsonDecode(calls.last.body), containsPair('token', '123456'));
    expect(await service.venueVerificationTier(), 'phone');
    tier = 'id';
    expect(await service.venueVerificationTier(), 'id');
    tier = <String, dynamic>{'verification_tier': 'phone'};
    expect(await service.venueVerificationTier(), 'none');
  });
  test(
      'venue metadata reads public Storage paths and survives distance sorting',
      () async {
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((request) async {
      final turf = request.url.path.endsWith('turf_fields');
      expect(request.url.queryParameters['select'], contains('surface_type'));
      expect(request.url.queryParameters['select'], contains('photo_paths'));
      return http.Response(
          jsonEncode([
            {
              'id': 'venue',
              'name': 'Venue',
              'venue_name': 'Tesis',
              'lat': 41,
              'lng': 29,
              'surface_type': 'Grass',
              'photo_paths': ['venue/photo.jpg', 1, null],
              'opens_at': '08:00',
              'closes_at': '23:00',
              if (!turf) 'capacity': 4
            }
          ]),
          200,
          request: request);
    }));
    addTearDown(client.dispose);
    final court =
        (await CourtService(client).courts()).single.withDistance(100);
    final turf = (await TurfService(client).fields()).single.withDistance(100);
    expect(court.surfaceType, 'Grass');
    expect(turf.surfaceType, 'Grass');
    expect(court.photoUrls.single,
        contains('/storage/v1/object/public/post-media/venue/photo.jpg'));
    expect(turf.photoUrls, court.photoUrls);
  });
}
