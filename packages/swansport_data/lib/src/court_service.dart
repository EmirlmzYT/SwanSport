import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_service.dart' show CityRow;
import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Halka açık kort sırası.
///
/// Sahadaki kural değişmiyor, dijitalleşiyor: orada olan oynar. Sistem
/// yalnızca beklemeyi kortun kenarından evine taşıyor.
///
/// AYRILABİLİRLİK: bu dosya kulüp kavramı bilmez — `activeClub`, üyelik,
/// lisans, aidat buraya girmez. Kort dünyası bir gün kendi uygulamasına
/// ayrılacak; sınır burada.
/// ---------------------------------------------------------------------------

/// Halka açık bir kort.
class Court {
  const Court({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.opensAt,
    required this.closesAt,
    required this.capacity,
    this.venue,
    this.cityName,
    this.district,
    this.sportCode,
    this.sportName,
    this.distanceMeters,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;

  /// `HH:MM` — kortun açılış/kapanış saati.
  final String opensAt;
  final String closesAt;
  final int capacity;

  final String? venue;
  final String? cityName;
  final String? district;

  /// `sports.code` — partner arama sistemi "kort branşları"nı buradan
  /// türetiyor (`court_sport_codes`); boşsa o kort branş eşleştirmesine
  /// hiç girmiyor.
  final String? sportCode;
  final String? sportName;

  /// Kullanıcının konumu biliniyorsa doldurulur; bilinmiyorsa null.
  final double? distanceMeters;

  String get where => [
        if ((district ?? '').isNotEmpty) district!,
        if ((cityName ?? '').isNotEmpty) cityName!,
      ].join(', ');

  /// "1,2 km" / "340 m" — konum yoksa boş.
  String get distanceLabel {
    final d = distanceMeters;
    if (d == null) return '';
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  Court withDistance(double? meters) => Court(
        id: id,
        name: name,
        lat: lat,
        lng: lng,
        opensAt: opensAt,
        closesAt: closesAt,
        capacity: capacity,
        venue: venue,
        cityName: cityName,
        district: district,
        sportCode: sportCode,
        sportName: sportName,
        distanceMeters: meters,
      );

  factory Court.fromMap(Map<String, dynamic> m) {
    final city = m['cities'];
    final sport = m['sports'];
    return Court(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      opensAt: _hhmm(m['opens_at']),
      closesAt: _hhmm(m['closes_at']),
      capacity: (m['capacity'] as int?) ?? 4,
      venue: m['venue'] as String?,
      cityName: city is Map ? city['name'] as String? : null,
      district: m['district'] as String?,
      sportCode: m['sport_code'] as String?,
      sportName: sport is Map ? sport['name'] as String? : null,
    );
  }

  /// Postgres `time` alanı `08:00:00` gelir; saniye gösterilmez.
  static String _hhmm(Object? raw) {
    final s = '${raw ?? ''}';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }
}

/// Şeritteki tek bir saat kutusu.
///
/// [slotId] null ise o saat boştur — [status] `free` döner.
class TimelineSlot {
  const TimelineSlot({
    required this.startsAt,
    required this.status,
    required this.needed,
    required this.players,
    required this.mine,
    this.slotId,
    this.ownerId,
    this.ownerName,
  });

  final DateTime startsAt;

  /// free | claimed | active
  final String status;
  final int needed;
  final int players;
  final bool mine;
  final String? slotId;
  final String? ownerId;
  final String? ownerName;

  bool get isFree => slotId == null;
  bool get isPlaying => status == 'active';
  bool get lookingForPlayers => needed > 0;

  /// `14:00`
  String get hourLabel =>
      '${startsAt.hour.toString().padLeft(2, '0')}:'
      '${startsAt.minute.toString().padLeft(2, '0')}';

  factory TimelineSlot.fromMap(Map<String, dynamic> m) => TimelineSlot(
        startsAt:
            DateTime.tryParse('${m['starts_at']}')?.toLocal() ?? DateTime.now(),
        status: (m['status'] as String?) ?? 'free',
        needed: (m['needed'] as int?) ?? 0,
        players: (m['players'] as int?) ?? 0,
        mine: (m['mine'] as bool?) ?? false,
        slotId: m['slot_id'] as String?,
        ownerId: m['owner_id'] as String?,
        ownerName: m['owner_name'] as String?,
      );
}

/// Oyuncu aranan bir oyun.
class OpenSlot {
  const OpenSlot({
    required this.slotId,
    required this.courtId,
    required this.courtName,
    required this.startsAt,
    required this.ownerId,
    required this.ownerName,
    required this.needed,
    required this.accepted,
    required this.requested,
    this.venue,
    this.cityName,
  });

  final String slotId;
  final String courtId;
  final String courtName;
  final DateTime startsAt;
  final String ownerId;
  final String ownerName;
  final int needed;
  final int accepted;

  /// Bu kullanıcı zaten istek gönderdi mi?
  final bool requested;
  final String? venue;
  final String? cityName;

  int get remaining => (needed - accepted).clamp(0, needed);

  factory OpenSlot.fromMap(Map<String, dynamic> m) => OpenSlot(
        slotId: m['slot_id'] as String,
        courtId: m['court_id'] as String,
        courtName: (m['court_name'] as String?) ?? '',
        startsAt:
            DateTime.tryParse('${m['starts_at']}')?.toLocal() ?? DateTime.now(),
        ownerId: (m['owner_id'] as String?) ?? '',
        ownerName: ((m['owner_name'] as String?) ?? '').trim().isEmpty
            ? 'Oyuncu'
            : (m['owner_name'] as String).trim(),
        needed: (m['needed'] as int?) ?? 0,
        accepted: (m['accepted'] as int?) ?? 0,
        requested: (m['requested'] as bool?) ?? false,
        venue: m['venue'] as String?,
        cityName: m['city_name'] as String?,
      );
}

/// Kutuya katılmak isteyen kişi.
class JoinRequest {
  const JoinRequest({
    required this.profileId,
    required this.name,
    required this.status,
    this.avatarUrl,
  });

  final String profileId;
  final String name;

  /// pending | accepted | rejected
  final String status;
  final String? avatarUrl;

  bool get isPending => status == 'pending';
}

/// Bana gelen, yanıtlamadığım partner isteği.
class IncomingPartnerPing {
  const IncomingPartnerPing({
    required this.requestId,
    required this.sportCode,
    required this.sportName,
    required this.requesterId,
    required this.requesterName,
    required this.createdAt,
  });

  final String requestId;
  final String sportCode;
  final String sportName;
  final String requesterId;
  final String requesterName;
  final DateTime createdAt;

  factory IncomingPartnerPing.fromMap(Map<String, dynamic> m) =>
      IncomingPartnerPing(
        requestId: m['request_id'] as String,
        sportCode: (m['sport_code'] as String?) ?? '',
        sportName: (m['sport_name'] as String?) ?? '',
        requesterId: (m['requester_id'] as String?) ?? '',
        requesterName: ((m['requester_name'] as String?) ?? '').trim().isEmpty
            ? 'Biri'
            : (m['requester_name'] as String).trim(),
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Benim açık ya da az önce eşleşmiş partner isteğim.
class MyPartnerRequest {
  const MyPartnerRequest({
    required this.id,
    required this.sportCode,
    required this.sportName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedBy,
    this.acceptedByName,
  });

  final String id;
  final String sportCode;
  final String sportName;

  /// open | matched
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? acceptedBy;
  final String? acceptedByName;

  bool get isMatched => status == 'matched' && acceptedBy != null;

  factory MyPartnerRequest.fromMap(Map<String, dynamic> m) => MyPartnerRequest(
        id: m['id'] as String,
        sportCode: (m['sport_code'] as String?) ?? '',
        sportName: (m['sport_name'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'open',
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
        expiresAt:
            DateTime.tryParse('${m['expires_at']}')?.toLocal() ?? DateTime.now(),
        acceptedBy: m['accepted_by'] as String?,
        acceptedByName: m['accepted_by_name'] as String?,
      );
}

/// İki koordinat arası mesafe (metre).
///
/// Sunucuda da aynı hesap var (`meters_between`); buradaki yalnızca listeyi
/// yakınlığa göre sıralamak için. Yetki kararı **asla** buna dayanmaz —
/// istemcinin hesabı istemcinin elindedir.
double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final a = math.pow(math.sin(rad(lat2 - lat1) / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(rad(lng2 - lng1) / 2), 2);
  return earthRadius * 2 * math.asin(math.sqrt(a.toDouble()));
}

class CourtService {
  CourtService(this._c);
  final SupabaseClient _c;

  /// Etkin kortlar. Giriş yapılmamışken de okunabilir.
  Future<List<Court>> courts({String? cityCode}) async {
    var q = _c
        .from('courts')
        .select('id, name, venue, district, lat, lng, opens_at, closes_at, '
            'capacity, sport_code, cities(name), sports(name)')
        .eq('active', true);
    if (cityCode != null && cityCode.isNotEmpty) {
      q = q.eq('city_code', cityCode);
    }
    final rows = await q.order('name');
    return (rows as List)
        .map((r) => Court.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Kortun 3 saatlik şeridi.
  Future<List<TimelineSlot>> timeline(String courtId) async {
    final rows = await _c
        .rpc<List<dynamic>>('court_timeline', params: {'p_court': courtId});
    return rows
        .map((r) => TimelineSlot.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Kortta olduğunu bir kez kanıtla; bundan sonra evden sıra alabilirsin.
  Future<void> verifyLocation({
    required String courtId,
    required double lat,
    required double lng,
  }) =>
      _c.rpc<bool>('verify_court_location',
          params: {'p_court': courtId, 'p_lat': lat, 'p_lng': lng});

  /// Kutu al. Sıraya girmek de saat seçmek de buradan geçer.
  Future<String> claimSlot({
    required String courtId,
    required DateTime startsAt,
    int guests = 0,
    int needed = 0,
  }) =>
      _c.rpc<String>('claim_slot', params: {
        'p_court': courtId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_guests': guests,
        'p_needed': needed,
      });

  Future<void> checkIn({
    required String slotId,
    required double lat,
    required double lng,
  }) =>
      _c.rpc<bool>('check_in_slot',
          params: {'p_slot': slotId, 'p_lat': lat, 'p_lng': lng});

  Future<String> extend(String slotId) =>
      _c.rpc<String>('extend_slot', params: {'p_slot': slotId});

  Future<void> cancel(String slotId) =>
      _c.rpc<void>('cancel_slot', params: {'p_slot': slotId});

  Future<List<OpenSlot>> openSlots({String? cityCode}) async {
    final rows = await _c.rpc<List<dynamic>>('open_slots',
        params: {if (cityCode != null && cityCode.isNotEmpty) 'p_city': cityCode});
    return rows
        .map((r) => OpenSlot.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> requestJoin(String slotId) =>
      _c.rpc<void>('request_join', params: {'p_slot': slotId});

  Future<void> reviewJoin({
    required String slotId,
    required String profileId,
    required bool accept,
  }) =>
      _c.rpc<void>('review_join', params: {
        'p_slot': slotId,
        'p_profile': profileId,
        'p_accept': accept,
      });

  /// Bir kutuya katılmak isteyenler — yalnızca kutu sahibi için anlamlı.
  Future<List<JoinRequest>> joinRequests(String slotId) async {
    final rows = await _c
        .from('court_slot_players')
        .select('profile_id, status, profiles(full_name, avatar_path)')
        .eq('slot_id', slotId)
        .order('created_at');
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final p = m['profiles'];
      return JoinRequest(
        profileId: m['profile_id'] as String,
        name: p is Map
            ? (((p['full_name'] as String?) ?? '').trim().isEmpty
                ? 'Oyuncu'
                : (p['full_name'] as String).trim())
            : 'Oyuncu',
        status: (m['status'] as String?) ?? 'pending',
        avatarUrl: p is Map && p['avatar_path'] != null
            ? _c.storage.from('post-media').getPublicUrl(p['avatar_path'] as String)
            : null,
      );
    }).toList();
  }

  // --------------------------- partner arama --------------------------------

  /// Kortu olan branşlar — partner arama seçicisi bunu kullanır. Branşsız
  /// kort (`courts.sport_code` boş) bu listeye hiç girmez.
  Future<List<CityRow>> courtSportCodes() async {
    final rows = await _c.rpc<List<dynamic>>('court_sport_codes');
    return rows
        .map((r) => CityRow(
              code: (r as Map)['code'] as String,
              name: r['name'] as String,
            ))
        .toList();
  }

  /// Kullanıcının ilgilendiği branşlar — aday havuzuna girmek için önce bu.
  Future<Set<String>> mySportInterests() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _c
        .from('sport_interests')
        .select('sport_code')
        .eq('profile_id', uid);
    return (rows as List)
        .map((r) => (r as Map)['sport_code'] as String)
        .toSet();
  }

  Future<void> setSportInterest(String sportCode, bool interested) async {
    final uid = _c.auth.currentUser!.id;
    if (interested) {
      await _c.from('sport_interests').upsert(
          {'profile_id': uid, 'sport_code': sportCode},
          onConflict: 'profile_id,sport_code');
    } else {
      await _c
          .from('sport_interests')
          .delete()
          .eq('profile_id', uid)
          .eq('sport_code', sportCode);
    }
  }

  Future<String> seekPartner({
    required String sportCode,
    double? lat,
    double? lng,
  }) =>
      _c.rpc<String>('seek_partner',
          params: {'p_sport': sportCode, 'p_lat': lat, 'p_lng': lng});

  Future<void> respondPartnerPing({
    required String requestId,
    required bool accept,
  }) =>
      _c.rpc<void>('respond_partner_ping',
          params: {'p_request': requestId, 'p_accept': accept});

  Future<void> cancelPartnerRequest(String id) =>
      _c.rpc<void>('cancel_partner_request', params: {'p_id': id});

  Future<List<IncomingPartnerPing>> incomingPartnerPings() async {
    final rows =
        await _c.rpc<List<dynamic>>('my_incoming_partner_pings');
    return rows
        .map((r) =>
            IncomingPartnerPing.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<MyPartnerRequest?> myOpenPartnerRequest() async {
    final rows = await _c.rpc<List<dynamic>>('my_open_partner_request');
    if (rows.isEmpty) return null;
    return MyPartnerRequest.fromMap((rows.first as Map).cast<String, dynamic>());
  }
}

// =============================== Provider'lar ==============================

final courtServiceProvider = Provider<CourtService>((ref) {
  return CourtService(ref.watch(supabaseClientProvider));
});

final courtsProvider =
    FutureProvider.autoDispose.family<List<Court>, String?>((ref, cityCode) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <Court>[]);
  }
  return ref.watch(courtServiceProvider).courts(cityCode: cityCode);
});

final courtTimelineProvider = FutureProvider.autoDispose
    .family<List<TimelineSlot>, String>((ref, courtId) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <TimelineSlot>[]);
  }
  return ref.watch(courtServiceProvider).timeline(courtId);
});

final openSlotsProvider =
    FutureProvider.autoDispose.family<List<OpenSlot>, String?>((ref, cityCode) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <OpenSlot>[]);
  }
  return ref.watch(courtServiceProvider).openSlots(cityCode: cityCode);
});

final joinRequestsProvider =
    FutureProvider.autoDispose.family<List<JoinRequest>, String>((ref, slotId) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <JoinRequest>[]);
  }
  return ref.watch(courtServiceProvider).joinRequests(slotId);
});

