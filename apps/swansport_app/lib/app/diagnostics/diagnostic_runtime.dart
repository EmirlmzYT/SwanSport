import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

bool _installed = false;

Future<void> initializeAppDiagnostics() async {
  final recorder = DiagnosticsRecorder.instance;
  recorder.platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  unawaited(_loadRelease(recorder));
  if (_installed) return;
  _installed = true;
  final oldFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    recorder.capture(
      details.exception,
      details.stack ?? StackTrace.current,
      code: 'framework',
      operation: 'framework',
    );
    if (oldFlutter != null) {
      oldFlutter(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final oldPlatform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    recorder.capture(error, stack, operation: 'async');
    return oldPlatform?.call(error, stack) ?? false;
  };
  WidgetsBinding.instance.addObserver(_DiagnosticLifecycle(recorder));
  DateTime lastSlow = DateTime.fromMillisecondsSinceEpoch(0);
  WidgetsBinding.instance.addTimingsCallback((frames) {
    for (final frame in frames) {
      if (frame.totalSpan.inMilliseconds > 32 &&
          DateTime.now().difference(lastSlow).inSeconds >= 10) {
        lastSlow = DateTime.now();
        recorder.record(
          'slow',
          operation: 'framework',
          durationMs: frame.totalSpan.inMilliseconds,
        );
      }
    }
  });
  await DiagnosticPreferencesController.initialize(recorder);
}

Future<void> _loadRelease(DiagnosticsRecorder recorder) async {
  try {
    final package = await PackageInfo.fromPlatform();
    recorder.release = '${package.version}+${package.buildNumber}';
  } catch (_) {
    recorder.release = 'unknown';
  }
}

Future<void> bindAppDiagnostics(SupabaseClient client) =>
    DiagnosticsRecorder.instance.bind(client);

class _DiagnosticLifecycle extends WidgetsBindingObserver {
  _DiagnosticLifecycle(this.recorder);
  final DiagnosticsRecorder recorder;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(recorder.flush());
    }
  }
}

class DiagnosticNavigationObserver extends NavigatorObserver {
  DiagnosticNavigationObserver(this.recorder);
  final DiagnosticsRecorder recorder;
  void _visit(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    recorder.navigate(route.settings.name);
    final trace = diagnosticId();
    final watch = Stopwatch()..start();
    recorder.record('start', operation: 'navigation', traceId: trace);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      recorder.record(
        'success',
        operation: 'navigation',
        traceId: trace,
        durationMs: watch.elapsedMilliseconds,
      );
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _visit(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _visit(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _visit(newRoute);
}

final diagnosticNavigationObserverProvider =
    Provider<DiagnosticNavigationObserver>(
  (ref) => DiagnosticNavigationObserver(ref.watch(diagnosticsProvider)),
);

class DiagnosticProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    container
        .read(diagnosticsProvider)
        .capture(error, stackTrace, code: 'provider', operation: 'provider');
  }
}
