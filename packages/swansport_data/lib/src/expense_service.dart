import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_athletes.dart';
import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Gider defteri ve mali raporlama.
///
/// Kulübün para **çıkışı** burada; girişi `finance_service.dart`'ta. İkisini
/// birleştiren okuma `ledger()` — o da veritabanındaki `acc_ledger` RPC'sinden
/// geliyor.
///
/// Muhasebeci bu servisi kullanırken sporcu adı görmez: okuma RPC'leri adı hiç
/// seçmiyor, yerine kimlikten türetilmiş sabit bir takma gösterim dönüyor
/// (`#A3F91C`). Bu bir arayüz kararı değil, veritabanı kararı — muhasebeciye
/// `athletes` tablosuna RLS erişimi verilmedi.
/// ---------------------------------------------------------------------------

/// Kasa, banka ya da POS hesabı.
class CashAccount {
  const CashAccount({
    required this.id,
    required this.name,
    required this.kind,
    this.active = true,
  });

  final String id;
  final String name;

  /// cash | bank | pos
  final String kind;
  final bool active;

  String get kindLabel => switch (kind) {
        'cash' => 'Nakit kasa',
        'pos' => 'POS',
        _ => 'Banka',
      };

  factory CashAccount.fromMap(Map<String, dynamic> m) => CashAccount(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'bank',
        active: (m['active'] as bool?) ?? true,
      );
}

/// Hesabın hareketlerden hesaplanmış durumu.
///
/// Bakiye veritabanında saklanmıyor; saklansaydı iptal edilen bir ödeme ya da
/// düzeltilen bir gider sonrası hareketlerle ayrışırdı.
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.income,
    required this.outgo,
    required this.balance,
  });

  final String accountId;
  final String name;
  final String kind;
  final num income;
  final num outgo;
  final num balance;

  factory AccountBalance.fromMap(Map<String, dynamic> m) => AccountBalance(
        accountId: (m['account_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'bank',
        income: (m['income'] as num?) ?? 0,
        outgo: (m['outgo'] as num?) ?? 0,
        balance: (m['balance'] as num?) ?? 0,
      );
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.clubId,
    this.sort = 100,
  });

  final String id;
  final String name;

  /// null ise tüm kulüplere açık ortak kategori.
  final String? clubId;
  final int sort;

  bool get isShared => clubId == null;

  factory ExpenseCategory.fromMap(Map<String, dynamic> m) => ExpenseCategory(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        clubId: m['club_id'] as String?,
        sort: (m['sort'] as int?) ?? 100,
      );
}

class ExpenseRow {
  const ExpenseRow({
    required this.id,
    required this.amount,
    required this.spentOn,
    required this.status,
    this.categoryId,
    this.categoryName,
    this.accountId,
    this.accountName,
    this.supplier,
    this.note,
    this.vendorId,
    this.receiptPath,
  });

  final String id;
  final num amount;
  final DateTime spentOn;

  /// draft | complete — taslak, mobilden fişle girilip tamamlanmayı bekleyen.
  final String status;

  final String? categoryId;
  final String? categoryName;
  final String? accountId;
  final String? accountName;
  final String? vendorId;
  final String? supplier;
  final String? note;
  final String? receiptPath;

  bool get isDraft => status == 'draft';

  factory ExpenseRow.fromMap(Map<String, dynamic> m) {
    String? nested(String table, String field) {
      final t = m[table];
      return t is Map ? t[field] as String? : null;
    }

    return ExpenseRow(
      id: m['id'] as String,
      amount: (m['amount'] as num?) ?? 0,
      spentOn: DateTime.tryParse('${m['spent_on']}') ?? DateTime.now(),
      status: (m['status'] as String?) ?? 'complete',
      categoryId: m['category_id'] as String?,
      categoryName: nested('expense_categories', 'name'),
      accountId: m['account_id'] as String?,
      accountName: nested('cash_accounts', 'name'),
      vendorId: m['vendor_id'] as String?,
      supplier: m['supplier'] as String?,
      note: m['note'] as String?,
      receiptPath: m['receipt_path'] as String?,
    );
  }
}

/// Kulüp tedarikçi kaydı.
///
/// **Vergi numarası, vergi dairesi ve IBAN burada YOK.** Onlar ayrı bir
/// tabloda (`vendor_private`) ve yalnızca kulüp yöneticisine açık. RLS satır
/// düzeyinde çalışır, sütun gizleyemez; alanı modelden çıkarmak tek başına
/// koruma olmazdı — koruma veritabanındaki ayrı tabloda ve politikasında.
class Vendor {
  const Vendor({
    required this.id,
    required this.clubId,
    required this.name,
    this.contactNote,
    this.defaultCategoryId,
    this.defaultCategoryName,
    this.active = true,
    this.lastSpentOn,
    this.expenseCount = 0,
    this.expenseTotal = 0,
  });

  final String id;
  final String clubId;
  final String name;
  final String? contactNote;
  final String? defaultCategoryId;
  final String? defaultCategoryName;
  final bool active;

