import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'expense_service.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Kulüp Operasyon ve Mali Yönetim Merkezi.
///
/// `expense_service.dart` günlük defteri taşıyor; burası defterin **etrafındaki
/// iş akışı**: taahhütler, onaylar, banka mutabakatı, bütçe ve dönem kapanışı.
/// İkiye bölünmesinin sebebi boyut değil sorumluluk — defter "ne oldu"yu,
/// burası "ne yapılmalı"yı yanıtlıyor.
///
/// MUHASEBECİ GİZLİLİĞİ: buradaki hiçbir okuma sporcu ya da veli adı
/// döndürmüyor. Aidat tarafında kimlik yerine `athlete_ref` kısaltması geliyor
/// ve bu bir arayüz kararı değil — RPC'ler adı hiç seçmiyor.
/// ---------------------------------------------------------------------------

/// İstemcide üretilen idempotency anahtarı (RFC 4122 v4 biçiminde).
///
/// Yeni bir paket eklemek yerine burada üretiliyor: `uuid` paketi yalnızca
/// dolaylı bir bağımlılık ve doğrudan kullanmak, başka bir paketin onu
/// bırakması hâlinde sessizce kırılırdı.
///
/// **Kullanım kuralı:** anahtar işlem başına bir kez üretilir ve tekrar
/// gönderimlerde AYNI değer kullanılır. Her denemede yeniden üretmek,
/// idempotency'yi tamamen ortadan kaldırır — sunucu iki farklı işlem görür.
String newOpId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // sürüm 4
  b[8] = (b[8] & 0x3f) | 0x80; // varyant
  String hex(int from, int to) =>
      b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

// ============================== Tekrarlayan gider ==========================

/// Taahhüdün tekrar sıklığı.
enum RecurrenceFrequency { monthly, quarterly, yearly, custom }

RecurrenceFrequency _freqFrom(String? v) => switch (v) {
      'quarterly' => RecurrenceFrequency.quarterly,
      'yearly' => RecurrenceFrequency.yearly,
      'custom' => RecurrenceFrequency.custom,
      _ => RecurrenceFrequency.monthly,
    };

String freqLabel(RecurrenceFrequency f) => switch (f) {
      RecurrenceFrequency.monthly => 'Aylık',
      RecurrenceFrequency.quarterly => 'Üç aylık',
      RecurrenceFrequency.yearly => 'Yıllık',
      RecurrenceFrequency.custom => 'Özel',
    };

