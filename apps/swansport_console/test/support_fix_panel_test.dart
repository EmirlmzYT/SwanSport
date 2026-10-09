import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/features/platform/support_fix_panel.dart';
import 'package:swansport_console/features/platform/diagnostic_fix_dialog.dart';
import 'package:swansport_data/swansport_data.dart';

class Service extends Fake implements DiagnosticsService {
  int reads = 0;
  final links = <(String, String)>[];
  @override
  Future<DiagnosticFixContext?> fixContext(String ticket) async {
    reads++;
    return links.isEmpty
        ? null
        : DiagnosticFixContext(
            issueId: links.last.$2,
            issueState: 'resolved',
            ticketStatus: 'awaiting_user_response',
            fixId: 'f',
            release: '0.5.2+17',
            platform: 'android',
            response: 'awaiting_confirmation');
  }

  @override
  Future<void> unlinkIssue(String ticket,String issue) async { links.clear(); }
  @override
  Future<void> linkIssue(String ticket, String issue) async {
    links.add((ticket, issue));
  }
}

void main() {
  late Service service;
  setUp(() => service = Service());
  const admin = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'member',
      coachLevel: 0,
      athleteKind: null);
  const coach = SwanAccess(
      isPlatformAdmin: false,
      clubRole: 'coach',
      coachLevel: 1,
      athleteKind: null);
  Future<void> mount(WidgetTester t, SwanAccess access) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          consoleAccessProvider.overrideWithValue(access),
          isSupabaseEnabledProvider.overrideWithValue(true),
          diagnosticsServiceProvider.overrideWithValue(service)
        ],
        child: const MaterialApp(
            home: Scaffold(body: SupportFixPanel(ticketId: 'ticket')))));
    await t.pumpAndSettle();
  }

  testWidgets('non-admin does not read support fix data', (t) async {
    await mount(t, coach);
    expect(service.reads, 0);
    expect(find.text('Hataya bağla'), findsNothing);
  });
  testWidgets('valid issue ID links the existing ticket then shows declaration',
      (t) async {
    await mount(t, admin);
    expect(
        t
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hataya bağla'))
            .onPressed,
        isNull);
    const issue = '00000000-0000-0000-0000-000000000123';
    await t.enterText(find.widgetWithText(TextField, 'Hata kimliği'), issue);
    await t.pump();
    await t.tap(find.text('Hataya bağla'));
    await t.pumpAndSettle();
    expect(service.links, [('ticket', issue)]);
    expect(find.text('Düzeltme: 0.5.2+17 · android'), findsOneWidget);
    await t.tap(find.text('Hata bağlantısını kaldır'));await t.pumpAndSettle();
    await t.tap(find.text('Bağlantıyı kaldır'));await t.pumpAndSettle();
    expect(service.links,isEmpty);expect(find.text('Hataya bağla'),findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('declaration form rejects empty version and platform', (t) async {
    await t.pumpWidget(
        const MaterialApp(home: Scaffold(body: DiagnosticFixDialog())));
    await t.tap(find.text('Düzeltmeyi bildir'));
    await t.pumpAndSettle();
    expect(find.text('Geçerli sürüm/build gir'), findsOneWidget);
    expect(find.text('Platform seç'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
