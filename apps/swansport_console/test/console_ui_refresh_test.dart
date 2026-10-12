import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_console/app/console_dashboard.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/modules/module_registry.dart';
import 'package:swansport_console/app/shell/console_shell.dart';
import 'package:swansport_console/app/shell/too_narrow_notice.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/features/auth/console_login_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const _staff = SwanAccess(isPlatformAdmin: false, clubRole: 'club_admin',
    coachLevel: 0, athleteKind: null);
const _accountant = SwanAccess(isPlatformAdmin: false, clubRole: null,
    coachLevel: 0, athleteKind: null, accountantClubIds: {'club'});
const _club = ClubRef(id: 'club', name: 'Swan Spor Kulübü');

class _AccountFake extends Fake implements AccountSessionService {
  int signIns = 0;
  int signOuts = 0;
  final pending = Completer<void>();
  @override
  Future<void> signIn({required String email, required String password}) {
    signIns++;
    return pending.future;
  }
  @override
  Future<void> signOut() async { signOuts++; }
}

void main() {
  testWidgets('shell and login consume configured branding', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    Widget wrap(Widget child) => ProviderScope(overrides: [
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {
        'app_name': 'Özel Kulüp', 'logo_url': 'https://example.com/logo.png'}})),
      consoleAccessProvider.overrideWithValue(_accountant),
      activeClubProvider.overrideWith((_) async => _club),
      myClubsProvider.overrideWith((_) async => [_club]),
      currentProfileProvider.overrideWith((_) async => const ProfileInfo(id: 'admin', fullName: 'Deniz Yönetici')),
      authSessionProvider.overrideWith((_) => Stream.value(null)),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: child));
    await tester.pumpWidget(wrap(const ConsoleShell(route: '/', child: Text('Content'))));
    await tester.pumpAndSettle(); expect(find.text('Özel Kulüp'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect((tester.widget<Image>(find.byType(Image)).image as NetworkImage).url, 'https://example.com/logo.png');
    await tester.pumpWidget(wrap(const ConsoleLoginScreen())); await tester.pumpAndSettle();
    expect(find.text('Özel Kulüp Konsol'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  void size(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('split login shows password toggle and validates before submission', (tester) async {
    size(tester, 900);
    final service = _AccountFake();
    await tester.pumpWidget(ProviderScope(overrides: [
      accountSessionServiceProvider.overrideWithValue(service),
    ], child: MaterialApp(theme: ConsoleTheme.light(), home: const ConsoleLoginScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Şeffaf Mali Defter'), findsOneWidget);
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    expect(service.signIns, 0);
    expect(find.text('Geçerli bir e-posta gir'), findsOneWidget);
    await tester.tap(find.byTooltip('Parolayı göster'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter submits once, busy state blocks duplicates, error is visible', (tester) async {
    size(tester, 1200);
    final service = _AccountFake();
    await tester.pumpWidget(ProviderScope(overrides: [
      accountSessionServiceProvider.overrideWithValue(service),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: const ConsoleLoginScreen())));
    await tester.enterText(find.byType(TextFormField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(service.signIns, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    service.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Giriş yapılamadı.'), findsOneWidget);
    expect(service.signIns, 1);
    expect(tester.takeException(), isNull);
  });

  for (final login in [true, false]) {
    testWidgets('desktop guard is preserved: login=$login', (tester) async {
      size(tester, 899);
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        home: login ? const ConsoleLoginScreen()
            : const ConsoleShell(route: '/', child: Text('PRIVATE')))));
      await tester.pumpAndSettle();
      expect(find.byType(TooNarrowNotice), findsOneWidget);
      expect(find.text('PRIVATE'), findsNothing);
    });
  }

  Widget dashboard({required GoRouter router, SwanAccess access = _staff,
    bool financeError = false, VoidCallback? onPrivateRead}) => ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(access),
      swanAccessProvider.overrideWithValue(access),
      currentProfileProvider.overrideWith((_) async => const ProfileInfo(id: 'admin', fullName: 'Deniz Yönetici')),
      activeClubProvider.overrideWith((_) async => _club),
      myClubsProvider.overrideWith((_) async => [_club]),
      authSessionProvider.overrideWith((_) => Stream.value(null)),
      financeOperationsSummaryProvider.overrideWith((_) async {
        if (financeError) throw StateError('offline');
        return const FinanceOperationsSummary(pendingApprovalCount: 2, pendingPaymentCount: 3);
      }),
      clubOperationsSummaryProvider.overrideWith((_) async {
        onPrivateRead?.call();
        return const ClubOperationsSummary(expiringDocumentCount: 1);
      }),
      clubRosterCountsProvider.overrideWith((_) async {
        onPrivateRead?.call();
        return const ClubRosterCounts(total: 37, active: 30);
      }),
      clubTodayAttendanceProvider.overrideWith((_) async {
        onPrivateRead?.call();
        return const ClubTodayAttendance(trainingCount: 4, markedCount: 2);
      }),
      eligibilityBoardProvider.overrideWith((_) async {
        onPrivateRead?.call();
        return const [EligibilityRow(athleteId: 'a', athleteRef: '#A',
          status: 'restricted', reasonLabel: 'Kısıt')];
      }),
    ], child: MaterialApp.router(theme: ConsoleTheme.light(), darkTheme: ConsoleTheme.dark(), routerConfig: router));

  GoRouter router() {
    final result = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ConsoleShell(route: '/', child: ConsoleDashboard())),
      for (final module in kConsoleModules)
        GoRoute(path: module.route, builder: (_, __) => Scaffold(body: Text('TARGET ${module.route}'))),
    ]);
    addTearDown(result.dispose);
    return result;
  }

  for (final width in [900.0, 1200.0, 1600.0]) {
    testWidgets('real dashboard values and layout fit desktop width $width', (tester) async {
      size(tester, width);
      final routes = router();
      await tester.pumpWidget(dashboard(router: routes));
      await tester.pumpAndSettle();
      expect(find.text('Hoş Geldin, Deniz'), findsOneWidget);
      expect(find.text('37'), findsOneWidget);
      expect(find.text('30 aktif sporcu'), findsOneWidget);
      expect(find.text('%81 Aktif Kadro'), findsOneWidget);
      expect(find.text('2/4 oturumda kayıt'), findsOneWidget);
      expect(find.text('5 onay bekliyor'), findsOneWidget);
      expect(find.text('2 gider onayı · 3 tahsilat onayı'), findsOneWidget);
      expect(find.text('Bugün · 2 oturumda yoklama kaydı'), findsOneWidget);
      if (width == 900) expect(find.byTooltip('Sporcular'), findsOneWidget);
      await tester.tap(find.text('Kadro & Sporcular'));
      await tester.pumpAndSettle();
      expect(find.text('TARGET /sporcular'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accountant dashboard never subscribes to sporting data', (tester) async {
    size(tester, 1200);
    var reads = 0;
    await tester.pumpWidget(dashboard(router: router(), access: _accountant,
      onPrivateRead: () => reads++));
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.text('37'), findsNothing);
    expect(find.text('Sporcu Listesi'), findsNothing);
    expect(find.text('Kulüp İşleri'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance failure is shown as unavailable, not a fake zero', (tester) async {
    size(tester, 1200);
    await tester.pumpWidget(dashboard(router: router(), financeError: true));
    await tester.pumpAndSettle();
    expect(find.text('Veri alınamadı'), findsOneWidget);
    expect(find.text('2 gider onayı · 3 tahsilat onayı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club switcher, collapse tooltip and theme preference work', (tester) async {
    size(tester, 1400);
    final service = _AccountFake();
    final container = ProviderContainer(overrides: [
      accountSessionServiceProvider.overrideWithValue(service),
      consoleAccessProvider.overrideWithValue(_staff),
      currentProfileProvider.overrideWith((_) async => const ProfileInfo(id: 'admin', fullName: 'Deniz Yönetici')),
      activeClubProvider.overrideWith((_) async => _club),
      myClubsProvider.overrideWith((_) async => [_club, const ClubRef(id: 'other', name: 'Diğer Kulüp')]),
      authSessionProvider.overrideWith((_) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(theme: ConsoleTheme.light(), home: const ConsoleShell(route: '/sporcular', child: Text('BODY')))));
    await tester.pumpAndSettle();
    expect(find.text('MALİ İŞLER'), findsOneWidget);
    await tester.tap(find.byTooltip('Kulüp değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diğer Kulüp'));
    await tester.pumpAndSettle();
    expect(container.read(selectedClubIdProvider), 'other');
    await tester.tap(find.byTooltip('Menüyü daralt'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Sporcular'), findsOneWidget);
    await tester.tap(find.byTooltip('Temayı değiştir'));
    await tester.pump();
    expect(container.read(consoleThemeModeProvider), ThemeMode.dark);
    await tester.tap(find.byTooltip('Çıkış yap'));
    await tester.pumpAndSettle();
    expect(service.signOuts, 1);
    expect(tester.takeException(), isNull);
  });
}
