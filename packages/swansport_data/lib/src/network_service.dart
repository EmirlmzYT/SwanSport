import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Spor ağı katmanı — keşfet, ilanlar, organizasyonlar.
///
/// Bunlar kulübün içine değil dışına bakan özellikler: kulüp yönetimi
/// kullanılmasa bile değerli olan taraf.
/// ---------------------------------------------------------------------------

// =============================== KEŞFET ====================================

class DiscoveredClub {
  const DiscoveredClub({
    required this.id,
    required this.name,
    required this.athleteCount,
    required this.coachCount,
    required this.isVerified,
    required this.isFollowing,
    this.shortName,
    this.city,
    this.district,
    this.sportName,
    this.logoUrl,
    this.bio,
  });

  final String id;
  final String name;
  final int athleteCount;
  final int coachCount;
  final bool isVerified;
  final bool isFollowing;
  final String? shortName;
  final String? city;
  final String? district;
  final String? sportName;
  final String? logoUrl;
  final String? bio;

  String get where => [
        if ((district ?? '').isNotEmpty) district!,
        if ((city ?? '').isNotEmpty) city!,
      ].join(', ');
}

class FilterOption {
  const FilterOption({
    required this.kind,
    required this.code,
    required this.label,
    required this.count,
  });
  final String kind; // city | sport
  final String code;
  final String label;
  final int count;
}

// =============================== İLANLAR ===================================

/// İlan türleri. Seçme de bir ilandır — ayrı bir sistem değil.
enum ListingKind { athleteWanted, coachWanted, clubWanted, tryout }

extension ListingKindX on ListingKind {
  String get code => switch (this) {
        ListingKind.athleteWanted => 'athlete_wanted',
        ListingKind.coachWanted => 'coach_wanted',
        ListingKind.clubWanted => 'club_wanted',
        ListingKind.tryout => 'tryout',
      };

  String get label => switch (this) {
        ListingKind.athleteWanted => 'Sporcu aranıyor',
        ListingKind.coachWanted => 'Antrenör aranıyor',
        ListingKind.clubWanted => 'Kulüp arıyorum',
        ListingKind.tryout => 'Seçme',
      };

  String get shortLabel => switch (this) {
        ListingKind.athleteWanted => 'Sporcu',
        ListingKind.coachWanted => 'Antrenör',
        ListingKind.clubWanted => 'Kulüp arayan',
        ListingKind.tryout => 'Seçme',
      };

  static ListingKind fromCode(String c) => switch (c) {
        'coach_wanted' => ListingKind.coachWanted,
        'club_wanted' => ListingKind.clubWanted,
        'tryout' => ListingKind.tryout,
        _ => ListingKind.athleteWanted,
      };
}

class Listing {
  const Listing({
    required this.id,
    required this.kind,
    required this.title,
    required this.ownerId,
    required this.ownerName,
    required this.applicationCount,
    required this.applied,
    required this.canManage,
    required this.createdAt,
    this.body,
    this.clubId,
    this.clubName,
    this.logoUrl,
    this.sportName,
    this.cityName,
    this.district,
    this.ageMin,
    this.ageMax,
    this.position,
    this.coachLevelMin,
    this.startsAt,
    this.location,
    this.quota,
    this.deadline,
  });

  final String id;
  final ListingKind kind;
  final String title;
  final String ownerId;
  final String ownerName;
  final int applicationCount;
  final bool applied;
  final bool canManage;
  final DateTime createdAt;
  final String? body;
  final String? clubId;
  final String? clubName;
  final String? logoUrl;
  final String? sportName;
  final String? cityName;
  final String? district;
  final int? ageMin;
  final int? ageMax;
  final String? position;
  final int? coachLevelMin;
  final DateTime? startsAt;
  final String? location;
  final int? quota;
  final DateTime? deadline;

  bool get isTryout => kind == ListingKind.tryout;
  String get byline => clubName ?? ownerName;