  /// Son işlem tarihi ve toplamlar yalnızca liste sorgusunda dolu gelir;
  /// tek kayıt okunduğunda sıfır kalır.
  final DateTime? lastSpentOn;
  final int expenseCount;
  final num expenseTotal;

  factory Vendor.fromMap(Map<String, dynamic> m) {
    final cat = m['expense_categories'];
    return Vendor(
      id: m['id'] as String,
      clubId: (m['club_id'] as String?) ?? '',
      name: (m['name'] as String?) ?? '',
      contactNote: m['contact_note'] as String?,
      defaultCategoryId: m['default_category_id'] as String?,
      defaultCategoryName: cat is Map ? cat['name'] as String? : null,
      active: (m['active'] as bool?) ?? true,
      lastSpentOn: m['last_spent_on'] == null
          ? null
          : DateTime.tryParse('${m['last_spent_on']}'),
      expenseCount: (m['expense_count'] as num?)?.toInt() ?? 0,
      expenseTotal: (m['expense_total'] as num?) ?? 0,
    );
  }
}

/// Tedarikçinin yalnızca kulüp yöneticisine açık vergi ve banka bilgisi.
class VendorPrivate {
  const VendorPrivate({
    required this.vendorId,
    this.taxOffice,
    this.taxId,
    this.iban,
    this.note,
  });

  final String vendorId;
  final String? taxOffice;
  final String? taxId;
  final String? iban;
  final String? note;

  factory VendorPrivate.fromMap(Map<String, dynamic> m) => VendorPrivate(
        vendorId: m['vendor_id'] as String,
        taxOffice: m['tax_office'] as String?,
        taxId: m['tax_id'] as String?,
        iban: m['iban'] as String?,
        note: m['note'] as String?,
      );
}

/// Gider değişikliğinin denetim kaydı.
///
/// Tetikleyici yazıyor, kimse silemiyor. [changed] yalnızca gerçekten değişen
/// alanları taşır; tam satırı döndürmek izi okunmaz yapardı ve ileride
/// eklenen her sütunu otomatik sızdırırdı.
class ExpenseAuditEntry {
  const ExpenseAuditEntry({
    required this.id,
    required this.action,
    required this.actor,
    required this.changedAt,
    this.reason,
    this.changed = const {},
  });

  final String id;
  final String action;

  /// Kulüp personeline gerçek ad, muhasebeciye kimlik kısaltması.
  final String actor;
  final DateTime changedAt;
  final String? reason;
  final Map<String, dynamic> changed;

  /// Kullanıcıya gösterilecek Türkçe eylem adı.
  String get actionLabel => switch (action) {
        'create' => 'Oluşturuldu',
        'update' => 'Düzenlendi',
        'complete' => 'Tamamlandı',
        'approve' => 'Onaylandı',
        'reject' => 'Reddedildi',
        'cancel' => 'İptal edildi',
        'correct' => 'Düzeltildi',
        'delete' => 'Silindi',
        _ => action,
      };

  factory ExpenseAuditEntry.fromMap(Map<String, dynamic> m) =>
      ExpenseAuditEntry(
        id: (m['log_id'] as String?) ?? '',
        action: (m['action'] as String?) ?? '',
        actor: (m['actor'] as String?) ?? 'Bilinmiyor',
        changedAt:
            DateTime.tryParse('${m['changed_at']}') ?? DateTime.now(),
        reason: m['reason'] as String?,
        changed: (m['changed'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Defterdeki tek satır — gelir ya da gider.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.movedOn,
    required this.direction,
    required this.label,
    required this.category,
    required this.counterpart,
    required this.account,
    required this.amount,
    required this.status,
  });

  final String id;
  final DateTime movedOn;

  /// in | out
  final String direction;
  final String label;
  final String category;

  /// Tedarikçi, bağışçı ya da sporcunun takma gösterimi (`#A3F91C`).
  final String counterpart;
  final String account;
  final num amount;
  final String status;

  bool get isIncome => direction == 'in';

  /// Toplamlarda kullanılacak işaretli tutar.
  num get signed => isIncome ? amount : -amount;

  factory LedgerEntry.fromMap(Map<String, dynamic> m) => LedgerEntry(
        id: (m['entry_id'] as String?) ?? '',
        movedOn: DateTime.tryParse('${m['moved_on']}') ?? DateTime.now(),
        direction: (m['direction'] as String?) ?? 'out',
        label: (m['label'] as String?) ?? '',
        category: (m['category'] as String?) ?? '—',
        counterpart: (m['counterpart'] as String?) ?? '—',
        account: (m['account'] as String?) ?? '—',
        amount: (m['amount'] as num?) ?? 0,
        status: (m['status'] as String?) ?? '',
      );
}

/// Defterin bir sayfası. [totalCount] seçilen süzgeçteki bütün satırları
/// gösterir; yalnızca bu sayfanın uzunluğu değildir.
class LedgerPage {
  const LedgerPage({required this.entries, required this.totalCount});

