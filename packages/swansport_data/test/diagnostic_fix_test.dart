import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test(
      'numeric versions compare minor, patch and build with unknown failing closed',
      () {
    expect(diagnosticReleaseAtLeast('0.5.10+1', '0.5.9+99'), true);
    expect(diagnosticReleaseAtLeast('0.5.2+16', '0.5.2+17'), false);
    expect(diagnosticReleaseAtLeast('0.5.2', '0.5.2+0'), true);
    expect(diagnosticReleaseAtLeast('1.0.0', '0.99.99+999'), true);
    for (final invalid in [
      'unknown',
      '0.5',
      '1.0.0+secret',
      '1.0.0 ',
      '${'9' * 65}.1.1',
    ]) {
      expect(diagnosticReleaseAtLeast(invalid, '0.5.2+17'), false);
    }
  });
  test(
      'confirmation is scoped to declared application platform and release and not closed',
      () {
    final recorder = DiagnosticsRecorder()
      ..release = '0.5.2+17'
      ..platform = 'android'
      ..application = 'app';
    addTearDown(recorder.dispose);
    const fix = DiagnosticFixContext(
        issueId: 'i',
        issueState: 'resolved',
        ticketStatus: 'awaiting_user_response',
        fixId: 'f',
        release: '0.5.2+17',
        platform: 'android',
        application: 'app',);
    expect(fix.canRespond(recorder), true);
    recorder.platform = 'web';
    expect(fix.canRespond(recorder), false);
    recorder.platform = 'android';
    recorder.application = 'console';
    expect(fix.canRespond(recorder), false);
    recorder.application = 'app';
    recorder.release = '0.5.1+999';
    expect(fix.canRespond(recorder), false);
    const closed = DiagnosticFixContext(
        issueId: 'i',
        issueState: 'resolved',
        ticketStatus: 'closed',
        fixId: 'f',
        release: '0.5.2+17',
        platform: 'android',
        application: 'app',);
    recorder.release = '0.5.2+17';
    expect(closed.canRespond(recorder), false);
  });
  test('declaration uses a distinct RPC with release and platform', () async {
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/declare_diagnostic_fix');
      expect(jsonDecode(request.body),
          {'p_issue': 'i', 'p_release': '0.5.2+17', 'p_platform': 'android'},);
      return http.Response('"f"', 200,
          headers: {'content-type': 'application/json'}, request: request,);
    }),);
    addTearDown(client.dispose);
    expect(
        await DiagnosticsService(client).declareFix('i', '0.5.2+17', 'android'),
        'f',);
  });
  test(
      'user feedback sends the displayed fix ID and current environment, not a staff identity',
      () async {
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/respond_support_fix');
      expect(jsonDecode(request.body), {
        'p_ticket': 't',
        'p_fix': 'f',
        'p_result': 'still_failing',
        'p_release': '0.5.2+17',
        'p_platform': 'android',
        'p_application': 'app',
      });
      return http.Response('', 204, request: request);
    }),);
    addTearDown(client.dispose);
    await DiagnosticsService(client).respondFix('t', 'f', 'still_failing',
        release: '0.5.2+17', platform: 'android', application: 'app',);
  });
  test('support association uses the existing ticket and issue', () async {
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/link_support_issue');
      expect(jsonDecode(request.body), {'p_ticket': 't', 'p_issue': 'i'});
      return http.Response('', 204, request: request);
    }),);
    addTearDown(client.dispose);
    await DiagnosticsService(client).linkIssue('t', 'i');
  });
  test('fix context parses safe fields and preserves missing declarations',
      () async {
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/support_fix_context');
      return http.Response(
          jsonEncode({
            'issue_id': 'i',
            'issue_state': 'investigating',
            'ticket_status': 'new',
            'fix_id': null,
            'regression_count': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,);
    }),);
    addTearDown(client.dispose);
    final context = await DiagnosticsService(client).fixContext('t');
    expect(context!.issueId, 'i');
    expect(context.fixId, isNull);
  });
}