  /// İlanın altında görünen özet satırı — yalnızca dolu alanlar.
  String get criteria {
    final p = <String>[
      if ((sportName ?? '').isNotEmpty) sportName!,
      if ((cityName ?? '').isNotEmpty)
        [if ((district ?? '').isNotEmpty) district!, cityName!].join(', '),
      if (ageMin != null || ageMax != null)
        '${ageMin ?? ''}–${ageMax ?? ''} yaş',
      if ((position ?? '').isNotEmpty) position!,
      if (coachLevelMin != null) '${coachLevelMin}. kademe+',
    ];
    return p.join(' · ');
  }

  factory Listing.fromMap(Map<String, dynamic> m, String? Function(String?) url) =>
      Listing(
        id: m['id'] as String,
        kind: ListingKindX.fromCode((m['kind'] as String?) ?? 'athlete_wanted'),
        title: (m['title'] as String?) ?? '',
        body: m['body'] as String?,
        clubId: m['club_id'] as String?,
        clubName: m['club_name'] as String?,
        logoUrl: url(m['club_logo'] as String?) ?? url(m['owner_avatar'] as String?),
        ownerId: m['owner_id'] as String,
        ownerName: ((m['owner_name'] as String?) ?? '').trim().isEmpty
            ? 'Kullanıcı'
            : (m['owner_name'] as String).trim(),
        sportName: m['sport_name'] as String?,
        cityName: m['city_name'] as String?,
        district: m['district'] as String?,
        ageMin: m['age_min'] as int?,
        ageMax: m['age_max'] as int?,
        position: m['position_name'] as String?,
        coachLevelMin: m['coach_level_min'] as int?,
        startsAt: m['starts_at'] == null
            ? null
            : DateTime.tryParse('${m['starts_at']}')?.toLocal(),
        location: m['location'] as String?,
        quota: m['quota'] as int?,
        deadline: m['deadline'] == null
            ? null
            : DateTime.tryParse('${m['deadline']}'),
        applicationCount: (m['application_count'] as int?) ?? 0,
        applied: (m['applied'] as bool?) ?? false,
        canManage: (m['can_manage'] as bool?) ?? false,
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

class Applicant {
  const Applicant({
    required this.id,
    required this.profileId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.username,
    this.avatarUrl,
    this.credentials,
    this.cityName,
    this.note,
  });

  final String id;
  final String profileId;
  final String name;
  final String status;
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;
  final String? credentials;
  final String? cityName;
  final String? note;

  bool get isPending => status == 'pending';

  String get subtitle => [
        if ((credentials ?? '').isNotEmpty) credentials!,
        if ((cityName ?? '').isNotEmpty) cityName!,
      ].join(' · ');
}

// =========================== ORGANİZASYONLAR ===============================

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    required this.participantCount,
    required this.canManage,
    this.sportName,
    this.cityName,
    this.ageGroup,
    this.startsOn,
    this.endsOn,
    this.clubName,
  });

  final String id;
  final String name;
  final String kind; // league | tournament | cup
  final String status;
  final int participantCount;
  final bool canManage;
  final String? sportName;
  final String? cityName;
  final String? ageGroup;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String? clubName;

  String get kindLabel => switch (kind) {
        'tournament' => 'Turnuva',
        'cup' => 'Kupa',
        _ => 'Lig',
      };

  bool get isFinished => status == 'finished';
}

class StandingRow {
  const StandingRow({
    required this.participantId,
    required this.name,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.scored,
    required this.conceded,
    required this.diff,
    required this.points,
  });

  final String participantId;
  final String name;
  final int played, won, drawn, lost, scored, conceded, diff, points;
}

