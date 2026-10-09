import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/configuration/presentation/season_setup_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class SeasonFake extends Fake implements ClubConfigService {
  final drafts = <SeasonSetupDraft>[];
  final operations = <String>[];
  Object? failure;
  Completer<SeasonSetupResult>? completer;
  @override
  Future<SeasonSetupResult> openSeason(SeasonSetupDraft draft,
      {required String operationId}) async {
    drafts.add(draft);
    operations.add(operationId);
    if (failure != null) {
      final f = failure!;
      failure = null;
      throw f;
    }
    if (completer != null) return completer!.future;
    return const SeasonSetupResult(
        seasonId: 's', teamId: 't', rosterCount: 1, eventCount: 0);
  }
}

const admin = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'club_admin',
    coachLevel: 0,
    athleteKind: null);
void main() {
  late SeasonFake service;
  setUp(() => service = SeasonFake());
  Future<void> mount(WidgetTester t,
      {SwanAccess access = admin, bool enabled = true}) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(true),
          swanAccessProvider.overrideWithValue(access),
          featureEnabledProvider(FeatureFlags.seasonSetup)
              .overrideWithValue(enabled),
          activeClubProvider.overrideWith((ref) async => ClubRef(
              id: ref.watch(selectedClubIdProvider) ?? 'c',
              name: 'Kulüp',
              role: 'club_admin')),
          clubAthletesProvider.overrideWith((ref) async => const [
                AthleteRow(id: 'a', firstName: 'Ada', lastName: 'Sporcu')
              ]),
          clubConfigServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(home: const SeasonSetupScreen(), routes: {
          '/teams': (_) => const Scaffold(body: Text('Takım kayıtları')),
        })));
    await t.pumpAndSettle();
  }

  Future<void> next(WidgetTester t) async {
    await t.tap(find.text('Devam'));
    await t.pumpAndSettle();
  }

  Future<void> review(WidgetTester t) async {
    await t.enterText(
        find.widgetWithText(TextField, 'Sezon adı'), '2026 sezonu');
    await next(t);
    await t.enterText(find.widgetWithText(TextField, 'Yeni takım adı'), 'U12');
    await t.tap(find.text('Ada Sporcu'));
    await next(t);
    await next(t);
    await next(t);
  }

  testWidgets('role and rollout gates prevent opening', (t) async {
    await mount(t, access: SwanAccess.none);
    expect(find.byType(TextField), findsNothing);
    await mount(t, enabled: false);
    expect(find.byType(TextField), findsNothing);
    expect(service.drafts, isEmpty);
  });
  testWidgets(
      'five steps save selected athlete with optional steps omitted at mobile width',
      (t) async {
    await mount(t);
    await review(t);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pumpAndSettle();
    expect(find.text('Sezon hazırlandı'), findsOneWidget);
    expect(service.drafts.single.athleteIds, ['a']);
    expect(service.drafts.single.scheduleUntil, isNull);
    expect(service.drafts.single.feeName, isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'lost response freezes draft; retry keeps operation ID and payload',
      (t) async {
    service.failure = TimeoutException('fixture');
    await mount(t);
    await review(t);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pumpAndSettle();
    expect(
        t.widget<TextButton>(find.widgetWithText(TextButton, 'Geri')).onPressed,
        isNull);
    await t.tap(find.text('Aynı işlemi tekrar dene'));
    await t.pumpAndSettle();
    expect(service.operations.length, 2);
    expect(service.operations.first, service.operations.last);
    expect(identical(service.drafts.first, service.drafts.last), isTrue);
  });
  testWidgets('definite rejection allows edits and new operation ID',
      (t) async {
    service.failure =
        const PostgrestException(message: 'fixture validation', code: 'P0001');
    await mount(t);
    await review(t);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pumpAndSettle();
    expect(
        t.widget<TextButton>(find.widgetWithText(TextButton, 'Geri')).onPressed,
        isNotNull);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pumpAndSettle();
    expect(service.operations.first, isNot(service.operations.last));
  });
  testWidgets('uncertain response can exit through explicit record check',
      (t) async {
    service.failure = TimeoutException('fixture');
    await mount(t);
    await review(t);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kayıtları kontrol ederek çık'));
    await t.pumpAndSettle();
    expect(find.text('Önce kayıtları kontrol et'), findsOneWidget);
    await t.tap(find.text('Takımları kontrol et'));
    await t.pumpAndSettle();
    expect(find.text('Takım kayıtları'), findsOneWidget);
    expect(service.drafts.length, 1);
  });
  testWidgets('in-flight submission cannot be sent twice', (t) async {
    service.completer = Completer();
    await mount(t);
    await review(t);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pump();
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Hazırlanıyor…'))
            .onPressed,
        isNull);
    expect(service.drafts.length, 1);
    service.completer!.complete(const SeasonSetupResult(
        seasonId: 's', teamId: 't', rosterCount: 1, eventCount: 0));
    await t.pumpAndSettle();
  });
  testWidgets('club change blocks submitting a roster from the previous club',
      (t) async {
    await mount(t);
    await review(t);
    final container =
        ProviderScope.containerOf(t.element(find.byType(SeasonSetupScreen)));
    container.read(selectedClubIdProvider.notifier).state = 'other';
    await t.pumpAndSettle();
    expect(find.text('Aktif kulüp değişti. Hazırlık için sayfayı yeniden aç.'),
        findsOneWidget);
    expect(find.text('Sezonu hazırla'), findsNothing);
    expect(service.drafts, isEmpty);
  });
  testWidgets('optional programme and fee are reviewed and sent as a draft',
      (t) async {
    await mount(t);
    await t.enterText(find.widgetWithText(TextField, 'Sezon adı'), 'Sezon');
    await next(t);
    await t.enterText(
        find.widgetWithText(TextField, 'Yeni takım adı'), 'Takım');
    await next(t);
    await t.tap(find.text('İlk haftaların programını ekle'));
    await t.pumpAndSettle();
    await next(t);
    await t.tap(find.text('Taslak aidat planı hazırla'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'Aidat planı adı'), 'Aylık');
    await t.ensureVisible(find.widgetWithText(TextField, 'Aylık tutar (TL)'));
    await t.enterText(
        find.widgetWithText(TextField, 'Aylık tutar (TL)'), '150,50');
    await next(t);
    expect(find.text('Pasif taslak · aidat ataması ve borç oluşturulmaz.'),
        findsOneWidget);
    await t.tap(find.text('Sezonu hazırla'));
    await t.pumpAndSettle();
    expect(service.drafts.single.eventCount, 12);
    expect(service.drafts.single.feeAmount, 150.50);
    expect(t.takeException(), isNull);
  });
}