  final List<LedgerEntry> entries;
  final int totalCount;

  factory LedgerPage.fromRows(List<dynamic> rows) {
    if (rows.isEmpty) return const LedgerPage(entries: [], totalCount: 0);
    final maps = rows.map((r) => (r as Map).cast<String, dynamic>()).toList();
    return LedgerPage(
      entries: maps.map(LedgerEntry.fromMap).toList(),
      totalCount: (maps.first['total_count'] as num?)?.toInt() ?? maps.length,
    );
  }
}

/// Seçilen defter aralığının tamamındaki gelir, gider ve net toplamı.
class LedgerTotals {
  const LedgerTotals({
    required this.income,
    required this.outgo,
    required this.net,
  });

  const LedgerTotals.empty()
      : income = 0,
        outgo = 0,
        net = 0;

  final num income;
  final num outgo;
  final num net;

  factory LedgerTotals.fromMap(Map<String, dynamic> m) => LedgerTotals(
        income: (m['income'] as num?) ?? 0,
        outgo: (m['outgo'] as num?) ?? 0,
        net: (m['net'] as num?) ?? 0,
      );
}

/// Mali iş kuyruğundaki tek bir iş kalemi.
///
/// `swansport_data` arayüze bağlanmıyor (değişmez 2): burada ikon ve renk
/// yok. [risk] bir veri sınıflandırması; onu renge çeviren tüketen uygulama.
class FinanceWorkItem {
  const FinanceWorkItem({
    required this.code,
    required this.title,
    required this.count,
    required this.total,
    required this.risk,
    required this.why,
    required this.route,
  });

  /// Kararlı anahtar. Başlık değişse de testler ve yönlendirme bozulmaz.
  final String code;
  final String title;
  final int count;

  /// Sıfırsa kalemin parasal karşılığı yok (ör. fişi eksik gider sayısı).
  final num total;
  final FinanceRisk risk;

  /// Neden önemli — kullanıcı kartı görünce ne yapacağını bilmeli.
  final String why;

  /// Süzgeci hazır ilgili konsol ekranı.
  final String route;

  bool get hasTotal => total != 0;
}

/// İş kaleminin aciliyeti.
enum FinanceRisk { info, attention, critical }

/// Muhasebe iş kuyruğunun kişi kimliği içermeyen özeti.
///
/// Dış muhasebeci için özellikle ad, sporcu kimliği veya ödeme açıklaması
/// taşımaz. Hangi kayıtların tamamlanması gerektiğini söyler; kimin kaydı
/// olduğunu değil.
///
/// Alan adları `acc_operations_summary`'nin döndürdüğü sütunlarla **birebir**.
/// İlk taslakta iki taraf ayrışmıştı ve `??` yedekleri bunu gizliyordu: SQL
/// sekiz sütun döndürürken model on alan okuyordu, eşleşmeyenler sessizce
/// sıfır kalıyordu. Yedek yok — ad tutmazsa sıfır döner ve test bunu yakalar.
class FinanceOperationsSummary {
  const FinanceOperationsSummary({
    this.draftExpenseCount = 0,
    this.draftExpenseTotal = 0,
    this.pendingPaymentCount = 0,
    this.pendingPaymentTotal = 0,
    this.overdueInvoiceCount = 0,
    this.overdueInvoiceTotal = 0,
    this.unlinkedIncomeCount = 0,
    this.unlinkedIncomeTotal = 0,
    this.unlinkedExpenseCount = 0,
    this.unlinkedExpenseTotal = 0,
    this.negativeAccountCount = 0,
    this.negativeAccountTotal = 0,
    this.missingReceiptCount = 0,
    this.commitmentDueCount = 0,
    this.commitmentDueTotal = 0,
    this.pendingApprovalCount = 0,
    this.pendingApprovalTotal = 0,
    this.bankUnmatchedCount = 0,
    this.bankUnmatchedTotal = 0,
    this.closeBlockerCount = 0,
  });

  /// Ana kurucunun tamamı varsayılanlı; yönlendirme tekrar yazmayı önlüyor.
  const FinanceOperationsSummary.empty() : this();

  final int draftExpenseCount;
  final num draftExpenseTotal;
  final int pendingPaymentCount;
  final num pendingPaymentTotal;
  final int overdueInvoiceCount;
  final num overdueInvoiceTotal;
  final int unlinkedIncomeCount;
  final num unlinkedIncomeTotal;
  final int unlinkedExpenseCount;
  final num unlinkedExpenseTotal;
  final int negativeAccountCount;
  final num negativeAccountTotal;
  final int missingReceiptCount;
  final int commitmentDueCount;
  final num commitmentDueTotal;
  final int pendingApprovalCount;
  final num pendingApprovalTotal;
  final int bankUnmatchedCount;
  final num bankUnmatchedTotal;
  final int closeBlockerCount;