class FixtureRow {
  const FixtureRow({
    required this.id,
    required this.status,
    required this.canManage,
    this.round,
    this.startsAt,
    this.homeName,
    this.awayName,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final String status;
  final bool canManage;
  final int? round;
  final DateTime? startsAt;
  final String? homeName;
  final String? awayName;
  final int? homeScore;
  final int? awayScore;

  bool get isPlayed => status == 'played';
}

// =============================== SERVİS ====================================

class NetworkService {
  NetworkService(this._c);
  final SupabaseClient _c;

  String? _url(String? p) =>
      (p == null || p.isEmpty) ? null : _c.storage.from('post-media').getPublicUrl(p);

  // ------------------------------- keşfet --------------------------------
  Future<List<DiscoveredClub>> discoverClubs({
    String? query,
    String? city,
    String? district,
    String? sport,
    bool verifiedOnly = false,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('discover_clubs', params: {
      if (query != null && query.isNotEmpty) 'p_query': query,
      if (city != null && city.isNotEmpty) 'p_city': city,
      if (district != null && district.isNotEmpty) 'p_district': district,
      if (sport != null && sport.isNotEmpty) 'p_sport': sport,
      'p_verified': verifiedOnly,
    });
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return DiscoveredClub(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        shortName: m['short_name'] as String?,
        city: m['city'] as String?,
        district: m['district'] as String?,
        sportName: m['sport_name'] as String?,
        logoUrl: _url(m['logo_path'] as String?),
        bio: m['bio'] as String?,
        isVerified: (m['status'] as String?) == 'active',
        athleteCount: (m['athlete_count'] as int?) ?? 0,
        coachCount: (m['coach_count'] as int?) ?? 0,
        isFollowing: (m['is_following'] as bool?) ?? false,
      );
    }).toList();
  }

  Future<List<FilterOption>> filterOptions() async {
    final rows = await _c.rpc<List<dynamic>>('club_filter_options');
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return FilterOption(
        kind: (m['kind'] as String?) ?? 'city',
        code: (m['code'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        count: (m['club_count'] as int?) ?? 0,
      );
    }).toList();
  }

  // ------------------------------ ilanlar --------------------------------
  Future<List<Listing>> searchListings({
    String? kind,
    String? sport,
    String? city,
    String? district,
    int? level,
    bool verifiedOnly = false,
    String? query,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('search_listings', params: {
      if (kind != null && kind.isNotEmpty) 'p_kind': kind,
      if (sport != null && sport.isNotEmpty) 'p_sport': sport,
      if (city != null && city.isNotEmpty) 'p_city': city,
      if (district != null && district.isNotEmpty) 'p_district': district,
      if (level != null) 'p_level': level,
      'p_verified': verifiedOnly,
      if (query != null && query.isNotEmpty) 'p_query': query,
    });
    return rows
        .map((r) => Listing.fromMap((r as Map).cast<String, dynamic>(), _url))
        .toList();
  }

  Future<String> createListing({
    required String kind,
    required String title,
    String? body,
    String? clubId,
    String? sport,
    String? city,
    String? district,
    int? ageMin,
    int? ageMax,
    String? position,
    int? levelMin,
    DateTime? startsAt,
    String? location,
    int? quota,
    String? requirements,
    DateTime? deadline,
  }) async {
    return await _c.rpc<String>('create_listing', params: {
      'p_kind': kind,
      'p_title': title.trim(),
      if (body != null && body.trim().isNotEmpty) 'p_body': body.trim(),
      if (clubId != null) 'p_club': clubId,
      if (sport != null && sport.isNotEmpty) 'p_sport': sport,
      if (city != null && city.isNotEmpty) 'p_city': city,
      if (district != null && district.trim().isNotEmpty)
        'p_district': district.trim(),
      if (ageMin != null) 'p_age_min': ageMin,
      if (ageMax != null) 'p_age_max': ageMax,
      if (position != null && position.trim().isNotEmpty)
        'p_position': position.trim(),
      if (levelMin != null) 'p_level_min': levelMin,
      if (startsAt != null) 'p_starts_at': startsAt.toUtc().toIso8601String(),
      if (location != null && location.trim().isNotEmpty)
        'p_location': location.trim(),
      if (quota != null) 'p_quota': quota,
      if (requirements != null && requirements.trim().isNotEmpty)
        'p_requirements': requirements.trim(),
      if (deadline != null)
        'p_deadline': deadline.toIso8601String().split('T').first,
    });
  }

  Future<void> closeListing(String id) =>
      _c.rpc<void>('close_listing', params: {'p_listing': id});

  Future<void> applyToListing(String id, {String? note}) =>
      _c.rpc<void>('apply_to_listing', params: {
        'p_listing': id,
        if (note != null && note.trim().isNotEmpty) 'p_note': note.trim(),
      });

  Future<void> reviewApplication(String id, bool accept) =>
      _c.rpc<void>('review_listing_application',
          params: {'p_application': id, 'p_accept': accept});

  Future<List<Applicant>> applicants(String listingId) async {
    final rows = await _c
        .rpc<List<dynamic>>('listing_applicants', params: {'p_listing': listingId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final n = ((m['name'] as String?) ?? '').trim();
      return Applicant(
        id: m['id'] as String,
        profileId: m['applicant_id'] as String,
        name: n.isEmpty ? 'Kullanıcı' : n,
        username: m['username'] as String?,
        avatarUrl: _url(m['avatar_path'] as String?),
        credentials: m['credentials'] as String?,
        cityName: m['city_name'] as String?,
        note: m['note'] as String?,
        status: (m['status'] as String?) ?? 'pending',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
      );
    }).toList();
  }

  // --------------------------- organizasyonlar ----------------------------
  Future<List<Organization>> organizations(
      {String? sport, String? city, String? kind}) async {
    final rows = await _c.rpc<List<dynamic>>('list_organizations', params: {
      if (sport != null && sport.isNotEmpty) 'p_sport': sport,
      if (city != null && city.isNotEmpty) 'p_city': city,
      if (kind != null && kind.isNotEmpty) 'p_kind': kind,
    });
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return Organization(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'league',
        sportName: m['sport_name'] as String?,
        cityName: m['city_name'] as String?,
        ageGroup: m['age_group'] as String?,
        startsOn: m['starts_on'] == null
            ? null
            : DateTime.tryParse('${m['starts_on']}'),
        endsOn:
            m['ends_on'] == null ? null : DateTime.tryParse('${m['ends_on']}'),
        status: (m['status'] as String?) ?? 'open',
        clubName: m['club_name'] as String?,
        participantCount: (m['participant_count'] as int?) ?? 0,
        canManage: (m['can_manage'] as bool?) ?? false,
      );
    }).toList();
  }

