import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final day = DateTime.utc(2026, 10, 9, 12);

  test('declared staff/admin roles and sport approval do not verify identity',
      () {
    const access = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'club_admin',
      coachLevel: 5,
      athleteKind: 'athlete_licensed',
    );
    expect(access.isInIdentityWaitingRoom, isTrue);
    expect(access.passesIdentityGateForClub('club'), isFalse);
    expect(SwanAccess.none.isInIdentityWaitingRoom, isFalse);
    // Existing read visibility is preserved; this is an additional write axis.
    expect(access.isClubStaff, isTrue);
  });

  test(
      'legacy access is limited to the existing club and never verifies identity',
      () {
    const access = SwanAccess(
      isPlatformAdmin: false,
      clubRole: 'coach',
      coachLevel: 2,
      athleteKind: null,
      legacyIdentityClubIds: {'old'},
    );
    expect(access.hasVerifiedIdentity, isFalse);
    expect(access.isInIdentityWaitingRoom, isFalse);
    expect(access.passesIdentityGateForClub('old'), isTrue);
    expect(access.passesIdentityGateForClub('new'), isFalse);
    expect(access.canRequestSportMembership('tenis', at: day), isFalse);
  });

  test(
      'new sport membership needs verified identity and a valid matching role/branch',
      () {
    final access = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'parent',
      coachLevel: 5,
      athleteKind: null,
      hasVerifiedIdentity: true,
      sportCredentials: [
        const CredentialRow(
          id: 'old',
          kind: 'coach',
          status: 'approved',
          sportCode: 'tenis',
          coachLevel: 2,
        ),
        CredentialRow(
          id: 'expired',
          kind: 'athlete_licensed',
          status: 'approved',
          sportCode: 'yuzme',
          expiresOn: DateTime(2026, 10, 8),
        ),
      ],
    );
    expect(
      access.canRequestSportMembership('tenis', role: 'coach', at: day),
      isTrue,
    );
    expect(access.canRequestSportMembership('tenis', at: day), isFalse);
    expect(access.canRequestSportMembership('yuzme', at: day), isFalse);
    expect(
      access.canRequestSportMembership('judo', role: 'coach', at: day),
      isFalse,
    );
  });

  test(
      'verified parent needs no license for identity but gains no coach eligibility',
      () {
    const access = SwanAccess(
      isPlatformAdmin: false,
      clubRole: null,
      coachLevel: 0,
      athleteKind: null,
      hasVerifiedIdentity: true,
    );
    expect(access.isInIdentityWaitingRoom, isFalse);
    expect(access.passesIdentityGateForClub('club'), isTrue);
    expect(access.canRequestSportMembership('tenis', role: 'coach'), isFalse);
  });

  test(
      'server state parser does not trust declarations; fixture provider stays closed',
      () async {
    final state = IdentityGateState.fromMap({
      'identity_verified': false,
      'national_id': '11111111110',
      'role': 'coach',
      'legacy_club_ids': ['old'],
    });
    expect(state.verified, isFalse);
    expect(state.legacyClubIds, {'old'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final fixture = await container.read(myIdentityGateProvider.future);
    expect(fixture.verified, isFalse);
    expect(fixture.legacyClubIds, isEmpty);
    expect(
      const CredentialRow(id: 'id', kind: 'identity', status: 'pending').label,
      'Kimlik',
    );
  });

  test(
      'existing review RPC carries reviewed TCKN and expiry without writing profiles',
      () async {
    Map<String, dynamic>? body;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/review_credential');
        body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    await VerificationService(client).reviewCredential(
      'cred',
      true,
      nationalId: '11111111110',
      expiresOn: DateTime(2027, 1, 31),
    );
    expect(body!['p_national_id'], '11111111110');
    expect(body!['p_expires_on'], '2027-01-31');
    expect(body!['p_cred'], 'cred');
  });

  test('verified identity does not give an accountant sports staff rights', () {
    const access = SwanAccess(
      isPlatformAdmin: false,
      clubRole: null,
      coachLevel: 0,
      athleteKind: null,
      hasVerifiedIdentity: true,
      accountantClubIds: {'club'},
    );
    expect(access.isAccountant, isTrue);
    expect(access.isClubStaff, isFalse);
    expect(access.isClubAdmin, isFalse);
    expect(access.canRequestSportMembership('tenis', role: 'coach'), isFalse);
  });
}