  static int _i(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toInt() ?? 0;

  static num _n(Map<String, dynamic> m, String k) => (m[k] as num?) ?? 0;

  factory FinanceOperationsSummary.fromMap(Map<String, dynamic> m) =>
      FinanceOperationsSummary(
        draftExpenseCount: _i(m, 'draft_expense_count'),
        draftExpenseTotal: _n(m, 'draft_expense_total'),
        pendingPaymentCount: _i(m, 'pending_payment_count'),
        pendingPaymentTotal: _n(m, 'pending_payment_total'),
        overdueInvoiceCount: _i(m, 'overdue_invoice_count'),
        overdueInvoiceTotal: _n(m, 'overdue_invoice_total'),
        unlinkedIncomeCount: _i(m, 'unlinked_income_count'),
        unlinkedIncomeTotal: _n(m, 'unlinked_income_total'),
        unlinkedExpenseCount: _i(m, 'unlinked_expense_count'),
        unlinkedExpenseTotal: _n(m, 'unlinked_expense_total'),
        negativeAccountCount: _i(m, 'negative_account_count'),
        negativeAccountTotal: _n(m, 'negative_account_total'),
        missingReceiptCount: _i(m, 'missing_receipt_count'),
        commitmentDueCount: _i(m, 'commitment_due_count'),
        commitmentDueTotal: _n(m, 'commitment_due_total'),
        pendingApprovalCount: _i(m, 'pending_approval_count'),
        pendingApprovalTotal: _n(m, 'pending_approval_total'),
        bankUnmatchedCount: _i(m, 'bank_unmatched_count'),
        bankUnmatchedTotal: _n(m, 'bank_unmatched_total'),
        closeBlockerCount: _i(m, 'close_blocker_count'),
      );

  /// Bekleyen bütün işler, önem sırasına göre.
  ///
  /// Adedi sıfır olan kalem hiç üretilmiyor: "0 taslak gider" göstermek,
  /// yapılacak iş yokken kuyruğu doluymuş gibi gösteriyordu. Başarı kartı da
  /// yok — yapılacak bir şey olmadığını söylemenin yolu boş durum.
  List<FinanceWorkItem> get items {
    final out = <FinanceWorkItem>[];

    void add(String code, String title, int count, num total, FinanceRisk risk,
        String why, String route) {
      if (count > 0) {
        out.add(FinanceWorkItem(
            code: code,
            title: title,
            count: count,
            total: total,
            risk: risk,
            why: why,
            route: route));
      }
    }

    add(
        'close_blocker',
        'Kapanışı engelleyen kayıt',
        closeBlockerCount,
        0,
        FinanceRisk.critical,
        'Süresi dolmuş dönem kapanamıyor. Listedeki maddeler giderilmeden '
            'ay kapanmaz.',
        '/donem-kapanis');
    add(
        'negative_account',
        'Negatif bakiyeli hesap',
        negativeAccountCount,
        negativeAccountTotal,
        FinanceRisk.critical,
        'Hesaptan olduğundan fazla para çıkmış görünüyor: ya bir tahsilat '
            'işlenmemiş ya da gider yanlış hesaba yazılmış.',
        '/kasa');
    add(
        'pending_approval',
        'Onay bekleyen gider',
        pendingApprovalCount,
        pendingApprovalTotal,
        FinanceRisk.critical,
        'Onay eşiğini aşan gider bekliyor. Onaylanmadan deftere ve bakiyeye '
            'girmiyor.',
        '/mali-isler');
    add(
        'overdue_invoice',
        'Gecikmiş aidat',
        overdueInvoiceCount,
        overdueInvoiceTotal,
        FinanceRisk.attention,
        'Vadesi geçmiş ve ödenmemiş aidatlar. Tahsilat ekranından hatırlatma '
            'gönderilebilir.',
        '/tahsilat');
    add(
        'pending_payment',
        'Onay bekleyen ödeme bildirimi',
        pendingPaymentCount,
        pendingPaymentTotal,
        FinanceRisk.attention,
        'Veli ödeme yaptığını bildirdi. Onaylanmadan tahsilat sayılmıyor.',
        '/tahsilat');
    add(
        'draft_expense',
        'Taslak gider',
        draftExpenseCount,
        draftExpenseTotal,
        FinanceRisk.attention,
        'Fiş mobilden kaydedildi; kategori, hesap veya tedarikçi eksik. '
            'Taslak gider bakiyeye, bütçeye ve rapora girmiyor.',
        '/defter');
    add(
        'commitment_due',
        'Vadesi yaklaşan taahhüt',
        commitmentDueCount,
        commitmentDueTotal,
        FinanceRisk.attention,
        'Kira, lisans veya bakım ödemesinin vadesi bir hafta içinde.',
        '/taahhutler');
    add(
        'bank_unmatched',
        'Eşleşmemiş banka hareketi',
        bankUnmatchedCount,
        bankUnmatchedTotal,
        FinanceRisk.attention,
        'Ekstredeki hareketin defterde karşılığı bulunamadı. Kapanışı '
            'engeller.',
        '/mutabakat');
    add(
        'unlinked_income',
        'Hesaba bağlanmamış gelir',
        unlinkedIncomeCount,
        unlinkedIncomeTotal,
        FinanceRisk.info,
        'Para girdi ama hangi kasaya girdiği yazılmamış; hesap bakiyesine '
            'yansımıyor.',
        '/defter');
    add(
        'unlinked_expense',
        'Hesaba bağlanmamış gider',
        unlinkedExpenseCount,
        unlinkedExpenseTotal,
        FinanceRisk.info,
        'Para çıktı ama hangi hesaptan çıktığı yazılmamış.',
        '/defter');
    add(
        'missing_receipt',
        'Belgesi eksik gider',
        missingReceiptCount,
        0,
        FinanceRisk.info,
        'Tamamlanmış ama fiş/fatura görseli olmayan giderler; denetimde '
            'sorun çıkarır.',
        '/defter');

    return out;
  }

  /// En fazla beş kritik iş öne çıkar; gerisi "Tüm işler"de.
  List<FinanceWorkItem> get topItems => items.take(5).toList();

  List<FinanceWorkItem> get otherItems => items.skip(5).toList();

  bool get hasWork => items.isNotEmpty;

  /// Kuyruktaki toplam kayıt sayısı — rozet için.
  int get totalCount => items.fold<int>(0, (sum, item) => sum + item.count);
}

/// Bir ayın gelir/gider özeti.
class MonthlyTotals {
  const MonthlyTotals({
    required this.month,
    required this.income,
    required this.outgo,
    required this.net,
  });

