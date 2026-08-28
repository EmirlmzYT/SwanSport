import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'supabase_athletes.dart';

/// ---------------------------------------------------------------------------
/// Kulüp başvuruları — kişi kulübe başvurur, kulüp yetkilisi karar verir.
/// ---------------------------------------------------------------------------

class ClubApplicationRow {
  const ClubApplicationRow({
    required this.id,
    required this.clubId,
    required this.profileId,
    required this.desiredRole,
    required this.status,
    required this.createdAt,
    this.message,
    this.personName,
    this.clubName,
    this.reviewNote,
  });

  final String id;
  final String clubId;
  final String profileId;
  final String desiredRole; // athlete | coach
  final String status; // pending | accepted | rejected
  final DateTime createdAt;
  final String? message;
  final String? personName;
  final String? clubName;
  final String? reviewNote;

  bool get isPending => status == 'pending';

  String get roleLabel => desiredRole == 'coach' ? 'Antrenör' : 'Sporcu';

  String get statusLabel => switch (status) {
        'accepted' => 'Kabul edildi',
        'rejected' => 'Reddedildi',
        _ => 'Bekliyor',
      };

  String get initials {
    final n = (personName ?? clubName ?? '?').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final res = '$a$b'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }
}

class ClubApplicationService {
  ClubApplicationService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  /// Kulübe başvur. [role] 'athlete' veya 'coach'.
  Future<void> apply(String clubId,
      {String role = 'athlete', String? message}) async {
    await _c.rpc<void>('apply_to_club', params: {
      'p_club': clubId,
      'p_role': role,
      if (message != null && message.trim().isNotEmpty)
        'p_message': message.trim(),
    });
  }

  /// Kulüp adına bir kişiye katılım teklifi gönder.
  Future<void> offerToPerson(String clubId, String profileId,
      {String role = 'athlete', String? message}) async {
    await _c.rpc<void>('offer_to_person', params: {
      'p_club': clubId,
      'p_profile': profileId,
      'p_role': role,
      if (message != null && message.trim().isNotEmpty)
        'p_message': message.trim(),
    });
  }

  /// Başvuru/teklifi kabul et veya reddet.
  ///
  /// Antrenör kabul edilirken [coachLevel] ve (1. kademe için) [supervisorId]
  /// verilir; üyelik bu bilgilerle oluşturulur.
  Future<void> review(
    String applicationId,
    bool accept, {
    String? note,
    int? coachLevel,
    String? supervisorId,
  }) async {
    await _c.rpc<void>('review_club_application', params: {
      'p_application': applicationId,
      'p_accept': accept,
      if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      if (coachLevel != null) 'p_coach_level': coachLevel,
      if (supervisorId != null) 'p_supervisor': supervisorId,
    });
  }

  /// Kulüpteki olası süpervizörler (2. kademe ve üstü).
  Future<List<({String profileId, String name, int level})>>
      eligibleSupervisors(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('eligible_supervisors', params: {'p_club': clubId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return (
        profileId: m['profile_id'] as String,
        name: ((m['full_name'] as String?) ?? '').trim().isEmpty
            ? 'Antrenör'
            : m['full_name'] as String,
        level: (m['coach_level'] as int?) ?? 2,
      );
    }).toList();
  }

  /// Bana gelen bekleyen teklifler.
  Future<List<ClubApplicationRow>> myPendingOffers() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('club_applications')
        .select('id, club_id, profile_id, desired_role, status, message, '
            'created_at, kind, clubs(name)')
        .eq('profile_id', uid)
        .eq('kind', 'offer')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final club = m['clubs'];
      return ClubApplicationRow(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        profileId: m['profile_id'] as String,
        desiredRole: (m['desired_role'] as String?) ?? 'athlete',
        status: (m['status'] as String?) ?? 'pending',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
        message: m['message'] as String?,
        clubName: club is Map ? club['name'] as String? : null,
      );
    }).toList();
  }

  /// Ferdi (kulüpsüz) sporcu kaydını oluşturur; varsa mevcut kaydı döner.
  Future<void> createIndividualAthlete() async {
    await _c.rpc<void>('ensure_individual_athlete');
  }

  /// 18 yaş altı olup velisi bağlı olmayan sporcu mu?
  Future<bool> needsGuardian(String athleteId) async {
    final res = await _c
        .rpc<bool>('athlete_needs_guardian', params: {'p_athlete': athleteId});
    return res;
  }

  Future<void> withdraw(String applicationId) async {
    await _c.from('club_applications').delete().eq('id', applicationId);
  }

  /// Kişinin kendi başvuruları.
  Future<List<ClubApplicationRow>> myApplications() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('club_applications')
        .select('id, club_id, profile_id, desired_role, status, message, '
            'created_at, review_note, clubs(name)')
        .eq('profile_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final club = m['clubs'];
      return ClubApplicationRow(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        profileId: m['profile_id'] as String,
        desiredRole: (m['desired_role'] as String?) ?? 'athlete',
        status: (m['status'] as String?) ?? 'pending',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
        message: m['message'] as String?,
        reviewNote: m['review_note'] as String?,
        clubName: club is Map ? club['name'] as String? : null,
      );
    }).toList();
  }

  /// Aktif kulübe gelen bekleyen başvurular (yetkili görür).
  Future<List<ClubApplicationRow>> pendingForClub(String clubId) async {
    final rows = await _c
        .from('club_applications')
        .select('id, club_id, profile_id, desired_role, status, message, '
            'created_at, profiles!club_applications_profile_id_fkey(full_name)')
        .eq('club_id', clubId)
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final prof = m['profiles'];
      return ClubApplicationRow(
        id: m['id'] as String,
        clubId: m['club_id'] as String,
        profileId: m['profile_id'] as String,
        desiredRole: (m['desired_role'] as String?) ?? 'athlete',
        status: (m['status'] as String?) ?? 'pending',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
        message: m['message'] as String?,
        personName: prof is Map ? prof['full_name'] as String? : null,
      );
    }).toList();
  }
}

// =============================== Provider'lar ==============================

final clubApplicationServiceProvider = Provider<ClubApplicationService>((ref) {
  return ClubApplicationService(ref.watch(supabaseClientProvider));
});

/// Kişinin kendi başvuruları.
final myApplicationsProvider =
    FutureProvider.autoDispose<List<ClubApplicationRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(clubApplicationServiceProvider).myApplications();
});

/// Bana gelen bekleyen kulüp teklifleri.
final myPendingOffersProvider =
    FutureProvider.autoDispose<List<ClubApplicationRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(clubApplicationServiceProvider).myPendingOffers();
});

/// Sporcunun veli bağı eksik mi (18 yaş altı).
final needsGuardianProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, athleteId) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(false);
  return ref.watch(clubApplicationServiceProvider).needsGuardian(athleteId);
});

/// Aktif kulübe gelen bekleyen başvurular.
final clubPendingApplicationsProvider =
    FutureProvider.autoDispose<List<ClubApplicationRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubApplicationServiceProvider).pendingForClub(club.id);
});
