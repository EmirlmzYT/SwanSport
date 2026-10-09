import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/support/presentation/support_fix_card.dart';
import 'package:swansport_data/swansport_data.dart';

class Service extends Fake implements DiagnosticsService {
  String? response = 'awaiting_confirmation';
  int calls = 0;
  Object? error;
  Completer<void>? held;
  List<String>? sent;
  @override
  Future<DiagnosticFixContext?> fixContext(String ticket) async =>
      DiagnosticFixContext(
          issueId: 'i',
          issueState: 'resolved',
          ticketStatus:
              response == 'confirmed' ? 'resolved' : 'awaiting_user_response',
          fixId: 'f',
          release: '0.5.2+17',
          platform: 'android',
          application: 'app',
          response: response,);
  @override
  Future<void> respondFix(String ticket, String fix, String result,
      {required String release,
      required String platform,
      required String application,}) async {
    calls++;
    sent = [ticket, fix, result, release, platform, application];
    if (error != null) throw error!;
    if (held != null) await held!.future;
    response = result;
  }
}

void main() {
  late Service service;
  late DiagnosticsRecorder recorder;
  setUp(() {
    service = Service();
    recorder = DiagnosticsRecorder()
      ..release = '0.5.2+17'
      ..platform = 'android';
  });
  tearDown(() => recorder.dispose());
  Future<void> mount(WidgetTester t, {bool enabled = true}) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(enabled),
          diagnosticsProvider.overrideWithValue(recorder),
          diagnosticsServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: SupportFixCard(ticketId: 't'),),),),),);
    await t.pumpAndSettle();
  }

  testWidgets(
      'confirmation uses current environment and blocks double send while waiting',
      (t) async {
    service.held = Completer<void>();
    await mount(t);
    await t.tap(find.text('Sorun çözüldü'));
    await t.pump();
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Sorun çözüldü'),)
            .onPressed,
        isNull,);
    expect(service.calls, 1);
    service.held!.complete();
    await t.pumpAndSettle();
    expect(service.sent, ['t', 'f', 'confirmed', '0.5.2+17', 'android', 'app']);
    expect(find.text('Çözüldüğünü teyit ettin.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'older version cannot submit confirmation but explains the update',
      (t) async {
    recorder.release = '0.5.1+999';
    await mount(t);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Sorun çözüldü'),)
            .onPressed,
        isNull,);
    expect(
        t
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Sorun devam ediyor'),)
            .onPressed,
        isNull,);
    expect(find.textContaining('Teyit için belirtilen platformda'),
        findsOneWidget,);
    expect(service.calls, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets('failed response does not pretend success and can be retried',
      (t) async {
    service.error = StateError('fixture');
    await mount(t);
    await t.tap(find.text('Sorun devam ediyor'));
    await t.pumpAndSettle();
    expect(find.textContaining('Teyit kaydedilemedi.'), findsOneWidget);
    expect(service.response, 'awaiting_confirmation');
    service.error = null;
    await t.tap(find.text('Sorun devam ediyor'));
    await t.pumpAndSettle();
    expect(service.sent![2], 'still_failing');
    expect(find.textContaining('talep tekrar incelemede'), findsOneWidget);
  });
  testWidgets('no backend leaves ordinary support thread unchanged', (t) async {
    await mount(t, enabled: false);
    expect(find.text('Düzeltme takibi'), findsNothing);
    expect(service.calls, 0);
  });
}
