import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/clubs/presentation/club_cockpit_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const club = ClubRef(
    id: 'club-123',
    name: 'Kadıköy Basketbol SK',
    city: 'İstanbul',
    role: 'club_admin');
const admin = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'club_admin',
    coachLevel: 0,
    athleteKind: null);
const coach = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 1,
    athleteKind: null);
const authorizedCoach = SwanAccess(
  isPlatformAdmin: false,
  clubRole: 'coach',
  coachLevel: 1,
  athleteKind: null,
  clubOperationsAuthority: [
    ClubOperationsAuthority(
      clubId: 'club-123',
      inventoryRead: true,
      inventoryWrite: true,
      healthRead: true,
      planningRead: true,
    ),
  ],
);

Future<void> pumpCockpit(
  WidgetTester tester,
  SwanAccess access, {
  bool training = false,
  bool operations = false,
  bool season = false,
  ClubRef? activeClub = club,
  double scale = 1,
  List<PendingPayment> payments = const [],
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(access),
        activeClubProvider.overrideWith((_) async => activeClub),
        clubPendingApplicationsProvider.overrideWith((_) async => const []),
        clubAthletesProvider.overrideWith((_) async => const []),
        pendingPaymentsProvider.overrideWith((_) async => payments),
        featureFlagsProvider.overrideWith(
          (_) async => FeatureFlags({
            FeatureFlags.coachWorkspace,
            FeatureFlags.teamHub,
            FeatureFlags.attendanceOperations,
            if (training) FeatureFlags.sportTrainingSessions,
          }),
        ),
        clubRosterCountsProvider.overrideWith(
          (_) async => const ClubRosterCounts(total: 0, active: 0),
        ),
        clubTodayAttendanceProvider.overrideWith(
          (_) async => const ClubTodayAttendance(
            trainingCount: 0,
            markedCount: 0,
          ),
        ),
        attendanceSummaryProvider.overrideWith((_) async => const []),
        trainingProtocolsProvider.overrideWith((_) async => const []),
        myLiveSessionProvider.overrideWith((_) async => null),
        featureEnabledProvider(FeatureFlags.sportTrainingSessions)
            .overrideWithValue(training),
        featureEnabledProvider(FeatureFlags.clubStaffOperations)
            .overrideWithValue(operations),
        featureEnabledProvider(FeatureFlags.seasonSetup)
            .overrideWithValue(season),
      ],
      child: MaterialApp(
          builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          home: const ClubCockpitScreen())));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 250,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty club and non-staff are guarded', (tester) async {
    await pumpCockpit(tester, admin, activeClub: null);
    expect(find.text('Aktif bir kulüp bulunamadı'), findsOneWidget);
    await pumpCockpit(tester, SwanAccess.none);
    expect(find.text('Yetkin yok'), findsOneWidget);
  });

  testWidgets('flagged routes stay hidden when flags are off', (tester) async {
    await pumpCockpit(tester, admin);
    expect(find.text('Antrenman Şablonları'), findsNothing);
    expect(find.text('Malzeme & Zimmet Takibi'), findsNothing);
    expect(find.text('Sağlık & İdari Dinlendirme'), findsNothing);
    expect(find.text('Sportif Kadro Planlama'), findsNothing);
    expect(find.text('Sezon Açılışı'), findsNothing);
  });

  testWidgets('coach cannot see admin-only season or unauthorized operations',
      (tester) async {
    await pumpCockpit(tester, coach,
        training: true, operations: true, season: true);
    await scrollTo(tester, 'Antrenman Şablonları');
    expect(find.text('Antrenman Şablonları'), findsOneWidget);
    expect(find.text('Sezon Açılışı'), findsNothing);
    expect(find.text('Malzeme & Zimmet Takibi'), findsNothing);
    expect(find.text('Sağlık & İdari Dinlendirme'), findsNothing);
    expect(find.text('Sportif Kadro Planlama'), findsNothing);
  });

  testWidgets('admin sees enabled season and athlete paths', (tester) async {
    await pumpCockpit(tester, admin, season: true);
    await scrollTo(tester, 'Sezon Açılışı');
    expect(find.text('Sezon Açılışı'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni Sporcu / Öğrenci Ekle').first);
    await tester.pumpAndSettle();
    expect(find.text('Davet Linki'), findsOneWidget);
    await tester.tap(find.text('Hesapsız Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Mevcut üyeyi kadroya bağla'), findsOneWidget);
  });

  testWidgets('operational entries need enabled flag and active-club authority',
      (tester) async {
    await pumpCockpit(tester, authorizedCoach, operations: true);
    await scrollTo(tester, 'Malzeme & Zimmet Takibi');
    expect(find.text('Malzeme & Zimmet Takibi'), findsOneWidget);
    await scrollTo(tester, 'Sağlık & İdari Dinlendirme');
    expect(find.text('Sağlık & İdari Dinlendirme'), findsOneWidget);
    await scrollTo(tester, 'Sportif Kadro Planlama');
    expect(find.text('Sportif Kadro Planlama'), findsOneWidget);
    await pumpCockpit(tester, authorizedCoach, operations: false);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
    await tester.pumpAndSettle();
    expect(find.text('Sportif Kadro Planlama'), findsNothing);
  });

  testWidgets(
      'payment sheet summarizes approval records without calling them debts',
      (tester) async {
    await pumpCockpit(tester, admin, payments: [
      PendingPayment(
          id: 'payment-1',
          amount: 250,
          method: 'havale',
          label: 'Ekim aidatı',
          paidAt: DateTime(2026, 10, 1),
          athleteName: 'Ayşe Yılmaz'),
    ]);
    await tester.tap(find.text('Hatırlat'));
    await tester.pumpAndSettle();
    expect(find.text('1 ödeme bildirimi onay bekliyor'), findsWidgets);
    expect(
        find.textContaining('Ayşe Yılmaz • Ekim aidatı • 250'), findsOneWidget);
    await tester.tap(find.text('WhatsApp ile Hatırlat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 and 375 pixel layouts with large text do not overflow',
      (tester) async {
    for (final width in [320.0, 375.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await pumpCockpit(tester, admin,
          training: true, season: true, scale: 1.6);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Yeni Sporcu / Öğrenci Ekle').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Hesapsız Ekle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hatırlat'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('admin sees shared operations and retains admin-only actions',
      (tester) async {
    tester.view.physicalSize = const Size(600, 3500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpCockpit(tester, admin, training: true, season: true);

    final operationsPos =
        tester.getTopLeft(find.text('Kulüp Operasyonları')).dy;
    final financePos = tester.getTopLeft(find.text('MALİ İŞLER & KASA')).dy;
    expect(operationsPos, lessThan(financePos));

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Kulüp Gideri Ekle'), findsOneWidget);
    expect(find.text('Kulüp Ayarları'), findsOneWidget);
  });

  testWidgets('coach sees shared operations and cannot see admin-only actions',
      (tester) async {
    tester.view.physicalSize = const Size(600, 3500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpCockpit(tester, coach, training: true, season: true);

    final operationsPos =
        tester.getTopLeft(find.text('Kulüp Operasyonları')).dy;
    final financePos = tester.getTopLeft(find.text('MALİ İŞLER & KASA')).dy;
    expect(operationsPos, lessThan(financePos));

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Kulüp Gideri Ekle'), findsNothing);
    expect(find.text('Kulüp Ayarları'), findsNothing);
  });

  testWidgets('urgent rows show relevant single-touch actions per role',
      (tester) async {
    await pumpCockpit(tester, coach, training: true);
    expect(find.text('GÜNÜN ACİL İŞLERİ'), findsOneWidget);
    expect(find.text('Yoklama Al'), findsOneWidget);
    expect(find.text('Oturum Aç'), findsOneWidget);

    await pumpCockpit(tester, admin, training: false);
    expect(find.text('Yoklama Al'), findsOneWidget);
    expect(find.text('Hatırlat'), findsOneWidget);
  });
}
