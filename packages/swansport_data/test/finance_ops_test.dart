import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Mali operasyon merkezi — veri katmanı.
///
/// Buradaki en önemli test **sütun adı sözleşmesi**. İlk taslakta SQL sekiz
/// sütun döndürüyordu, Dart modeli on alan okuyordu ve `??` yedekleri farkı
/// gizliyordu: ekran çalışıyor görünüyor, yarısı sessizce sıfır gösteriyordu.
/// Adlar ayrışırsa bu test düşer.
void main() {
  group('FinanceOperationsSummary — SQL sözleşmesi', () {
    /// `acc_operations_summary` (0061) tam olarak bu yirmi sütunu döndürüyor.
    /// Her birine ayrı bir değer veriliyor ki bir alan yanlış sütundan
    /// okunursa test yakalasın.
    final rpcRow = <String, dynamic>{
      'draft_expense_count': 1,
      'draft_expense_total': 101,
      'pending_payment_count': 2,
      'pending_payment_total': 102,
      'overdue_invoice_count': 3,
      'overdue_invoice_total': 103,
      'unlinked_income_count': 4,
      'unlinked_income_total': 104,
      'unlinked_expense_count': 5,
      'unlinked_expense_total': 105,
      'negative_account_count': 6,
      'negative_account_total': -106,
      'missing_receipt_count': 7,
      'commitment_due_count': 8,
      'commitment_due_total': 108,
      'pending_approval_count': 9,
      'pending_approval_total': 109,
      'bank_unmatched_count': 10,
      'bank_unmatched_total': 110,
      'close_blocker_count': 11,
    };

    test('yirmi sütunun hepsi doğru alana düşüyor', () {
      final s = FinanceOperationsSummary.fromMap(rpcRow);

      expect(s.draftExpenseCount, 1);
      expect(s.draftExpenseTotal, 101);
      expect(s.pendingPaymentCount, 2);
      expect(s.pendingPaymentTotal, 102);
      expect(s.overdueInvoiceCount, 3);
      expect(s.overdueInvoiceTotal, 103);
      expect(s.unlinkedIncomeCount, 4);
      expect(s.unlinkedIncomeTotal, 104);
      expect(s.unlinkedExpenseCount, 5);
      expect(s.unlinkedExpenseTotal, 105);
      expect(s.negativeAccountCount, 6);
      expect(s.negativeAccountTotal, -106);
      expect(s.missingReceiptCount, 7);
      expect(s.commitmentDueCount, 8);
      expect(s.commitmentDueTotal, 108);
      expect(s.pendingApprovalCount, 9);
      expect(s.pendingApprovalTotal, 109);
      expect(s.bankUnmatchedCount, 10);
      expect(s.bankUnmatchedTotal, 110);
      expect(s.closeBlockerCount, 11);
    });

    test('eski taslağın sütun adları artık okunmuyor', () {
      // 0055 taslağı bu adları döndürüyordu. Yedek bırakılsaydı iki sözleşme
      // bir arada yaşar ve hangisinin doğru olduğu belirsizleşirdi.
      final legacy = FinanceOperationsSummary.fromMap({
        'draft_expenses_count': 3,
        'pending_payment_notifs_count': 2,
        'unlinked_transactions_count': 5,
        'negative_accounts_count': 1,
        'overdue_fees_count': 8,
      });

      expect(legacy.draftExpenseCount, 0);
      expect(legacy.pendingPaymentCount, 0);
      expect(legacy.overdueInvoiceCount, 0);
      expect(legacy.hasWork, isFalse);
    });

    test('bilinmeyen sütun çökmeye yol açmıyor', () {
      final s = FinanceOperationsSummary.fromMap(
          {'draft_expense_count': 2, 'gelecekte_eklenen_sutun': 'x'});
      expect(s.draftExpenseCount, 2);
    });
  });

  group('İş kalemleri', () {
    test('adedi sıfır olan kalem hiç üretilmiyor', () {
      const s = FinanceOperationsSummary(draftExpenseCount: 2);
      expect(s.items.length, 1);
      expect(s.items.single.code, 'draft_expense');
      expect(s.items.single.count, 2);
    });

    test('boş özette iş yok ve başarı kartı üretilmiyor', () {
      const s = FinanceOperationsSummary.empty();
      expect(s.hasWork, isFalse);
      expect(s.items, isEmpty);
      expect(s.topItems, isEmpty);
      expect(s.otherItems, isEmpty);
      expect(s.totalCount, 0);
    });

    test('kritik olanlar önce geliyor', () {
      const s = FinanceOperationsSummary(
        draftExpenseCount: 5, // dikkat
        negativeAccountCount: 1, // kritik
        missingReceiptCount: 9, // bilgi
      );

      expect(s.items.first.risk, FinanceRisk.critical);
      expect(s.items.last.risk, FinanceRisk.info);
    });

    test('en fazla beş kalem öne çıkıyor, gerisi ayrı listede', () {
      const s = FinanceOperationsSummary(
        closeBlockerCount: 1,
        negativeAccountCount: 1,
        pendingApprovalCount: 1,
        overdueInvoiceCount: 1,
        pendingPaymentCount: 1,
        draftExpenseCount: 1,
        commitmentDueCount: 1,
      );

      expect(s.items.length, 7);
      expect(s.topItems.length, 5);
      expect(s.otherItems.length, 2);
      // İkisi birlikte tam listeyi vermeli; kalem kaybolmamalı.
      expect(s.topItems.length + s.otherItems.length, s.items.length);
    });

    test('her kalemin rotası ve gerekçesi var', () {
      const s = FinanceOperationsSummary(
        draftExpenseCount: 1,
        bankUnmatchedCount: 1,
        overdueInvoiceCount: 1,
      );
      for (final item in s.items) {
        expect(item.route, startsWith('/'));
        expect(item.why, isNotEmpty);
        expect(item.title, isNotEmpty);
      }
    });

    test('parasal karşılığı olmayan kalem tutar göstermiyor', () {
      const s = FinanceOperationsSummary(missingReceiptCount: 4);
      expect(s.items.single.hasTotal, isFalse);
    });

    test('rozet sayısı bütün kalemlerin toplamı', () {
      const s = FinanceOperationsSummary(
          draftExpenseCount: 3, overdueInvoiceCount: 4);
      expect(s.totalCount, 7);
    });
  });

  group('Tedarikçi gizliliği', () {
    test('Vendor vergi ve IBAN taşımıyor', () {
      final v = Vendor.fromMap({
        'id': 'v1',
        'club_id': 'c1',
        'name': 'Spor Ekipman Ltd',
        'contact_note': 'Ahmet Bey',
        'active': true,
        // Sunucu bunları bu tablodan hiç döndürmüyor; yanlışlıkla gelse
        // bile modele girmemeli.
        'tax_id': '1234567890',
        'iban': 'TR330006100519786457841326',
      });

      expect(v.name, 'Spor Ekipman Ltd');
      expect(v.contactNote, 'Ahmet Bey');
      expect(v.active, isTrue);
    });

    test('VendorPrivate ayrı tip — yalnızca yönetici sorgusundan gelir', () {
      final p = VendorPrivate.fromMap({
        'vendor_id': 'v1',
        'tax_office': 'Selçuk',
        'tax_id': '1234567890',
        'iban': 'TR33...',
      });
      expect(p.taxId, '1234567890');
      expect(p.taxOffice, 'Selçuk');
    });
  });

  group('Denetim izi', () {
    test('yalnızca değişen alanlar taşınıyor', () {
      final e = ExpenseAuditEntry.fromMap({
        'log_id': 'l1',
        'action': 'update',
        'actor': 'Emir',
        'reason': 'kategori düzeltildi',
        'changed_at': '2026-09-02T10:00:00Z',
        'changed': {'category_id': 'c9'},
      });

      expect(e.changed.keys, ['category_id']);
      expect(e.actionLabel, 'Düzenlendi');
      expect(e.actor, 'Emir');
    });

    test('bilinmeyen eylem ham hâliyle gösteriliyor', () {
      final e = ExpenseAuditEntry.fromMap(
          {'log_id': 'l', 'action': 'yeni_eylem', 'changed_at': ''});
      expect(e.actionLabel, 'yeni_eylem');
    });
  });

  group('Taahhüt vadesi', () {
    final now = DateTime(2026, 9, 2);

    test('vadeye kalan gün saat farkından etkilenmiyor', () {
      final o = RecurringOccurrence.fromMap({
        'id': 'o1',
        'recurring_id': 'r1',
        'due_on': '2026-09-09',
        'amount': 12000,
        'status': 'pending',
      });
      expect(o.daysLeft(DateTime(2026, 9, 2, 23, 59)), 7);
      expect(o.daysLeft(DateTime(2026, 9, 2, 0, 1)), 7);
    });

    test('vadesi bugün olan gecikmiş sayılmıyor', () {
      final o = RecurringOccurrence.fromMap({
        'id': 'o',
        'recurring_id': 'r',
        'due_on': '2026-09-02',
        'amount': 1,
        'status': 'pending',
      });
      expect(o.daysLeft(now), 0);
      expect(o.isOverdue(now), isFalse);
    });

    test('kaydedilmiş vade gecikmiş sayılmıyor', () {
      final o = RecurringOccurrence.fromMap({
        'id': 'o',
        'recurring_id': 'r',
        'due_on': '2026-08-01',
        'amount': 1,
        'status': 'recorded',
      });
      expect(o.isOverdue(now), isFalse);
    });
  });

  group('Nakit tahmini', () {
    test('belirsiz tutar hiçbir projeksiyona girmiyor', () {
      final f = CashForecast.fromMap({
        'horizon_days': 30,
        'opening': 1000,
        'confirmed_in': 200,
        'confirmed_out': 100,
        'expected_in': 500,
        'expected_out': 300,
        'uncertain_out': 9999,
        'projected_low': 1100,
        'projected_high': 1300,
      });

      // low = opening + confirmed_in - confirmed_out
      expect(f.projectedLow, 1100);
      // high = low + expected_in - expected_out
      expect(f.projectedHigh, 1300);
      // Belirsiz ayrı duruyor; iki projeksiyonun hiçbirinde yok.
      expect(f.uncertainOut, 9999);
      expect(f.hasShortfall, isFalse);
    });

    test('kötümser uçta açık varsa uyarı veriyor', () {
      final f = CashForecast.fromMap({
        'horizon_days': 90,
        'projected_low': -500,
        'projected_high': 2000,
      });
      expect(f.hasShortfall, isTrue);
    });
  });

  group('Kapanış kontrol listesi', () {
    test('engelleyen madde yalnızca adet sıfırdan büyükken engel', () {
      final clean = CloseCheckItem.fromMap({
        'code': 'draft_expense',
        'label': 'Açık taslak gider',
        'blocking': true,
        'qty': 0,
        'amount': 0,
      });
      final dirty = CloseCheckItem.fromMap({
        'code': 'draft_expense',
        'label': 'Açık taslak gider',
        'blocking': true,
        'qty': 2,
        'amount': 500,
      });
      final info = CloseCheckItem.fromMap({
        'code': 'overdue_fee',
        'label': 'Gecikmiş tahsilat',
        'blocking': false,
        'qty': 9,
        'amount': 9000,
      });

      expect(clean.isBlocker, isFalse);
      expect(dirty.isBlocker, isTrue);
      // Bilgi amaçlı madde adedi yüksek olsa da kapanışı durdurmuyor.
      expect(info.isBlocker, isFalse);
    });
  });

  group('Mali dönem', () {
    test('durum etiketleri Türkçe', () {
      FinancePeriod p(String s) => FinancePeriod.fromMap({
            'id': 'p',
            'club_id': 'c',
            'period_from': '2026-09-01',
            'period_to': '2026-09-30',
            'status': s,
          });

      expect(p('open').statusLabel, 'Açık');
      expect(p('closed').statusLabel, 'Kapandı');
      expect(p('needs_correction').statusLabel, 'Düzeltme gerekli');
      expect(p('closed').isClosed, isTrue);
      expect(p('open').isClosed, isFalse);
    });
  });

  group('Kulüp operasyon özeti', () {
    test('sıfır olan kalem üretilmiyor', () {
      const s = ClubOperationsSummary(pendingMembershipCount: 2);
      expect(s.items.length, 1);
      expect(s.items.single.code, 'pending_membership');
      expect(s.hasWork, isTrue);
    });

    test('boş özet iş göstermiyor', () {
      const s = ClubOperationsSummary.empty();
      expect(s.hasWork, isFalse);
      expect(s.items, isEmpty);
    });

    test('şikayet en kritik kalem', () {
      const s = ClubOperationsSummary(
          openReportCount: 1, lowRsvpEventCount: 3);
      final report =
          s.items.firstWhere((i) => i.code == 'open_report');
      expect(report.risk, FinanceRisk.critical);
    });
  });

  group('Banka hareketi', () {
    test('yön ve eşleşme durumu okunuyor', () {
      final t = BankTransaction.fromMap({
        'txn_id': 't1',
        'txn_on': '2026-09-01',
        'amount': 1500,
        'direction': 'in',
        'match_status': 'unmatched',
        'description': 'EFT - •••••••',
      });

      expect(t.isIncoming, isTrue);
      expect(t.isMatched, isFalse);
      // Açıklama sunucuda maskelenmiş geliyor; istemci ham metni hiç görmüyor.
      expect(t.description, isNot(contains('TR33')));
    });

    test('eşleşme önerisi gün farkını taşıyor', () {
      final s = BankMatchSuggestion.fromMap({
        'kind': 'payment',
        'entry_id': 'p1',
        'entry_on': '2026-09-02',
        'amount': 1500,
        'label': '#A3F91C',
        'day_gap': 1,
      });
      expect(s.dayGap, 1);
      // Muhasebeci sporcu adı değil kısaltma görüyor.
      expect(s.label, startsWith('#'));
    });
  });

  group('Bütçe satırı', () {
    test('aşım kalan negatifken', () {
      final line = BudgetLine.fromMap({
        'budget_id': 'b1',
        'scope': 'team',
        'scope_label': 'U-16 Erkek',
        'category': 'Malzeme',
        'period_from': '2026-09-01',
        'period_to': '2026-09-30',
        'planned': 10000,
        'actual': 9000,
        'committed': 3000,
        'remaining': -2000,
        'overrun_pct': 120.0,
        'risk': 'kritik',
      });

      expect(line.isOverrun, isTrue);
      expect(line.risk, 'kritik');
      expect(line.scopeLabel, 'U-16 Erkek');
    });
  });
}