  final int month;
  final num income;
  final num outgo;
  final num net;

  factory MonthlyTotals.fromMap(Map<String, dynamic> m) => MonthlyTotals(
        month: (m['month'] as num?)?.toInt() ?? 0,
        income: (m['income'] as num?) ?? 0,
        outgo: (m['outgo'] as num?) ?? 0,
        net: (m['net'] as num?) ?? 0,
      );
}

/// Kategori bazında gider dağılımı.
class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.count,
  });

  final String category;
  final num total;
  final int count;

  factory CategoryTotal.fromMap(Map<String, dynamic> m) => CategoryTotal(
        category: (m['category'] as String?) ?? 'Kategorisiz',
        total: (m['total'] as num?) ?? 0,
        count: (m['entry_count'] as num?)?.toInt() ?? 0,
      );
}

/// Ödenmemiş aidatlar — sporcu adı yerine takma gösterimle.
class Receivable {
  const Receivable({
    required this.athleteCode,
    required this.unpaidCount,
    required this.total,
    this.oldest,
  });

  final String athleteCode;
  final int unpaidCount;
  final num total;
  final DateTime? oldest;

  factory Receivable.fromMap(Map<String, dynamic> m) => Receivable(
        athleteCode: (m['athlete_code'] as String?) ?? '—',
        unpaidCount: (m['unpaid_count'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?) ?? 0,
        oldest: DateTime.tryParse('${m['oldest']}'),
      );
}

/// Kulübün defterine erişimi olan bir muhasebeci.
class AccountantRef {
  const AccountantRef({
    required this.profileId,
    required this.name,
    required this.status,
    this.username,
    this.since,
  });

  final String profileId;
  final String name;

  /// active | revoked — kayıt silinmiyor, erişim geçmişi korunuyor.
  final String status;
  final String? username;
  final DateTime? since;

  bool get isActive => status == 'active';

  factory AccountantRef.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'];
    return AccountantRef(
      profileId: m['profile_id'] as String,
      name: (p is Map ? p['full_name'] as String? : null) ?? 'Muhasebeci',
      username: p is Map ? p['username'] as String? : null,
      status: (m['status'] as String?) ?? 'active',
      since: DateTime.tryParse('${m['created_at']}')?.toLocal(),
    );
  }
}

/// Henüz kullanılmamış, süresi dolmamış davet.
class PendingInvite {
  const PendingInvite({
    required this.code,
    required this.expiresAt,
    this.targetEmail,
  });

  final String code;
  final DateTime expiresAt;

  /// Doluysa yalnızca bu e-posta kullanabilir.
  final String? targetEmail;

  Duration get remaining => expiresAt.difference(DateTime.now());

  factory PendingInvite.fromMap(Map<String, dynamic> m) => PendingInvite(
        code: (m['code'] as String?) ?? '',
        targetEmail: m['target_email'] as String?,
        expiresAt: DateTime.tryParse('${m['expires_at']}')?.toLocal() ??
            DateTime.now(),
      );
}

// ============================================================== servis

class ExpenseService {
  ExpenseService(this._c);
  final SupabaseClient _c;

  /// Fiş/fatura görsellerinin bucket'ı — özel, imzalı URL ile okunur.
  static const String docsBucket = 'finance-docs';

