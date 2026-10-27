import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('denies federation operations when user lacks federation access',
      (tester) async {
    await _pumpPanel(
      tester,
      access: const SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'coach',
        coachLevel: 1,
        athleteKind: null,
      ),
    );

    expect(find.text('Federasyon operasyon yetkisi gerekli'), findsOneWidget);
    expect(find.byType(ClubOperationCard), findsNothing);
  });

  testWidgets('shows explicit no-scope state when scopes are empty',
      (tester) async {
    await _pumpPanel(
      tester,
      scopes: const [],
    );

    expect(
      find.text('Aktif federasyon veya branş kapsamı bulunamadı'),
      findsOneWidget,
    );
    expect(find.byType(ClubOperationCard), findsNothing);
  });

  testWidgets(
      'renders authorized federation cards and invokes typed navigator ports',
      (tester) async {
    final navigator = _Navigator();
    await _pumpPanel(tester, navigator: navigator);

    expect(find.text('Federasyon Operasyonları'), findsOneWidget);
    expect(find.text('Resmî Müsabakalar & Takvim'), findsOneWidget);
    expect(find.text('MHK Hakem Atamaları'), findsOneWidget);
    expect(find.text('Lig & Puan Durumu'), findsOneWidget);
    expect(find.text('Disiplin Kurulu'), findsOneWidget);
    expect(find.text('Federasyon Bülten & Duyurular'), findsOneWidget);

    await tester.tap(find.text('Resmî Müsabakalar & Takvim'));
    await tester.tap(find.text('MHK Hakem Atamaları'));
    await tester.tap(find.text('Lig & Puan Durumu'));
    await tester.tap(find.text('Disiplin Kurulu'));
    await tester.tap(find.text('Federasyon Bülten & Duyurular'));

    expect(
      navigator.calls,
      [
        'federation-matches',
        'referee-assignments',
        'league-standings',
        'disciplinary-board',
        'federation-bulletins',
      ],
    );
  });

  testWidgets('multi-scope selector switches active federation scope safely',
      (tester) async {
    await _pumpPanel(
      tester,
      scopes: const [
        FederationConsoleScope(
          federationId: 'fed-1',
          name: 'Türkiye Futbol Federasyonu',
          sportCode: 'futbol',
          role: 'president',
        ),
        FederationConsoleScope(
          federationId: 'fed-2',
          name: 'Türkiye Basketbol Federasyonu',
          sportCode: 'basketbol',
          role: 'provincial_rep',
          cityCode: '06',
        ),
      ],
    );

    expect(
      find.byKey(const Key('federation-scope-selector')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('federation-scope-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Türkiye Basketbol Federasyonu').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('basketbol · İl 06'),
      findsWidgets,
    );
  });

  testWidgets(
      'SharedFederationMatchesScreen uses server query pagination and preserves null facility conflict as Doğrulanamıyor',
      (tester) async {
    final observedQueries = <FederationMatchQuery>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(_presidentAccess()),
          federationConsoleScopesProvider.overrideWith(
            (ref) async => const [
              FederationConsoleScope(
                federationId: 'fed-1',
                name: 'Türkiye Futbol Federasyonu',
                sportCode: 'futbol',
                role: 'president',
              ),
            ],
          ),
          citiesProvider.overrideWith(
            (ref) async => const [
              CityRow(code: '34', name: 'İstanbul'),
              CityRow(code: '06', name: 'Ankara'),
            ],
          ),
          federationConsoleMatchesProvider.overrideWith((ref, query) async {
            observedQueries.add(query);
            return FederationConsolePage<FederationConsoleMatch>(
              total: 65,
              rows: [
                FederationConsoleMatch(
                  id: 'match-1',
                  program: 'U19 Elit Lig',
                  sportCode: 'futbol',
                  status: 'scheduled',
                  cityCode: '34',
                  homeName: 'Anadolu SK',
                  awayName: 'Boğaziçi SK',
                  facilityName: null,
                  facilityConflictCount: null,
                ),
                FederationConsoleMatch(
                  id: 'match-2',
                  program: 'U19 Elit Lig',
                  sportCode: 'futbol',
                  status: 'played',
                  cityCode: '06',
                  homeName: 'Başkent SK',
                  awayName: 'Çankaya SK',
                  facilityName: 'Merkez Stadyumu',
                  facilityConflictCount: 0,
                ),
              ],
            );
          }),
        ],
        child: MaterialApp(
          home: ProFeatureHostScope(
            navigator: _Navigator(),
            chrome: const _Chrome(),
            theme: ProFeatureThemeData.dark,
            child: const SharedFederationMatchesScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Doğrulanamıyor'), findsOneWidget);
    expect(find.text('Çakışma yok'), findsOneWidget);
    expect(observedQueries.last.offset, 0);

    await tester.enterText(
      find.byKey(const Key('federation-matches-search')),
      'Anadolu',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(observedQueries.last.search, 'Anadolu');

    await tester.tap(find.byKey(const Key('federation-matches-next-page')));
    await tester.pumpAndSettle();
    expect(observedQueries.last.offset, 50);
  });

  testWidgets('renders without overflow at 320px width and 2x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPanel(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Federasyon Operasyonları'), findsOneWidget);
  });
}