  Future<String> createOrganization({
    required String name,
    String kind = 'league',
    String? clubId,
    String? sport,
    String? city,
    String? ageGroup,
    DateTime? startsOn,
    String? description,
    int winPoints = 3,
    int drawPoints = 1,
  }) async {
    return await _c.rpc<String>('create_organization', params: {
      'p_name': name.trim(),
      'p_kind': kind,
      if (clubId != null) 'p_club': clubId,
      if (sport != null && sport.isNotEmpty) 'p_sport': sport,
      if (city != null && city.isNotEmpty) 'p_city': city,
      if (ageGroup != null && ageGroup.trim().isNotEmpty)
        'p_age': ageGroup.trim(),
      if (startsOn != null)
        'p_starts': startsOn.toIso8601String().split('T').first,
      if (description != null && description.trim().isNotEmpty)
        'p_description': description.trim(),
      'p_win': winPoints,
      'p_draw': drawPoints,
    });
  }

  Future<void> joinOrganization(String orgId,
          {String? clubId, String? teamId, String? name}) =>
      _c.rpc<void>('join_organization', params: {
        'p_org': orgId,
        if (clubId != null) 'p_club': clubId,
        if (teamId != null) 'p_team': teamId,
        if (name != null && name.trim().isNotEmpty) 'p_name': name.trim(),
      });

  Future<int> generateFixture(String orgId, {DateTime? start}) async {
    return await _c.rpc<int>('generate_fixture', params: {
      'p_org': orgId,
      if (start != null) 'p_start': start.toIso8601String().split('T').first,
    });
  }

  Future<void> setMatchResult(String matchId, int home, int away) =>
      _c.rpc<void>('set_match_result',
          params: {'p_match': matchId, 'p_home': home, 'p_away': away});

