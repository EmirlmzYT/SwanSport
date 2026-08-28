import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Moderasyon — şikayet, engelleme ve hesap silme.
/// ---------------------------------------------------------------------------

/// Şikayet sebepleri (kullanıcıya gösterilen etiketleriyle).
const List<({String key, String label})> kReportReasons = [
  (key: 'spam', label: 'Spam veya reklam'),
  (key: 'taciz', label: 'Taciz veya hakaret'),
  (key: 'uygunsuz', label: 'Uygunsuz içerik'),
  (key: 'yanlis_bilgi', label: 'Yanlış bilgi'),
  (key: 'diger', label: 'Diğer'),
];

class ReportRow {
  const ReportRow({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.createdAt,
    this.detail,
    this.reporterName,
  });

  final String id;
  final String targetType; // post | comment | profile
  final String targetId;
  final String reason;
  final DateTime createdAt;
  final String? detail;
  final String? reporterName;

  String get targetLabel => switch (targetType) {
        'post' => 'Gönderi',
        'comment' => 'Yorum',
        _ => 'Kullanıcı',
      };

  String get reasonLabel {
    for (final r in kReportReasons) {
      if (r.key == reason) return r.label;
    }
    return reason;
  }

  factory ReportRow.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'];
    return ReportRow(
      id: m['id'] as String,
      targetType: (m['target_type'] as String?) ?? 'post',
      targetId: m['target_id'] as String,
      reason: (m['reason'] as String?) ?? 'diger',
      detail: m['detail'] as String?,
      reporterName: p is Map ? p['full_name'] as String? : null,
      createdAt:
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}

class ModerationService {
  ModerationService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  // ------------------------------ şikayet ------------------------------
  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? detail,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı');
    await _c.from('content_reports').insert({
      'reporter_id': uid,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
    });
  }

  /// Platform yöneticisi için açık şikayetler.
  Future<List<ReportRow>> openReports() async {
    final rows = await _c
        .from('content_reports')
        .select('id, target_type, target_id, reason, detail, created_at, '
            'profiles!content_reports_reporter_id_fkey(full_name)')
        .eq('status', 'open')
        .order('created_at');
    return (rows as List)
        .map((r) => ReportRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Şikayeti sonuçlandır. [deleteContent] true ise içerik de silinir.
  Future<void> reviewReport(String id,
      {required bool dismiss, bool deleteContent = false, String? note}) async {
    await _c.rpc<void>('review_report', params: {
      'p_report': id,
      'p_action': dismiss ? 'dismissed' : 'reviewed',
      'p_delete_content': deleteContent,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
    });
  }

  // ----------------------------- engelleme -----------------------------
  Future<void> block(String profileId) async {
    final uid = _uid;
    if (uid == null) return;
    await _c
        .from('blocks')
        .upsert({'blocker_id': uid, 'blocked_id': profileId});
  }

  Future<void> unblock(String profileId) async {
    final uid = _uid;
    if (uid == null) return;
    await _c
        .from('blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', profileId);
  }

  Future<bool> isBlocked(String profileId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _c
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', uid)
        .eq('blocked_id', profileId)
        .maybeSingle();
    return row != null;
  }

  /// Engellenen ve engelleyen kişilerin kimlikleri — içerik gizlemede kullanılır.
  Future<Set<String>> hiddenProfiles() async {
    if (_uid == null) return <String>{};
    final rows = await _c.rpc<List<dynamic>>('hidden_profiles');
    return rows.map((r) => r.toString()).toSet();
  }

  Future<List<({String id, String name})>> myBlocks() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('blocks')
        .select('blocked_id, profiles!blocks_blocked_id_fkey(full_name)')
        .eq('blocker_id', uid);
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final p = m['profiles'];
      return (
        id: m['blocked_id'] as String,
        name: (p is Map ? p['full_name'] as String? : null) ?? 'Kullanıcı',
      );
    }).toList();
  }

  // ---------------------------- hesap silme ----------------------------
  Future<void> deleteMyAccount() async {
    await _c.rpc<void>('delete_my_account');
  }
}

// =============================== Provider'lar ==============================

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(ref.watch(supabaseClientProvider));
});

/// Engellenen/engelleyen kişiler — akış ve yorumlarda gizlenir.
final hiddenProfilesProvider = FutureProvider<Set<String>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(<String>{});
  return ref.watch(moderationServiceProvider).hiddenProfiles();
});

final openReportsProvider = FutureProvider.autoDispose<List<ReportRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(moderationServiceProvider).openReports();
});

final myBlocksProvider =
    FutureProvider.autoDispose<List<({String id, String name})>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(moderationServiceProvider).myBlocks();
});
