import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'supabase_athletes.dart';

/// ---------------------------------------------------------------------------
/// Aidat, tahsilat ve bağış — gerçek veri katmanı.
///
/// Tahsilat modeli: kulüp IBAN'ını tanımlar, veli havale yapıp "ödedim" der,
/// kulüp dekontu görüp onaylayınca borç kapanır. Nakit tahsilatı kulüp
/// doğrudan onaylı olarak girer.
/// ---------------------------------------------------------------------------

/// Tutarı okunur biçimde yazar: 1500 → "1.500 ₺"
String money(num v) {
  final whole = v.round();
  final s = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${whole < 0 ? '-' : ''}$buf ₺';
}

class FeePlan {
  const FeePlan({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.active,
  });

  final String id;
  final String name;
  final num amount;
  final int dueDay;
  final bool active;

  factory FeePlan.fromMap(Map<String, dynamic> m) => FeePlan(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        amount: (m['amount'] as num?) ?? 0,
        dueDay: (m['due_day'] as int?) ?? 10,
        active: (m['active'] as bool?) ?? true,
      );
}

class FinanceSummary {
  const FinanceSummary({
    required this.billed,
    required this.collected,
    required this.outstanding,
    required this.overdueCount,
    required this.overdueTotal,
    required this.pendingPayments,
    required this.athletesWithFee,
  });

  final num billed;
  final num collected;
  final num outstanding;
  final int overdueCount;
  final num overdueTotal;
  final int pendingPayments;
  final int athletesWithFee;

  /// Tahsilat oranı (0..1) — hiç tahakkuk yoksa 0.
  double get rate => billed == 0 ? 0 : (collected / billed).clamp(0, 1).toDouble();

  static const empty = FinanceSummary(
    billed: 0,
    collected: 0,
    outstanding: 0,
    overdueCount: 0,
    overdueTotal: 0,
    pendingPayments: 0,
    athletesWithFee: 0,
  );

  factory FinanceSummary.fromMap(Map<String, dynamic> m) => FinanceSummary(
        billed: (m['billed'] as num?) ?? 0,
        collected: (m['collected'] as num?) ?? 0,
        outstanding: (m['outstanding'] as num?) ?? 0,
        overdueCount: (m['overdue_count'] as int?) ?? 0,
        overdueTotal: (m['overdue_total'] as num?) ?? 0,
        pendingPayments: (m['pending_payments'] as int?) ?? 0,
        athletesWithFee: (m['athletes_with_fee'] as int?) ?? 0,
      );
}

class FeeRow {
  const FeeRow({
    required this.invoiceId,
    required this.label,
    required this.amount,
    required this.status,
    required this.overdue,
    this.athleteId,
    this.athleteName,
    this.clubName,
    this.clubId,
    this.dueDate,
    this.period,
    this.pendingDeclared = false,
  });

  final String invoiceId;
  final String label;
  final num amount;
  final String status; // pending | paid | overdue
  final bool overdue;
  final String? athleteId;
  final String? athleteName;
  final String? clubName;
  final String? clubId;
  final DateTime? dueDate;
  final String? period;

  /// Ödeme bildirimi yapılmış, kulüp onayı bekliyor.
  final bool pendingDeclared;

  bool get isPaid => status == 'paid';

  String get statusLabel {
    if (isPaid) return 'Ödendi';
    if (pendingDeclared) return 'Onay bekliyor';
    if (overdue) return 'Gecikmiş';
    return 'Ödenmedi';
  }

  factory FeeRow.fromLedger(Map<String, dynamic> m) => FeeRow(
        invoiceId: m['invoice_id'] as String,
        athleteId: m['athlete_id'] as String?,
        athleteName: ((m['athlete_name'] as String?) ?? '').trim().isEmpty
            ? 'Sporcu'
            : (m['athlete_name'] as String).trim(),
        label: (m['label'] as String?) ?? '',
        amount: (m['amount'] as num?) ?? 0,
        status: (m['status'] as String?) ?? 'pending',
        overdue: (m['overdue'] as bool?) ?? false,
        period: m['period'] as String?,
        dueDate: m['due_date'] == null
            ? null
            : DateTime.tryParse('${m['due_date']}'),
      );

  factory FeeRow.fromMine(Map<String, dynamic> m) => FeeRow(
        invoiceId: m['invoice_id'] as String,
        athleteName: ((m['athlete_name'] as String?) ?? '').trim(),
        clubName: m['club_name'] as String?,
        clubId: m['club_id'] as String?,
        label: (m['label'] as String?) ?? '',
        amount: (m['amount'] as num?) ?? 0,
        status: (m['status'] as String?) ?? 'pending',
        overdue: (m['overdue'] as bool?) ?? false,
        pendingDeclared: (m['pending_declared'] as bool?) ?? false,
        dueDate: m['due_date'] == null
            ? null
            : DateTime.tryParse('${m['due_date']}'),
      );
}

