import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/facilities/presentation/facility_reservation_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class MockClubOpsService extends Fake implements ClubOpsService {
  Completer<List<FacilitySlot>>? nextConflictsCompleter;
  bool shouldThrow = false;
  String? lastCheckedFacilityId;

  @override
  Future<List<FacilitySlot>> conflicts({
    required String facilityId,
    required DateTime start,
    DateTime? end,
    String? excludeEventId,
  }) {
    lastCheckedFacilityId = facilityId;
    if (shouldThrow) {
      return Future.error(Exception('Ağ bağlantısı koptu'));
    }
    if (nextConflictsCompleter != null) {
      return nextConflictsCompleter!.future;
    }
    return Future.value([]);
  }

  @override
  Future<void> createEvent({
    required String clubId,
    required String title,
    required String kind,
    required DateTime startsAt,
    DateTime? endsAt,
    String? facilityId,
    String? place,
    String? teamId,
  }) async {}
}

void main() {
  late MockClubOpsService mockOps;

  setUp(() {
    mockOps = MockClubOpsService();
  });

  Widget buildTestWidget({required MockClubOpsService opsService}) {
    return ProviderScope(
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(true),
        activeClubProvider.overrideWith((ref) => Future.value(
              const ClubRef(
                id: 'club-100',
                name: 'Swan Spor Kulübü',
                role: 'manager',
              ),
            ),
        ),
        facilityLoadProvider.overrideWith((ref) => Future.value([
              const FacilityLoad(
                facilityId: 'fac-1',
                name: '1 Nolu Kapalı Kort',
                status: 'Müsait',
                eventCount: 2,
                busyMinutes: 120,
                loadPercent: 50,
                kind: 'Kort',
              ),
            ]),
        ),
        facilityScheduleProvider('fac-1').overrideWith(
          (ref) => Future.value([]),
        ),
        clubOpsServiceProvider.overrideWithValue(opsService),
      ],
      child: MaterialApp(
        theme: SwanTheme.light(),
        home: const FacilityReservationScreen(),
      ),
    );
  }

  testWidgets(
      'Çakışma kontrolü sürerken parametre değişince yüklenme durumu sıfırlanır ve kilit kalkar',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final req1 = Completer<List<FacilitySlot>>();
    mockOps.nextConflictsCompleter = req1;

    await tester.pumpWidget(buildTestWidget(opsService: mockOps));
    await tester.pumpAndSettle();

    expect(find.text('Tesis Rezervasyonu'), findsOneWidget);
    final checkBtn = find.text('Çakışma Kontrolü Yap');
    expect(checkBtn, findsOneWidget);

    // 1. İlk kontrolü başlat (istek havada bekliyor)
    await tester.tap(checkBtn);
    await tester.pump();

    // Butonun içinde CircularProgressIndicator olmalı
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 2. İstek sürerken kullanıcı süreyi değiştirir (örn: 90 dk seçer)
    final chip90 = find.text('90 dk');
    expect(chip90, findsOneWidget);
    await tester.tap(chip90);
    await tester.pump();

    // _invalidateConflictCheck _isChecking'i false yapmalı ve butonu hemen yeniden etkinleştirmeli!
    expect(find.text('Çakışma Kontrolü Yap'), findsOneWidget);

    // 3. İlk isteğin yanıtı gecikmeli olarak döner (stale response)
    req1.complete([
      FacilitySlot(
        id: 'slot-old',
        title: 'Eski Çakışan Maç',
        kind: 'match',
        startsAt: DateTime.now(),
        endsAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    ]);
    await tester.pump();

    // Eski yanıt atıldığı için çakışma kartı görünmemeli
    expect(find.text('Eski Çakışan Maç'), findsNothing);

    // 4. Yeni parametrelerle ikinci kontrol başlatılır
    mockOps.nextConflictsCompleter = null; // anında boş döner (çakışma yok)
    await tester.tap(find.text('Çakışma Kontrolü Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Saha müsait'), findsOneWidget);
  });

  testWidgets(
      'Çakışma bulunduğunda uyarı kartı gösterilir ancak rezervasyon butonu engellenmez (ürün kuralı)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final conflictSlot = FacilitySlot(
      id: 'slot-c1',
      title: 'Yıldız Takım Antrenmanı',
      kind: 'training',
      startsAt: DateTime(2026, 10, 7, 18, 0),
      endsAt: DateTime(2026, 10, 7, 19, 30),
    );

    mockOps.nextConflictsCompleter =
        Completer<List<FacilitySlot>>()..complete([conflictSlot]);

    await tester.pumpWidget(buildTestWidget(opsService: mockOps));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Çakışma Kontrolü Yap'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 çakışma var!'), findsOneWidget);
    expect(find.textContaining('Yıldız Takım Antrenmanı'), findsOneWidget);

    // Rezervasyonu Onayla butonu hâlâ mevcut olmalı (bilerek çakışan grup çalışması yapılabilir)
    expect(find.text('Rezervasyonu Onayla ve Ayırt'), findsOneWidget);
  });

  testWidgets('Ağ hatası durumunda hata mesajı ve tekrar dene butonu çalışır',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    mockOps.shouldThrow = true;

    await tester.pumpWidget(buildTestWidget(opsService: mockOps));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Çakışma Kontrolü Yap'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Çakışma kontrolü başarısız oldu'), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);

    // Hatayı kaldırıp Tekrar Dene'ye bas
    mockOps.shouldThrow = false;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(find.text('Saha müsait'), findsOneWidget);
  });
}
