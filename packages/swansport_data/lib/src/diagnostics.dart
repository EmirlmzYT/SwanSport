import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'diagnostics_catalog.dart';
import 'supabase_scope.dart';

String diagnosticId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class DiagnosticPreferences {
  const DiagnosticPreferences({this.errors = false, this.usage = false});
  final bool errors;
  final bool usage;
  bool get enabled => errors || usage;
}

/// Only catalogued code identifiers and numeric metadata enter the recorder.
/// No exception messages, HTTP bodies/headers, URL parameters or form values.
class DiagnosticsRecorder {
  DiagnosticsRecorder({this.maxQueue = 100, this.maxBreadcrumbs = 30});
  static final instance = DiagnosticsRecorder();
  final int maxQueue;
  final int maxBreadcrumbs;
  DiagnosticPreferences preferences = const DiagnosticPreferences();
  final _preferenceChanges =
      StreamController<DiagnosticPreferences>.broadcast(sync: true);
  String release = 'unknown';
  String platform = 'unknown';
  String application = 'app';
  String screen = '/';
  String sessionId = diagnosticId();
  String? _actor;
  final Queue<Map<String, dynamic>> _queue = Queue();
  final Queue<Map<String, dynamic>> _breadcrumbs = Queue();
  Future<void> Function(String, List<Map<String, dynamic>>)? transport;
  Timer? _timer;
  bool _flushing = false;
  int _generation = 0;
  int _failures = 0;
  StreamSubscription<AuthState>? _authSubscription;
  DateTime _lastActivity = DateTime.now();
  int get queuedCount => _queue.length;

  Future<void> bind(SupabaseClient client) async {
    transport = DiagnosticsService(client).ingest;
    setActor(client.auth.currentUser?.id);
    await _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange
        .listen((event) => setActor(event.session?.user.id));
  }

  List<Map<String, dynamic>> get breadcrumbs =>
      _breadcrumbs.map((e) => Map<String, dynamic>.from(e)).toList();

  void setPreferences(DiagnosticPreferences value) {
    preferences = value;
    _generation++;
    _queue.clear();
    _breadcrumbs.clear();
    _timer?.cancel();
    if (value.enabled && transport != null) _schedule();
    _preferenceChanges.add(value);
  }

  void setActor(String? actor) {
    if (_actor == actor) return;
    _actor = actor;
    _failures = 0;
    _generation++;
    sessionId = diagnosticId();
    _queue.clear();
    _breadcrumbs.clear();
    _timer?.cancel();
    if (actor != null && preferences.enabled && transport != null) _schedule();
  }

  String safeScreen(String? route) =>
      diagnosticRoutes.contains(route) ? route! : '/unknown';

  void navigate(String? route) {
    screen = safeScreen(route);
    record('screen', operation: 'navigation');
  }