class PendingPayment {
  const PendingPayment({
    required this.id,
    required this.amount,
    required this.method,
    required this.label,
    required this.paidAt,
    this.athleteName,
    this.declaredName,
    this.note,
    this.receiptUrl,
  });

  final String id;
  final num amount;
  final String method;
  final String label;
  final DateTime paidAt;
  final String? athleteName;
  final String? declaredName;
  final String? note;
  final String? receiptUrl;
}

class Campaign {
  const Campaign({
    required this.id,
    required this.clubId,
    required this.title,
    required this.target,
    required this.collected,
    required this.supporters,
    required this.status,
    required this.canManage,
    required this.pendingCount,
    this.clubName,
    this.description,
    this.endsAt,
    this.coverUrl,
  });

  final String id;
  final String clubId;
  final String title;
  final num target;
  final num collected;
  final int supporters;
  final String status;
  final bool canManage;
  final int pendingCount;
  final String? clubName;
  final String? description;
  final DateTime? endsAt;
  final String? coverUrl;

  bool get isActive => status == 'active';

  /// Hedefe ulaşma oranı (0..1). Hedef tanımsızsa 0.
  double get progress =>
      target <= 0 ? 0 : (collected / target).clamp(0, 1).toDouble();

  int get percent => (progress * 100).round();
}

class DonorRow {
  const DonorRow({
    required this.id,
    required this.name,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.canManage,
    this.message,
  });

  final String id;
  final String name;
  final num amount;
  final String status;
  final DateTime createdAt;
  final bool canManage;
  final String? message;

  bool get isPending => status == 'pending';
}

class FinanceService {
  FinanceService(this._c);
  final SupabaseClient _c;

  static const String receiptsBucket = 'post-media';