final courtSportCodesProvider = FutureProvider.autoDispose<List<CityRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(courtServiceProvider).courtSportCodes();
});

final mySportInterestsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const {});
  return ref.watch(courtServiceProvider).mySportInterests();
});

final incomingPartnerPingsProvider =
    FutureProvider.autoDispose<List<IncomingPartnerPing>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <IncomingPartnerPing>[]);
  }
  return ref.watch(courtServiceProvider).incomingPartnerPings();
});

final myOpenPartnerRequestProvider =
    FutureProvider.autoDispose<MyPartnerRequest?>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(courtServiceProvider).myOpenPartnerRequest();
});

// ---------------------------------------------------------------------------
// Kort kullanım ölçümü (0041)
//
// Belediye görüşmesinin gövdesi. Yalnızca platform yöneticisi çağırabiliyor;
// RPC gövdesinde `is_platform_admin()` kontrolü var, burada tekrar
// kontrol etmiyoruz — yetki hesabı tek yerde kalsın (SwanAccess kuralı) ve
// istemci tarafı kontrolü zaten güvenlik sağlamıyor.
// ---------------------------------------------------------------------------

/// Kort kullanımının genel özeti.
class CourtUsage {
  const CourtUsage({
    required this.slotsTotal,
    required this.slotsDone,
    required this.slotsExpired,
    required this.slotsCancelled,
    required this.uniquePlayers,
    required this.totalPeople,
    required this.noShowPct,
    required this.checkinPct,
    required this.peakHour,
  });

