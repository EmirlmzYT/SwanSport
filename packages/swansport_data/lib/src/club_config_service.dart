import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'supabase_athletes.dart';

/// ---------------------------------------------------------------------------
/// Kulüp yapılandırması — kimlik, üyeler/roller ve sezonlar.
///
/// Hepsi mevcut yetki kurallarıyla çalışır: `clubs` ve `club_memberships`
/// üzerinde kulüp yöneticisine yazma izni zaten tanımlı, `seasons` üzerinde
/// kulüp görevlisine. Bu yüzden yeni bir veritabanı kurulumu gerekmiyor.
/// ---------------------------------------------------------------------------

class ClubIdentity {
  const ClubIdentity({
    required this.id,
    required this.name,
    this.shortName,
    this.city,
    this.bio,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String? shortName;
  final String? city;
  final String? bio;
  final String status;

  bool get isPending => status == 'pending';

  factory ClubIdentity.fromMap(Map<String, dynamic> m) => ClubIdentity(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        shortName: m['short_name'] as String?,
        city: m['city'] as String?,
        bio: m['bio'] as String?,
        status: (m['status'] as String?) ?? 'active',
      );
}

class ClubMember {
  const ClubMember({
    required this.membershipId,
    required this.profileId,
    required this.name,
    required this.role,
    required this.status,
    this.coachLevel,
    this.username,
  });

  final String membershipId;
  final String profileId;
  final String name;
  final String role; // club_admin | coach | athlete | parent | official
  final String status;
  final int? coachLevel;
  final String? username;

  bool get isAdmin => role == 'club_admin';

  String get roleLabel => switch (role) {
        'club_admin' => 'Kulüp Yöneticisi',
        'coach' => coachLevel == null
            ? 'Antrenör'
            : '$coachLevel. Kademe Antrenör',
        'athlete' => 'Sporcu',
        'parent' => 'Veli',
        'official' => 'Görevli',
        'federation_rep' => 'Federasyon Temsilcisi',
        _ => 'Üye',
      };

  String get initials =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  factory ClubMember.fromMap(Map<String, dynamic> m) {
    final p = (m['profiles'] as Map?)?.cast<String, dynamic>();
    final full = ((p?['full_name'] as String?) ?? '').trim();
    return ClubMember(
      membershipId: m['id'] as String,
      profileId: m['profile_id'] as String,
      name: full.isEmpty ? 'Kullanıcı' : full,
      username: p?['username'] as String?,
      role: (m['role'] as String?) ?? 'athlete',
      status: (m['status'] as String?) ?? 'active',
      coachLevel: m['coach_level'] as int?,
    );
  }
}

class SeasonRow {
  const SeasonRow({
    required this.id,
    required this.label,
    required this.isActive,
    this.startsOn,
    this.endsOn,
  });

  final String id;
  final String label;
  final bool isActive;
  final DateTime? startsOn;
  final DateTime? endsOn;

  factory SeasonRow.fromMap(Map<String, dynamic> m) => SeasonRow(
        id: m['id'] as String,
        label: (m['label'] as String?) ?? '',
        isActive: (m['is_active'] as bool?) ?? false,
        startsOn: m['starts_on'] == null
            ? null
            : DateTime.tryParse('${m['starts_on']}'),
        endsOn: m['ends_on'] == null
            ? null
            : DateTime.tryParse('${m['ends_on']}'),
      );
}

class ClubConfigService {
  ClubConfigService(this._c);
  final SupabaseClient _c;

  // ------------------------------- kimlik ---------------------------------
  Future<ClubIdentity?> identity(String clubId) async {
    final row = await _c
        .from('clubs')
        .select('id, name, short_name, city, bio, status')
        .eq('id', clubId)
        .maybeSingle();
    return row == null
        ? null
        : ClubIdentity.fromMap(row.cast<String, dynamic>());
  }

  Future<void> updateIdentity(
    String clubId, {
    String? name,
    String? shortName,
    String? city,
  }) async {
    await _c.from('clubs').update({
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (shortName != null)
        'short_name': shortName.trim().isEmpty ? null : shortName.trim(),
      if (city != null) 'city': city.trim().isEmpty ? null : city.trim(),
    }).eq('id', clubId);
  }

  // ------------------------------- üyeler ---------------------------------
  Future<List<ClubMember>> members(String clubId) async {
    final rows = await _c
        .from('club_memberships')
        .select('id, profile_id, role, status, coach_level, '
            'profiles(full_name, username)')
        .eq('club_id', clubId)
        .order('role');
    return (rows as List)
        .map((r) => ClubMember.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> setMemberRole(String membershipId, String role,
      {int? coachLevel}) async {
    await _c.from('club_memberships').update({
      'role': role,
      'coach_level': role == 'coach' ? coachLevel : null,
    }).eq('id', membershipId);
  }

  Future<void> removeMember(String membershipId) async {
    await _c.from('club_memberships').delete().eq('id', membershipId);
  }

  // ------------------------------- sezonlar --------------------------------
  Future<List<SeasonRow>> seasons(String clubId) async {
    final rows = await _c
        .from('seasons')
        .select('id, label, starts_on, ends_on, is_active')
        .eq('club_id', clubId)
        .order('starts_on', ascending: false);
    return (rows as List)
        .map((r) => SeasonRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> createSeason(String clubId, String label,
      {DateTime? startsOn, DateTime? endsOn}) async {
    await _c.from('seasons').insert({
      'club_id': clubId,
      'label': label.trim(),
      if (startsOn != null)
        'starts_on': startsOn.toIso8601String().split('T').first,
      if (endsOn != null)
        'ends_on': endsOn.toIso8601String().split('T').first,
    });
  }

  /// Bir sezonu aktif yapar; aynı kulüpteki diğerleri pasife düşer.
  Future<void> activateSeason(String clubId, String seasonId) async {
    await _c
        .from('seasons')
        .update({'is_active': false})
        .eq('club_id', clubId);
    await _c.from('seasons').update({'is_active': true}).eq('id', seasonId);
  }

  Future<void> removeSeason(String id) async {
    await _c.from('seasons').delete().eq('id', id);
  }
}

// =============================== Provider'lar ==============================

final clubConfigServiceProvider = Provider<ClubConfigService>((ref) {
  return ClubConfigService(ref.watch(supabaseClientProvider));
});

final clubIdentityProvider =
    FutureProvider.autoDispose<ClubIdentity?>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return null;
  return ref.watch(clubConfigServiceProvider).identity(club.id);
});

final clubMembersAdminProvider =
    FutureProvider.autoDispose<List<ClubMember>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubConfigServiceProvider).members(club.id);
});

final clubSeasonsProvider =
    FutureProvider.autoDispose<List<SeasonRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubConfigServiceProvider).seasons(club.id);
});
