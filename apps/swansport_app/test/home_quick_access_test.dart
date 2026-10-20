import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swansport_app/app/home/home_quick_access.dart';
import 'package:swansport_app/app/home/quick_access_catalog.dart';
import 'package:swansport_app/app/home/quick_access_preferences.dart';
import 'package:swansport_app/app/home/quick_access_screen.dart';
import 'package:swansport_app/features/demo/demo_role.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

const coach = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 2,
    athleteKind: null);
const accountant = SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    accountantClubIds: {'club'});
const athlete = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'athlete',
    coachLevel: 0,
    athleteKind: 'athlete_licensed');
const parent = SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    guardianAthleteIds: {'child'});

Future<void> ready(QuickAccessController controller) async {
  if (controller.state.isLoading) {
    await controller.stream.firstWhere((value) => !value.isLoading);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('accountant only gets financial and personal targets', () {
    final choices = availableHomeShortcuts(accountant, {});
    final ids = choices.map((s) => s.id).toSet();
    expect(ids, containsAll(['finance', 'expenses', 'dues_admin']));
    expect(ids.intersection({'attendance', 'roster', 'training', 'parent'}),
        isEmpty);
    expect(defaultHomeShortcuts(accountant, choices).map((s) => s.id),
        ['finance', 'expenses', 'dues_admin', 'calendar']);
  });

  test('coach defaults respect the training flag', () {
    final closed = availableHomeShortcuts(coach, {});
    expect(defaultHomeShortcuts(coach, closed).map((s) => s.id),
        ['attendance', 'roster', 'calendar', 'dues']);
    final open =
        availableHomeShortcuts(coach, {FeatureFlags.sportTrainingSessions});
    expect(defaultHomeShortcuts(coach, open).map((s) => s.id),
        ['attendance', 'training', 'roster', 'calendar']);
  });

  test('athlete opens personal training, never staff attendance or roster', () {
    final choices = availableHomeShortcuts(athlete,
        {FeatureFlags.sportTrainingSessions, FeatureFlags.developmentReport});
    expect(
        defaultHomeShortcuts(athlete, choices).first.route, '/antrenmanlarim');
    expect(choices.map((s) => s.id), isNot(contains('attendance')));
    expect(choices.map((s) => s.id), isNot(contains('roster')));
  });

  test('guardian relationship works independently of membership label', () {
    expect(availableHomeShortcuts(parent, {}).map((s) => s.id),
        isNot(contains('parent')));
    expect(
        availableHomeShortcuts(parent, {FeatureFlags.parentHub})
            .map((s) => s.id),
        contains('parent'));
  });

  test('saved ids do not restore revoked authority or closed features', () {
    const prefs =
        QuickAccessPreferences(ids: ['roster', 'training', 'parent', 'venues']);
    expect(
        selectedHomeShortcuts(
                prefs, accountant, availableHomeShortcuts(accountant, {}))
            .map((s) => s.id),
        ['venues']);
    expect(availableHomeShortcuts(SwanAccess.none, {}), isEmpty);
  });

  test(
      'invalid storage falls back, duplicates and oversized selections normalize',
      () {
    expect(QuickAccessPreferences.decode('broken').ids, isNull);
    expect(
        QuickAccessPreferences.decode('{"ids":["a","a",2,"b","c","d","e"]}')
            .ids,
        ['a', 'b', 'c', 'd']);
    const empty = QuickAccessPreferences(ids: []);
    expect(
        selectedHomeShortcuts(empty, coach, availableHomeShortcuts(coach, {})),
        isEmpty);
  });

  test('preferences persist across recreation and remain isolated by account',
      () async {
    final first = QuickAccessController('first');
    final second = QuickAccessController('second');
    await Future.wait([ready(first), ready(second)]);
    await first.save(
        const QuickAccessPreferences(hidden: true, ids: ['venues', 'dues']));
    expect(second.state.requireValue.hidden, isFalse);
    first.dispose();
    second.dispose();
    final reopened = QuickAccessController('first');
    await ready(reopened);
    expect(reopened.state.requireValue.hidden, isTrue);
    expect(reopened.state.requireValue.ids, ['venues', 'dues']);
    reopened.dispose();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          quickAccessAccountProvider.overrideWithValue('widget-user'),
          swanAccessProvider.overrideWithValue(coach),
          effectiveAllowedRoutesProvider.overrideWithValue(null),
          featureFlagsProvider
              .overrideWith((_) async => const FeatureFlags.none()),
        ],
        child: MaterialApp(
            theme: SwanTheme.light(),
            home: const Scaffold(
                body: SingleChildScrollView(child: HomeQuickAccess())),
            routes: {
              '/attendance': (_) =>
                  const Scaffold(body: Text('Attendance destination'))
            })));
    await tester.pumpAndSettle();
  }

  testWidgets('shortcut opens its real named route', (tester) async {
    await pumpHome(tester);
    expect(tester.getSize(find.byKey(const Key('home-quick-access'))).height,
        lessThanOrEqualTo(150));
    await tester.tap(find.text('Yoklama Al'));
    await tester.pumpAndSettle();
    expect(find.text('Attendance destination'), findsOneWidget);
  });

  testWidgets('edit, remove, add, reorder, save and hide', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byTooltip('Hızlı erişimi düzenle'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAccessScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Yoklama Al kaldır'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Partner Bul'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Partner Bul'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ana sayfada göster'), -250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Takvim yukarı taşı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Yoklama Al'), findsNothing);
    expect(find.text('Partner Bul'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final saved = QuickAccessPreferences.decode(
        prefs.getString('swan.quick_access.v1.widget-user'));
    expect(saved.ids, ['calendar', 'roster', 'dues', 'partner']);
    await tester.tap(find.byTooltip('Hızlı erişimi düzenle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-quick-access')), findsNothing);
  });

  testWidgets('narrow screen with large text does not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          quickAccessAccountProvider.overrideWithValue('large-type'),
          swanAccessProvider.overrideWithValue(coach),
          effectiveAllowedRoutesProvider.overrideWithValue(null),
          featureFlagsProvider
              .overrideWith((_) async => const FeatureFlags.none()),
        ],
        child: MaterialApp(
            theme: SwanTheme.dark(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!),
            home: const Scaffold(
                body: SingleChildScrollView(child: HomeQuickAccess())))));
    await tester.pumpAndSettle();
    expect(find.text('Yoklama Al'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