  void record(
    String kind, {
    String operation = 'unknown',
    String? traceId,
    String code = 'none',
    int durationMs = 0,
    List<Map<String, dynamic>> frames = const [],
  }) {
    if (!preferences.enabled ||
        !{'screen', 'start', 'success', 'error', 'slow', 'cancel'}
            .contains(kind)) {
      return;
    }
    if (DateTime.now().difference(_lastActivity) >
        const Duration(minutes: 30)) {
      // Discard expired in-memory events instead of relabelling the session.
      _generation++;
      _queue.clear();
      _breadcrumbs.clear();
      sessionId = diagnosticId();
    }
    _lastActivity = DateTime.now();
    final safeOperation =
        diagnosticOperations.contains(operation) ? operation : 'unknown';
    final safeCode =
        RegExp(r'^(none|network_error|timeout|framework|async|provider|validation|consistency|http_[1-5][0-9]{2})$')
                .hasMatch(code)
            ? code
            : 'unknown';
    final event = <String, dynamic>{
      'id': diagnosticId(),
      'trace_id':
          traceId != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(traceId)
              ? traceId
              : diagnosticId(),
      'kind': kind,
      'operation': safeOperation,
      'screen': safeScreen(screen),
      'code': safeCode,
      'duration_ms': durationMs.clamp(0, 600000),
      'release':
          RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?$').hasMatch(release)
              ? release
              : 'unknown',
      'platform': {'web', 'android', 'ios', 'windows', 'linux', 'macos'}
              .contains(platform)
          ? platform
          : 'unknown',
      'application': application == 'console' ? 'console' : 'app',
      'usage_enabled': preferences.usage,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'frames': preferences.errors
          ? frames
              .where(
                (f) =>
                    diagnosticSources.contains(f['source']) && f['line'] is int,
              )
              .take(10)
              .map(
                (f) => {
                  'source': f['source'],
                  'line': (f['line'] as int).clamp(1, 100000),
                },
              )
              .toList()
          : <Map<String, dynamic>>[],
    };
    // Breadcrumbs are uploaded only with an error or explicit support report.
    if (preferences.errors) {
      _breadcrumbs.add(Map<String, dynamic>.from(event)..remove('frames'));
      while (_breadcrumbs.length > maxBreadcrumbs) {
        _breadcrumbs.removeFirst();
      }
    }
    if ((kind == 'error' && preferences.errors) || preferences.usage) {
      if (kind == 'error' && preferences.errors) {
        event['breadcrumbs'] = breadcrumbs;
      }
      _queue.add(event);
      while (_queue.length > maxQueue) {
        _queue.removeFirst();
      }
      if (kind == 'error' && _failures == 0) {
        unawaited(flush());
      } else {
        _schedule();
      }
    }
  }

  List<Map<String, dynamic>> safeFrames(StackTrace stack) {
    final frames = <Map<String, dynamic>>[];
    for (final match
        in RegExp(r'(package:swansport_[a-z_]+/[^\s():]+\.dart):(\d+)(?::\d+)?')
            .allMatches('$stack')) {
      final source = match.group(1)!;
      if (diagnosticSources.contains(source)) {
        frames.add({
          'source': source,
          'line': int.parse(match.group(2)!).clamp(1, 100000),
        });
      }
      if (frames.length == 10) break;
    }
    return frames;
  }

  void capture(
    Object error,
    StackTrace stack, {
    String code = 'async',
    String operation = 'unknown',
  }) {
    if (!preferences.errors) return;
    record(
      'error',
      operation: operation,
      code: code,
      frames: safeFrames(stack),
    );
  }

