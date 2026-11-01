import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('dues overview parses partial payment and server summary', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/pro_club_dues_overview');
        expect(jsonDecode(request.body), {
          'p_club': 'club',
          'p_period': '2026-11',
        });
        return http.Response(
          jsonEncode({
            'summary': {
              'billed': 1000,
              'collected': 400,
              'outstanding': 600,
              'paid_count': 0,
              'partial_count': 1,
              'pending_count': 0,
              'overdue_count': 1,
              'pending_payment_count': 0,
            },
            'invoices': [
              {
                'id': 'invoice',
                'athlete_id': 'athlete',
                'athlete_name': 'Ada Yılmaz',
                'label': 'Kasım aidatı',
                'amount': 1000,
                'confirmed_amount': 400,
                'pending_amount': 0,
                'balance': 600,
                'status': 'partial',
                'period': '2026-11',
                'due_date': '2026-11-10',
              },
            ],
            'payments': const <Object?>[],
            'plans': const <Object?>[],
            'periods': ['2026-11'],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final overview = await ClubDuesManagementService(client).overview(
      'club',
      period: '2026-11',
    );
    expect(overview.summary.partialCount, 1);
    expect(overview.invoices.single.status, 'partial');
    expect(overview.invoices.single.balance, 600);
  });

  test('record payment sends stable operation id to guarded RPC', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/pro_record_payment');
        expect(jsonDecode(request.body), {
          'p_invoice': 'invoice',
          'p_amount': 250,
          'p_method': 'nakit',
          'p_note': 'Kısmi',
          'p_operation': 'operation-id',
        });
        return http.Response(
          jsonEncode('payment-id'),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await ClubDuesManagementService(client).recordPayment(
      invoiceId: 'invoice',
      amount: 250,
      method: 'nakit',
      note: 'Kısmi',
      operationId: 'operation-id',
    );
    expect(result, 'payment-id');
  });

  test('ambiguous server response is not reported as success', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'key',
      httpClient: MockClient(
        (request) => Future.value(
          http.Response(
            '{"message":"timeout","code":"57014"}',
            500,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      ClubDuesManagementService(client).recordPayment(
        invoiceId: 'invoice',
        amount: 250,
        method: 'nakit',
        operationId: 'operation-id',
      ),
      throwsA(isA<PostgrestException>()),
    );
  });
}
