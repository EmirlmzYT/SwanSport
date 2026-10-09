import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/financial_management/presentation/closed_period_reversal_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class MockFinanceOpsService extends Fake implements FinanceOpsService {
  String? lastSearch;
  String? lastTargetKind;
  int? lastLimit;
  int? lastOffset;

  @override
  Future<ClosedPeriodCandidatesPage> closedPeriodCandidates(
    String clubId, {
    String? targetKind,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    lastSearch = search;
    lastTargetKind = targetKind;
    lastLimit = limit;
    lastOffset = offset;

    // 120 adet test kaydı üret (100'den fazla kayıt testi)
    final all = List.generate(120, (i) {
      final kind = (i % 3 == 0)
          ? 'expense'
          : (i % 3 == 1)
              ? 'payment'
              : 'donation';
      return ClosedPeriodCandidateEntry(
        entryId: 'entry-$i',
        targetKind: kind,
        movedOn: DateTime(2026, 8, 1).add(Duration(days: i % 30)),
        amount: 100.0 + i * 10,
        label: 'İşlem Kaydı #$i',
        counterpart: 'Karşı Taraf #$i',
        accountName: 'Ana Kasa',
        alreadyReversed: 0,
        remainingAmount: 100.0 + i * 10,
      );
    });

    final filtered = all.where((e) {
      if (targetKind != null && e.targetKind != targetKind) return false;
      if (search != null && search.isNotEmpty) {
        if (!e.label.toLowerCase().contains(search.toLowerCase()) &&
            !e.counterpart.toLowerCase().contains(search.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    final paged = filtered.skip(offset).take(limit).toList();
    return ClosedPeriodCandidatesPage(
      entries: paged,
      totalCount: filtered.length,
    );
  }

  @override
  Future<List<FinanceAdjustment>> adjustments(String clubId) async {
    return [];
  }
}

void main() {
  late MockFinanceOpsService mockFinance;

  setUp(() {
    mockFinance = MockFinanceOpsService();
  });

  Widget buildTestWidget({required MockFinanceOpsService opsService}) {
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
        financeAdjustmentsProvider.overrideWith((ref) => Future.value([])),
        financeOpsServiceProvider.overrideWithValue(opsService),
      ],
      child: MaterialApp(
        theme: SwanTheme.light(),
        home: const ClosedPeriodReversalScreen(),
      ),
    );
  }

  testWidgets(
      'Mali hedef 100+ kayıt, sayfalama ve sunucu araması doğru çalışır',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(opsService: mockFinance));
    await tester.pumpAndSettle();

    // Yeni düzeltme modalını aç
    await tester.tap(find.text('Yeni Ters İşlem'));
    await tester.pumpAndSettle();

    // 1. Sayfa yüklendi: toplam 120 kayıt olmalı (50'şer sayfalama)
    expect(find.textContaining('Toplam 120 kayıt (Sayfa 1 / 3)'), findsOneWidget);

    // Dropdown'ı açarak ilk sayfa kaydını doğrula
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('İşlem Kaydı #0'), findsWidgets);

    // Dropdown'ı kapatmak için bir öğe seç
    await tester.tap(find.textContaining('İşlem Kaydı #0').last);
    await tester.pumpAndSettle();

    // 2. Sonraki sayfaya geçiş
    final nextBtn = find.byIcon(Icons.chevron_right);
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // 2. sayfaya geçildi
    expect(mockFinance.lastOffset, 50);
    expect(find.textContaining('Sayfa 2 / 3'), findsOneWidget);

    // 3. Sunucu araması: "İşlem Kaydı #8" yaz
    final searchInput = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText?.contains('Hedef kayıtlarda ara') == true,
    );
    await tester.enterText(searchInput, 'İşlem Kaydı #8');
    await tester.pumpAndSettle();

    expect(mockFinance.lastSearch, 'İşlem Kaydı #8');
    expect(mockFinance.lastOffset, 0); // arama değişince sayfa 1'e sıfırlanır
  });

  testWidgets(
      'Seçili giderden bağış filtresine geçişte seçim güvenle temizlenir ve assertion patlamaz',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget(opsService: mockFinance));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yeni Ters İşlem'));
    await tester.pumpAndSettle();

    // Giderler filtresine bas
    await tester.tap(find.text('Giderler'));
    await tester.pumpAndSettle();

    expect(mockFinance.lastTargetKind, 'expense');

    // Dropdown'dan bir gider seç
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // İlk gideri tıkla
    await tester.tap(find.textContaining('[Gider] İşlem Kaydı #0').last);
    await tester.pumpAndSettle();

    // Şimdi "Bağışlar" filtresine geç
    await tester.tap(find.text('Bağışlar'));
    await tester.pumpAndSettle();

    // Hiçbir exception fırlatılmamalı; hedef tür bağışa uygun sıfırlanmalı
    expect(mockFinance.lastTargetKind, 'donation');
    expect(tester.takeException(), isNull);
  });
}