/// Kira, lisans, bakım gibi düzenli gider taahhüdü.
class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.clubId,
    required this.title,
    required this.amount,
    required this.frequency,
    required this.startsOn,
    this.intervalMonths,
    this.endsOn,
    this.vendorId,
    this.vendorName,
    this.categoryId,
    this.accountId,
    this.ownerId,
    this.needsApproval = false,
    this.note,
    this.active = true,
  });

  final String id;
  final String clubId;
  final String title;
  final num amount;
  final RecurrenceFrequency frequency;
  final int? intervalMonths;
  final DateTime startsOn;
  final DateTime? endsOn;
  final String? vendorId;
  final String? vendorName;
  final String? categoryId;
  final String? accountId;
  final String? ownerId;
  final bool needsApproval;
  final String? note;
  final bool active;

  factory RecurringExpense.fromMap(Map<String, dynamic> m) {
    final v = m['vendors'];
    return RecurringExpense(
      id: m['id'] as String,
      clubId: (m['club_id'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      amount: (m['amount'] as num?) ?? 0,
      frequency: _freqFrom(m['frequency'] as String?),
      intervalMonths: (m['interval_months'] as num?)?.toInt(),
      startsOn: DateTime.tryParse('${m['starts_on']}') ?? DateTime.now(),
      endsOn: m['ends_on'] == null
          ? null
          : DateTime.tryParse('${m['ends_on']}'),
      vendorId: m['vendor_id'] as String?,
      vendorName: v is Map ? v['name'] as String? : null,
      categoryId: m['category_id'] as String?,
      accountId: m['account_id'] as String?,
      ownerId: m['owner_id'] as String?,
      needsApproval: (m['needs_approval'] as bool?) ?? false,
      note: m['note'] as String?,
      active: (m['active'] as bool?) ?? true,
    );
  }
}

/// Taahhüdün tek bir vadesi.
///
/// Gider kaydından **önce** var olur: yoksa "vadesine üç gün kaldı" uyarısı
/// için ortada hiçbir şey olmazdı.
class RecurringOccurrence {
  const RecurringOccurrence({
    required this.id,
    required this.recurringId,
    required this.dueOn,
    required this.amount,
    required this.status,
    this.title,
    this.expenseId,
  });

  final String id;
  final String recurringId;
  final DateTime dueOn;
  final num amount;

  /// pending | recorded | skipped
  final String status;
  final String? title;
  final String? expenseId;

  bool get isPending => status == 'pending';

  /// Vadeye kalan gün. Negatifse vade geçmiş.
  int daysLeft(DateTime now) =>
      DateTime(dueOn.year, dueOn.month, dueOn.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

  bool isOverdue(DateTime now) => isPending && daysLeft(now) < 0;

  factory RecurringOccurrence.fromMap(Map<String, dynamic> m) {
    final r = m['recurring_expenses'];
    return RecurringOccurrence(
      id: m['id'] as String,
      recurringId: (m['recurring_id'] as String?) ?? '',
      dueOn: DateTime.tryParse('${m['due_on']}') ?? DateTime.now(),
      amount: (m['amount'] as num?) ?? 0,
      status: (m['status'] as String?) ?? 'pending',
      title: r is Map ? r['title'] as String? : m['title'] as String?,
      expenseId: m['expense_id'] as String?,
    );
  }
}

// ================================== Onay ===================================

/// Gider onay politikası — tutar aralığı, kaç onay, hangi roller.
class ExpenseApprovalPolicy {
  const ExpenseApprovalPolicy({
    required this.id,
    required this.clubId,
    required this.label,
    required this.minAmount,
    required this.requiredApprovals,
    required this.approverRoles,
    this.maxAmount,
    this.categoryId,
    this.reminderHours = 48,
    this.validFrom,
    this.validTo,
    this.active = true,
  });

  final String id;
  final String clubId;
  final String label;
  final num minAmount;

  /// null = üst sınır yok.
  final num? maxAmount;
  final String? categoryId;
  final int requiredApprovals;
  final List<String> approverRoles;
  final int reminderHours;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;

  factory ExpenseApprovalPolicy.fromMap(Map<String, dynamic> m) =>
      ExpenseApprovalPolicy(
        id: m['id'] as String,
        clubId: (m['club_id'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        minAmount: (m['min_amount'] as num?) ?? 0,
        maxAmount: m['max_amount'] as num?,
        categoryId: m['category_id'] as String?,
        requiredApprovals:
            (m['required_approvals'] as num?)?.toInt() ?? 1,
        approverRoles: ((m['approver_roles'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        reminderHours: (m['reminder_hours'] as num?)?.toInt() ?? 48,
        validFrom: m['valid_from'] == null
            ? null
            : DateTime.tryParse('${m['valid_from']}'),
        validTo: m['valid_to'] == null
            ? null
            : DateTime.tryParse('${m['valid_to']}'),
        active: (m['active'] as bool?) ?? true,
      );
}

/// Bir gidere verilmiş onay/red oyu.
class ExpenseApproval {
  const ExpenseApproval({
    required this.id,
    required this.expenseId,
    required this.approverId,
    required this.decision,
    required this.createdAt,
    this.reason,
    this.approverName,
  });

  final String id;
  final String expenseId;
  final String approverId;

  /// approve | reject
  final String decision;
  final DateTime createdAt;
  final String? reason;
  final String? approverName;

  bool get isApproval => decision == 'approve';

  factory ExpenseApproval.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'];
    return ExpenseApproval(
      id: m['id'] as String,
      expenseId: (m['expense_id'] as String?) ?? '',
      approverId: (m['approver_id'] as String?) ?? '',
      decision: (m['decision'] as String?) ?? '',
      createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
      reason: m['reason'] as String?,
      approverName: p is Map ? p['full_name'] as String? : null,
    );
  }
}

// ============================ Banka mutabakatı =============================

/// Yüklenmiş bir banka ekstresi.
class BankImport {
  const BankImport({
    required this.id,
    required this.accountId,
    required this.rowCount,
    required this.createdAt,
    this.accountName,
    this.periodFrom,
    this.periodTo,
  });

  final String id;
  final String accountId;
  final String? accountName;
  final int rowCount;
  final DateTime createdAt;
  final DateTime? periodFrom;
  final DateTime? periodTo;

  factory BankImport.fromMap(Map<String, dynamic> m) {
    final a = m['cash_accounts'];
    return BankImport(
      id: m['id'] as String,
      accountId: (m['account_id'] as String?) ?? '',
      accountName: a is Map ? a['name'] as String? : null,
      rowCount: (m['row_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
      periodFrom: m['period_from'] == null
          ? null
          : DateTime.tryParse('${m['period_from']}'),
      periodTo: m['period_to'] == null
          ? null
          : DateTime.tryParse('${m['period_to']}'),
    );
  }
}

/// Ekstredeki tek hareket.
///
/// [description] sunucuda maskelenmiş geliyor: IBAN ve uzun rakam dizileri
/// gizli. Ham metin okuma RPC'sinden hiç çıkmıyor ve dışa aktarıma girmiyor.
class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.txnOn,
    required this.amount,
    required this.direction,
    required this.matchStatus,
    this.description,
    this.matchedKind,
    this.matchedId,
    this.accountName,
  });

  final String id;
  final DateTime txnOn;
  final num amount;

  /// in | out
  final String direction;

  /// unmatched | matched | ignored
  final String matchStatus;
  final String? description;
  final String? matchedKind;
  final String? matchedId;
  final String? accountName;

  bool get isIncoming => direction == 'in';
  bool get isMatched => matchStatus == 'matched';

  factory BankTransaction.fromMap(Map<String, dynamic> m) => BankTransaction(
        id: (m['txn_id'] ?? m['id']) as String,
        txnOn: DateTime.tryParse('${m['txn_on']}') ?? DateTime.now(),
        amount: (m['amount'] as num?) ?? 0,
        direction: (m['direction'] as String?) ?? 'in',
        matchStatus: (m['match_status'] as String?) ?? 'unmatched',
        description: m['description'] as String?,
        matchedKind: m['matched_kind'] as String?,
        matchedId: m['matched_id'] as String?,
        accountName: m['account_name'] as String?,
      );
}

/// Sistemin önerdiği eşleşme adayı. **Öneri, karar değil.**
class BankMatchSuggestion {
  const BankMatchSuggestion({
    required this.kind,
    required this.entryId,
    required this.entryOn,
    required this.amount,
    required this.label,
    required this.dayGap,
  });

  /// payment | donation | expense
  final String kind;
  final String entryId;
  final DateTime entryOn;
  final num amount;
  final String label;

  /// Banka hareketiyle defter kaydı arasındaki gün farkı. 0 = aynı gün.
  final int dayGap;

  factory BankMatchSuggestion.fromMap(Map<String, dynamic> m) =>
      BankMatchSuggestion(
        kind: (m['kind'] as String?) ?? '',
        entryId: (m['entry_id'] as String?) ?? '',
        entryOn: DateTime.tryParse('${m['entry_on']}') ?? DateTime.now(),
        amount: (m['amount'] as num?) ?? 0,
        label: (m['label'] as String?) ?? '',
        dayGap: (m['day_gap'] as num?)?.toInt() ?? 0,
      );
}

// ============================ Bütçe ve tahmin ==============================

/// Bütçe satırı ile gerçekleşenin karşılaştırması.
///
/// [actual] elle girilmiyor — `expenses`'ten hesaplanıyor. [committed] henüz
/// harcanmamış ama bağlanmış para: onay bekleyen giderler ve vadesi gelmemiş
/// taahhütler. Onu "kalan"dan düşmemek bütçeyi olduğundan geniş gösterirdi.
class BudgetLine {
  const BudgetLine({
    required this.budgetId,
    required this.scope,
    required this.scopeLabel,
    required this.category,
    required this.periodFrom,
    required this.periodTo,
    required this.planned,
    required this.actual,
    required this.committed,
    required this.remaining,
    required this.risk,
    this.scopeId,
    this.categoryId,
    this.overrunPct,
  });

  final String budgetId;

  /// club | team | facility | event
  final String scope;
  final String? scopeId;
  final String scopeLabel;
  final String? categoryId;
  final String category;
  final DateTime periodFrom;
  final DateTime periodTo;
  final num planned;
  final num actual;
  final num committed;
  final num remaining;
  final num? overrunPct;

  /// bilgi | dikkat | kritik
  final String risk;

  bool get isOverrun => remaining < 0;

  factory BudgetLine.fromMap(Map<String, dynamic> m) => BudgetLine(
        budgetId: (m['budget_id'] as String?) ?? '',
        scope: (m['scope'] as String?) ?? 'club',
        scopeId: m['scope_id'] as String?,
        scopeLabel: (m['scope_label'] as String?) ?? 'Kulüp geneli',
        categoryId: m['category_id'] as String?,
        category: (m['category'] as String?) ?? 'Tüm kategoriler',
        periodFrom:
            DateTime.tryParse('${m['period_from']}') ?? DateTime.now(),
        periodTo: DateTime.tryParse('${m['period_to']}') ?? DateTime.now(),
        planned: (m['planned'] as num?) ?? 0,
        actual: (m['actual'] as num?) ?? 0,
        committed: (m['committed'] as num?) ?? 0,
        remaining: (m['remaining'] as num?) ?? 0,
        overrunPct: m['overrun_pct'] as num?,
        risk: (m['risk'] as String?) ?? 'bilgi',
      );
}

/// 30/60/90 gün nakit tahmininin tek ufku.
///
/// Üç güven kademesi **ayrı** duruyor ve tek bir sayıya indirgenmiyor:
/// [projectedLow] yalnızca onaylıyı, [projectedHigh] beklenenle birlikte
/// taşıyor. [uncertainOut] hiçbirine girmiyor — bütçelenmiş ama taahhüt
/// edilmemiş parayı gerçek borç gibi göstermek, kulübü yanıltırdı.
class CashForecast {
  const CashForecast({
    required this.horizonDays,
    required this.opening,
    required this.confirmedIn,
    required this.confirmedOut,
    required this.expectedIn,
    required this.expectedOut,
    required this.uncertainOut,
    required this.projectedLow,
    required this.projectedHigh,
  });

  final int horizonDays;
  final num opening;
  final num confirmedIn;
  final num confirmedOut;
  final num expectedIn;
  final num expectedOut;
  final num uncertainOut;
  final num projectedLow;
  final num projectedHigh;

  /// Kötümser uçta bile para bitmiyorsa açık yok.
  bool get hasShortfall => projectedLow < 0 || projectedHigh < 0;

  factory CashForecast.fromMap(Map<String, dynamic> m) => CashForecast(
        horizonDays: (m['horizon_days'] as num?)?.toInt() ?? 0,
        opening: (m['opening'] as num?) ?? 0,
        confirmedIn: (m['confirmed_in'] as num?) ?? 0,
        confirmedOut: (m['confirmed_out'] as num?) ?? 0,
        expectedIn: (m['expected_in'] as num?) ?? 0,
        expectedOut: (m['expected_out'] as num?) ?? 0,
        uncertainOut: (m['uncertain_out'] as num?) ?? 0,
        projectedLow: (m['projected_low'] as num?) ?? 0,
        projectedHigh: (m['projected_high'] as num?) ?? 0,
      );
}

// ============================== Dönem kapanışı =============================

/// Mali dönem.
class FinancePeriod {
  const FinancePeriod({
    required this.id,
    required this.clubId,
    required this.periodFrom,
    required this.periodTo,
    required this.status,
    this.closedAt,
    this.closeNote,
  });

  final String id;
  final String clubId;
  final DateTime periodFrom;
  final DateTime periodTo;

  /// open | preparing | review | closed | needs_correction
  final String status;
  final DateTime? closedAt;
  final String? closeNote;

  bool get isClosed => status == 'closed';

  String get statusLabel => switch (status) {
        'open' => 'Açık',
        'preparing' => 'Hazırlanıyor',
        'review' => 'İncelemede',
        'closed' => 'Kapandı',
        'needs_correction' => 'Düzeltme gerekli',
        _ => status,
      };

  factory FinancePeriod.fromMap(Map<String, dynamic> m) => FinancePeriod(
        id: m['id'] as String,
        clubId: (m['club_id'] as String?) ?? '',
        periodFrom:
            DateTime.tryParse('${m['period_from']}') ?? DateTime.now(),
        periodTo: DateTime.tryParse('${m['period_to']}') ?? DateTime.now(),
        status: (m['status'] as String?) ?? 'open',
        closedAt: m['closed_at'] == null
            ? null
            : DateTime.tryParse('${m['closed_at']}'),
        closeNote: m['close_note'] as String?,
      );
}

/// Kapanış kontrol listesinin bir maddesi.
class CloseCheckItem {
  const CloseCheckItem({
    required this.code,
    required this.label,
    required this.blocking,
    required this.qty,
    required this.amount,
  });

  final String code;
  final String label;

  /// true ise bu madde sıfırlanmadan dönem kapanmaz.
  final bool blocking;
  final int qty;
  final num amount;

  bool get isBlocker => blocking && qty > 0;

  factory CloseCheckItem.fromMap(Map<String, dynamic> m) => CloseCheckItem(
        code: (m['code'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        blocking: (m['blocking'] as bool?) ?? false,
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        amount: (m['amount'] as num?) ?? 0,
      );
}

/// Kulübün sportif/operasyonel bekleyen işleri.
///
/// **Muhasebeci bu özeti alamaz** — üyelik, belge ve yoklama sayıları
/// içeriyor. Sunucudaki `club_operations_summary` yalnızca kulüp personeline
/// açık; buradaki tip bir kolaylık, kısıt değil.
class ClubOperationsSummary {
  const ClubOperationsSummary({
    this.pendingMembershipCount = 0,
    this.expiringDocumentCount = 0,
    this.unmarkedEventCount = 0,
    this.lowRsvpEventCount = 0,
    this.openReportCount = 0,
    this.pendingStoreCount = 0,
  });

  /// Ana kurucunun tamamı varsayılanlı; yönlendirme tekrar yazmayı önlüyor.
  const ClubOperationsSummary.empty() : this();

  final int pendingMembershipCount;
  final int expiringDocumentCount;
  final int unmarkedEventCount;
  final int lowRsvpEventCount;
  final int openReportCount;
  final int pendingStoreCount;

  factory ClubOperationsSummary.fromMap(Map<String, dynamic> m) {
    int v(String k) => (m[k] as num?)?.toInt() ?? 0;
    return ClubOperationsSummary(
      pendingMembershipCount: v('pending_membership_count'),
      expiringDocumentCount: v('expiring_document_count'),
      unmarkedEventCount: v('unmarked_event_count'),
      lowRsvpEventCount: v('low_rsvp_event_count'),
      openReportCount: v('open_report_count'),
      pendingStoreCount: v('pending_store_count'),
    );
  }

  /// Mali kuyrukla aynı biçimde iş kalemleri. Rota adları **mobil** değil
  /// konsol rotaları; ikisi ayrı yönlendirici.
  List<FinanceWorkItem> get items {
    final out = <FinanceWorkItem>[];

    void add(String code, String title, int count, FinanceRisk risk,
        String why, String route) {
      if (count > 0) {
        out.add(FinanceWorkItem(
            code: code,
            title: title,
            count: count,
            total: 0,
            risk: risk,
            why: why,
            route: route));
      }
    }

    add(
        'pending_membership',
        'Onay bekleyen üyelik',
        pendingMembershipCount,
        FinanceRisk.attention,
        'Kulübe katılmak isteyenler yanıt bekliyor.',
        '/onaylar');
    add(
        'expiring_document',
        'Süresi dolmak üzere belge',
        expiringDocumentCount,
        FinanceRisk.attention,
        'Otuz gün içinde süresi dolacak belgeler var.',
        '/onaylar');
    add(
        'unmarked_event',
        'Yoklaması alınmamış antrenman',
        unmarkedEventCount,
        FinanceRisk.attention,
        'Geçmiş antrenmanların yoklaması hiç alınmamış; katılım oranı ve '
            'gelişim verisi eksik kalıyor.',
        '/yoklama');
    add(
        'low_rsvp',
        'Yanıt oranı düşük antrenman',
        lowRsvpEventCount,
        FinanceRisk.info,
        'Yaklaşan antrenmanda kadronun yarısından azı yanıt verdi.',
        '/takvim');
    add(
        'open_report',
        'İncelenmemiş şikayet',
        openReportCount,
        FinanceRisk.critical,
        'Raporlanan içerik moderasyon bekliyor.',
        '/moderasyon');
    add(
        'pending_store',
        'Bekleyen mağaza başvurusu',
        pendingStoreCount,
        FinanceRisk.info,
        'Pazaryeri mağaza başvurusu değerlendirilmeyi bekliyor.',
        '/pazaryeri');

    return out;
  }

  bool get hasWork => items.isNotEmpty;
}

// ================================= Servis ==================================

class FinanceOpsService {
  FinanceOpsService(this._c);

  final SupabaseClient _c;

  static String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ tedarikçi
  Future<List<Vendor>> vendors(String clubId, {bool onlyActive = true}) async {
    var q = _c
        .from('vendors')
        .select('id, club_id, name, contact_note, default_category_id, '
            'active, expense_categories(name)')
        .eq('club_id', clubId);
    if (onlyActive) q = q.eq('active', true);
    final rows = await q.order('name');
    return rows
        .map((e) => Vendor.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> saveVendor({
    required String clubId,
    String? id,
    required String name,
    String? contactNote,
    String? defaultCategoryId,
    bool active = true,
  }) async {
    final row = {
      'club_id': clubId,
      'name': name.trim(),
      'contact_note': contactNote,
      'default_category_id': defaultCategoryId,
      'active': active,
    };
    if (id == null) {
      final r = await _c.from('vendors').insert(row).select('id').single();
      return r['id'] as String;
    }
    await _c.from('vendors').update(row).eq('id', id);
    return id;
  }

  /// Vergi ve IBAN bilgisi. Muhasebeci çağırırsa RLS boş döndürür — bu bir
  /// hata değil, kuralın kendisi.
  Future<VendorPrivate?> vendorPrivate(String vendorId) async {
    final rows = await _c
        .from('vendor_private')
        .select()
        .eq('vendor_id', vendorId)
        .limit(1);
    if (rows.isEmpty) return null;
    return VendorPrivate.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  Future<void> saveVendorPrivate({
    required String vendorId,
    required String clubId,
    String? taxOffice,
    String? taxId,
    String? iban,
    String? note,
  }) =>
      _c.from('vendor_private').upsert({
        'vendor_id': vendorId,
        'club_id': clubId,
        'tax_office': taxOffice,
        'tax_id': taxId,
        'iban': iban,
        'note': note,
        'updated_at': DateTime.now().toIso8601String(),
      });

  // -------------------------------------------------------------- denetim
  Future<List<ExpenseAuditEntry>> auditTrail(String expenseId) async {
    final rows = await _c.rpc<List<dynamic>>('expense_audit_trail',
        params: {'p_expense': expenseId});
    return rows
        .map((e) =>
            ExpenseAuditEntry.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---------------------------------------------------------------- gider
  /// Mobilden hızlı taslak gider. [opId] istemcide üretilen idempotency
  /// anahtarı: ağ koptuğunda tekrar gönderim aynı kaydı döndürür.
  Future<String> createDraftExpense({
    required String clubId,
    required num amount,
    required String opId,
    String? receiptPath,
    String? note,
    DateTime? spentOn,
  }) =>
      _c.rpc<String>('create_draft_expense', params: {
        'p_club': clubId,
        'p_amount': amount,
        'p_op_id': opId,
        'p_receipt': receiptPath,
        'p_note': note,
        'p_spent_on': spentOn == null ? null : _d(spentOn),
      });

  /// Taslağı tamamlar. Dönen değer `not_required` | `pending`: onay
  /// gerekiyorsa gider `complete` olmuyor, kuyrukta bekliyor.
  Future<String> completeDraftExpense({
    required String expenseId,
    required String categoryId,
    required String accountId,
    String? vendorId,
    num? amount,
    DateTime? spentOn,
    String? note,
    String? receiptPath,
    String? teamId,
    String? facilityId,
    String? eventId,
    String? reason,
  }) =>
      _c.rpc<String>('complete_draft_expense', params: {
        'p_expense': expenseId,
        'p_category': categoryId,
        'p_account': accountId,
        'p_vendor': vendorId,
        'p_amount': amount,
        'p_spent_on': spentOn == null ? null : _d(spentOn),
        'p_note': note,
        'p_receipt': receiptPath,
        'p_team': teamId,
        'p_facility': facilityId,
        'p_event': eventId,
        'p_reason': reason,
      });

  // ------------------------------------------------------------- taahhüt
  Future<List<RecurringExpense>> recurringExpenses(String clubId) async {
    final rows = await _c
        .from('recurring_expenses')
        .select('*, vendors(name)')
        .eq('club_id', clubId)
        .order('active', ascending: false)
        .order('title');
    return rows
        .map((e) =>
            RecurringExpense.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<RecurringOccurrence>> upcomingOccurrences(String clubId,
      {int withinDays = 30}) async {
    final until = DateTime.now().add(Duration(days: withinDays));
    final rows = await _c
        .from('recurring_occurrences')
        .select('*, recurring_expenses(title)')
        .eq('club_id', clubId)
        .eq('status', 'pending')
        .lte('due_on', _d(until))
        .order('due_on');
    return rows
        .map((e) =>
            RecurringOccurrence.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> saveRecurringExpense(Map<String, dynamic> row,
      {String? id}) async {
    if (id == null) {
      final r = await _c
          .from('recurring_expenses')
          .insert(row)
          .select('id')
          .single();
      return r['id'] as String;
    }
    await _c.from('recurring_expenses').update(row).eq('id', id);
    return id;
  }

  Future<void> cancelRecurringExpense(String id) =>
      _c.rpc<void>('cancel_recurring_expense', params: {'p_id': id});

  Future<String> recordOccurrence(String occurrenceId,
          {num? amount, String? accountId, DateTime? spentOn}) =>
      _c.rpc<String>('record_recurring_occurrence', params: {
        'p_occurrence': occurrenceId,
        'p_amount': amount,
        'p_account': accountId,
        'p_spent_on': spentOn == null ? null : _d(spentOn),
      });

  // ---------------------------------------------------------------- onay
  Future<List<ExpenseApprovalPolicy>> approvalPolicies(String clubId) async {
    final rows = await _c
        .from('expense_approval_policies')
        .select()
        .eq('club_id', clubId)
        .order('min_amount');
    return rows
        .map((e) =>
            ExpenseApprovalPolicy.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> savePolicy(Map<String, dynamic> row, {String? id}) async {
    if (id == null) {
      await _c.from('expense_approval_policies').insert(row);
    } else {
      await _c.from('expense_approval_policies').update(row).eq('id', id);
    }
  }

  Future<List<ExpenseApproval>> approvalsFor(String expenseId) async {
    final rows = await _c
        .from('expense_approvals')
        .select('*, profiles(full_name)')
        .eq('expense_id', expenseId)
        .order('created_at');
    return rows
        .map((e) => ExpenseApproval.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Dönen değer: `approved` | `rejected` | `pending`.
  Future<String> decideApproval(String expenseId, bool approve,
          {String? reason}) =>
      _c.rpc<String>('decide_expense_approval', params: {
        'p_expense': expenseId,
        'p_approve': approve,
        'p_reason': reason,
      });

  /// Onay bekleyen giderler.
  ///
  /// Kendi girdiği kayıt listeden düşürülüyor: onaylayamayacağı bir şeyi
  /// "onayını bekliyor" diye göstermek kullanıcıyı sistemle güreştirirdi.
  /// Asıl kural sunucuda (`decide_expense_approval` reddediyor); buradaki
  /// süzgeç yalnızca gereksiz satırı gizliyor.
  Future<List<ExpenseRow>> pendingApprovals(String clubId) async {
    final me = _c.auth.currentUser?.id;
    final rows = await _c
        .from('expenses')
        .select('id, club_id, amount, spent_on, note, status, supplier, '
            'receipt_path, entered_by, category_id, account_id, vendor_id, '
            'expense_categories(name), cash_accounts(name)')
        .eq('club_id', clubId)
        .eq('approval_status', 'pending')
        .order('spent_on', ascending: false);
    return rows
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((m) => me == null || m['entered_by'] != me)
        .map(ExpenseRow.fromMap)
        .toList();
  }

  // ----------------------------------------------------------- mutabakat
  Future<List<BankImport>> bankImports(String clubId) async {
    final rows = await _c
        .from('bank_imports')
        .select('*, cash_accounts(name)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows
        .map((e) => BankImport.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// [rows] her biri `date`, `amount`, `direction`, `description` taşıyan
  /// haritalar. [hash] dosyanın ham içeriğinden istemcide hesaplanır;
  /// mükerrer yüklemeyi o engelliyor.
  Future<String> importStatement({
    required String clubId,
    required String accountId,
    required String hash,
    required List<Map<String, dynamic>> rows,
    String? filePath,
  }) =>
      _c.rpc<String>('import_bank_statement', params: {
        'p_club': clubId,
        'p_account': accountId,
        'p_hash': hash,
        'p_rows': rows,
        'p_path': filePath,
      });

  Future<List<BankTransaction>> bankTransactions(String clubId,
      {String status = 'unmatched', int limit = 100, int offset = 0}) async {
    final rows = await _c.rpc<List<dynamic>>('bank_transactions_page', params: {
      'p_club': clubId,
      'p_status': status,
      'p_limit': limit,
      'p_offset': offset,
    });
    return rows
        .map((e) => BankTransaction.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<BankMatchSuggestion>> matchSuggestions(String txnId) async {
    final rows = await _c
        .rpc<List<dynamic>>('bank_match_suggestions', params: {'p_txn': txnId});
    return rows
        .map((e) =>
            BankMatchSuggestion.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> decideMatch(String txnId, String action,
          {String? kind, String? entryId, String? note}) =>
      _c.rpc<void>('decide_bank_match', params: {
        'p_txn': txnId,
        'p_action': action,
        'p_kind': kind,
        'p_id': entryId,
        'p_note': note,
      });

  // --------------------------------------------------------------- bütçe
  Future<List<BudgetLine>> budgetLines(String clubId,
      {DateTime? from, DateTime? to}) async {
    final rows = await _c.rpc<List<dynamic>>('budget_vs_actual', params: {
      'p_club': clubId,
      'p_from': from == null ? null : _d(from),
      'p_to': to == null ? null : _d(to),
    });
    return rows
        .map((e) => BudgetLine.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> saveBudget(Map<String, dynamic> row, {String? id}) async {
    if (id == null) {
      await _c.from('budgets').insert(row);
    } else {
      await _c.from('budgets').update(row).eq('id', id);
    }
  }

  Future<List<CashForecast>> cashForecast(String clubId) async {
    final rows =
        await _c.rpc<List<dynamic>>('cash_forecast', params: {'p_club': clubId});
    return rows
        .map((e) => CashForecast.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ------------------------------------------------------------- kapanış
  Future<List<FinancePeriod>> periods(String clubId) async {
    final rows = await _c
        .from('finance_periods')
        .select()
        .eq('club_id', clubId)
        .order('period_from', ascending: false)
        .limit(36);
    return rows
        .map((e) => FinancePeriod.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> createPeriod(String clubId, DateTime from, DateTime to) =>
      _c.from('finance_periods').insert({
        'club_id': clubId,
        'period_from': _d(from),
        'period_to': _d(to),
        'status': 'open',
      });

  Future<List<CloseCheckItem>> closeChecklist(
      String clubId, DateTime from, DateTime to) async {
    final rows =
        await _c.rpc<List<dynamic>>('period_close_checklist', params: {
      'p_club': clubId,
      'p_from': _d(from),
      'p_to': _d(to),
    });
    return rows
        .map((e) => CloseCheckItem.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> closePeriod(String periodId, {String? note}) => _c.rpc<void>(
      'close_finance_period',
      params: {'p_period': periodId, 'p_note': note});

  Future<void> reopenPeriod(String periodId, String reason) => _c.rpc<void>(
      'reopen_finance_period',
      params: {'p_period': periodId, 'p_reason': reason});

  Future<String> createAdjustment({
    required String clubId,
    required String targetKind,
    String? targetId,
    required num amount,
    required String reason,
  }) =>
      _c.rpc<String>('create_finance_adjustment', params: {
        'p_club': clubId,
        'p_target_kind': targetKind,
        'p_target_id': targetId,
        'p_amount': amount,
        'p_reason': reason,
      });

  // ------------------------------------------------------- operasyon özeti
  Future<ClubOperationsSummary> clubOperations(String clubId) async {
    final rows = await _c.rpc<List<dynamic>>('club_operations_summary',
        params: {'p_club': clubId});
    if (rows.isEmpty) return const ClubOperationsSummary.empty();
    return ClubOperationsSummary.fromMap(
        (rows.first as Map).cast<String, dynamic>());
  }
}

// =============================== Provider'lar ==============================

final financeOpsServiceProvider = Provider<FinanceOpsService>((ref) {
  return FinanceOpsService(ref.watch(supabaseClientProvider));
});

final vendorsProvider = FutureProvider.autoDispose<List<Vendor>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).vendors(club.id);
});

final recurringExpensesProvider =
    FutureProvider.autoDispose<List<RecurringExpense>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).recurringExpenses(club.id);
});

final upcomingOccurrencesProvider =
    FutureProvider.autoDispose<List<RecurringOccurrence>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).upcomingOccurrences(club.id);
});

final approvalPoliciesProvider =
    FutureProvider.autoDispose<List<ExpenseApprovalPolicy>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).approvalPolicies(club.id);
});

final bankImportsProvider =
    FutureProvider.autoDispose<List<BankImport>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).bankImports(club.id);
});

/// Eşleşmemiş banka hareketleri. Süzgeç parametreli: `all`, `matched`,
/// `ignored` de geçilebilir.
final bankTransactionsProvider = FutureProvider.autoDispose
    .family<List<BankTransaction>, String>((ref, status) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref
      .watch(financeOpsServiceProvider)
      .bankTransactions(club.id, status: status);
});

final bankMatchSuggestionsProvider = FutureProvider.autoDispose
    .family<List<BankMatchSuggestion>, String>((ref, txnId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(financeOpsServiceProvider).matchSuggestions(txnId);
});

final budgetLinesProvider =
    FutureProvider.autoDispose<List<BudgetLine>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).budgetLines(club.id);
});

final cashForecastProvider =
    FutureProvider.autoDispose<List<CashForecast>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).cashForecast(club.id);
});

final financePeriodsProvider =
    FutureProvider.autoDispose<List<FinancePeriod>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).periods(club.id);
});

/// Kulübün sportif/operasyonel bekleyen işleri.
///
/// Muhasebeci çağırırsa sunucu hata veriyor; bu sağlayıcı hatayı yutmuyor —
/// yutsaydı yetkisiz erişim "iş yok" gibi görünür ve sorun fark edilmezdi.
final clubOperationsSummaryProvider =
    FutureProvider.autoDispose<ClubOperationsSummary>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const ClubOperationsSummary.empty();
  }
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const ClubOperationsSummary.empty();
  return ref.watch(financeOpsServiceProvider).clubOperations(club.id);
});

/// Onayımı bekleyen giderler. Kendi kaydım listede yok.
final pendingApprovalsProvider =
    FutureProvider.autoDispose<List<ExpenseRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeOpsServiceProvider).pendingApprovals(club.id);
});