  Future<T> trace<T>(String operation, Future<T> Function() action) async {
    final trace = diagnosticId();
    final watch = Stopwatch()..start();
    record('start', operation: operation, traceId: trace);
    try {
      final result =
          await runZoned(action, zoneValues: {#diagnosticTrace: trace});
      record(
        'success',
        operation: operation,
        traceId: trace,
        durationMs: watch.elapsedMilliseconds,
      );
      return result;
    } catch (error, stack) {
      record(
        'error',
        operation: operation,
        traceId: trace,
        code: 'validation',
        durationMs: watch.elapsedMilliseconds,
        frames: safeFrames(stack),
      );
      rethrow;
    }
  }

  Map<String, dynamic> supportSnapshot() => {
        'session_id': sessionId,
        'release': release,
        'platform': platform,
        'screen': safeScreen(screen),
        'events': breadcrumbs,
      };

  void _schedule() {
    if (_timer?.isActive == true ||
        !preferences.enabled ||
        _actor == null ||
        transport == null) {
      return;
    }
    final seconds =
        _failures == 0 ? 15 : min(300, 15 * (1 << min(_failures, 4)));
    _timer = Timer(Duration(seconds: seconds), () => unawaited(flush()));
  }

  Future<void> flush() async {
    if (_flushing ||
        !preferences.enabled ||
        _actor == null ||
        transport == null ||
        _queue.isEmpty) {
      return;
    }
    _timer?.cancel();
    _flushing = true;
    final generation = _generation;
    final session = sessionId;
    final batch = <Map<String, dynamic>>[];
    var bytes = 2;
    for (final event in _queue.take(20)) {
      final size = utf8.encode(jsonEncode(event)).length + 1;
      if (bytes + size > 60000) break;
      batch.add(event);
      bytes += size;
    }
    if (batch.isEmpty) {
      _queue.removeFirst();
      _flushing = false;
      _schedule();
      return;
    }
    try {
      await transport!(session, batch).timeout(const Duration(seconds: 8));
      if (generation == _generation) {
        final ids = batch.map((e) => e['id']).toSet();
        _queue.removeWhere((e) => ids.contains(e['id']));
        _failures = 0;
      }
    } catch (_) {
      // Diagnostics must not break a user operation or recursively report itself.
      if (generation == _generation) _failures++;
    } finally {
      _flushing = false;
      if (_queue.isNotEmpty) _schedule();
    }
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_authSubscription?.cancel());
    _queue.clear();
    _breadcrumbs.clear();
    unawaited(_preferenceChanges.close());
  }
}

/// Instruments the initialized Supabase transport, including REST, RPC and storage.
/// Stream contents are forwarded unchanged and never buffered/read by telemetry.
class DiagnosticHttpClient extends http.BaseClient {
  DiagnosticHttpClient(this.inner, this.recorder, {required this.backendHost});
  final http.Client inner;
  final DiagnosticsRecorder recorder;
  final String backendHost;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final parts = request.url.pathSegments;
    if (request.url.host != backendHost ||
        parts.any((p) => p.contains('diagnostic'))) {
      return inner.send(request);
    }
    var operation = 'unknown';
    if (parts.length >= 3 && parts[0] == 'rest' && parts[1] == 'v1') {
      operation = parts[2] == 'rpc' && parts.length >= 4
          ? 'rpc:${parts[3]}'
          : 'table:${parts[2]}';
    } else if (parts.isNotEmpty && parts[0] == 'storage') {
      operation = 'storage';
    } else if (parts.isNotEmpty && parts[0] == 'auth') {
      operation = 'auth';
    }
    final trace = Zone.current[#diagnosticTrace] as String? ?? diagnosticId();
    if (recorder.preferences.enabled) {
      request.headers['x-client-info'] =
          '${request.headers['x-client-info'] ?? 'swansport'};swan-trace=$trace';
    }
    final watch = Stopwatch()..start();
    recorder.record('start', operation: operation, traceId: trace);
    try {
      final response = await inner.send(request);
      var failed = false;
      final stream = response.stream.transform<List<int>>(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (bytes, sink) => sink.add(bytes),
          handleError: (Object error, StackTrace stack, sink) {
            if (!failed) {
              failed = true;
              recorder.record(
                'error',
                operation: operation,
                traceId: trace,
                code: 'network_error',
                durationMs: watch.elapsedMilliseconds,
              );
            }
            sink.addError(error, stack);
          },
          handleDone: (sink) {
            if (!failed) {
              final duration = watch.elapsedMilliseconds;
              recorder.record(
                response.statusCode >= 400 ? 'error' : 'success',
                operation: operation,
                traceId: trace,
                code: response.statusCode >= 400
                    ? 'http_${response.statusCode}'
                    : 'none',
                durationMs: duration,
              );
              if (duration > 3000) {
                recorder.record(
                  'slow',
                  operation: operation,
                  traceId: trace,
                  durationMs: duration,
                );
              }
            }
            sink.close();
          },
        ),
      );
      return http.StreamedResponse(
        stream,
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      recorder.record(
        'error',
        operation: operation,
        traceId: trace,
        code: 'network_error',
        durationMs: watch.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  @override
  void close() => inner.close();
}

final diagnosticsProvider =
    Provider<DiagnosticsRecorder>((ref) => DiagnosticsRecorder.instance);

class DiagnosticPreferencesController
    extends StateNotifier<DiagnosticPreferences> {
  DiagnosticPreferencesController(this.recorder) : super(recorder.preferences) {
    _subscription =
        recorder._preferenceChanges.stream.listen((value) => state = value);
  }
  late final StreamSubscription<DiagnosticPreferences> _subscription;
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  final DiagnosticsRecorder recorder;
  Future<void> _pending = Future.value();
  static Future<void> initialize(DiagnosticsRecorder recorder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      recorder.setPreferences(
        DiagnosticPreferences(
          errors: prefs.getBool('diagnostics_errors_v1') ?? false,
          usage: prefs.getBool('diagnostics_usage_v1') ?? false,
        ),
      );
    } catch (_) {
      recorder.setPreferences(const DiagnosticPreferences());
    }
  }

  Future<void> update({bool? errors, bool? usage}) async {
    final next = DiagnosticPreferences(
      errors: errors ?? state.errors,
      usage: usage ?? state.usage,
    );
    state = next;
    recorder.setPreferences(next);
    // Serialize device writes so rapid toggles cannot persist an older choice.
    final saving = _pending.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final errorsSaved =
          await prefs.setBool('diagnostics_errors_v1', next.errors);
      final usageSaved =
          await prefs.setBool('diagnostics_usage_v1', next.usage);
      if (!errorsSaved || !usageSaved) {
        throw StateError('Preference persistence failed');
      }
    });
    _pending = saving.catchError((Object _) {});
    await saving;
  }
}

final diagnosticPreferencesProvider = StateNotifierProvider<
    DiagnosticPreferencesController, DiagnosticPreferences>(
  (ref) => DiagnosticPreferencesController(ref.watch(diagnosticsProvider)),
);

class DiagnosticsService {
  DiagnosticsService(this.client);
  final SupabaseClient client;
  Future<void> ingest(String session, List<Map<String, dynamic>> events) async {
    await client.rpc<int>(
      'ingest_diagnostics',
      params: {'p_session': session, 'p_events': events},
    );
  }