  static const empty = CourtUsage(
    slotsTotal: 0,
    slotsDone: 0,
    slotsExpired: 0,
    slotsCancelled: 0,
    uniquePlayers: 0,
    totalPeople: 0,
    noShowPct: 0,
    checkinPct: 0,
    peakHour: 0,
  );

  factory CourtUsage.fromMap(Map<String, dynamic> m) => CourtUsage(
        slotsTotal: (m['slots_total'] as num?)?.toInt() ?? 0,
        slotsDone: (m['slots_done'] as num?)?.toInt() ?? 0,
        slotsExpired: (m['slots_expired'] as num?)?.toInt() ?? 0,
        slotsCancelled: (m['slots_cancelled'] as num?)?.toInt() ?? 0,
        uniquePlayers: (m['unique_players'] as num?)?.toInt() ?? 0,
        totalPeople: (m['total_people'] as num?)?.toInt() ?? 0,
        noShowPct: (m['no_show_pct'] as num?)?.toDouble() ?? 0,
        checkinPct: (m['checkin_pct'] as num?)?.toDouble() ?? 0,
        peakHour: (m['peak_hour'] as num?)?.toInt() ?? 0,
      );

  final int slotsTotal;
  final int slotsDone;
  final int slotsExpired;
  final int slotsCancelled;
  final int uniquePlayers;

