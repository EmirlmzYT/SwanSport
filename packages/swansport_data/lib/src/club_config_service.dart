import 'dart:typed_data';
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

/// Kulüp profilinde gösterilebilecek bölümler.
///
/// Anahtarlar `clubs_sections_check` kısıtıyla birebir; ayrışırsa kulübün
/// kaydettiği sıra sunucuda reddedilir.
class ClubSection {
  const ClubSection._();

  static const about = 'about';
  static const teams = 'teams';
  static const roster = 'roster';
  static const achievements = 'achievements';
  static const announcements = 'announcements';
  static const contact = 'contact';

  /// Kulüp dokunmadıysa kullanılan sıra.
  static const defaults = [
    about,
    teams,
    roster,
    achievements,
    announcements,
    contact,
  ];

  static String label(String key) => switch (key) {
        about => 'Hakkında',
        teams => 'Takımlar',
        roster => 'Kadro',
        achievements => 'Başarılar',
        announcements => 'Duyurular',
        contact => 'İletişim',
        _ => key,
      };
}

class ClubIdentity {
  const ClubIdentity({
    required this.id,
    required this.name,
    this.shortName,
    this.city,
    this.district,
    this.bio,
    this.status = 'active',
    this.logoPath,
    this.coverPath,
    this.brandColor,
    this.sections,
    this.phone,
    this.email,
    this.website,
    this.instagram,
    this.address,
    this.foundedYear,
  });

  final String id;
  final String name;
  final String? shortName;
  final String? city;
  final String? district;
  final String? bio;
  final String status;

  /// Storage **yolu**, URL değil. Bucket ya da alan adı değişince saklanmış
  /// URL'ler kırılırdı (0050'deki aynı karar).
  final String? logoPath;
  final String? coverPath;

  /// `#RRGGBB`. **`accent`'in yerine geçmiyor** — yalnızca kimlik yüzeyleri.
  final String? brandColor;

  /// null = varsayılan sıra. Boş liste ile null farklı: boş liste "hiçbir
  /// bölüm gösterme" demek ve geçerli bir tercih.
  final List<String>? sections;

  final String? phone;
  final String? email;
  final String? website;
  final String? instagram;
  final String? address;
  final int? foundedYear;

  bool get isPending => status == 'pending';

  List<String> get effectiveSections => sections ?? ClubSection.defaults;

  factory ClubIdentity.fromMap(Map<String, dynamic> m) => ClubIdentity(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        shortName: m['short_name'] as String?,
        city: m['city'] as String?,
        district: m['district'] as String?,
        bio: m['bio'] as String?,
        status: (m['status'] as String?) ?? 'active',
        logoPath: m['logo_path'] as String?,
        coverPath: m['cover_path'] as String?,
        brandColor: m['brand_color'] as String?,
        sections: (m['sections'] as List?)?.map((e) => '$e').toList(),
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        website: m['website'] as String?,
        instagram: m['instagram'] as String?,
        address: m['address'] as String?,
        foundedYear: (m['founded_year'] as num?)?.toInt(),
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
        .select('id, name, short_name, city, district, bio, status, logo_path, cover_path, brand_color, sections, phone, email, website, instagram, address, founded_year')
        .eq('id', clubId)
        .maybeSingle();
    return row == null
        ? null
        : ClubIdentity.fromMap(row.cast<String, dynamic>());
  }

  /// Kulüp kimliğini günceller.
  ///
  /// Yeni servis yazılmadı, var olan genişletildi: kulüp bilgisi tek yerden
  /// yazılmalı, yoksa iki yol zamanla ayrışır.
  ///
  /// Görseller burada **yok** — onlar [setMedia] üzerinden, çünkü yolun
  /// kulübün klasörüne yazıldığını sunucu doğruluyor.
  Future<void> updateIdentity(
    String clubId, {
    String? name,
    String? shortName,
    String? city,
    String? district,
    String? bio,
    String? brandColor,
    List<String>? sections,
    String? phone,
    String? email,
    String? website,
    String? instagram,
    String? address,
    int? foundedYear,
  }) async {
    String? clean(String? v) =>
        v == null ? null : (v.trim().isEmpty ? null : v.trim());

    final brand = brandColor?.trim();

    await _c.from('clubs').update({
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (shortName != null) 'short_name': clean(shortName),
      if (city != null) 'city': clean(city),
      if (district != null) 'district': clean(district),
      if (bio != null) 'bio': clean(bio),
      if (phone != null) 'phone': clean(phone),
      if (email != null) 'email': clean(email),
      if (website != null) 'website': clean(website),
      if (instagram != null) 'instagram': clean(instagram),
      if (address != null) 'address': clean(address),
      if (foundedYear != null)
        'founded_year': foundedYear <= 0 ? null : foundedYear,
      if (brand != null)
        'brand_color': RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(brand)
            ? brand.toUpperCase()
            : null,
      // Boş liste geçerli bir tercih ("hiçbir bölüm gösterme"), o yüzden
      // null'a çevrilmiyor.
      if (sections != null) 'sections': sections,
    }).eq('id', clubId);
  }

  /// Logo ve kapak yolunu yazar.
  ///
  /// Ayrı RPC: yükleme istemcide yapılıyor ama yolun **bu kulübün** klasörüne
  /// (`club/<id>/...`) ait olduğunu sunucu doğruluyor. Doğrulamasaydık bir
  /// kulüp yöneticisi başka kulübün görselini kendi kapağı yapabilirdi.
  Future<void> setMedia(String clubId,
          {String? logoPath, String? coverPath}) =>
      _c.rpc<void>('set_club_media', params: {
        'p_club': clubId,
        'p_logo': logoPath,
        'p_cover': coverPath,
      });

  /// Kulüp görselini `post-media` bucket'ına yükler ve yolunu döner.
  ///
  /// Klasör `club/<id>/` — storage politikası (0068) bu ön eki ve
  /// `is_club_admin` kontrolünü birlikte uyguluyor.
  Future<String> uploadMedia(
    String clubId, {
    required Uint8List bytes,
    required String fileName,
    required String kind,
  }) async {
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'jpg';
    final path =
        'club/$clubId/${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from('post-media').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
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
