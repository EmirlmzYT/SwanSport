import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'finance_ops_service.dart';
import 'finance_service.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';

class ClubDuesSummary {
  const ClubDuesSummary({
    required this.billed,
    required this.collected,
    required this.outstanding,
    required this.paidCount,
    required this.partialCount,
    required this.pendingCount,
    required this.overdueCount,
    required this.pendingPaymentCount,
  });

  final num billed;
  final num collected;
  final num outstanding;
  final int paidCount;
  final int partialCount;
  final int pendingCount;
  final int overdueCount;
  final int pendingPaymentCount;

  static const empty = ClubDuesSummary(
    billed: 0,
    collected: 0,
    outstanding: 0,
    paidCount: 0,
    partialCount: 0,
    pendingCount: 0,
    overdueCount: 0,
    pendingPaymentCount: 0,
  );

  factory ClubDuesSummary.fromMap(Map<String, dynamic> map) => ClubDuesSummary(
        billed: (map['billed'] as num?) ?? 0,
        collected: (map['collected'] as num?) ?? 0,
        outstanding: (map['outstanding'] as num?) ?? 0,
        paidCount: (map['paid_count'] as num?)?.toInt() ?? 0,
        partialCount: (map['partial_count'] as num?)?.toInt() ?? 0,
        pendingCount: (map['pending_count'] as num?)?.toInt() ?? 0,
        overdueCount: (map['overdue_count'] as num?)?.toInt() ?? 0,
        pendingPaymentCount:
            (map['pending_payment_count'] as num?)?.toInt() ?? 0,
      );
}

class ClubDueInvoice {
  const ClubDueInvoice({
    required this.id,
    required this.athleteName,
    required this.label,
    required this.amount,
    required this.confirmedAmount,
    required this.pendingAmount,
    required this.balance,
    required this.status,
    this.athleteId,
    this.period,
    this.dueDate,
  });

  final String id;
  final String? athleteId;
  final String athleteName;
  final String label;
  final num amount;
  final num confirmedAmount;
  final num pendingAmount;
  final num balance;
  final String status;
  final String? period;
  final DateTime? dueDate;

  factory ClubDueInvoice.fromMap(Map<String, dynamic> map) => ClubDueInvoice(
        id: map['id'] as String,
        athleteId: map['athlete_id'] as String?,
        athleteName: (map['athlete_name'] as String?) ?? 'Sporcu',
        label: (map['label'] as String?) ?? 'Aidat',
        amount: (map['amount'] as num?) ?? 0,
        confirmedAmount: (map['confirmed_amount'] as num?) ?? 0,
        pendingAmount: (map['pending_amount'] as num?) ?? 0,
        balance: (map['balance'] as num?) ?? 0,
        status: (map['status'] as String?) ?? 'pending',
        period: map['period'] as String?,
        dueDate: map['due_date'] == null
            ? null
            : DateTime.tryParse('${map['due_date']}'),
      );
}

class ClubPaymentHistoryItem {
  const ClubPaymentHistoryItem({
    required this.id,
    required this.athleteName,
    required this.label,
    required this.amount,
    required this.method,
    required this.status,
    required this.paidAt,
    required this.createdAt,
    this.invoiceId,
    this.receiptUrl,
  });

  final String id;
  final String? invoiceId;
  final String athleteName;
  final String label;
  final num amount;
  final String method;
  final String status;
  final DateTime paidAt;
  final DateTime createdAt;
  final String? receiptUrl;
}

class ClubDuesOverview {
  const ClubDuesOverview({
    required this.summary,
    this.invoices = const [],
    this.payments = const [],
    this.plans = const [],
    this.periods = const [],
  });

  final ClubDuesSummary summary;
  final List<ClubDueInvoice> invoices;
  final List<ClubPaymentHistoryItem> payments;
  final List<FeePlan> plans;
  final List<String> periods;

  static const empty = ClubDuesOverview(summary: ClubDuesSummary.empty);
}

class ClubDuesManagementService {
  ClubDuesManagementService(this._client);

  final SupabaseClient _client;

  Future<ClubDuesOverview> overview(String clubId, {String? period}) async {
    final raw = await _client.rpc<dynamic>(
      'pro_club_dues_overview',
      params: {'p_club': clubId, 'p_period': period},
    );
    final map = (raw as Map).cast<String, dynamic>();
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) fromMap) =>
        (map[key] as List? ?? const [])
            .map((row) => fromMap((row as Map).cast<String, dynamic>()))
            .toList(growable: false);
    final payments = (map['payments'] as List? ?? const []).map((row) {
      final item = (row as Map).cast<String, dynamic>();
      final receipt = item['receipt_path'] as String?;
      return ClubPaymentHistoryItem(
        id: item['id'] as String,
        invoiceId: item['invoice_id'] as String?,
        athleteName: (item['athlete_name'] as String?) ?? 'Sporcu',
        label: (item['label'] as String?) ?? 'Ödeme',
        amount: (item['amount'] as num?) ?? 0,
        method: (item['method'] as String?) ?? 'diger',
        status: (item['status'] as String?) ?? 'pending',
        paidAt: DateTime.parse('${item['paid_at']}'),
        createdAt: DateTime.parse('${item['created_at']}').toLocal(),
        receiptUrl: receipt == null || receipt.isEmpty
            ? null
            : _client.storage
                .from(FinanceService.receiptsBucket)
                .getPublicUrl(receipt),
      );
    }).toList(growable: false);
    return ClubDuesOverview(
      summary: ClubDuesSummary.fromMap(
        ((map['summary'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      invoices: parse('invoices', ClubDueInvoice.fromMap),
      payments: payments,
      plans: parse('plans', FeePlan.fromMap),
      periods: (map['periods'] as List? ?? const [])
          .map((value) => '$value')
          .toList(growable: false),
    );
  }

  Future<String> decidePayment(
    String paymentId, {
    required bool approve,
    String? note,
  }) async =>
      await _client.rpc<String>(
        'pro_decide_payment',
        params: {
          'p_payment': paymentId,
          'p_approve': approve,
          'p_note': note,
        },
      );

  Future<String> recordPayment({
    required String invoiceId,
    required num amount,
    required String method,
    String? note,
    required String operationId,
  }) async =>
      await _client.rpc<String>(
        'pro_record_payment',
        params: {
          'p_invoice': invoiceId,
          'p_amount': amount,
          'p_method': method,
          'p_note': note,
          'p_operation': operationId,
        },
      );
}

final clubDuesManagementServiceProvider =
    Provider<ClubDuesManagementService>((ref) {
  return ClubDuesManagementService(ref.watch(supabaseClientProvider));
});

final clubDuesPeriodProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final clubDuesOverviewProvider =
    FutureProvider.autoDispose<ClubDuesOverview>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return ClubDuesOverview.empty;
  final club = await ref.watch(activeClubProvider.future);
  if (club == null || club.role != 'club_admin') {
    throw StateError('Kulüp yöneticisi yetkisi gerekli.');
  }
  return ref.watch(clubDuesManagementServiceProvider).overview(
        club.id,
        period: ref.watch(clubDuesPeriodProvider),
      );
});

String newFinanceOperationId() => newOpId();