  /// Sahipler + kabul edilen katılımcılar + misafirler.
  ///
  /// Belediyenin asıl sorusu bu, kutu sayısı değil: "kaç kişiye ulaştı".
  final int totalPeople;

  /// Sonucu belli olan kutular içinde gelinmeyenlerin oranı.
  ///
  /// Paydada iptal edilenler **yok** — iptal cezasız ve teşvik edilen
  /// davranış; onu gelmeme gibi saymak sistemi doğru kullanan kişiyi kötü
  /// gösterirdi.
  final double noShowPct;

  final double checkinPct;
  final int peakHour;

  /// Hiç veri yoksa ekranda "0" değil "henüz kullanılmadı" göstermek için.
  bool get isEmpty => slotsTotal == 0;
}

/// Kort başına kırılım.
class CourtUsageRow {
  const CourtUsageRow({
    required this.courtId,
    required this.courtName,
    required this.slotsTotal,
    required this.slotsDone,
    required this.noShowPct,
    required this.fillPct,
    this.venue,
  });

  factory CourtUsageRow.fromMap(Map<String, dynamic> m) => CourtUsageRow(
        courtId: m['court_id'] as String,
        courtName: (m['court_name'] as String?) ?? '',
        venue: m['venue'] as String?,
        slotsTotal: (m['slots_total'] as num?)?.toInt() ?? 0,
        slotsDone: (m['slots_done'] as num?)?.toInt() ?? 0,
        noShowPct: (m['no_show_pct'] as num?)?.toDouble() ?? 0,
        fillPct: (m['fill_pct'] as num?)?.toDouble() ?? 0,
      );

