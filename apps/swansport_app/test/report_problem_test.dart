import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swansport_app/app/diagnostics/diagnostic_preferences_tile.dart';
import 'package:swansport_app/features/support/presentation/report_problem_sheet.dart';
import 'package:swansport_data/swansport_data.dart';

class TicketFake extends Fake implements ClubLifecycleService {
  int calls = 0;
  @override
  Future<String> openTicket(
      {required String subject,
      required String body,
      Map<String, dynamic> context = const {},
      String? clubId}) async {
    calls++;
    return 'ticket-1';
  }
}

class SupportDiagnosticFake extends Fake implements DiagnosticsService {
  int calls = 0;
  bool fail = false;
  Map<String, dynamic>? snapshot;
  @override
  Future<void> linkTicket(String ticket, Map<String, dynamic> data,
      {String? attachment}) async {
    calls++;
    snapshot = data;
    if (fail) throw StateError('offline');
  }
}

void main() {
  late DiagnosticsRecorder recorder;
  late TicketFake ticket;
  late SupportDiagnosticFake diagnostics;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    recorder = DiagnosticsRecorder();
    ticket = TicketFake();
    diagnostics = SupportDiagnosticFake();
  });
  tearDown(() => recorder.dispose());
  Future<void> mount(WidgetTester tester, {bool preference = false}) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticsProvider.overrideWithValue(recorder),
          clubLifecycleServiceProvider.overrideWithValue(ticket),
          diagnosticsServiceProvider.overrideWithValue(diagnostics),
          activeClubProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: preference
                    ? const DiagnosticPreferencesTile()
                    : Builder(
                        builder: (context) => TextButton(
                              onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => const ReportProblemSheet()),
                              child: const Text('Aç'),
                            ))))));
    await tester.pumpAndSettle();
    if (!preference) {
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'Konu'), 'İşlem kaydedilmedi');
    await tester.enterText(
        find.widgetWithText(TextField, 'Ne oldu?'), 'Kaydet düğmesine bastım.');
  }

  testWidgets('both collection switches default off and can be disabled again',
      (tester) async {
    await mount(tester, preference: true);
    expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((s) => !s.value),
        true);
    await tester.tap(find.text('Hata tanılaması'));
    await tester.pumpAndSettle();
    expect(recorder.preferences.errors, true);
    recorder.record('error', operation: 'auth', code: 'network_error');
    await tester.tap(find.text('Hata tanılaması'));
    await tester.pumpAndSettle();
    expect(recorder.preferences.errors, false);
    expect(recorder.queuedCount, 0);
  });
  testWidgets(
      'support submits without technical collection unless explicitly selected',
      (tester) async {
    await mount(tester);
    await fill(tester);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false);
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(ticket.calls, 1);
    expect(diagnostics.calls, 0);
    expect(find.byType(ReportProblemSheet), findsNothing);
    expect(recorder.preferences.enabled, false);
  });
  testWidgets('technical attachment retry reuses the existing support ticket',
      (tester) async {
    diagnostics.fail = true;
    await mount(tester);
    await fill(tester);
    await tester.tap(find.text('Teknik bilgileri bu talebe ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(ticket.calls, 1);
    expect(diagnostics.calls, 1);
    diagnostics.fail = false;
    await tester.ensureVisible(find.text('Teknik ekleri tekrar gönder'));
    await tester.tap(find.text('Teknik ekleri tekrar gönder'));
    await tester.pumpAndSettle();
    expect(ticket.calls, 1);
    expect(diagnostics.calls, 2);
    expect(diagnostics.snapshot!['events'], isEmpty);
    expect(recorder.preferences.enabled, false);
  });
}
