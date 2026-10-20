import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/home/quick_access_preferences.dart';
import 'package:swansport_app/app/home/today_training_card.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

final now = DateTime.utc(2026, 10, 20, 14);
final fixtureProvider = StateProvider<TodayTrainingSnapshot?>((_) => null);
final actorProvider = StateProvider<String>((_) => 'student');
TodayTrainingRsvp entry(
        {String id = 'one',
        String? response,
        bool self = true,
        DateTime? start}) =>
    TodayTrainingRsvp(
        eventId: id,
        athleteId: 'athlete-$id',
        title: id == 'one' ? 'Basketbol antrenmanı' : 'Basketbol $id',
        clubName: 'Swan Kulübü',
        isSelf: self,
        childName: self ? null : 'Ada',
        startsAt: start ?? now.add(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 2)),
        place: 'Spor Salonu',
        response: response);
TodayTrainingSnapshot snapshot(List<TodayTrainingRsvp> items,
        {String account = 'student'}) =>
    TodayTrainingSnapshot(serverNow: now, items: items, accountId: account);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<ProviderContainer> render(WidgetTester tester,
      {List<TodayTrainingRsvp> items = const [],
      Future<void> Function(TodayTrainingRsvp, String)? respond,
      bool enabled = true,
      bool parent = false,
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'athlete',
              coachLevel: 0,
              athleteKind: null,
              guardianAthleteIds: parent ? {'child'} : {})),
          quickAccessAccountProvider
              .overrideWith((ref) => ref.watch(actorProvider)),
          featureFlagsProvider.overrideWith((_) async => FeatureFlags({
                if (enabled) FeatureFlags.sportTrainingSessions,
                if (parent) FeatureFlags.parentHub
              })),
          todayTrainingRsvpsProvider
              .overrideWith((ref) => ref.watch(fixtureProvider)),
          respondTodayTrainingProvider
              .overrideWithValue(respond ?? (_, __) async {}),
        ],
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: brightness == Brightness.dark
                ? SwanTheme.dark()
                : SwanTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(
                body: SingleChildScrollView(
                    child: RepaintBoundary(
                        key: Key('today-training-preview'),
                        child: HomeTodayTraining()))))));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeTodayTraining)));
    container.read(fixtureProvider.notifier).state = snapshot(items);
    await tester.pumpAndSettle();
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    return container;
  }

  testWidgets('no training and closed feature stay invisible', (tester) async {
    await render(tester);
    expect(find.text('Bugünkü antrenman'), findsNothing);
    await render(tester, items: [entry()], enabled: false);
    expect(find.text('Bugünkü antrenman'), findsNothing);
  });
  testWidgets('time/place, two choices and no default attendance',
      (tester) async {
    await render(tester, items: [entry()]);
    expect(find.text('18:00–19:00'), findsOneWidget);
    expect(find.text('Spor Salonu'), findsOneWidget);
    expect(find.text('Katılacağım'), findsOneWidget);
    expect(find.text('Katılamayacağım'), findsOneWidget);
    expect(find.textContaining('Katılacağım dedin'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'saving blocks duplicates and only refreshed response becomes selected',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    final container =
        await render(tester, items: [entry()], respond: (item, status) {
      calls++;
      expect(status, 'attending');
      return pending.future;
    });
    await tester.tap(find.text('Katılacağım'));
    await tester.pump();
    await tester.tap(find.text('Katılamayacağım'));
    await tester.pump();
    expect(calls, 1);
    expect(find.textContaining('Katılacağım dedin'), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
    container.read(fixtureProvider.notifier).state =
        snapshot([entry(response: 'attending')]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Katılacağım dedin'), findsOneWidget);
  });
  testWidgets('failed or conflicting reply retains card and reports failure',
      (tester) async {
    await render(tester,
        items: [entry()],
        respond: (_, __) async => throw StateError('conflict'));
    await tester.tap(find.text('Katılamayacağım'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Yanıt kaydedilemedi'), findsOneWidget);
    expect(find.text('Basketbol antrenmanı'), findsOneWidget);
    expect(find.textContaining('Katılamayacağım dedin'), findsNothing);
  });
  testWidgets('started training is read only', (tester) async {
    var calls = 0;
    await render(tester,
        items: [entry(start: now.subtract(const Duration(seconds: 1)))],
        respond: (_, __) async {
      calls++;
    });
    expect(find.textContaining('Yanıt süresi doldu'), findsOneWidget);
    expect(find.text('Katılacağım'), findsNothing);
    expect(calls, 0);
  });
  testWidgets('guardian child identity and multiple sessions stay distinct',
      (tester) async {
    await render(tester,
        parent: true,
        items: [entry(self: false), entry(id: 'two', self: false)]);
    expect(find.text('Ada · Swan Kulübü'), findsOneWidget);
    expect(find.text('Basketbol two'), findsNothing);
    await tester.tap(find.text('1 antrenman daha'));
    await tester.pumpAndSettle();
    expect(find.text('Basketbol two'), findsOneWidget);
  });
  testWidgets(
      'account change cannot display retained previous-account snapshot',
      (tester) async {
    final container = await render(tester, items: [entry()]);
    container.read(actorProvider.notifier).state = 'other-account';
    await tester.pump();
    expect(find.text('Basketbol antrenmanı'), findsNothing);
  });
  testWidgets('narrow dark card and large text remain bounded', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(tester,
        items: [entry()], scale: 1.6, brightness: Brightness.dark);
    expect(find.text('Katılamayacağım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('CAPTURE_TODAY_TRAINING')) {
    for (final dark in [false, true]) {
      testWidgets('capture actual training card ${dark ? 'dark' : 'light'}',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          final body = FontLoader('Roboto')
            ..addFont(
                rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'));
          await icons.load();
          await body.load();
        });
        await render(tester,
            items: [entry(response: dark ? 'attending' : null)],
            brightness: dark ? Brightness.dark : Brightness.light);
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('today-training-preview')));
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
              '../../build/quick-access-verification/today-training-${dark ? 'dark' : 'light'}.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