  final String courtId;
  final String courtName;
  final String? venue;
  final int slotsTotal;
  final int slotsDone;
  final double noShowPct;

  /// Alınan kutu / açık olunan saat. Kort hiç kullanılmadıysa 0 —
  /// bu da bir bilgi, listede kalıyor.
  final double fillPct;
}

extension CourtUsageQueries on CourtService {
  Future<CourtUsage> usage({int days = 30}) async {
    final rows = await _c.rpc<dynamic>(
      'court_usage_stats',
      params: {'p_days': days},
    );
    final list = (rows as List?) ?? const [];
    if (list.isEmpty) return CourtUsage.empty;
    return CourtUsage.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  Future<List<CourtUsageRow>> usageByCourt({int days = 30}) async {
    final rows = await _c.rpc<dynamic>(
      'court_usage_by_court',
      params: {'p_days': days},
    );
    return ((rows as List?) ?? const [])
        .map((r) => CourtUsageRow.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

/// Ölçüm penceresi gün cinsinden — konsolda 7/30/90 arasında değişiyor.
final courtUsageProvider =
    FutureProvider.autoDispose.family<CourtUsage, int>((ref, days) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(CourtUsage.empty);
  }
  return ref.watch(courtServiceProvider).usage(days: days);
});

final courtUsageByCourtProvider =
    FutureProvider.autoDispose.family<List<CourtUsageRow>, int>((ref, days) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <CourtUsageRow>[]);
  }
  return ref.watch(courtServiceProvider).usageByCourt(days: days);
});
