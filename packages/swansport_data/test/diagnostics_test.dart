import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swansport_data/swansport_data.dart';

class BrokenStreamClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream<List<int>>.error(StateError('SECRET')), 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiagnosticsRecorder recorder;
  setUp(() {
    recorder = DiagnosticsRecorder();
  });
  tearDown(() {
    recorder.dispose();
  });
  Future<List<Map<String, dynamic>>> collect() async {
    final batches = <Map<String, dynamic>>[];
    recorder.setActor('test-user');
    recorder.transport = (_, events) async {
      batches.addAll(events);
    };
    await recorder.flush();
    return batches;
  }

  test('default preferences collect nothing', () async {
    recorder.navigate('/destek');
    recorder.capture(Exception('SECRET'), StackTrace.current);
    expect(recorder.queuedCount, 0);
    expect(recorder.breadcrumbs, isEmpty);
  });
  test(
      'only catalogued technical identifiers and safe source locations survive',
      () async {
    recorder
        .setPreferences(const DiagnosticPreferences(errors: true, usage: true));
    recorder.setActor('test-user');
    recorder.navigate('/profile/private@example.com?id=SECRET');
    recorder.record('error',
        operation: 'private@example.com',
        code: 'SECRET',
        frames: [
          {
            'source': 'package:swansport_data/src/diagnostics.dart',
            'line': 10,
            'token': 'SECRET'
          },
          {'source': 'file:///private/person.dart', 'line': 1}
        ]);
    final events = await collect();
    final text = jsonEncode(events);
    expect(text, isNot(contains('SECRET')));
    expect(text, isNot(contains('private@example')));
    expect(events.last['screen'], '/unknown');
    expect(events.last['operation'], 'unknown');
    expect(events.last['frames'], [
      {'source': 'package:swansport_data/src/diagnostics.dart', 'line': 10}
    ]);
  });
  test('error-only mode keeps breadcrumbs locally and uploads them with errors',
      () async {
    recorder.setPreferences(const DiagnosticPreferences(errors: true));
    recorder.setActor('test-user');
    recorder.navigate('/destek');
    recorder.record('success', operation: 'auth');
    expect(recorder.queuedCount, 0);
    expect(recorder.breadcrumbs.length, 2);
    recorder.capture(
        Exception('SECRET'),
        StackTrace.fromString(
            '#0 f (package:swansport_data/src/diagnostics.dart:10:5)'),
        operation: 'async');
    final events = await collect();
    expect(events.length, 1);
    expect((events.single['breadcrumbs'] as List).length, 3);
    expect(jsonEncode(events), isNot(contains('SECRET')));
    expect(events.single['usage_enabled'], false);
  });
  test('usage-only mode includes failed operations but no exception stacks',
      () async {
    recorder.setPreferences(const DiagnosticPreferences(usage: true));
    recorder.setActor('test-user');
    recorder.record('error', operation: 'auth', code: 'http_400', frames: [
      {'source': 'package:swansport_data/src/diagnostics.dart', 'line': 10}
    ]);
    recorder.capture(Exception('SECRET'), StackTrace.current);
    final events = await collect();
    expect(events.length, 1);
    expect(events.single['frames'], isEmpty);
    expect(events.single.containsKey('breadcrumbs'), false);
    expect(events.single['usage_enabled'], true);
  });
  test('queue and breadcrumbs stay bounded; disabling clears unsent data', () {
    recorder
        .setPreferences(const DiagnosticPreferences(errors: true, usage: true));
    for (var i = 0; i < 200; i++) {
      recorder.record('success', operation: 'auth');
    }
    expect(recorder.queuedCount, 100);
    expect(recorder.breadcrumbs.length, 30);
    recorder.setPreferences(const DiagnosticPreferences());
    expect(recorder.queuedCount, 0);
    expect(recorder.breadcrumbs, isEmpty);
  });
  test('account change rotates the session and drops previous account history',
      () {
    recorder
        .setPreferences(const DiagnosticPreferences(errors: true, usage: true));
    recorder.setActor('first');
    recorder.navigate('/destek');
    final session = recorder.sessionId;
    recorder.setActor('second');
    expect(recorder.sessionId, isNot(session));
    expect(recorder.queuedCount, 0);
    expect(recorder.breadcrumbs, isEmpty);
  });
  test(
      'transport failure keeps bounded retry data and never escapes into business actions',
      () async {
    recorder.setPreferences(const DiagnosticPreferences(usage: true));
    recorder.setActor('test-user');
    recorder.record('success', operation: 'auth');
    recorder.transport = (_, __) async {
      throw Exception('offline');
    };
    await recorder.flush();
    expect(recorder.queuedCount, 1);
    recorder.transport = (_, __) async {};
    await recorder.flush();
    expect(recorder.queuedCount, 0);
  });
  test('completion of an old-session upload cannot erase new-session events',
      () async {
    recorder.setPreferences(const DiagnosticPreferences(usage: true));
    recorder.setActor('first');
    recorder.record('success', operation: 'auth');
    final gate = Completer<void>();
    recorder.transport = (_, __) => gate.future;
    final flushing = recorder.flush();
    recorder.setActor('second');
    recorder.record('success', operation: 'auth');
    gate.complete();
    await flushing;
    expect(recorder.queuedCount, 1);
  });
  test('batch byte limit holds even with thirty breadcrumbs per error',
      () async {
    recorder
        .setPreferences(const DiagnosticPreferences(errors: true, usage: true));
    recorder.setActor('test-user');
    for (var i = 0; i < 50; i++) {
      recorder.record('error', operation: 'auth', code: 'network_error');
    }
    final sizes = <int>[];
    recorder.transport = (_, events) async {
      sizes.add(utf8.encode(jsonEncode(events)).length);
    };
    await recorder.flush();
    expect(sizes.single, lessThan(65536));
    expect(recorder.queuedCount, greaterThan(0));
  });
  test('HTTP bodies, query strings and auth headers never enter diagnostics',
      () async {
    recorder
        .setPreferences(const DiagnosticPreferences(errors: true, usage: true));
    recorder.setActor('test-user');
    final client = DiagnosticHttpClient(MockClient((request) async {
      expect(request.body, 'SECRET body');
      expect(request.headers['authorization'], 'SECRET token');
      expect(request.headers['x-client-info'], contains('swan-trace='));
      return http.Response('SECRET response', 400);
    }), recorder, backendHost: 'backend.example');
    final response = await client.post(
        Uri.parse(
            'https://backend.example/rest/v1/rpc/create_finance_adjustment?name=SECRET'),
        headers: {'authorization': 'SECRET token'},
        body: 'SECRET body');
    expect(response.body, 'SECRET response');
    final events = await collect();
    expect(jsonEncode(events), isNot(contains('SECRET')));
    expect(events.last['operation'], 'rpc:create_finance_adjustment');
    expect(events.last['code'], 'http_400');
    client.close();
  });
  test(
      'diagnostic transport and unrelated hosts are not instrumented recursively',
      () async {
    recorder.setPreferences(const DiagnosticPreferences(usage: true));
    recorder.setActor('test-user');
    final client = DiagnosticHttpClient(
        MockClient((_) async => http.Response('{}', 200)), recorder,
        backendHost: 'backend.example');
    await client.get(
        Uri.parse('https://backend.example/rest/v1/rpc/ingest_diagnostics'));
    await client.get(Uri.parse(
        'https://elsewhere.example/rest/v1/rpc/create_finance_adjustment'));
    expect(recorder.queuedCount, 0);
    client.close();
  });
  test(
      'business action and its network calls share a trace; original failure is rethrown',
      () async {
    recorder
        .setPreferences(const DiagnosticPreferences(errors: true, usage: true));
    recorder.setActor('test-user');
    final client = DiagnosticHttpClient(
        MockClient((_) async => http.Response('{}', 200)), recorder,
        backendHost: 'backend.example');
    final value = await recorder.trace('action:finance_adjustment', () async {
      await client.get(Uri.parse(
          'https://backend.example/rest/v1/rpc/create_finance_adjustment'));
      return 42;
    });
    expect(value, 42);
    final events = await collect();
    expect(events.map((e) => e['trace_id']).toSet().length, 1);
    final original = StateError('SECRET');
    await expectLater(
        recorder.trace('action:finance_adjustment', () async {
          throw original;
        }),
        throwsA(same(original)));
    client.close();
  });
  test('preference initialization defaults off and persists user choices',
      () async {
    SharedPreferences.setMockInitialValues({});
    await DiagnosticPreferencesController.initialize(recorder);
    expect(recorder.preferences.enabled, false);
    final controller = DiagnosticPreferencesController(recorder);
    await controller.update(errors: true);
    expect(recorder.preferences.errors, true);
    final next = DiagnosticsRecorder();
    await DiagnosticPreferencesController.initialize(next);
    expect(next.preferences.errors, true);
    expect(next.preferences.usage, false);
    controller.dispose();
    next.dispose();
  });
  test('body stream failure records one failure and no premature success',
      () async {
    recorder.setPreferences(const DiagnosticPreferences(usage: true));
    recorder.setActor('test-user');
    final client = DiagnosticHttpClient(BrokenStreamClient(), recorder,
        backendHost: 'backend.example');
    await expectLater(
        client.get(Uri.parse(
            'https://backend.example/rest/v1/rpc/create_finance_adjustment')),
        throwsStateError);
    final events = await collect();
    expect(events.where((e) => e['kind'] == 'success'), isEmpty);
    expect(events.where((e) => e['kind'] == 'error').length, 1);
    expect(jsonEncode(events), isNot(contains('SECRET')));
    client.close();
  });
  test('rapid preference toggles persist the last choice', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = DiagnosticPreferencesController(recorder);
    await Future.wait([
      controller.update(errors: true),
      controller.update(errors: false),
      controller.update(usage: true)
    ]);
    final fresh = DiagnosticsRecorder();
    await DiagnosticPreferencesController.initialize(fresh);
    expect(fresh.preferences.errors, false);
    expect(fresh.preferences.usage, true);
    fresh.dispose();
    controller.dispose();
  });
  test('late preference initialization updates an already mounted controller',
      () async {
    SharedPreferences.setMockInitialValues({'diagnostics_errors_v1': true});
    final controller = DiagnosticPreferencesController(recorder);
    expect(controller.state.errors, false);
    await DiagnosticPreferencesController.initialize(recorder);
    expect(controller.state.errors, true);
    controller.dispose();
  });
}
