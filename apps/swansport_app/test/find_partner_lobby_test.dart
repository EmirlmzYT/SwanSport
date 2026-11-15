import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/location/place.dart';
import 'package:swansport_app/features/courts/presentation/find_partner_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class _CourtService extends Fake implements CourtService {
  int joinCalls = 0;
  int responseCalls = 0;
  int seekCalls = 0;
  bool? published;
  Completer<void>? joinCompleter;
  Object? responseError;

  @override
  Future<void> requestJoin(String slotId) {
    joinCalls++;
    return joinCompleter?.future ?? Future.value();
  }

  @override
  Future<void> respondPartnerPing({
    required String requestId,
    required bool accept,
  }) async {
    responseCalls++;
    if (responseError != null) throw responseError!;
  }

  @override
  Future<String> seekPartner({
    required String sportCode,
    double? lat,
    double? lng,
    bool isPublic = false,
  }) async {
    seekCalls++;
    published = isPublic;
    return 'request-1';
  }
}

void main() {
  testWidgets(
      'katılma isteği çift gönderilmez ve bekleyen durum açık gösterilir',
      (tester) async {
    final service = _CourtService()..joinCompleter = Completer<void>();
    await tester.pumpWidget(_host(service: service, slots: [_slot]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Katılma isteği gönder'));
    await tester.pump();
    await tester.tap(find.text('Gönderiliyor…'));
    await tester.pump();
    expect(service.joinCalls, 1);

    service.joinCompleter!.complete();
    await tester.pumpAndSettle();
    expect(find.text('İstek gönderildi'), findsOneWidget);
  });

  testWidgets('başarısız davet yanıtında davet görünür ve yeniden denenebilir',
      (tester) async {
    final service = _CourtService()
      ..responseError = Exception('message: Ağ bağlantısı kesildi');
    await tester.pumpWidget(_host(service: service, inbox: [_invite]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kabul et'));
    await tester.pumpAndSettle();

    expect(service.responseCalls, 1);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Ağ bağlantısı kesildi'), findsOneWidget);
    expect(find.text('Kabul et'), findsOneWidget);
  });

  testWidgets('eşleşen arama mevcut sohbet rotasına doğru kişiyi taşır',
      (tester) async {
    await tester.pumpWidget(_host(request: _matched));
    await tester.pumpAndSettle();
    expect(find.text('Partner bulundu'), findsOneWidget);

    await tester.tap(find.text('Sohbete geç'));
    await tester.pumpAndSettle();
    expect(find.text('CHAT actor-1 Ayşe Yılmaz'), findsOneWidget);
  });

  testWidgets('arama paneli branşı ve halka açık tercihini servise taşır',
      (tester) async {
    final service = _CourtService();
    await tester.pumpWidget(_host(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Partner ara').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Halka açık yayımla'));
    await tester.pump();
    await tester.ensureVisible(find.text('Aramayı başlat'));
    await tester.tap(find.text('Aramayı başlat'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(service.seekCalls, 1);
    expect(service.published, isTrue);
  });

  testWidgets('dar ekran ve büyük yazıda uzun saha adı taşma yapmaz',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        slots: [_slot],
        inbox: [_invite],
        textScaler: const TextScaler.linear(1.6),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Olağanüstü Uzun'), findsOneWidget);
  });
}

Widget _host({
  _CourtService? service,
  List<OpenSlot> slots = const [],
  List<IncomingPartnerPing> inbox = const [],
  MyPartnerRequest? request,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final actualService = service ?? _CourtService();
  return ProviderScope(
    overrides: [
      swanAccessProvider.overrideWithValue(_access),
      courtServiceProvider.overrideWithValue(actualService),
      courtSportCodesProvider.overrideWith(
        (_) async => const [CityRow(code: 'tennis', name: 'Tenis')],
      ),
      mySportInterestsProvider.overrideWith((_) async => {'tennis'}),
      myOpenPartnerRequestProvider.overrideWith((_) async => request),
      incomingPartnerPingsProvider.overrideWith((_) async => inbox),
      openSlotsProvider(null).overrideWith((_) async => slots),
      publicPartnerRequestsProvider.overrideWith((_) async => const []),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routes: {
        '/sohbet': (context) {
          final args = ModalRoute.of(context)!.settings.arguments!
              as Map<String, dynamic>;
          return Scaffold(body: Text('CHAT ${args['id']} ${args['name']}'));
        },
      },
      home: const FindPartnerScreen(placeResolver: _noPlace),
    ),
  );
}

Future<Place?> _noPlace() async => null;

const _access = SwanAccess(
  isPlatformAdmin: false,
  clubRole: null,
  coachLevel: 0,
  athleteKind: null,
  verificationTier: 'phone',
);

final _slot = OpenSlot(
  slotId: 'slot-1',
  courtId: 'court-1',
  courtName: 'Olağanüstü Uzun Merkez Kortu ve Spor Kompleksi Adı',
  startsAt: DateTime.now().add(const Duration(hours: 2)),
  ownerId: 'owner-1',
  ownerName: 'Mert Demir',
  needed: 2,
  accepted: 1,
  requested: false,
  venue: 'Swan Spor Tesisi',
  cityName: 'İstanbul',
);

final _invite = IncomingPartnerPing(
  requestId: 'request-1',
  sportCode: 'tennis',
  sportName: 'Tenis',
  requesterId: 'actor-1',
  requesterName: 'Ayşe Yılmaz',
  createdAt: DateTime.now(),
);

final _matched = MyPartnerRequest(
  id: 'mine-1',
  sportCode: 'tennis',
  sportName: 'Tenis',
  status: 'matched',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(hours: 4)),
  acceptedBy: 'actor-1',
  acceptedByName: 'Ayşe Yılmaz',
);
