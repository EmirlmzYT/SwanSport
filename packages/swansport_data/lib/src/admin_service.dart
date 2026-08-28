import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Platform yönetimi — özet sayılar, kişi yönetimi, işlem geçmişi.
///
/// Onay/ret işlemlerinin kendisi `verification_service.dart` içinde kalır;
/// burası panelin çevresindeki yönetim işleri.
/// ---------------------------------------------------------------------------

class PlatformStats {
  const PlatformStats({
    required this.people,
    required this.clubsActive,
    required this.clubsPending,
    required this.coaches,
    required this.athletes,
    required this.posts,
    required this.credsPending,
    required this.reportsOpen,
  });

  final int people;
  final int clubsActive;
  final int clubsPending;
  final int coaches;
  final int athletes;
  final int posts;
  final int credsPending;
  final int reportsOpen;

  /// Yöneticiyi bekleyen toplam iş.
  int get pendingTotal => clubsPending + credsPending + reportsOpen;

  static const empty = PlatformStats(
    people: 0,
    clubsActive: 0,
    clubsPending: 0,
    coaches: 0,
    athletes: 0,
    posts: 0,
    credsPending: 0,
    reportsOpen: 0,
  );

  factory PlatformStats.fromMap(Map<String, dynamic> m) => PlatformStats(
        people: (m['people'] as int?) ?? 0,
        clubsActive: (m['clubs_active'] as int?) ?? 0,
        clubsPending: (m['clubs_pending'] as int?) ?? 0,
        coaches: (m['coaches'] as int?) ?? 0,
        athletes: (m['athletes'] as int?) ?? 0,
        posts: (m['posts'] as int?) ?? 0,
        credsPending: (m['creds_pending'] as int?) ?? 0,
        reportsOpen: (m['reports_open'] as int?) ?? 0,
      );
}

class AdminPerson {
  const AdminPerson({
    required this.id,
    required this.name,
    required this.isAdmin,
    this.username,
    this.cityName,
    this.credentials,
    this.clubName,
  });

  final String id;
  final String name;
  final bool isAdmin;
  final String? username;
  final String? cityName;
  final String? credentials;
  final String? clubName;

  String get initials => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// Alt satırda gösterilecek künye — boş alanlar atlanır.
  String get subtitle {
    final parts = <String>[
      if (username != null && username!.isNotEmpty) '@$username',
      if (credentials != null && credentials!.isNotEmpty) credentials!,
      if (clubName != null && clubName!.isNotEmpty) clubName!,
      if (cityName != null && cityName!.isNotEmpty) cityName!,
    ];
    return parts.isEmpty ? 'Kayıtlı kullanıcı' : parts.join(' · ');
  }

  factory AdminPerson.fromMap(Map<String, dynamic> m) => AdminPerson(
        id: m['id'] as String,
        name: ((m['full_name'] as String?) ?? '').trim().isEmpty
            ? 'Kullanıcı'
            : (m['full_name'] as String).trim(),
        username: m['username'] as String?,
        cityName: m['city_name'] as String?,
        isAdmin: (m['is_admin'] as bool?) ?? false,
        credentials: m['credentials'] as String?,
        clubName: m['club_name'] as String?,
      );
}

class ReviewLogRow {
  const ReviewLogRow({
    required this.kind,
    required this.subject,
    required this.approved,
    required this.reviewedAt,
    this.detail,
    this.note,
    this.reviewer,
  });

  final String kind; // credential | club
  final String subject;
  final bool approved;
  final DateTime reviewedAt;
  final String? detail;
  final String? note;
  final String? reviewer;

  bool get isClub => kind == 'club';

  factory ReviewLogRow.fromMap(Map<String, dynamic> m) => ReviewLogRow(
        kind: (m['kind'] as String?) ?? 'credential',
        subject: ((m['subject'] as String?) ?? '').trim().isEmpty
            ? '—'
            : (m['subject'] as String).trim(),
        detail: m['detail'] as String?,
        approved: (m['approved'] as bool?) ?? false,
        note: m['note'] as String?,
        reviewer: m['reviewer'] as String?,
        reviewedAt:
            DateTime.tryParse('${m['reviewed_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Branşı eksik kalmış onaylı antrenör belgesi.
class SportlessCredential {
  const SportlessCredential({
    required this.id,
    required this.name,
    this.coachLevel,
  });

  final String id;
  final String name;
  final int? coachLevel;

  factory SportlessCredential.fromMap(Map<String, dynamic> m) =>
      SportlessCredential(
        id: m['id'] as String,
        name: ((m['full_name'] as String?) ?? '').trim().isEmpty
            ? 'Kişi'
            : (m['full_name'] as String).trim(),
        coachLevel: m['coach_level'] as int?,
      );
}

class AdminService {
  AdminService(this._c);
  final SupabaseClient _c;

  Future<PlatformStats> stats() async {
    final rows = await _c.rpc<List<dynamic>>('platform_stats');
    if (rows.isEmpty) return PlatformStats.empty;
    return PlatformStats.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  Future<List<AdminPerson>> searchPeople(String query) async {
    final rows = await _c
        .rpc<List<dynamic>>('admin_search_people', params: {'p_query': query});
    return rows
        .map((r) => AdminPerson.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> setPlatformAdmin(String profileId, bool value) =>
      _c.rpc<void>('set_platform_admin',
          params: {'p_profile': profileId, 'p_value': value});

  Future<List<ReviewLogRow>> recentReviews() async {
    final rows = await _c.rpc<List<dynamic>>('admin_recent_reviews');
    return rows
        .map((r) => ReviewLogRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<SportlessCredential>> credentialsWithoutSport() async {
    final rows = await _c.rpc<List<dynamic>>('credentials_without_sport');
    return rows
        .map((r) =>
            SportlessCredential.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> setCredentialSport(String credId, String sportCode) =>
      _c.rpc<void>('set_credential_sport',
          params: {'p_cred': credId, 'p_sport_code': sportCode});
}

// =============================== Provider'lar ==============================

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.watch(supabaseClientProvider));
});

final platformStatsProvider = FutureProvider.autoDispose<PlatformStats>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(PlatformStats.empty);
  }
  return ref.watch(adminServiceProvider).stats();
});

/// Kişi araması — boş sorgu ilk 40 kişiyi getirir.
final adminPeopleProvider =
    FutureProvider.autoDispose.family<List<AdminPerson>, String>((ref, q) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <AdminPerson>[]);
  }
  return ref.watch(adminServiceProvider).searchPeople(q);
});

final reviewLogProvider =
    FutureProvider.autoDispose<List<ReviewLogRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <ReviewLogRow>[]);
  }
  return ref.watch(adminServiceProvider).recentReviews();
});

final sportlessCredentialsProvider =
    FutureProvider.autoDispose<List<SportlessCredential>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <SportlessCredential>[]);
  }
  return ref.watch(adminServiceProvider).credentialsWithoutSport();
});
