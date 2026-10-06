import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/app/config/app_environment.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/courts/presentation/venues_screen.dart';
import 'package:swansport_app/features/teams/presentation/screens/team_roster_screen.dart';
import 'package:swansport_app/features/financial_management/presentation/accountant_privacy_ledger_screen.dart';
import 'package:swansport_app/features/financial_management/presentation/finance_screen.dart';
import 'package:swansport_app/features/training/presentation/session_screen.dart';
import 'package:swansport_app/features/training/presentation/workout_builder_screen.dart';

const staff = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 0,
    athleteKind: null);
const club = ClubRef(id: 'club-1', name: 'Gerçek Kulüp', role: 'coach');

void main() {
  testWidgets('team roster uses saved names and jerseys without invented bios',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          activeClubProvider.overrideWith((ref) async => null),
          teamRosterProvider.overrideWith((ref, team) async => [
                (
                  id: 'member-1',
                  athleteId: 'athlete-1',
                  name: 'Işık',
                  jersey: null
                ),
              ]),
        ],
        child: const MaterialApp(
            home: TeamRosterScreen(
                teamId: 'team-1', teamName: 'Kayıtlı takım'))));
    await tester.pumpAndSettle();
    expect(find.text('Işık'), findsOneWidget);
    expect(find.text('1 sporcu'), findsOneWidget);
    expect(find.textContaining('UEFA'), findsNothing);
    expect(find.textContaining('2006'), findsNothing);
    expect(find.textContaining('Sağ Ayak'), findsNothing);
    expect(find.text('3 - 1'), findsNothing);
    expect(find.textContaining('Forma:'), findsNothing);
    await tester.enterText(find.byType(TextField), 'ışık');
    await tester.pumpAndSettle();
    expect(find.text('Işık'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registered court never receives invented bookings or IoT status',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      courtsProvider.overrideWith((ref, city) async => const [
            Court(
                id: 'court-1',
                name: 'Kayıtlı kort',
                lat: 40,
                lng: 29,
                opensAt: '08:00',
                closesAt: '22:00',
                capacity: 1),
          ]),
    ], child: const MaterialApp(home: VenuesScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Kayıtlı kort'), findsOneWidget);
    expect(find.text('08:00 – 22:00'), findsOneWidget);
    expect(find.text('Ayırt'), findsNothing);
    expect(find.textContaining('Projektör'), findsNothing);
    expect(find.textContaining('U18 Genç Takım'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty live session opens real templates, no telemetry fallback',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      myLiveSessionProvider.overrideWith((ref) async => null),
    ], child: const MaterialApp(home: TrainingSessionScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Aktif oturum yok'), findsOneWidget);
    expect(find.textContaining('GPS'), findsNothing);
  });

  testWidgets('ledger paginates masked RPC records and keeps total',
      (tester) async {
    final offsets = <int>[];
    await tester.pumpWidget(ProviderScope(overrides: [
      activeClubProvider.overrideWith((ref) async => club),
      clubLedgerPageProvider.overrideWith((ref, offset) async {
        offsets.add(offset);
        return LedgerPage.fromRows([
          {
            'entry_id': '$offset',
            'moved_on': '2026-10-06',
            'direction': 'in',
            'label': 'Aidat',
            'category': 'Aidat',
            'counterpart': '#A3F91C',
            'account': 'Banka',
            'amount': 500,
            'status': 'confirmed',
            'total_count': 51,
          }
        ]);
      }),
    ], child: const MaterialApp(home: AccountantPrivacyLedgerScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('#A3F91C'), findsOneWidget);
    expect(find.text('51 kayıt'), findsOneWidget);
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(offsets, contains(50));
    await tester.tap(find.text('Önceki'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#A3F91C'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero finance remains zero and failure is explicit',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      financeSummaryProvider.overrideWith((ref) async => FinanceSummary.empty),
    ], child: const MaterialApp(home: FinanceScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('142.500'), findsNothing);
    expect(find.textContaining('284.200'), findsNothing);
    expect(find.textContaining('%0'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ProviderScope(overrides: [
      financeSummaryProvider
          .overrideWith((ref) async => throw StateError('Bağlantı yok')),
    ], child: const MaterialApp(home: FinanceScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mali özet alınamadı'), findsOneWidget);
    expect(find.textContaining('142.500'), findsNothing);
  });

  testWidgets('live preview route never displays fixture report',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      appEnvironmentProvider
          .overrideWithValue(const AppEnvironment.production()),
    ], child: const SwanSportApp()));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.pushNamed('/auth'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Rolü ile Dene'), findsNothing);
    unawaited(nav.pushNamed('/demo-rol'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Modu'), findsNothing);
    unawaited(nav.pushNamed('/report-detail'));
    await tester.pumpAndSettle();
    expect(find.text('Ayrıntı görünümü kullanılamıyor'), findsOneWidget);
    expect(find.text('Profil ve yönetime git'), findsOneWidget);
  });

  testWidgets(
      'protocol save waits for service, prevents duplicates and reports failure',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = RecordingTrainingService();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          activeClubProvider.overrideWith((ref) async => club),
          swanAccessProvider.overrideWithValue(staff),
          sportsProvider.overrideWith(
              (ref) async => const [CityRow(code: 'archery', name: 'Okçuluk')]),
          trainingSessionServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
            home: WorkoutProtocolBuilderScreen(initialTitle: 'Yeni çalışma'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Okçuluk').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Şablonu kaydet'));
    await tester.tap(find.text('Şablonu kaydet'));
    await tester.pump();
    expect(service.calls, 1);
    expect(service.savedClub, 'club-1');
    expect(service.savedSport, 'archery');
    expect(service.savedConfig?.setCount, 6);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    service.result.completeError(StateError('Sunucu reddetti'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Şablon kaydedilemedi'), findsOneWidget);
    expect(find.text('Şablon kaydedildi.'), findsNothing);
    expect(service.calls, 1);
  });
}

class RecordingTrainingService extends TrainingSessionService {
  RecordingTrainingService() : super(Supabase.instance.client);
  final result = Completer<String>();
  int calls = 0;
  String? savedClub;
  String? savedSport;
  TrainingProtocolConfig? savedConfig;
  @override
  Future<String> createProtocol(
      {required String clubId,
      required String sportCode,
      required String name,
      required TrainingProtocolConfig config,
      String? description}) {
    calls++;
    savedClub = clubId;
    savedSport = sportCode;
    savedConfig = config;
    return result.future;
  }
}