  // ------------------------------- planlar --------------------------------
  Future<List<FeePlan>> plans(String clubId) async {
    final rows = await _c
        .from('fee_plans')
        .select('id, name, amount, due_day, active')
        .eq('club_id', clubId)
        .order('created_at');
    return (rows as List)
        .map((r) => FeePlan.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> createPlan(String clubId, String name, num amount,
      {int dueDay = 10}) async {
    await _c.from('fee_plans').insert({
      'club_id': clubId,
      'name': name.trim(),
      'amount': amount,
      'due_day': dueDay,
    });
  }

  Future<void> setPlanActive(String planId, bool active) async {
    await _c.from('fee_plans').update({'active': active}).eq('id', planId);
  }

  /// Sporcuya aidat atar. [customAmount] verilirse plandaki tutarın yerine
  /// geçer (burs, kardeş indirimi).
  Future<void> assignFee({
    required String clubId,
    required String athleteId,
    required String planId,
    num? customAmount,
    String? note,
  }) async {
    await _c.from('athlete_fees').upsert({
      'athlete_id': athleteId,
      'club_id': clubId,
      'plan_id': planId,
      'custom_amount': customAmount,
      'note': note,
      'active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'athlete_id');
  }

  Future<void> removeFee(String athleteId) async {
    await _c.from('athlete_fees').delete().eq('athlete_id', athleteId);
  }

  /// Hangi sporcuya hangi aidat atanmış?
  Future<Map<String, ({String planId, num? custom, String? note})>> assignments(
      String clubId) async {
    final rows = await _c
        .from('athlete_fees')
        .select('athlete_id, plan_id, custom_amount, note')
        .eq('club_id', clubId)
        .eq('active', true);
    final out = <String, ({String planId, num? custom, String? note})>{};
    for (final r in rows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final plan = m['plan_id'] as String?;
      if (plan == null) continue;
      out[m['athlete_id'] as String] = (
        planId: plan,
        custom: m['custom_amount'] as num?,
        note: m['note'] as String?,
      );
    }
    return out;
  }

  // ------------------------------ tahakkuk --------------------------------
  /// Dönem için borçları üretir; kaç yeni fatura oluştuğunu döner.
  Future<int> generateCharges(String clubId, {String? period}) async {
    return await _c.rpc<int>('generate_fee_charges', params: {
      'p_club': clubId,
      if (period != null) 'p_period': period,
    });
  }

  Future<void> addExtraCharge({
    required String clubId,
    required String athleteId,
    required String label,
    required num amount,
    DateTime? due,
  }) async {
    await _c.rpc<void>('add_extra_charge', params: {
      'p_club': clubId,
      'p_athlete': athleteId,
      'p_label': label.trim(),
      'p_amount': amount,
      if (due != null) 'p_due': due.toIso8601String().split('T').first,
    });
  }

  // ------------------------------- raporlar -------------------------------
  Future<FinanceSummary> summary(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('club_finance_summary', params: {'p_club': clubId});
    if (rows.isEmpty) return FinanceSummary.empty;
    return FinanceSummary.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  Future<List<FeeRow>> ledger(String clubId, {String? period}) async {
    final rows = await _c.rpc<List<dynamic>>('club_fee_ledger', params: {
      'p_club': clubId,
      if (period != null) 'p_period': period,
    });
    return rows
        .map((r) => FeeRow.fromLedger((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FeeRow>> myFees() async {
    final rows = await _c.rpc<List<dynamic>>('my_fees');
    return rows
        .map((r) => FeeRow.fromMine((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<PendingPayment>> pendingPayments(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('pending_payments', params: {'p_club': clubId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final receipt = m['receipt_path'] as String?;
      return PendingPayment(
        id: m['id'] as String,
        athleteName: ((m['athlete_name'] as String?) ?? '').trim().isEmpty
            ? null
            : (m['athlete_name'] as String).trim(),
        label: (m['label'] as String?) ?? '',
        amount: (m['amount'] as num?) ?? 0,
        method: (m['method'] as String?) ?? 'havale',
        paidAt: DateTime.tryParse('${m['paid_at']}') ?? DateTime.now(),
        note: m['note'] as String?,
        declaredName: m['declared_name'] as String?,
        receiptUrl: (receipt == null || receipt.isEmpty)
            ? null
            : _c.storage.from(receiptsBucket).getPublicUrl(receipt),
      );
    }).toList();
  }

  // ------------------------------- ödemeler -------------------------------
  /// Dekontu yükler, storage yolunu döner.
  Future<String> uploadReceipt(Uint8List bytes, String name) async {
    final uid = _c.auth.currentUser?.id ?? 'anon';
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : 'jpg';
    final path = '$uid/dekont_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from(receiptsBucket).uploadBinary(path, bytes,
        fileOptions: const FileOptions(upsert: true));
    return path;
  }

  Future<void> declarePayment({
    required String invoiceId,
    num? amount,
    String method = 'havale',
    DateTime? paidAt,
    String? note,
    String? receiptPath,
  }) async {
    await _c.rpc<void>('declare_payment', params: {
      'p_invoice': invoiceId,
      if (amount != null) 'p_amount': amount,
      'p_method': method,
      if (paidAt != null)
        'p_paid_at': paidAt.toIso8601String().split('T').first,
      if (note != null && note.isNotEmpty) 'p_note': note,
      if (receiptPath != null) 'p_receipt': receiptPath,
    });
  }

  Future<void> confirmPayment(String paymentId, bool approve,
      {String? note}) async {
    await _c.rpc<void>('confirm_payment', params: {
      'p_payment': paymentId,
      'p_approve': approve,
      if (note != null && note.isNotEmpty) 'p_note': note,
    });
  }

  /// Kulüp elden/nakit tahsilat girer — onay adımı yok.
  Future<void> recordPayment(String invoiceId,
      {num? amount, String method = 'nakit', String? note}) async {
    await _c.rpc<void>('record_payment', params: {
      'p_invoice': invoiceId,
      if (amount != null) 'p_amount': amount,
      'p_method': method,
      if (note != null && note.isNotEmpty) 'p_note': note,
    });
  }

  // ------------------------------- bağışlar -------------------------------
  Future<List<Campaign>> campaigns({String? clubId}) async {
    final rows = await _c.rpc<List<dynamic>>('campaigns',
        params: {if (clubId != null) 'p_club': clubId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final cover = m['cover_path'] as String?;
      return Campaign(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        clubName: m['club_name'] as String?,
        title: (m['title'] as String?) ?? '',
        description: m['description'] as String?,
        target: (m['target'] as num?) ?? 0,
        collected: (m['collected'] as num?) ?? 0,
        supporters: (m['supporters'] as int?) ?? 0,
        status: (m['status'] as String?) ?? 'active',
        canManage: (m['can_manage'] as bool?) ?? false,
        pendingCount: (m['pending_count'] as int?) ?? 0,
        endsAt: m['ends_at'] == null
            ? null
            : DateTime.tryParse('${m['ends_at']}'),
        coverUrl: (cover == null || cover.isEmpty)
            ? null
            : _c.storage.from(receiptsBucket).getPublicUrl(cover),
      );
    }).toList();
  }

  Future<void> createCampaign({
    required String clubId,
    required String title,
    required num target,
    String? description,
    DateTime? endsAt,
  }) async {
    await _c.from('donation_campaigns').insert({
      'club_id': clubId,
      'title': title.trim(),
      'target': target,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (endsAt != null)
        'ends_at': endsAt.toIso8601String().split('T').first,
      'created_by': _c.auth.currentUser?.id,
    });
  }

  Future<void> closeCampaign(String id) async {
    await _c
        .from('donation_campaigns')
        .update({'status': 'closed'}).eq('id', id);
  }

  Future<List<DonorRow>> donors(String campaignId) async {
    final rows = await _c
        .rpc<List<dynamic>>('campaign_donors', params: {'p_campaign': campaignId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return DonorRow(
        id: m['id'] as String,
        name: (m['donor_name'] as String?) ?? 'Bağışçı',
        amount: (m['amount'] as num?) ?? 0,
        message: m['message'] as String?,
        status: (m['status'] as String?) ?? 'pending',
        canManage: (m['can_manage'] as bool?) ?? false,
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> donate({
    required String campaignId,
    required num amount,
    String? message,
    bool anonymous = false,
    String? receiptPath,
  }) async {
    await _c.rpc<void>('donate', params: {
      'p_campaign': campaignId,
      'p_amount': amount,
      if (message != null && message.trim().isNotEmpty)
        'p_message': message.trim(),
      'p_anonymous': anonymous,
      if (receiptPath != null) 'p_receipt': receiptPath,
    });
  }

  Future<void> confirmDonation(String id, bool approve) async {
    await _c.rpc<void>('confirm_donation',
        params: {'p_donation': id, 'p_approve': approve});
  }

  // ------------------------------ banka bilgisi ----------------------------
  Future<({String? iban, String? bank, String? holder})> bankInfo(
      String clubId) async {
    final row = await _c
        .from('clubs')
        .select('iban, bank_name, account_holder')
        .eq('id', clubId)
        .maybeSingle();
    return (
      iban: row?['iban'] as String?,
      bank: row?['bank_name'] as String?,
      holder: row?['account_holder'] as String?,
    );
  }

  Future<void> setBankInfo(String clubId,
      {String? iban, String? bank, String? holder}) async {
    await _c.from('clubs').update({
      'iban': iban?.trim(),
      'bank_name': bank?.trim(),
      'account_holder': holder?.trim(),
    }).eq('id', clubId);
  }
}

// =============================== Provider'lar ==============================

final financeServiceProvider = Provider<FinanceService>((ref) {
  return FinanceService(ref.watch(supabaseClientProvider));
});

/// Aktif kulübün mali özeti.
final financeSummaryProvider =
    FutureProvider.autoDispose<FinanceSummary>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return FinanceSummary.empty;
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return FinanceSummary.empty;
  return ref.watch(financeServiceProvider).summary(club.id);
});

/// Borç listesi — parametre dönem (boş = tüm dönemler).
final feeLedgerProvider =
    FutureProvider.autoDispose.family<List<FeeRow>, String>((ref, period) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref
      .watch(financeServiceProvider)
      .ledger(club.id, period: period.isEmpty ? null : period);
});

final feePlansProvider = FutureProvider.autoDispose<List<FeePlan>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeServiceProvider).plans(club.id);
});

final feeAssignmentsProvider = FutureProvider.autoDispose<
    Map<String, ({String planId, num? custom, String? note})>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const {};
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const {};
  return ref.watch(financeServiceProvider).assignments(club.id);
});

final pendingPaymentsProvider =
    FutureProvider.autoDispose<List<PendingPayment>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(financeServiceProvider).pendingPayments(club.id);
});

/// Sporcunun/velinin kendi borçları.
final myFeesProvider = FutureProvider.autoDispose<List<FeeRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <FeeRow>[]);
  }
  return ref.watch(financeServiceProvider).myFees();
});

/// Bağış kampanyaları — boş parametre tüm kulüpleri getirir.
final campaignsProvider =
    FutureProvider.autoDispose.family<List<Campaign>, String>((ref, clubId) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <Campaign>[]);
  }
  return ref
      .watch(financeServiceProvider)
      .campaigns(clubId: clubId.isEmpty ? null : clubId);
});

final campaignDonorsProvider =
    FutureProvider.autoDispose.family<List<DonorRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <DonorRow>[]);
  }
  return ref.watch(financeServiceProvider).donors(id);
});

final clubBankInfoProvider = FutureProvider.autoDispose<
    ({String? iban, String? bank, String? holder})>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null || !ref.watch(isSupabaseEnabledProvider)) {
    return (iban: null, bank: null, holder: null);
  }
  return ref.watch(financeServiceProvider).bankInfo(club.id);
});
