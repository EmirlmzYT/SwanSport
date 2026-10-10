import 'package:swansport_app/features/courts/presentation/venue_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/widgets/action_gate.dart';
import 'package:swansport_app/features/courts/presentation/court_detail_screen.dart';
import 'package:swansport_app/features/courts/presentation/find_partner_screen.dart';
import 'package:swansport_app/features/courts/presentation/venues_screen.dart';
import 'package:swansport_app/features/turf/presentation/turf_field_detail_screen.dart';
import 'package:swansport_app/features/verification/presentation/phone_verification_section.dart';
import 'package:swansport_data/swansport_data.dart';

const court = Court(
    id: 'court',
    name: 'Halka Açık Kort',
    lat: 41,
    lng: 29,
    opensAt: '08:00',
    closesAt: '23:00',
    capacity: 4);
const field = TurfField(
    id: 'field',
    name: 'Halı Saha',
    venueName: 'Spor Tesisi',
    opensAt: '08:00',
    closesAt: '23:00');
final time = DateTime.now().add(const Duration(hours: 1));
SwanAccess account(String tier) => SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    verificationTier: tier);
const accountMessage =
    'Tesis rezervasyonu ve partner iletişimi için SwanSport hesabı gereklidir.';
const phoneMessage =
    'Tesis güvenliği ve sahte rezervasyonları önlemek için telefon numarası doğrulaması gerekmektedir.';

class Courts extends Fake implements CourtService {
  int writes = 0;
  bool? published;
  @override
  Future<void> sendPartnerPing(String id) async {
    writes++;
  }

  @override
  Future<void> requestJoin(String id) async {
    writes++;
  }

  @override
  Future<String> seekPartner(
      {required String sportCode,
      double? lat,
      double? lng,
      bool isPublic = false}) async {
    writes++;
    published = isPublic;
    return 'request';
  }
}

class Turf extends Fake implements TurfService {
  int writes = 0;
  @override
  Future<void> requestSlot(
      {required String fieldId, required DateTime startsAt}) async {
    writes++;
  }
}

class Verification extends Fake implements VerificationService {
  String? sent, confirmed;
  Object? error;
  @override
  Future<void> requestPhoneVerification(String phone) async {
    if (error != null) throw error!;
    sent = phone;
  }

