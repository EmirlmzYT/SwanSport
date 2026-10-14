import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  Future<SupabaseClient> signedClient() async {
    final client = SupabaseClient('https://example.supabase.co', 'test',
      httpClient: MockClient((request) async => http.Response(jsonEncode({
        'access_token': 'user-token', 'refresh_token': 'refresh', 'expires_in': 3600,
        'token_type': 'bearer', 'user': {'id': 'me', 'aud': 'authenticated',
          'created_at': '2026-10-14T00:00:00Z', 'app_metadata': <String,dynamic>{},
          'user_metadata': <String,dynamic>{}},
      }), 200, headers: {'content-type': 'application/json'}, request: request)));
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(email: 'test@example.com', password: 'test-password');
    return client;
  }

  test('checksum validates shape and both digits but is not identity proof', () {
    expect(isValidNationalId('10000000146'), isTrue);
    for (final value in ['10000000147', '00000000146', '1000000014', '100000001460', '1000000014x', ' 10000000146']) {
      expect(isValidNationalId(value), isFalse);
    }
  });
  test('invalid checksum never sends an HTTP request', () async {
    final client = await signedClient(); var calls = 0;
    final transport = MockClient((_) async { calls++; return http.Response('{}',200); });
    addTearDown(transport.close);
    final result = await VerificationService(client,httpClient:transport).verifyWithMernis(
      nationalId:'10000000147',firstName:'İlker',lastName:'Işık',birthYear:1995);
    expect(result.success,isFalse); expect(calls,0);
  });
  test('verified completion sends only user token and triggers authoritative refresh once', () async {
    final client = await signedClient(); var changes = 0;
    final transport = MockClient((r) async {
      expect(r.url.path,'/api/verify-tckn'); expect(r.headers['authorization'],'Bearer user-token');
      final body=jsonDecode(r.body) as Map;
      expect(body.keys.toSet(),{'national_id','first_name','last_name','birth_year'});
      expect(body['first_name'],'İlker'); expect(body['birth_year'],1995);
      return http.Response('{"success":true}',200);
    });
    addTearDown(transport.close);
    final result=await VerificationService(client,httpClient:transport,onIdentityVerified:()=>changes++)
      .verifyWithMernis(nationalId:'10000000146',firstName:'İlker',lastName:'Işık',birthYear:1995);
    expect(result.success,isTrue);expect(changes,1);
  });
  test('unavailable/rate/conflict responses cannot echo identity data or claim success', () async {
    final client=await signedClient(); var changes=0;
    for(final code in [503,429,409,422,401]) {
      final transport=MockClient((_)async=>http.Response('{"success":true,"error":"10000000146"}',code));
      addTearDown(transport.close);
      final result=await VerificationService(client,httpClient:transport,onIdentityVerified:()=>changes++)
        .verifyWithMernis(nationalId:'10000000146',firstName:'İlker',lastName:'Işık',birthYear:1995);
      expect(result.success,isFalse);expect(result.error,isNot(contains('10000000146')));
    }
    expect(changes,0);
  });
  test('malformed/network responses fail closed, availability is boolean and uses GET', () async {
    final client=await signedClient();
    final transport=MockClient((r)async {
      if(r.method=='GET')return http.Response('{"available":true}',200);
      return http.Response('not-json',200);
    });
    addTearDown(transport.close);
    final service=VerificationService(client,httpClient:transport);
    expect(await service.mernisAvailable(),isTrue);
    expect((await service.verifyWithMernis(nationalId:'10000000146',firstName:'A',lastName:'B',birthYear:1995)).success,isFalse);
  });
  test('guest does not transmit identity fields', () async {
    final client=SupabaseClient('https://example.supabase.co','test');addTearDown(client.dispose);
    var calls=0;final transport=MockClient((_)async{calls++;return http.Response('{}',200);});addTearDown(transport.close);
    final service=VerificationService(client,httpClient:transport);
    expect(await service.mernisAvailable(),isFalse);
    expect((await service.verifyWithMernis(nationalId:'10000000146',firstName:'A',lastName:'B',birthYear:1995)).success,isFalse);
    expect(calls,0);
  });
  test('late success after logout cannot refresh another session', () async {
    final client=await signedClient();final pending=Completer<http.Response>();var changes=0;
    final transport=MockClient((_)=>pending.future);addTearDown(transport.close);
    final result=VerificationService(client,httpClient:transport,onIdentityVerified:()=>changes++)
      .verifyWithMernis(nationalId:'10000000146',firstName:'A',lastName:'B',birthYear:1995);
    await client.auth.signOut(scope:SignOutScope.local);
    pending.complete(http.Response('{"success":true}',200));
    expect((await result).success,isFalse);expect(changes,0);
  });
}
