import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  const club = ClubRef(
    id: 'club-1',
    name: 'Anadolu SK',
    role: 'kit_manager',
  );
  const specialistAccess = SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    clubOperationsAuthority: [
      ClubOperationsAuthority(
        clubId: 'club-1',
        inventoryRead: true,
        inventoryWrite: true,
        healthRead: true,
        planningRead: true,
      ),
    ],
  );

  testWidgets('specialist panel exposes only authorized typed destinations',
      (tester) async {
    final navigator = _Navigator();
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(specialistAccess),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.clubStaffOperations,
          }),
        ),
        activeClubProvider.overrideWith((ref) async => club),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        navigator: navigator,
        child: const SharedClubStaffOperationsPanel(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Envanter ve Zimmet'), findsOneWidget);
    expect(find.text('Sağlık ve İdari Dinlendirme'), findsOneWidget);
    expect(find.text('Sportif Kadro Planlama'), findsOneWidget);

    await tester.tap(find.text('Envanter ve Zimmet'));
    expect(navigator.calls, contains('inventory'));
  });

  testWidgets('inventory remains masked and usable at 320px with 2x text',
      (tester) async {
    tester.view
      ..physicalSize = const Size(320, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(specialistAccess),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.clubStaffOperations,
          }),
        ),
        activeClubProvider.overrideWith((ref) async => club),
        clubInventoryBoardProvider('club-1').overrideWith(
          (ref) async => ClubInventoryBoard(
            items: const [
              ClubInventoryItem(
                id: 'item-1',
                name: 'Antrenman Topu',
                category: 'Top',
                quantity: 12,
                available: 10,
                damaged: 1,
                missing: 1,
                status: 'active',
              ),
            ],
            assignments: [
              ClubInventoryAssignment(
                id: 'assignment-1',
                itemName: 'Antrenman Topu',
                targetReference: '#A3F91C',
                quantity: 1,
                assignedAt: DateTime.utc(2026, 10, 27),
                outcome: 'assigned',
              ),
            ],
            targets: const [],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        textScale: 2,
        child: const SharedClubInventoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Antrenman Topu'), findsOneWidget);
    expect(find.byType(OverflowBar), findsNothing);
    await tester.tap(find.text('Zimmet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#A3F91C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('platform panel fails closed without admin and runs no queries',
      (tester) async {
    var configCalls = 0;
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(SwanAccess.none),
        platformConfigProvider.overrideWith((ref) async {
          configCalls++;
          return const PlatformConfig.empty();
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        child: const SharedPlatformOperationsPanel(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform yöneticisi yetkisi gerekli'), findsOneWidget);
    expect(configCalls, 0);
  });

  testWidgets(
      'platform admin panel renders typed status and audit destinations',
      (tester) async {
    final navigator = _Navigator();
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: true,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
          ),
        ),
        platformConfigProvider.overrideWith(
          (ref) async => PlatformConfig.fromMap(const {
            'maintenance': {'enabled': false},
          }),
        ),
        platformPlansProvider.overrideWith((ref) async => const []),
        platformAuditLogsProvider.overrideWith((ref) async => const []),
        launchWaitlistSummaryProvider.overrideWith(
          (ref) async => const LaunchWaitlistSummary(totalCount: 4),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        navigator: navigator,
        child: const SharedPlatformOperationsPanel(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sırlar, API anahtarları ve Firebase yapılandırması bu çalışma alanında gösterilmez.',
      ),
      findsOneWidget,
    );
    expect(find.text('4 kayıt'), findsOneWidget);
    await tester.tap(find.text('Platform Durumu'));
    await tester.tap(find.text('Denetim Kayıtları'));
    expect(navigator.calls, containsAll(['platform-status', 'platform-audit']));
  });
}

Widget _host({
  required ProviderContainer container,
  required Widget child,
  _Navigator? navigator,
  double textScale = 1,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, appChild) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: appChild!,
        ),
        home: ProFeatureHostScope(
          navigator: navigator ?? _Navigator(),
          chrome: const _Chrome(),
          theme: ProFeatureThemeData.light,
          child: Scaffold(body: child),
        ),
      ),
    );

final class _Navigator extends ProFeatureNavigatorBase {
  final List<String> calls = [];

  @override
  void openTeams() {}
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openAttendance() {}
  @override
  void openAttendanceHistory() {}
  @override
  void openTrainingList() {}
  @override
  void openTrainingProtocols() {}
  @override
  void openTrainingBuilder() {}
  @override
  void openTrainingSession({String? sessionId}) {}
  @override
  void openTrainingResult({String? sessionId}) {}
  @override
  void openClubInventory() => calls.add('inventory');
  @override
  void openPlatformStatus() => calls.add('platform-status');
  @override
  void openPlatformAudit() => calls.add('platform-audit');
}

final class _Chrome implements ProFeatureChrome {
  const _Chrome();

  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
        bottomNavigationBar: bottomBar,
      );

  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async =>
      true;

  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {}
}