  // ----------------------------------------------------------- hesaplar
  Future<List<CashAccount>> accounts(String clubId) async {
    final rows = await _c
        .from('cash_accounts')
        .select('id, name, kind, active')
        .eq('club_id', clubId)
        .eq('active', true)
        .order('name');
    return (rows as List)
        .map((r) => CashAccount.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addAccount(String clubId, String name, String kind) async {
    await _c
        .from('cash_accounts')
        .insert({'club_id': clubId, 'name': name, 'kind': kind});
  }

  // --------------------------------------------------------- tedarikçiler
  Future<List<Vendor>> vendors(String clubId) async {
    final rows = await _c
        .from('vendors')
        .select('*')
        .eq('club_id', clubId)
        .eq('active', true)
        .order('name');
    return (rows as List)
        .map((r) => Vendor.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addVendor(
    String clubId,
    String name, {
    String? taxId,
    String? contactPhone,
    String? contactEmail,
    String? defaultCategoryId,
    String? notes,
  }) async {
    await _c.from('vendors').insert({
      'club_id': clubId,
      'name': name,
      if (taxId != null) 'tax_id': taxId,
      if (contactPhone != null) 'contact_phone': contactPhone,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (defaultCategoryId != null) 'default_category_id': defaultCategoryId,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> updateExpenseWithAudit({
    required String expenseId,
    required String clubId,
    num? amount,
    String? categoryId,
    String? accountId,
    String? vendorId,
    String? supplier,
    String? note,
    String? status,
    String? reason,
  }) async {
    await _c.rpc<dynamic>('update_expense_with_audit', params: {
      'p_expense_id': expenseId,
      'p_club_id': clubId,
      if (amount != null) 'p_amount': amount,
      if (categoryId != null) 'p_category_id': categoryId,
      if (accountId != null) 'p_account_id': accountId,
      if (vendorId != null) 'p_vendor_id': vendorId,
      if (supplier != null) 'p_supplier': supplier,
      if (note != null) 'p_note': note,
      if (status != null) 'p_status': status,
      if (reason != null) 'p_reason': reason,
    });
  }

  Future<List<AccountBalance>> balances(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('acc_account_balances', params: {'p_club': clubId});
    return rows
        .map((r) => AccountBalance.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<FinanceOperationsSummary> operationsSummary(String clubId) async {
    final rows = await _c.rpc<List<dynamic>>('acc_operations_summary',
        params: {'p_club': clubId});
    if (rows.isEmpty) return const FinanceOperationsSummary.empty();
    return FinanceOperationsSummary.fromMap(
        (rows.first as Map).cast<String, dynamic>());
  }

  // -------------------------------------------------------- kategoriler
  Future<List<ExpenseCategory>> categories(String clubId) async {
    // Ortak kategoriler (club_id null) ve kulübün kendi kategorileri birlikte.
    final rows = await _c
        .from('expense_categories')
        .select('id, name, club_id, sort')
        .or('club_id.is.null,club_id.eq.$clubId')
        .order('sort');
    return (rows as List)
        .map((r) => ExpenseCategory.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addCategory(String clubId, String name) async {
    await _c
        .from('expense_categories')
        .insert({'club_id': clubId, 'name': name});
  }

  // ------------------------------------------------------------ gider
  Future<List<ExpenseRow>> expenses(
    String clubId, {
    DateTime? from,
    DateTime? to,
    String? categoryId,
    String? status,
    int? limit,
    int offset = 0,
  }) async {
    var q = _c
        .from('expenses')
        .select('id, amount, spent_on, status, category_id, account_id, '
            'supplier, note, receipt_path, '
            'expense_categories(name), cash_accounts(name)')
        .eq('club_id', clubId);

    if (from != null) q = q.gte('spent_on', _d(from));
    if (to != null) q = q.lte('spent_on', _d(to));
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (status != null) q = q.eq('status', status);

    final ordered = q.order('spent_on', ascending: false);
    final rows = limit == null
        ? await ordered
        : await ordered.range(offset, offset + limit - 1);

    return (rows as List)
        .map((r) => ExpenseRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Tek gider kaydı — defterde bir satıra tıklanınca düzenleme için.
  Future<ExpenseRow?> expenseById(String id) async {
    final row = await _c
        .from('expenses')
        .select('id, amount, spent_on, status, category_id, account_id, '
            'supplier, note, receipt_path, '
            'expense_categories(name), cash_accounts(name)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ExpenseRow.fromMap(row.cast<String, dynamic>());
  }

  /// Tam gider kaydı (masaüstü).
  Future<String> addExpense({
    required String clubId,
    required num amount,
    required DateTime spentOn,
    String? categoryId,
    String? accountId,
    String? supplier,
    String? note,
    String? receiptPath,
  }) async {
    final row = await _c
        .from('expenses')
        .insert({
          'club_id': clubId,
          'amount': amount,
          'spent_on': _d(spentOn),
          'status': 'complete',
          if (categoryId != null) 'category_id': categoryId,
          if (accountId != null) 'account_id': accountId,
          if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
          if (note != null && note.isNotEmpty) 'note': note,
          if (receiptPath != null) 'receipt_path': receiptPath,
          'entered_by': _c.auth.currentUser?.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Mobilden hızlı giriş — tutar ve fiş yeter, gerisi sonra tamamlanır.
  ///
  /// Taslak olarak kaydedilir; raporlar taslakları saymaz. Amaç fişin
  /// kaybolmasını önlemek, mükemmel kaydı ilk anda almak değil.
  Future<String> addDraftExpense({
    required String clubId,
    required num amount,
    String? categoryId,
    String? receiptPath,
    String? note,
  }) async {
    final row = await _c
        .from('expenses')
        .insert({
          'club_id': clubId,
          'amount': amount,
          'spent_on': _d(DateTime.now()),
          'status': 'draft',
          if (categoryId != null) 'category_id': categoryId,
          if (receiptPath != null) 'receipt_path': receiptPath,
          if (note != null && note.isNotEmpty) 'note': note,
          'entered_by': _c.auth.currentUser?.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateExpense(
    String id, {
    num? amount,
    DateTime? spentOn,
    String? categoryId,
    String? accountId,
    String? supplier,
    String? note,
    String? status,
  }) async {
    await _c.from('expenses').update({
      if (amount != null) 'amount': amount,
      if (spentOn != null) 'spent_on': _d(spentOn),
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (supplier != null) 'supplier': supplier,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
    }).eq('id', id);
  }

  Future<void> deleteExpense(String id) async {
    await _c.from('expenses').delete().eq('id', id);
  }

  /// Daha önce yazılmış tedarikçi adları — giriş sırasında öneri için.
  ///
  /// Ayrı bir tedarikçi tablosu yok; öneri listesi yazım farklarını
  /// ("Migros" / "migros") azaltmak için var.
  Future<List<String>> supplierSuggestions(String clubId) async {
    final rows = await _c
        .from('expenses')
        .select('supplier')
        .eq('club_id', clubId)
        .not('supplier', 'is', null)
        .order('created_at', ascending: false)
        .limit(200);
    final seen = <String>{};
    for (final r in rows as List) {
      final s = (r as Map)['supplier'] as String?;
      if (s != null && s.trim().isNotEmpty) seen.add(s.trim());
    }
    return seen.toList()..sort();
  }

  // ------------------------------------------------------------ belge
  Future<String> uploadReceipt({
    required String clubId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'jpg';
    // Yol düzeni: {club_id}/{zaman}.{uzantı} — RLS ilk klasöre bakıyor.
    final path = '$clubId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from(docsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  Future<String> receiptUrl(String path) =>
      _c.storage.from(docsBucket).createSignedUrl(path, 3600);

  // ----------------------------------------------------------- raporlar
  Future<LedgerPage> ledger(
    String clubId, {
    DateTime? from,
    DateTime? to,
    String? direction,
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('acc_ledger', params: {
      'p_club': clubId,
      if (from != null) 'p_from': _d(from),
      if (to != null) 'p_to': _d(to),
      if (direction != null) 'p_direction': direction,
      'p_limit': limit,
      'p_offset': offset,
    });
    return LedgerPage.fromRows(rows);
  }

  Future<LedgerTotals> ledgerTotals(
    String clubId, {
    DateTime? from,
    DateTime? to,
    String? direction,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('acc_ledger_totals', params: {
      'p_club': clubId,
      if (from != null) 'p_from': _d(from),
      if (to != null) 'p_to': _d(to),
      if (direction != null) 'p_direction': direction,
    });
    if (rows.isEmpty) return const LedgerTotals.empty();
    return LedgerTotals.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  /// CSV gibi kullanıcı tarafından açıkça istenen işlemler için bütün
  /// satırları küçük sunucu sayfalarıyla toplar. Ekran bu metodu kullanmaz.
  Future<List<LedgerEntry>> ledgerAll(
    String clubId, {
    DateTime? from,
    DateTime? to,
    String? direction,
  }) async {
    const pageSize = 200;
    var offset = 0;
    var total = 0;
    final entries = <LedgerEntry>[];
    do {
      final page = await ledger(
        clubId,
        from: from,
        to: to,
        direction: direction,
        limit: pageSize,
        offset: offset,
      );
      total = page.totalCount;
      entries.addAll(page.entries);
      offset += page.entries.length;
    } while (offset < total);
    return entries;
  }

  Future<List<MonthlyTotals>> monthlySummary(String clubId, int year) async {
    final rows = await _c.rpc<List<dynamic>>('acc_monthly_summary',
        params: {'p_club': clubId, 'p_year': year});
    return rows
        .map((r) => MonthlyTotals.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<CategoryTotal>> categoryBreakdown(
    String clubId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('acc_category_breakdown', params: {
      'p_club': clubId,
      if (from != null) 'p_from': _d(from),
      if (to != null) 'p_to': _d(to),
    });
    return rows
        .map((r) => CategoryTotal.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Receivable>> receivables(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('acc_receivables', params: {'p_club': clubId});
    return rows
        .map((r) => Receivable.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  // -------------------------------------------------------- muhasebeci
  /// Kulüp adına muhasebeci davet kodu üretir — 48 saat geçerli, tek kullanım.
  ///
  /// [email] verilirse davet o hesaba bağlanır ve başkası kullanamaz. Zorunlu
  /// değil ama önerilir: kodu eline geçiren kişi kulübün bütün mali verisini
  /// görüyor.
  ///
  /// Yalnızca kulüp **yöneticisi** çağırabilir; antrenör çağırırsa sunucu
  /// reddeder.
  Future<String> createAccountantInvite(String clubId, {String? email}) async {
    final res = await _c.rpc<dynamic>('create_accountant_invite', params: {
      'p_club': clubId,
      if (email != null && email.trim().isNotEmpty) 'p_email': email.trim(),
    });
    return res as String;
  }

  /// Kulübün muhasebecileri — erişimi kaldırılmış olanlar dahil.
  Future<List<AccountantRef>> accountants(String clubId) async {
    final rows = await _c
        .from('club_accountants')
        .select('profile_id, status, created_at, profiles(full_name, username)')
        .eq('club_id', clubId)
        .order('created_at');
    return (rows as List)
        .map((r) => AccountantRef.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Erişimi kaldırır. Satır silinmiyor, `revoked` işaretleniyor — kimin ne
  /// zaman erişimi olduğunun izi kalsın.
  Future<void> revokeAccountant(String clubId, String profileId) async {
    await _c
        .from('club_accountants')
        .update({'status': 'revoked'})
        .eq('club_id', clubId)
        .eq('profile_id', profileId);
  }

  Future<void> restoreAccountant(String clubId, String profileId) async {
    await _c
        .from('club_accountants')
        .update({'status': 'active'})
        .eq('club_id', clubId)
        .eq('profile_id', profileId);
  }

  /// Kulübün bekleyen muhasebeci davetleri.
  Future<List<PendingInvite>> pendingAccountantInvites(String clubId) async {
    final rows = await _c
        .from('invite_codes')
        .select('code, target_email, expires_at, used_at')
        .eq('club_id', clubId)
        .eq('purpose', 'accountant')
        .isFilter('used_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at', ascending: false);
    return (rows as List)
        .map((r) => PendingInvite.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  static String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// =============================== Provider'lar ==============================

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref.watch(supabaseClientProvider));
});

/// Muhasebecisi olunan kulüplerin kimlikleri.
///
/// Ayrı sorgu, kulüp listesinden türetme **değil**: `fetchMyClubs` zaten üye
/// olunan bir kulübü ikinci kez eklemiyor (üyelik rolü daha yetkili). Bu
/// yüzden aynı kulübün hem yöneticisi hem muhasebecisi olan biri için
/// muhasebeci bayrağı hiç yanmıyordu. İki ilişki birbirinden bağımsız
/// olduğuna göre kaynakları da bağımsız olmalı.
final myAccountantClubIdsProvider = FutureProvider<Set<String>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const {};
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const {};

  final rows = await client
      .from('club_accountants')
      .select('club_id')
      .eq('profile_id', uid)
      .eq('status', 'active');

  return {
    for (final r in rows as List) (r as Map)['club_id'] as String,
  };
});

final cashAccountsProvider =
    FutureProvider.autoDispose<List<CashAccount>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).accounts(club.id);
});

final accountBalancesProvider =
    FutureProvider.autoDispose<List<AccountBalance>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).balances(club.id);
});

/// Günlük mali iş kuyruğu. Aynı anonim özet, kulüp yetkilisi ve muhasebeci
/// tarafından okunabilir; ayrım veritabanı fonksiyonunda korunur.
final financeOperationsSummaryProvider =
    FutureProvider.autoDispose<FinanceOperationsSummary>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const FinanceOperationsSummary.empty();
  }
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const FinanceOperationsSummary.empty();
  return ref.watch(expenseServiceProvider).operationsSummary(club.id);
});

final expenseCategoriesProvider =
    FutureProvider.autoDispose<List<ExpenseCategory>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).categories(club.id);
});

final receivablesProvider =
    FutureProvider.autoDispose<List<Receivable>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).receivables(club.id);
});

/// Kulübün defterine erişimi olanlar — erişimi kaldırılmış olanlar dahil.
///
/// Kulübün "kim benim paramı görüyor" sorusunu yanıtlar. Bu liste olmadan
/// erişim verilebiliyor ama görülemiyordu.
final clubAccountantsProvider =
    FutureProvider.autoDispose<List<AccountantRef>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).accountants(club.id);
});

/// Henüz kullanılmamış, süresi dolmamış muhasebeci davetleri.
final pendingAccountantInvitesProvider =
    FutureProvider.autoDispose<List<PendingInvite>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).pendingAccountantInvites(club.id);
});
