import 'dart:async';

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
    expect(find.text('RSS Kaynakları'), findsOneWidget);
    expect(find.text('Mesleki Belge Başvuruları'), findsOneWidget);
    expect(find.text('Rol ve Erişim'), findsOneWidget);
    expect(find.text('Federasyon Yetkilileri'), findsOneWidget);
    await tester.tap(find.text('Platform Durumu'));
    await tester.tap(find.text('Denetim Kayıtları'));
    await tester.tap(find.text('RSS Kaynakları'));
    expect(
      navigator.calls,
      containsAll(['platform-status', 'platform-audit', 'platform-rss']),
    );
  });

  testWidgets('platform parity screens do not query when access is absent',
      (tester) async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(SwanAccess.none),
        platformRssSourcesProvider.overrideWith((ref) async {
          calls++;
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(
        container: container,
        child: const PlatformRssSourcesScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Platform yöneticisi yetkisi gerekli'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('professional review opens a protected detail and approves once',
      (tester) async {
    final decisions = <({String id, bool approve, String? note})>[];
    final decisionGate = Completer<void>();
    var documentRequests = 0;
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
        pendingCredentialsProvider.overrideWith(
          (ref) async => const [
            CredentialRow(
              id: 'credential-1',
              kind: 'athlete_licensed',
              status: 'pending',
              personName: 'Ayşe Yılmaz',
              sportCode: 'basketbol',
              sportName: 'Basketbol',
            ),
          ],
        ),
        sportlessCredentialsProvider.overrideWith((ref) async => const []),
        reviewLogProvider.overrideWith((ref) async => const []),
        credentialDocumentsProvider('credential-1').overrideWith((ref) async {
          documentRequests++;
          return const [
            (docType: 'coach_certificate', url: 'https://signed.invalid/doc'),
          ];
        }),
        credentialReviewActionProvider.overrideWithValue((
          id,
          approve, {
          note,
          coachLevel,
          sportCode,
          nationalId,
          expiresOn,
        }) async {
          decisions.add((id: id, approve: approve, note: note));
          await decisionGate.future;
        }),
      ],
    );

    await tester.pumpWidget(
      _host(
        container: container,
        navigator: navigator,
        child: const PlatformProfessionalReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayşe Yılmaz'));
    await tester.pumpAndSettle();

    expect(find.text('Başvuru ayrıntısı'), findsOneWidget);
    expect(find.text('coach_certificate'), findsOneWidget);
    expect(documentRequests, 1);
    await tester.tap(find.byTooltip('Belgeyi aç'));
    await tester.pump();
    expect(navigator.protectedDocuments, [
      Uri.parse('https://signed.invalid/doc'),
    ]);

    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
    await tester.pump();

    expect(decisions, [
      (id: 'credential-1', approve: true, note: null),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    decisionGate.complete();
    await tester.pump();

    expect(decisions, [
      (id: 'credential-1', approve: true, note: null),
    ]);
    container.dispose();
  });

  testWidgets('professional review renders an explicit empty queue',
      (tester) async {
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
        pendingCredentialsProvider.overrideWith((ref) async => const []),
        sportlessCredentialsProvider.overrideWith((ref) async => const []),
        reviewLogProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        child: const PlatformProfessionalReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen başvuru yok'), findsOneWidget);
  });

  testWidgets('professional review rejects with the entered reason',
      (tester) async {
    final decisions = <({String id, bool approve, String? note})>[];
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
        pendingCredentialsProvider.overrideWith(
          (ref) async => const [
            CredentialRow(
              id: 'credential-reject',
              kind: 'athlete_individual',
              status: 'pending',
              personName: 'Mehmet Kaya',
              sportCode: 'tenis',
              sportName: 'Tenis',
            ),
          ],
        ),
        sportlessCredentialsProvider.overrideWith((ref) async => const []),
        reviewLogProvider.overrideWith((ref) async => const []),
        credentialDocumentsProvider('credential-reject')
            .overrideWith((ref) async => const []),
        credentialReviewActionProvider.overrideWithValue((
          id,
          approve, {
          note,
          coachLevel,
          sportCode,
          nationalId,
          expiresOn,
        }) async {
          decisions.add((id: id, approve: approve, note: note));
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        child: const PlatformProfessionalReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mehmet Kaya'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Belge okunamıyor');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reddet'));
    await tester.pumpAndSettle();

    expect(decisions, [
      (id: 'credential-reject', approve: false, note: 'Belge okunamıyor'),
    ]);
  });

  testWidgets('professional review reports a protected file opening failure',
      (tester) async {
    final chrome = _Chrome();
    final navigator = _Navigator()..documentOpenResult = false;
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
        pendingCredentialsProvider.overrideWith(
          (ref) async => const [
            CredentialRow(
              id: 'credential-file-error',
              kind: 'athlete_licensed',
              status: 'pending',
              personName: 'Deniz Ak',
              sportCode: 'voleybol',
              sportName: 'Voleybol',
            ),
          ],
        ),
        sportlessCredentialsProvider.overrideWith((ref) async => const []),
        reviewLogProvider.overrideWith((ref) async => const []),
        credentialDocumentsProvider('credential-file-error').overrideWith(
          (ref) async => const [
            (docType: 'license', url: 'https://signed.invalid/unavailable'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(
        container: container,
        navigator: navigator,
        chrome: chrome,
        child: const PlatformProfessionalReviewScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deniz Ak'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Belgeyi aç'));
    await tester.pumpAndSettle();

    expect(chrome.messages, contains('Belge açılamadı. Tekrar deneyin.'));
  });
}

Widget _host({
  required ProviderContainer container,
  required Widget child,
  _Navigator? navigator,
  _Chrome? chrome,
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
          chrome: chrome ?? _Chrome(),
          theme: ProFeatureThemeData.light,
          child: Scaffold(body: child),
        ),
      ),
    );

final class _Navigator extends ProFeatureNavigatorBase {
  final List<String> calls = [];
  final List<Uri> protectedDocuments = [];
  bool documentOpenResult = true;

  @override
  Future<bool> openProtectedDocument(Uri uri) async {
    protectedDocuments.add(uri);
    return documentOpenResult;
  }

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
  @override
  void openPlatformRssSources() => calls.add('platform-rss');
}

final class _Chrome implements ProFeatureChrome {
  final List<String> messages = [];

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
  }) =>
      messages.add(message);
}
