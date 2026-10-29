import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_console/app/console_dashboard.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/modules/console_workspace.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/app/today/console_today.dart';
import 'package:swansport_console/app/today/console_today_referee.dart';
import 'package:swansport_data/swansport_data.dart';

const staff = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'club_admin',
    coachLevel: 0,
    athleteKind: null);
const accountant = SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    accountantClubIds: {'club'});

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('queues sort by real risk, keep filters and today attendance scope', () {
    final items = consoleTodayItems(
        access: staff,
        finance: const FinanceOperationsSummary(
            pendingApprovalCount: 2,
            pendingPaymentCount: 3,
            overdueInvoiceCount: 1),
        operations: const ClubOperationsSummary(unmarkedEventCount: 7),
        attendance:
            const ClubTodayAttendance(trainingCount: 4, markedCount: 2));
    expect(items.where((i) => i.route == '/yoklama').length, 1);
    expect(items.singleWhere((i) => i.code == 'today_attendance').count, 2);
    expect(items.where((i) => i.code == 'today_attendance').single.why,
        contains('tamamlandığı anlamına gelmez'));
    for (var i = 1; i < items.length; i++) {
      expect(
          items[i - 1].risk.index, greaterThanOrEqualTo(items[i].risk.index));
    }
    const summary = FinanceOperationsSummary(
        pendingApprovalCount: 2,
        pendingPaymentCount: 3,
        overdueInvoiceCount: 1);
    for (final source in [...summary.topItems, ...summary.otherItems]) {
      expect(items.singleWhere((item) => item.code == source.code).route,
          source.route);
    }
  });

  testWidgets(
      'dashboard accountant isolates providers and navigates filtered task',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var privateReads = 0;
    final items = consoleTodayItems(
        access: accountant,
        finance: const FinanceOperationsSummary(pendingApprovalCount: 2));
    expect(items, isNotEmpty);
    final target = Uri.parse(items.first.route).path;
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: ConsoleDashboard())),
      GoRoute(
          path: target,
          builder: (_, state) => Scaffold(body: Text('TARGET ${state.uri}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          consoleAccessProvider.overrideWithValue(accountant),
          swanAccessProvider.overrideWithValue(accountant),
          consoleWorkspaceProvider.overrideWith((_) => ConsoleWorkspace.club),
          currentProfileProvider.overrideWith((_) async => null),
          activeClubProvider.overrideWith(
              (_) async => const ClubRef(id: 'club', name: 'Club')),
          financeOperationsSummaryProvider.overrideWith((_) async =>
              const FinanceOperationsSummary(pendingApprovalCount: 2)),
          clubOperationsSummaryProvider.overrideWith((_) async {
            privateReads++;
            throw StateError('private');
          }),
          clubRosterCountsProvider.overrideWith((_) async {
            privateReads++;
            throw StateError('private');
          }),
          clubTodayAttendanceProvider.overrideWith((_) async {
            privateReads++;
            throw StateError('private');
          }),
          eligibilityBoardProvider.overrideWith((_) async {
            privateReads++;
            throw StateError('private');
          }),
        ],
        child: MaterialApp.router(
            theme: ConsoleTheme.light(), routerConfig: router)));
    await tester.pumpAndSettle();
    expect(privateReads, 0);
    expect(find.text('Bugün yapacaklarım'), findsOneWidget);
    await tester.tap(find.text('${items.first.title} · 2 kayıt'));
    await tester.pumpAndSettle();
    expect(find.text('TARGET ${items.first.route}'), findsOneWidget);
  });

  testWidgets('referee tasks use actual duty provider and explicit empty state',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          myRefereeMatchesProvider(null).overrideWith((_) async {
            reads++;
            return <RefereeMatchSummary>[];
          }),
        ],
        child: MaterialApp(
            theme: ConsoleTheme.light(),
            home: const Scaffold(body: ConsoleTodayReferee()))));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('Listelenecek hakem görevin yok.'), findsOneWidget);
    expect(find.text('Canlı Skor & Maç Kokpiti'), findsNothing);
  });

  testWidgets('real provider loading and error never become an empty queue',
      (tester) async {
    final pending = Completer<FinanceOperationsSummary>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          financeOperationsSummaryProvider.overrideWith((_) => pending.future),
        ],
        child: MaterialApp(
            theme: ConsoleTheme.light(),
            home: Scaffold(
                body: Consumer(
                    builder: (_, ref, __) => ConsoleToday(
                        access: accountant,
                        finance:
                            ref.watch(financeOperationsSummaryProvider)))))));
    await tester.pump();
    expect(find.text('Mali işler yükleniyor…'), findsOneWidget);
    expect(
        find.text('Erişebildiğin kuyruklarda bekleyen iş yok.'), findsNothing);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Mali işler alınamadı. Özeti yenileyerek tekrar dene.'),
        findsOneWidget);
    expect(
        find.text('Erişebildiğin kuyruklarda bekleyen iş yok.'), findsNothing);
  });
}
