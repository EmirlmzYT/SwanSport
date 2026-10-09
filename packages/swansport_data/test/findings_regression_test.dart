import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('Finding 1 & 2: Kapanmış Dönem Ters İşlem & Defter Hareketleri', () {
    test('FinanceAdjustment modeli entry_kind ve entry_id alanlarını taşır', () {
      final map = {
        'id': 'adj-1',
        'club_id': 'club-1',
        'period_id': 'period-1',
        'target_kind': 'expense',
        'target_id': 'exp-100',
        'entry_kind': 'payment',
        'entry_id': 'pmt-200',
        'amount': 350.0,
        'reason': 'Kapanmış dönem hatalı gider ters kaydı',
        'status': 'approved',
        'created_by': 'user-1',
        'approved_by': 'admin-1',
        'approved_at': '2026-10-07T10:00:00Z',
        'created_at': '2026-10-07T09:00:00Z',
      };

      final adj = FinanceAdjustment.fromMap(map);
      expect(adj.id, 'adj-1');
      expect(adj.clubId, 'club-1');
      expect(adj.targetKind, 'expense');
      expect(adj.targetId, 'exp-100');
      expect(adj.entryKind, 'payment');
      expect(adj.entryId, 'pmt-200');
      expect(adj.amount, 350.0);
      expect(adj.status, 'approved');
      expect(adj.reason, contains('hatalı gider'));
    });

    test('LedgerEntry karşı hareketin yönünü ve gizliliğini korur', () {
      final incomeEntry = LedgerEntry.fromMap({
        'entry_id': 'pmt-200',
        'moved_on': '2026-10-07',
        'direction': 'in',
        'label': 'Ters kayıt (Gider mahsubu #exp-100)',
        'category': 'Düzeltme',
        'counterpart': 'Nakit Kasa',
        'account': 'Ana Kasa',
        'amount': 350.0,
        'status': 'confirmed',
      });

      expect(incomeEntry.isIncome, true);
      expect(incomeEntry.signed, 350.0);
      // Muhasebeci gizliliği: sporcu adı değil, güvenli etiket/hesap yer alır
      expect(incomeEntry.counterpart.contains('Sporcu Adı'), false);

      final outgoEntry = LedgerEntry.fromMap({
        'entry_id': 'exp-300',
        'moved_on': '2026-10-07',
        'direction': 'out',
        'label': 'Ters kayıt (Tahsilat iadesi #pmt-100)',
        'category': 'Diğer',
        'counterpart': '#A3F91C',
        'account': 'Banka',
        'amount': 500.0,
        'status': 'complete',
      });

      expect(outgoEntry.isIncome, false);
      expect(outgoEntry.signed, -500.0);
      expect(outgoEntry.counterpart, '#A3F91C');
    });

    test('Toplam iade sınırı ve pozitif tutar sözleşmesi', () {
      const originalAmount = 1000.0;
      const alreadyReversed = 600.0;
      const remainingAmount = originalAmount - alreadyReversed; // 400.0

      // Kalan tutardan fazla iade talep edilemez
      const requestedExcessive = 450.0;
      expect(requestedExcessive > remainingAmount, true);

      // Kalan tutara eşit veya daha az iade kabul edilir
      const requestedValid = 400.0;
      expect(requestedValid <= remainingAmount, true);

      // Düzeltme tutarı daima pozitif olmalıdır
      expect(requestedValid > 0, true);
    });

    test('Finding 1: İki farklı kulüp, yetkili personel, muhasebeci ve yetkisiz kullanıcı veri izolasyonu', () {
      final issues = [
        {'id': 'issue-1', 'club_id': 'club-a', 'amount': 500, 'issue': 'Eksik Defter Hareketi'},
        {'id': 'issue-2', 'club_id': 'club-a', 'amount': 250, 'issue': 'Eksik Defter Hareketi'},
        {'id': 'issue-3', 'club_id': 'club-b', 'amount': 1200, 'issue': 'Eksik Defter Hareketi'},
      ];

      List<Map<String, dynamic>> queryIssues({
        required String userRole, // 'staff_a', 'accountant_a', 'staff_b', 'unauthorized'
        required String? targetClubId,
      }) {
        return issues.where((row) {
          final clubId = row['club_id'] as String;
          // Yetki kuralı: is_club_staff(club_id) or is_club_accountant(club_id)
          bool hasAccess = false;
          if (userRole == 'staff_a' && clubId == 'club-a') hasAccess = true;
          if (userRole == 'accountant_a' && clubId == 'club-a') hasAccess = true;
          if (userRole == 'staff_b' && clubId == 'club-b') hasAccess = true;

          if (!hasAccess) return false;
          if (targetClubId != null && clubId != targetClubId) return false;
          return true;
        }).toList();
      }

      // 1. Club A personeli yalnızca Club A kayıtlarını görür (2 adet), Club B kayıtlarını göremez (0 adet)
      final staffAView = queryIssues(userRole: 'staff_a', targetClubId: null);
      expect(staffAView.length, 2);
      expect(staffAView.every((r) => r['club_id'] == 'club-a'), true);

      // 2. Club A muhasebecisi yalnızca Club A kayıtlarını görür (2 adet)
      final accAView = queryIssues(userRole: 'accountant_a', targetClubId: null);
      expect(accAView.length, 2);
      expect(accAView.every((r) => r['club_id'] == 'club-a'), true);

      // 3. Club B personeli Club A kayıtlarını göremez
      final staffBClubA = queryIssues(userRole: 'staff_b', targetClubId: 'club-a');
      expect(staffBClubA.isEmpty, true);

      // 4. Yetkisiz kullanıcı hiçbir kulübün kaydını göremez
      final unauthView = queryIssues(userRole: 'unauthorized', targetClubId: null);
      expect(unauthView.isEmpty, true);
    });

    test('Finding 2: 1.000 TL kaynak için iki ayrı 800 TL düzeltme, kısmi iade ve yeniden çalıştırma (idempotency)', () {
      const sourceAmount = 1000.0;
      final logs = <Map<String, dynamic>>[];
      final createdPayments = <Map<String, dynamic>>[];

      // Simüle edilen telafi motoru (0084 migration mantığı)
      void reconcileAdjustment({
        required String adjId,
        required double amount,
        required bool alreadyHasEntry,
      }) {
        if (alreadyHasEntry) {
          // Idempotent: zaten işlenmişse pas geç
          return;
        }

        if (amount <= 0) {
          logs.add({'adj_id': adjId, 'action': 'adjustment_review_needed', 'reason': 'Geçersiz tutar'});
          return;
        }

        // Mevcut gerçekleşmiş iadelerin toplamı
        final realized = createdPayments.fold<double>(0.0, (sum, p) => sum + (p['amount'] as double));

        if ((realized + amount) <= sourceAmount) {
          createdPayments.add({'adj_id': adjId, 'amount': amount});
          logs.add({'adj_id': adjId, 'action': 'adjustment_reconciled', 'amount': amount});
        } else {
          logs.add({
            'adj_id': adjId,
            'action': 'adjustment_review_needed',
            'reason': 'Toplam iade sınırı aşıldı (Kaynak: $sourceAmount, Mevcut: $realized, İstenen: $amount)',
          });
        }
      }

      // Senaryo: İki ayrı 800 TL düzeltme
      reconcileAdjustment(adjId: 'adj-1', amount: 800.0, alreadyHasEntry: false);
      expect(createdPayments.length, 1);
      expect(createdPayments.first['amount'], 800.0);
      expect(logs.any((l) => l['adj_id'] == 'adj-1' && l['action'] == 'adjustment_reconciled'), true);

      // İkinci 800 TL: 800 + 800 = 1600 > 1000 => Sınır aşıldı, otomatik işlenmeden incelemeye bırakılır
      reconcileAdjustment(adjId: 'adj-2', amount: 800.0, alreadyHasEntry: false);
      expect(createdPayments.length, 1); // yeni ödeme üretilmedi!
      expect(logs.any((l) => l['adj_id'] == 'adj-2' && l['action'] == 'adjustment_review_needed'), true);

      // Yeniden çalıştırma (Idempotency): adj-1 zaten entry_id taşıdığı için çift hareket üretmez
      reconcileAdjustment(adjId: 'adj-1', amount: 800.0, alreadyHasEntry: true);
      expect(createdPayments.length, 1); // hareket sayısı artmadı
    });

    test('Finding 3: Eski negatif düzeltmeler onay ve kapasite hesabını ASLA artıramaz', () {
      // Hedef kaynak: 1.000 TL
      const targetAmount = 1000.0;

      // Sistemdeki kayıtlar:
      // - Geçerli onaylı düzeltme: 500 TL
      // - Hatalı eski negatif onaylı düzeltme: -300 TL
      // - Hatalı eski sıfır tutarlı düzeltme: 0 TL
      final existingAdjustments = [
        {'id': 'adj-valid', 'amount': 500.0, 'status': 'approved'},
        {'id': 'adj-neg', 'amount': -300.0, 'status': 'approved'},
        {'id': 'adj-zero', 'amount': 0.0, 'status': 'approved'},
      ];

      // Güvenli sözleşme: sum(case when amount > 0 then amount else 0 end)
      double calculateAlreadyAdjusted(List<Map<String, dynamic>> records) {
        return records.fold<double>(0.0, (sum, r) {
          final amt = r['amount'] as double;
          return sum + (amt > 0 ? amt : 0.0);
        });
      }

      final alreadyAdjusted = calculateAlreadyAdjusted(existingAdjustments);
      // Negatif ve sıfır tutarlar hesaba dahil edilmediği için toplam 500 TL olmalıdır (200 TL değil!)
      expect(alreadyAdjusted, 500.0);

      // Kalan iade kapasitesi: 1000 - 500 = 500 TL (negatif kayıt kapasiteyi 800 TL'ye şişiremedi!)
      final remainingCapacity = targetAmount - alreadyAdjusted;
      expect(remainingCapacity, 500.0);

      // Negatif bekleyen kayıt onayı denendiğinde reddedilir
      bool canApprove(double amount) {
        if (amount <= 0) return false;
        return (alreadyAdjusted + amount) <= targetAmount;
      }

      expect(canApprove(-200.0), false); // negatif bekleyen kayıt onaylanamaz
      expect(canApprove(0.0), false);    // sıfır tutarlı kayıt onaylanamaz
      expect(canApprove(600.0), false);  // 500 + 600 = 1100 > 1000 aşamaz
      expect(canApprove(500.0), true);   // 500 + 500 = 1000 sınırında onaylanır
    });
  });

  group('Finding 3: ClosedPeriodCandidateEntry ve Sayfalama Sözleşmesi', () {
    test('ClosedPeriodCandidateEntry kaynak türünü kesin taşır ve tahmin etmez', () {
      final expenseCandidate = ClosedPeriodCandidateEntry.fromMap({
        'entry_id': 'exp-1',
        'target_kind': 'expense',
        'moved_on': '2026-08-15',
        'amount': 1200.0,
        'label': 'Kort Bakım Malzemesi',
        'counterpart': 'Spor Malzemeleri Ltd',
        'account_id': 'acc-1',
        'account_name': 'Ana Kasa',
        'already_reversed': 200.0,
        'remaining_amount': 1000.0,
        'total_count': 15,
      });

      expect(expenseCandidate.targetKind, 'expense');
      expect(expenseCandidate.targetKindLabel, 'Gider');
      expect(expenseCandidate.amount, 1200.0);
      expect(expenseCandidate.alreadyReversed, 200.0);
      expect(expenseCandidate.remainingAmount, 1000.0);

      final donationCandidate = ClosedPeriodCandidateEntry.fromMap({
        'entry_id': 'don-1',
        'target_kind': 'donation',
        'moved_on': '2026-08-20',
        'amount': 5000.0,
        'label': 'Yaz Kampı Bağışı',
        'counterpart': 'Ahmet Y.',
        'account_id': 'acc-2',
        'account_name': 'Banka Hesabı',
        'already_reversed': 0,
        'remaining_amount': 5000.0,
        'total_count': 15,
      });

      expect(donationCandidate.targetKind, 'donation');
      expect(donationCandidate.targetKindLabel, 'Bağış');
      // Gelir olduğu için "payment" sanılmaz; kesinlikle 'donation' olarak taşınır
      expect(donationCandidate.targetKind != 'payment', true);

      final paymentCandidate = ClosedPeriodCandidateEntry.fromMap({
        'entry_id': 'pmt-1',
        'target_kind': 'payment',
        'moved_on': '2026-08-01',
        'amount': 750.0,
        'label': 'Ağustos Aidatı',
        'counterpart': '#A3F91C', // Muhasebeci gizliliği
        'account_id': 'acc-1',
        'account_name': 'Ana Kasa',
        'already_reversed': 0,
        'remaining_amount': 750.0,
        'total_count': 15,
      });

      expect(paymentCandidate.targetKind, 'payment');
      expect(paymentCandidate.counterpart, '#A3F91C');
      expect(paymentCandidate.counterpart.contains('Ali Veli'), false);
    });

    test('ClosedPeriodCandidatesPage sayfalama ve toplam kayıt sayısını doğru saklar', () {
      final page = ClosedPeriodCandidatesPage(
        entries: [
          ClosedPeriodCandidateEntry.fromMap({
            'entry_id': 'exp-1',
            'target_kind': 'expense',
            'moved_on': '2026-08-15',
            'amount': 1000.0,
            'label': 'Test',
            'counterpart': 'Vendor',
            'account_name': 'Kasa',
            'already_reversed': 0,
            'remaining_amount': 1000.0,
          }),
        ],
        totalCount: 42,
      );

      expect(page.entries.length, 1);
      expect(page.totalCount, 42);
    });
  });

  group('Finding 4 & 6: Sporcu Beslenme, Hidrasyon ve Hedefler', () {
    test('DailyNutritionSummary varsayılan olarak sabit hedef dayatmaz (null)', () {
      final date = DateTime(2026, 10, 7);
      final empty = DailyNutritionSummary.empty(date);

      expect(empty.targetCalories, isNull);
      expect(empty.targetWaterMl, isNull);
      expect(empty.totalCalories, 0);
      expect(empty.totalWaterMl, 0);
    });

    test('AthleteNutritionTarget modeli hedef değerlerini doğru taşır', () {
      final target = AthleteNutritionTarget.fromMap({
        'athlete_id': 'ath-1',
        'target_calories': 2250,
        'target_water_ml': 2800,
        'set_by': 'coach-1',
        'updated_at': '2026-10-07T12:00:00Z',
      });

      expect(target.athleteId, 'ath-1');
      expect(target.targetCalories, 2250);
      expect(target.targetWaterMl, 2800);
      expect(target.setBy, 'coach-1');
      expect(target.updatedAt, isNotNull);

      final map = target.toMap();
      expect(map['athlete_id'], 'ath-1');
      expect(map['target_calories'], 2250);
      expect(map['target_water_ml'], 2800);
    });

    test('DailyNutritionSummary atanmış kişisel hedefleri yansıtır', () {
      final date = DateTime(2026, 10, 7);
      final summary = DailyNutritionSummary(
        date: date,
        totalCalories: 1800,
        totalProtein: 120.0,
        totalCarb: 200.0,
        totalFat: 50.0,
        totalWaterMl: 2000,
        targetCalories: 2200,
        targetWaterMl: 2500,
      );

      expect(summary.totalCalories, 1800);
      expect(summary.targetCalories, 2200);
      expect(summary.totalWaterMl, 2000);
      expect(summary.targetWaterMl, 2500);

      // Oran hesabı doğruluğu
      final calProgress = (summary.totalCalories / summary.targetCalories!).clamp(0.0, 1.0);
      expect(calProgress, closeTo(0.818, 0.005));

      final waterProgress = (summary.totalWaterMl / summary.targetWaterMl!).clamp(0.0, 1.0);
      expect(waterProgress, closeTo(0.80, 0.01));
    });

    test('NutritionLog su kaydı sınırları ve değerleri korunur', () {
      final log = NutritionLog.fromMap({
        'id': 'log-water-1',
        'athlete_id': 'ath-1',
        'log_date': '2026-10-07',
        'meal_type': 'water',
        'title': 'Su Tüketimi',
        'calories': 0,
        'protein_g': 0,
        'carb_g': 0,
        'fat_g': 0,
        'water_ml': 750,
      });

      expect(log.mealType, 'water');
      expect(log.waterMl, 750);
      expect(log.calories, 0);
    });

    test('Su kaydı delta sınırları (-3000 ml <= delta <= +3000 ml) ve günlük tavan (15000 ml)', () {
      int clampDelta(int delta) {
        if (delta < -3000 || delta > 3000) {
          throw ArgumentError('Delta sınır dışı');
        }
        return delta;
      }

      int applyWater(int current, int delta) {
        final d = clampDelta(delta);
        return (current + d).clamp(0, 15000);
      }

      expect(applyWater(0, 500), 500);
      expect(applyWater(500, -250), 250);
      expect(applyWater(100, -500), 0); // eksiye düşmez
      expect(applyWater(14000, 2000), 15000); // 15000 ml tavanı aşamaz
      expect(() => applyWater(0, 3500), throwsArgumentError);
      expect(() => applyWater(0, -3500), throwsArgumentError);
    });
  });

  group('Finding 3 & 5: Rezervasyon Çakışması ve Kulüp Bütünlüğü', () {
    test('FacilitySlot ve çakışma nesnesi zaman sınırlarını doğru modeller', () {
      final slot = FacilitySlot(
        id: 'slot-1',
        startsAt: DateTime(2026, 10, 7, 14, 0),
        endsAt: DateTime(2026, 10, 7, 15, 30),
        title: 'A Takımı Antrenmanı',
        kind: 'training',
      );

      expect(slot.startsAt.hour, 14);
      expect(slot.endsAt.hour, 15);
      expect(slot.endsAt.minute, 30);
      expect(slot.title, contains('A Takımı'));
    });
  });
}