  Future<List<StandingRow>> standings(String orgId) async {
    final rows =
        await _c.rpc<List<dynamic>>('org_standings', params: {'p_org': orgId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return StandingRow(
        participantId: m['participant_id'] as String,
        name: (m['name'] as String?) ?? '',
        played: (m['played'] as int?) ?? 0,
        won: (m['won'] as int?) ?? 0,
        drawn: (m['drawn'] as int?) ?? 0,
        lost: (m['lost'] as int?) ?? 0,
        scored: (m['scored'] as int?) ?? 0,
        conceded: (m['conceded'] as int?) ?? 0,
        diff: (m['diff'] as int?) ?? 0,
        points: (m['points'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<List<FixtureRow>> fixture(String orgId) async {
    final rows =
        await _c.rpc<List<dynamic>>('org_fixture', params: {'p_org': orgId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return FixtureRow(
        id: m['id'] as String,
        round: m['round'] as int?,
        startsAt: m['starts_at'] == null
            ? null
            : DateTime.tryParse('${m['starts_at']}')?.toLocal(),
        status: (m['status'] as String?) ?? 'scheduled',
        homeName: m['home_name'] as String?,
        awayName: m['away_name'] as String?,
        homeScore: m['home_score'] as int?,
        awayScore: m['away_score'] as int?,
        canManage: (m['can_manage'] as bool?) ?? false,
      );
    }).toList();
  }
}

// =============================== Provider'lar ==============================

final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService(ref.watch(supabaseClientProvider));
});

/// Keşfet filtresi — ekranlar arasında taşınabilsin diye ayrı sınıf.
class DiscoverFilter {
  const DiscoverFilter({
    this.query = '',
    this.city = '',
    this.district = '',
    this.sport = '',
    this.verifiedOnly = false,
  });

  final String query;
  final String city;
  final String district;
  final String sport;
  final bool verifiedOnly;

  bool get isEmpty =>
      query.isEmpty &&
      city.isEmpty &&
      district.isEmpty &&
      sport.isEmpty &&
      !verifiedOnly;

  DiscoverFilter copyWith({
    String? query,
    String? city,
    String? district,
    String? sport,
    bool? verifiedOnly,
  }) =>
      DiscoverFilter(
        query: query ?? this.query,
        city: city ?? this.city,
        district: district ?? this.district,
        sport: sport ?? this.sport,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      );

  /// Provider anahtarı olarak kullanılabilmesi için değer eşitliği.
  @override
  bool operator ==(Object other) =>
      other is DiscoverFilter &&
      other.query == query &&
      other.city == city &&
      other.district == district &&
      other.sport == sport &&
      other.verifiedOnly == verifiedOnly;

  @override
  int get hashCode => Object.hash(query, city, district, sport, verifiedOnly);
}

final discoverClubsProvider = FutureProvider.autoDispose
    .family<List<DiscoveredClub>, DiscoverFilter>((ref, f) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <DiscoveredClub>[]);
  }
  return ref.watch(networkServiceProvider).discoverClubs(
        query: f.query,
        city: f.city,
        district: f.district,
        sport: f.sport,
        verifiedOnly: f.verifiedOnly,
      );
});

final filterOptionsProvider =
    FutureProvider.autoDispose<List<FilterOption>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <FilterOption>[]);
  }
  return ref.watch(networkServiceProvider).filterOptions();
});

final listingsProvider = FutureProvider.autoDispose
    .family<List<Listing>, DiscoverFilter>((ref, f) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <Listing>[]);
  }
  return ref.watch(networkServiceProvider).searchListings(
        kind: f.district, // district alanı ilan ekranında "tür" olarak kullanılır
        sport: f.sport,
        city: f.city,
        verifiedOnly: f.verifiedOnly,
        query: f.query,
      );
});

final applicantsProvider =
    FutureProvider.autoDispose.family<List<Applicant>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <Applicant>[]);
  }
  return ref.watch(networkServiceProvider).applicants(id);
});

final organizationsProvider =
    FutureProvider.autoDispose.family<List<Organization>, String>((ref, sport) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <Organization>[]);
  }
  return ref
      .watch(networkServiceProvider)
      .organizations(sport: sport.isEmpty ? null : sport);
});

final standingsProvider =
    FutureProvider.autoDispose.family<List<StandingRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <StandingRow>[]);
  }
  return ref.watch(networkServiceProvider).standings(id);
});

final fixtureProvider =
    FutureProvider.autoDispose.family<List<FixtureRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <FixtureRow>[]);
  }
  return ref.watch(networkServiceProvider).fixture(id);
});