SwanAccess _presidentAccess() {
  final now = DateTime.now().toUtc();
  return SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    federationRoles: [
      FederationRole(
        id: 'role-1',
        federationId: 'fed-1',
        profileId: 'user-1',
        role: FederationRoleKind.president,
        startsOn: now.subtract(const Duration(days: 10)),
        endsOn: now.add(const Duration(days: 30)),
      ),
    ],
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  SwanAccess? access,
  List<FederationConsoleScope>? scopes,
  FeatureFlags flags = const FeatureFlags({
    FeatureFlags.leagueStandings,
    FeatureFlags.federationBulletin,
    FeatureFlags.liveMatchHub,
  }),
  _Navigator? navigator,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(access ?? _presidentAccess()),
        featureFlagsProvider.overrideWith((ref) async => flags),
        federationConsoleScopesProvider.overrideWith(
          (ref) async =>
              scopes ??
              const [
                FederationConsoleScope(
                  federationId: 'fed-1',
                  name: 'Türkiye Futbol Federasyonu',
                  sportCode: 'futbol',
                  role: 'president',
                ),
              ],
        ),
        federationConsoleMatchesProvider.overrideWith(
          (ref, query) async => FederationConsolePage<FederationConsoleMatch>(
            total: 4,
            rows: [
              FederationConsoleMatch(
                id: 'm1',
                program: 'Bölgesel Lig',
                sportCode: 'futbol',
                status: 'scheduled',
                cityCode: '34',
                homeName: 'A',
                awayName: 'B',
              ),
            ],
          ),
        ),
        federationDisciplinaryReportsProvider.overrideWith(
          (ref, offset) async =>
              FederationConsolePage<FederationDisciplinaryReport>(
            total: 2,
            rows: const [],
          ),
        ),
        standingsLeaguesProvider.overrideWith(
          (ref) async => const [
            StandingsLeague(
              id: '11111111-1111-4111-8111-111111111111',
              federationId: 'fed-1',
              name: 'U19 Elit Lig',
              sportCode: 'futbol',
              winPoints: 3,
              drawPoints: 1,
              lossPoints: 0,
            ),
          ],
        ),
        federationDisciplinaryBulletinProvider.overrideWith(
          (ref, filter) async => const [],
        ),
        federationNoticesProvider.overrideWith(
          (ref, filter) async => const [],
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ProFeatureHostScope(
            navigator: navigator ?? _Navigator(),
            chrome: const _Chrome(),
            theme: ProFeatureThemeData.dark,
            child: const SingleChildScrollView(
              child: SharedFederationOperationsPanel(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _Navigator extends ProFeatureNavigatorBase {
  final calls = <String>[];

  @override
  void openTeams() => calls.add('teams');
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openAttendance() => calls.add('attendance');
  @override
  void openAttendanceHistory() => calls.add('attendance-history');
  @override
  void openTrainingList() => calls.add('training-list');
  @override
  void openTrainingProtocols() => calls.add('training-protocols');
  @override
  void openTrainingBuilder() => calls.add('training-builder');
  @override
  void openTrainingSession({String? sessionId}) {}
  @override
  void openTrainingResult({String? sessionId}) {}
  @override
  void openFederationMatches() => calls.add('federation-matches');
  @override
  void openRefereeAssignments() => calls.add('referee-assignments');
  @override
  void openLeagueStandings() => calls.add('league-standings');
  @override
  void openDisciplinaryBoard() => calls.add('disciplinary-board');
  @override
  void openFederationBulletins() => calls.add('federation-bulletins');
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
