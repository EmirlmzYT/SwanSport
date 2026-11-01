import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('masked guardian overview parses real server aggregate', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/club_guardian_link_overview');
        expect(jsonDecode(request.body), {'p_club': 'club'});
        return http.Response(
          jsonEncode({
            'athletes': [
              {
                'id': 'athlete',
                'display_name': 'A. Y.',
                'is_minor': true,
                'status': 'active',
                'guardian_count': 1,
              },
            ],
            'links': [
              {
                'id': 'link',
                'athlete_id': 'athlete',
                'athlete_display_name': 'A. Y.',
                'guardian_label': 'Doğrulanmış veli hesabı',
                'relationship': 'Anne',
              },
            ],
            'pending_invites': [
              {
                'id': 'invite',
                'athlete_id': 'athlete',
                'athlete_display_name': 'A. Y.',
                'created_at': '2026-10-31T09:00:00Z',
                'expires_at': '2099-11-01T09:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final overview =
        await GuardianLinkManagementService(client).overview('club');
    expect(overview.athletes.single.displayName, 'A. Y.');
    expect(overview.athletes.single.isMinor, isTrue);
    expect(overview.links.single.guardianLabel, 'Doğrulanmış veli hesabı');
    expect(overview.pendingCount, 1);
  });

  test('pending invite cancellation uses guarded RPC', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/cancel_guardian_invite');
        expect(jsonDecode(request.body), {'p_invite': 'invite'});
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);

    await GuardianLinkManagementService(client).cancelPendingInvite('invite');
  });

  test('server failure is not converted into an empty successful overview',
      () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'key',
      httpClient: MockClient(
        (request) => Future.value(
          http.Response(
            '{"message":"forbidden","code":"P0001"}',
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      GuardianLinkManagementService(client).overview('club'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