  Future<List<Map<String, dynamic>>> issues({
    String? status,
    String? release,
    String? platform,
    String? screen,
    int offset = 0,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      'admin_diagnostic_issues',
      params: {
        'p_status': status,
        'p_release': release,
        'p_platform': platform,
        'p_screen': screen,
        'p_offset': offset,
      },
    );
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<Map<String, dynamic>> detail(String issue) async =>
      Map<String, dynamic>.from(
        await client.rpc<Map<String, dynamic>>(
          'admin_diagnostic_detail',
          params: {'p_issue': issue},
        ) as Map,
      );
  Future<void> setStatus(String issue, String status) async {
    await client.rpc<void>(
      'set_diagnostic_issue_status',
      params: {'p_issue': issue, 'p_status': status},
    );
  }

  Future<String> declareFix(String issue, String release, String platform) =>
      client.rpc<String>(
        'declare_diagnostic_fix',
        params: {
          'p_issue': issue,
          'p_release': release,
          'p_platform': platform,
        },
      );
  Future<void> linkIssue(String ticket, String issue) => client.rpc<void>(
        'link_support_issue',
        params: {'p_ticket': ticket, 'p_issue': issue},
      );
  Future<void> unlinkIssue(String ticket, String issue) =>
      client.rpc<void>('unlink_support_issue',
          params: {'p_ticket': ticket, 'p_issue': issue},);
  Future<DiagnosticFixContext?> fixContext(String ticket) async {
    final result = await client.rpc<Map<String, dynamic>?>(
      'support_fix_context',
      params: {'p_ticket': ticket},
    );
    return result == null ? null : DiagnosticFixContext.fromMap(result);
  }

  Future<void> respondFix(
    String ticket,
    String fix,
    String result, {
    required String release,
    required String platform,
    required String application,
  }) =>
      client.rpc<void>(
        'respond_support_fix',
        params: {
          'p_ticket': ticket,
          'p_fix': fix,
          'p_result': result,
          'p_release': release,
          'p_platform': platform,
          'p_application': application,
        },
      );

  Future<Map<String, dynamic>> overview() async => Map<String, dynamic>.from(
        await client.rpc<Map<String, dynamic>>('admin_diagnostic_overview')
            as Map,
      );
  Future<void> linkTicket(
    String ticket,
    Map<String, dynamic> snapshot, {
    String? attachment,
  }) async {
    await client.rpc<void>(
      'link_support_diagnostics',
      params: {
        'p_ticket': ticket,
        'p_session': snapshot['session_id'],
        'p_snapshot': snapshot,
        'p_attachment': attachment,
      },
    );
  }

  Future<String> uploadScreenshot(String ticket, Uint8List bytes) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null ||
        bytes.length > 5242880 ||
        bytes.length < 8 ||
        !(bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71)) {
      throw ArgumentError('Invalid screenshot');
    }
    final path = '$owner/$ticket/${diagnosticId()}.png';
    await client.storage.from('diagnostic-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
    return path;
  }