  @override
  Future<void> confirmPhoneVerification(String phone, String code) async {
    if (error != null) throw error!;
    confirmed = '$phone:$code';
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Widget host(Widget child,
          {SwanAccess access = SwanAccess.none,
          Courts? courts,
          Turf? turf,
          Verification? verification}) =>
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(access),
          courtsProvider(null).overrideWith((_) async => [court]),
          turfFieldsProvider(null).overrideWith((_) async => [field]),
          courtTimelineProvider(court.id).overrideWith((_) async => [
                TimelineSlot(
                    startsAt: time,
                    status: 'free',
                    needed: 0,
                    players: 0,
                    mine: false)
              ]),
          turfOccupancyGridProvider(field.id).overrideWith(
              (_) async => [TurfSlot(startsAt: time, occupied: false)]),
          courtSportCodesProvider.overrideWith(
              (_) async => [const CityRow(code: 'tennis', name: 'Tenis')]),
          publicPartnerRequestsProvider.overrideWith((_) async => [
                PublicPartnerRequest(
                    id: 'request',
                    sportCode: 'tennis',
                    sportName: 'Tenis daveti',
                    cityName: 'İstanbul',
                    expiresAt: time)
              ]),
          courtServiceProvider.overrideWithValue(courts ?? Courts()),
          turfServiceProvider.overrideWithValue(turf ?? Turf()),
          if (verification != null)
            verificationServiceProvider.overrideWithValue(verification),
          myVenueVerificationTierProvider.overrideWith(
              (_) async => verification?.confirmed != null ? 'phone' : 'none'),
        ],
        child: MaterialApp(home: child, routes: {
          '/auth': (_) => const Scaffold(body: Text('AUTH TARGET')),
          '/dogrulama': (_) => const Scaffold(body: PhoneVerificationSection()),
        }),
      );

  testWidgets('guest browses unified venue list and opens court timetable',
      (tester) async {
    await tester.pumpWidget(host(const VenuesScreen()));
    await tester.pumpAndSettle();
    expect(find.text(court.name), findsOneWidget);
    await tester.tap(find.text(court.name));
    await tester.pumpAndSettle();
    expect(find.text('Boş'), findsOneWidget);
    await tester.tap(find.text('Al'));
    await tester.pumpAndSettle();
    expect(find.byType(SwanActionGateBottomSheet), findsOneWidget);
    expect(find.text(accountMessage), findsOneWidget);
    await tester.tap(find.text('Giriş Yap / Kayıt Ol'));
    await tester.pumpAndSettle();
    expect(find.text('AUTH TARGET'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Boş'),
        findsOneWidget); // no automatic reservation after login
  });

  for (final access in [SwanAccess.none, account('location')]) {
    testWidgets(
        '${access.verificationTier} turf request is explained before service/dialog',
        (tester) async {
      final turf = Turf();
      await tester.pumpWidget(host(const TurfFieldDetailScreen(field: field),
          access: access, turf: turf));
      await tester.pumpAndSettle();
      expect(find.text('Boş'), findsOneWidget);
      await tester.tap(find.text('Boş'));
      await tester.pumpAndSettle();
      expect(find.text(access.hasAccount ? phoneMessage : accountMessage),
          findsOneWidget);
      expect(turf.writes, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
    testWidgets(
        '${access.verificationTier} court action remains tappable and gated',
        (tester) async {
      await tester.pumpWidget(
          host(const CourtDetailScreen(court: court), access: access));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Al'));
      await tester.pumpAndSettle();
      expect(find.text(access.hasAccount ? phoneMessage : accountMessage),
          findsOneWidget);
      if (access.hasAccount) {
        await tester.tap(find.text('Telefonumu doğrula'));
        await tester.pumpAndSettle();
        expect(find.text('SMS kodu gönder'), findsOneWidget);
      }
    });
    testWidgets(
        '${access.verificationTier} public partner invitation is readable, ping blocked',
        (tester) async {
      final courts = Courts();
      await tester.pumpWidget(
          host(const FindPartnerScreen(), access: access, courts: courts));
      await tester.pumpAndSettle();
      expect(find.text('Tenis daveti'), findsOneWidget);
      await tester.tap(find.text('Oynayalım'));
      await tester.pumpAndSettle();
      expect(find.text(access.hasAccount ? phoneMessage : accountMessage),
          findsOneWidget);
      expect(courts.writes, 0);
    });
  }

  for (final tier in ['phone', 'id']) {
    testWidgets('$tier can ping a public invitation using the data service',
        (tester) async {
      final courts = Courts();
      await tester.pumpWidget(host(const FindPartnerScreen(),
          access: account(tier), courts: courts));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oynayalım'));
      await tester.pumpAndSettle();
      expect(courts.writes, 1);
      expect(find.byType(SwanActionGateBottomSheet), findsNothing);
    });
    testWidgets('$tier can enter court reservation form', (tester) async {
      await tester.pumpWidget(
          host(const CourtDetailScreen(court: court), access: account(tier)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Al'));
      await tester.pumpAndSettle();
      expect(find.byType(SwanActionGateBottomSheet), findsNothing);
      expect(find.text('Saati al'), findsOneWidget);
    });
  }

  testWidgets(
      'phone OTP goes through data service and surfaces retryable failure',
      (tester) async {
    final verification = Verification();
    await tester.pumpWidget(host(
        const Scaffold(body: PhoneVerificationSection()),
        access: account('none'),
        verification: verification));
    await tester.enterText(find.byType(TextField).first, '+905321234567');
    await tester.tap(find.text('SMS kodu gönder'));
    await tester.pumpAndSettle();
    expect(verification.sent, '+905321234567');
    await tester.enterText(find.byType(TextField).last, '123456');
    verification.error = StateError('Yanlış kod');
    await tester.tap(find.text('Kodu doğrula'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Yanlış kod'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    verification.error = null;
    await tester.tap(find.text('Kodu doğrula'));
    await tester.pumpAndSettle();
    expect(verification.confirmed, '+905321234567:123456');
  });

  testWidgets('dark narrow action sheet supports enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: const Scaffold(
            body: SwanActionGateBottomSheet(
                decision: SwanActionDecision.phoneRequired,
                action: SwanAction.reservation))));
    await tester.pumpAndSettle();
    expect(find.text(phoneMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('guest overview shows actual surface, photo and map',
      (tester) async {
    await tester.pumpWidget(host(const Scaffold(
        body: VenueOverview(
            where: 'Kadıköy, İstanbul',
            surfaceType: 'Sert zemin',
            photoUrls: ['https://example.com/court.jpg'],
            lat: 41,
            lng: 29))));
    await tester.pumpAndSettle();
    expect(find.text('Zemin: Sert zemin'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Haritada göster'), findsOneWidget);
    expect(find.byType(SwanActionGateBottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing venue metadata creates no invented facts',
      (tester) async {
    await tester
        .pumpWidget(host(const Scaffold(body: VenueOverview(where: ''))));
    expect(find.byType(Image), findsNothing);
    expect(find.text('Haritada göster'), findsNothing);
  });
}
