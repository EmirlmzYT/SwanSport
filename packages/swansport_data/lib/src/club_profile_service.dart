import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Detaylı kulüp künyesi — adres, iletişim, antrenör kadrosu ve başarılar.
/// ---------------------------------------------------------------------------

class ClubDetails {
  const ClubDetails({
    required this.id,
    required this.name,
    required this.athleteCount,
    required this.coachCount,
    required this.teamCount,
    required this.memberCount,
    required this.canManage,
    this.shortName,
    this.bio,
    this.city,
    this.district,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.instagram,
    this.foundedYear,
    this.sportName,
    this.status,
    this.logoUrl,
  });

  final String id;
  final String name;
  final int athleteCount;
  final int coachCount;
  final int teamCount;
  final int memberCount;
  final bool canManage;
  final String? shortName;
  final String? bio;
  final String? city;
  final String? district;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? instagram;
  final int? foundedYear;
  final String? sportName;
  final String? status;
  final String? logoUrl;

  /// Künyede gösterilecek konum satırı: "Selçuklu, Konya"
  String? get location {
    final parts = [
      if ((district ?? '').isNotEmpty) district!,
      if ((city ?? '').isNotEmpty) city!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Künyede doldurulmuş alan var mı? Yoksa bölüm hiç gösterilmez.
  bool get hasAnyDetail =>
      (address ?? '').isNotEmpty ||
      (phone ?? '').isNotEmpty ||
      (email ?? '').isNotEmpty ||
      (website ?? '').isNotEmpty ||
      (instagram ?? '').isNotEmpty ||
      foundedYear != null ||
      (sportName ?? '').isNotEmpty ||
      location != null;
}

class ClubCoach {
  const ClubCoach({
    required this.profileId,
    required this.name,
    required this.role,
    this.username,
    this.avatarUrl,
    this.coachLevel,
  });

  final String profileId;
  final String name;
  final String role;
  final String? username;
  final String? avatarUrl;
  final int? coachLevel;

  bool get isAdmin => role == 'club_admin';

  String get title {
    if (isAdmin) return 'Kulüp Yöneticisi';
    return coachLevel == null
        ? 'Antrenör'
        : '$coachLevel. Kademe Antrenör';
  }

  String get initials =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class ClubAchievement {
  const ClubAchievement({
    required this.id,
    required this.title,
    required this.canManage,
    this.rank,
    this.year,
    this.note,
  });

  final String id;
  final String title;
  final bool canManage;
  final String? rank;
  final int? year;
  final String? note;
}

class ClubProfileService {
  ClubProfileService(this._c);
  final SupabaseClient _c;

  String? _url(String? path) => (path == null || path.isEmpty)
      ? null
      : _c.storage.from('post-media').getPublicUrl(path);

  Future<ClubDetails?> details(String clubId) async {
    final rows =
        await _c.rpc<List<dynamic>>('club_details', params: {'p_club': clubId});
    if (rows.isEmpty) return null;
    final m = (rows.first as Map).cast<String, dynamic>();
    return ClubDetails(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      shortName: m['short_name'] as String?,
      bio: m['bio'] as String?,
      city: m['city'] as String?,
      district: m['district'] as String?,
      address: m['address'] as String?,
      phone: m['phone'] as String?,
      email: m['email'] as String?,
      website: m['website'] as String?,
      instagram: m['instagram'] as String?,
      foundedYear: m['founded_year'] as int?,
      sportName: m['sport_name'] as String?,
      status: m['status'] as String?,
      logoUrl: _url(m['logo_path'] as String?),
      athleteCount: (m['athlete_count'] as int?) ?? 0,
      coachCount: (m['coach_count'] as int?) ?? 0,
      teamCount: (m['team_count'] as int?) ?? 0,
      memberCount: (m['member_count'] as int?) ?? 0,
      canManage: (m['can_manage'] as bool?) ?? false,
    );
  }

  Future<List<ClubCoach>> coaches(String clubId) async {
    final rows =
        await _c.rpc<List<dynamic>>('club_coaches', params: {'p_club': clubId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final full = ((m['full_name'] as String?) ?? '').trim();
      return ClubCoach(
        profileId: m['profile_id'] as String,
        name: full.isEmpty ? 'Antrenör' : full,
        username: m['username'] as String?,
        avatarUrl: _url(m['avatar_path'] as String?),
        coachLevel: m['coach_level'] as int?,
        role: (m['role'] as String?) ?? 'coach',
      );
    }).toList();
  }

  Future<List<ClubAchievement>> achievements(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('club_achievement_list', params: {'p_club': clubId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return ClubAchievement(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        rank: m['rank'] as String?,
        year: m['year'] as int?,
        note: m['note'] as String?,
        canManage: (m['can_manage'] as bool?) ?? false,
      );
    }).toList();
  }

  Future<void> updateDetails(
    String clubId, {
    String? address,
    String? district,
    String? phone,
    String? email,
    String? website,
    String? instagram,
    int? foundedYear,
    String? sportCode,
  }) async {
    await _c.rpc<void>('update_club_details', params: {
      'p_club': clubId,
      if (address != null) 'p_address': address,
      if (district != null) 'p_district': district,
      if (phone != null) 'p_phone': phone,
      if (email != null) 'p_email': email,
      if (website != null) 'p_website': website,
      if (instagram != null) 'p_instagram': instagram,
      if (foundedYear != null) 'p_founded': foundedYear,
      if (sportCode != null) 'p_sport': sportCode,
    });
  }

  Future<void> addAchievement(String clubId, String title,
      {String? rank, int? year, String? note}) async {
    await _c.from('club_achievements').insert({
      'club_id': clubId,
      'title': title.trim(),
      if (rank != null && rank.trim().isNotEmpty) 'rank': rank.trim(),
      if (year != null) 'year': year,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> removeAchievement(String id) async {
    await _c.from('club_achievements').delete().eq('id', id);
  }
}

// =============================== Provider'lar ==============================

final clubProfileServiceProvider = Provider<ClubProfileService>((ref) {
  return ClubProfileService(ref.watch(supabaseClientProvider));
});

final clubDetailsProvider =
    FutureProvider.autoDispose.family<ClubDetails?, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(clubProfileServiceProvider).details(id);
});

final clubCoachesProvider =
    FutureProvider.autoDispose.family<List<ClubCoach>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <ClubCoach>[]);
  }
  return ref.watch(clubProfileServiceProvider).coaches(id);
});

final clubAchievementsProvider =
    FutureProvider.autoDispose.family<List<ClubAchievement>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <ClubAchievement>[]);
  }
  return ref.watch(clubProfileServiceProvider).achievements(id);
});