  Future<String> screenshotUrl(String path) =>
      client.storage.from('diagnostic-attachments').createSignedUrl(path, 300);
  Future<Map<String, dynamic>?> ticketDiagnostics(String ticket) async {
    final result = await client.rpc<Map<String, dynamic>?>(
      'support_diagnostic_context',
      params: {'p_ticket': ticket},
    );
    return result == null ? null : Map<String, dynamic>.from(result as Map);
  }
}

final diagnosticsServiceProvider = Provider<DiagnosticsService>(
  (ref) => DiagnosticsService(ref.watch(supabaseClientProvider)),
);

/// Numeric version/build comparison. Unknown versions never count as evidence.
bool diagnosticReleaseAtLeast(String observed, String required) {
  List<BigInt>? parts(String value) {
    if (value.length > 64 ||
        !RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?$').hasMatch(value)) {
      return null;
    }
    final numbers =
        value.replaceAll('+', '.').split('.').map(BigInt.parse).toList();
    if (numbers.length == 3) numbers.add(BigInt.zero);
    return numbers;
  }

  final a = parts(observed), b = parts(required);
  if (a == null || b == null) return false;
  for (var i = 0; i < 4; i++) {
    final comparison = a[i].compareTo(b[i]);
    if (comparison != 0) return comparison > 0;
  }
  return true;
}

class DiagnosticFixContext {
  const DiagnosticFixContext({
    required this.issueId,
    required this.issueState,
    required this.ticketStatus,
    this.fixId,
    this.release,
    this.platform,
    this.application,
    this.response,
    this.regressionCount = 0,
  });
  final String issueId, issueState, ticketStatus;
  final String? fixId, release, platform, application, response;
  final int regressionCount;
  bool canRespond(DiagnosticsRecorder recorder) =>
      fixId != null &&
      ticketStatus != 'closed' &&
      platform == recorder.platform &&
      application == recorder.application &&
      diagnosticReleaseAtLeast(recorder.release, release ?? 'unknown');
  factory DiagnosticFixContext.fromMap(Map<String, dynamic> value) =>
      DiagnosticFixContext(
        issueId: value['issue_id'] as String,
        issueState: value['issue_state'] as String,
        ticketStatus: value['ticket_status'] as String,
        fixId: value['fix_id'] as String?,
        release: value['release'] as String?,
        platform: value['platform'] as String?,
        application: value['application'] as String?,
        response: value['response'] as String?,
        regressionCount: (value['regression_count'] as num?)?.toInt() ?? 0,
      );
}

final supportFixProvider = FutureProvider.autoDispose
    .family<DiagnosticFixContext?, String>((ref, ticket) {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(diagnosticsServiceProvider).fixContext(ticket);
});
