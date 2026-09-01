import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Supabase ile sporcu/kulüp veri katmanı (dikey dilim 1).
/// ---------------------------------------------------------------------------

class ClubRef {
  const ClubRef({
    required this.id,
    required this.name,
    this.city,
    this.role,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String? city;
  final String? role;
  final String status;

  /// Kulüp onay bekliyor mu (belgeler platform yöneticisince incelenmemiş).
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';

  factory ClubRef.fromMembershipRow(Map<String, dynamic> row) {
    final club = (row['clubs'] as Map).cast<String, dynamic>();
    return ClubRef(
      id: club['id'] as String,
      name: club['name'] as String,
      city: club['city'] as String?,
      role: row['role'] as String?,
      status: (club['status'] as String?) ?? 'active',
    );
  }

  factory ClubRef.fromClubRow(Map<String, dynamic> club) => ClubRef(
        id: club['id'] as String,
        name: club['name'] as String,
        city: club['city'] as String?,
        status: (club['status'] as String?) ?? 'active',
      );
}

class AthleteRow {
  const AthleteRow({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.position,
    this.status = 'active',
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? position;
  final String status;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final res = '$f$l'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }

  bool get isActive => status == 'active';

  factory AthleteRow.fromMap(Map<String, dynamic> m) => AthleteRow(
        id: m['id'] as String,
        firstName: (m['first_name'] as String?) ?? '',
        lastName: (m['last_name'] as String?) ?? '',
        position: m['position'] as String?,
        status: (m['status'] as String?) ?? 'active',
      );
}

/// Supabase sorgularını kapsayan servis.
class SupabaseAthleteService {
  SupabaseAthleteService(this._client);

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  /// Giriş yapan kullanıcının aktif kulüp üyelikleri.
  /// Kişinin eriştiği kulüpler.
  ///
  /// İki kaynak birleşir:
  ///
  /// * `club_memberships` — kulüpte görevi olanlar (yönetici, antrenör, sporcu…)
  /// * `club_accountants` — dışarıdan hizmet veren muhasebeci
  ///
  /// Muhasebeci kulübün **üyesi değil**; ayrı tabloda durur ve buraya
  /// `role: 'accountant'` ile katılır. Mevcut `role` kontrolleri yalnızca
  /// `club_admin`/`coach` aradığı için muhasebeciye kulüp yönetim düğmeleri
  /// açılmaz — kontrol edildi.
  Future<List<ClubRef>> fetchMyClubs() async {
    final uid = _uid;
    if (uid == null) return const [];

    final memberRows = await _client
        .from('club_memberships')
        .select('role, clubs(id, name, city, status)')
        .eq('profile_id', uid)
        .eq('status', 'active');

    final clubs = (memberRows as List)
        .map((r) =>
            ClubRef.fromMembershipRow((r as Map).cast<String, dynamic>()))
        .toList();

    final accountantRows = await _client
        .from('club_accountants')
        .select('clubs(id, name, city, status)')
        .eq('profile_id', uid)
        .eq('status', 'active');

    final seen = clubs.map((c) => c.id).toSet();
    for (final r in accountantRows as List) {
      final club = ((r as Map)['clubs'] as Map?)?.cast<String, dynamic>();
      if (club == null) continue;
      final id = club['id'] as String;
      // Hem üye hem muhasebeci olan biri için üyelik rolü daha yetkili;
      // ikinci kez eklemiyoruz.
      if (seen.contains(id)) continue;
      clubs.add(ClubRef(
        id: id,
        name: (club['name'] as String?) ?? '',
        city: club['city'] as String?,
        role: 'accountant',
        status: (club['status'] as String?) ?? 'active',
      ));
    }

    return clubs;
  }

  /// Yeni kulüp oluştur ve kullanıcıyı yönetici yap (create_club RPC).
  Future<ClubRef> createClub(String name, {String? city}) async {
    final res = await _client.rpc<dynamic>('create_club', params: {
      'p_name': name,
      if (city != null && city.isNotEmpty) 'p_city': city,
    });
    final club = (res is List ? res.first : res) as Map;
    return ClubRef.fromClubRow(club.cast<String, dynamic>());
  }

  /// Kulübün sporcularını getir.
  ///
  /// Parametrelerin hepsi opsiyonel ve varsayılanları eski davranışı korur:
  /// `fetchAthletes(clubId)` hâlâ tüm sporcuları ada göre sıralı döner.
  /// Mobil uygulama böyle çağırıyor; masaüstü konsolu ise tabloyu sunucu
  /// tarafında sıralayıp sayfalamak için parametreleri kullanıyor — 200
  /// kişilik bir kadroyu tarayıcıya indirip orada süzmek yerine.
  Future<List<AthleteRow>> fetchAthletes(
    String clubId, {
    int? limit,
    int offset = 0,
    String? search,
    String? status,
    String orderBy = 'first_name',
    bool ascending = true,
  }) async {
    var q = _client
        .from('athletes')
        .select('id, first_name, last_name, position, status')
        .eq('club_id', clubId);

    if (status != null && status.isNotEmpty) q = q.eq('status', status);
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      q = q.or('first_name.ilike.%$s%,last_name.ilike.%$s%,position.ilike.%$s%');
    }

    final ordered = q.order(orderBy, ascending: ascending);
    final rows = limit == null
        ? await ordered
        : await ordered.range(offset, offset + limit - 1);

    return (rows as List)
        .map((r) => AthleteRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// [fetchAthletes] ile aynı süzgeçlere uyan toplam satır sayısı.
  ///
  /// Sayfalayıcının "kaç sayfa var" sorusunu yanıtlar. Ayrı bir sorgu olması
  /// gerekiyor: sayfalanmış sonuç toplamı bilmiyor.
  Future<int> countAthletes(
    String clubId, {
    String? search,
    String? status,
  }) async {
    var q = _client
        .from('athletes')
        .select('id')
        .eq('club_id', clubId);

    if (status != null && status.isNotEmpty) q = q.eq('status', status);
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      q = q.or('first_name.ilike.%$s%,last_name.ilike.%$s%,position.ilike.%$s%');
    }

    final rows = await q.count(CountOption.exact);
    return rows.count;
  }

  /// Seçili sporcuların durumunu topluca değiştirir.
  ///
  /// Konsolun toplu işlem çubuğu bunu çağırır. Tek sorgu; 50 sporcu için 50
  /// istek atmak hem yavaş hem yarıda kalabilir.
  Future<void> setAthletesStatus(List<String> ids, String status) async {
    if (ids.isEmpty) return;
    await _client
        .from('athletes')
        .update({'status': status}).inFilter('id', ids);
  }

  /// Verilen sporculardan, [since] anından sonra değişmiş olanları döner.
  ///
  /// Toplu işlemden hemen önce çağrılır. Senaryo şu: konsolda kadroyu açtın,
  /// beş dakika sonra otuz kişiyi seçip "aktif yap" dedin — bu arada antrenör
  /// telefondan birini pasife almışsa, senin işlemin onu sessizce geri açardı
  /// ve kimse fark etmezdi. Tabloyu iki kişi aynı anda yönetince bu kaçınılmaz;
  /// çözüm engellemek değil, **görünür kılmak**.
  ///
  /// `athletes.updated_at` zaten mevcut ve tetikleyicisi kurulu
  /// (`trg_athletes_updated`), yeni bir sütuna gerek yok.
  Future<List<AthleteRow>> athletesChangedSince(
    List<String> ids,
    DateTime since,
  ) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('athletes')
        .select('id, first_name, last_name, position, status')
        .inFilter('id', ids)
        .gt('updated_at', since.toUtc().toIso8601String());
    return (rows as List)
        .map((r) => AthleteRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Yeni sporcu ekle (sunucuda kalıcı).
  Future<void> addAthlete({
    required String clubId,
    required String firstName,
    required String lastName,
    String? position,
  }) async {
    await _client.from('athletes').insert({
      'club_id': clubId,
      'first_name': firstName,
      'last_name': lastName,
      if (position != null && position.isNotEmpty) 'position': position,
      'status': 'active',
    });
  }
}

/// ---------------------------------------------------------------------------
/// Provider'lar
/// ---------------------------------------------------------------------------

final athleteServiceProvider = Provider<SupabaseAthleteService>((ref) {
  return SupabaseAthleteService(ref.watch(supabaseClientProvider));
});

/// Kullanıcının kulüpleri.
final myClubsProvider = FutureProvider<List<ClubRef>>((ref) {
  return ref.watch(athleteServiceProvider).fetchMyClubs();
});

/// Kullanıcının seçtiği kulübün kimliği. null = seçim yapılmadı.
///
/// Birden fazla kulüpte görevli biri (ör. iki kulübe antrenörlük yapan)
/// eskiden ikinci kulübüne hiçbir yerden ulaşamıyordu: `activeClubProvider`
/// körlemesine listenin ilkini döndürüyordu. Seçim burada tutulur ki hem
/// uygulama hem konsol aynı kulübe baksın.
final selectedClubIdProvider = StateProvider<String?>((ref) => null);

/// Üzerinde çalışılan kulüp — yoksa null.
///
/// Seçim yapılmışsa o, yapılmamışsa listenin ilki. Seçili kulüp artık
/// üyelikler arasında değilse (kulüpten çıkarılmışsan) sessizce ilkine döner;
/// var olmayan bir kulübün ekranını göstermek daha kötü olurdu.
final activeClubProvider = FutureProvider<ClubRef?>((ref) async {
  final clubs = await ref.watch(myClubsProvider.future);
  if (clubs.isEmpty) return null;

  final selected = ref.watch(selectedClubIdProvider);
  if (selected == null) return clubs.first;

  for (final c in clubs) {
    if (c.id == selected) return c;
  }
  return clubs.first;
});

/// Aktif kulübün sporcuları.
final clubAthletesProvider =
    FutureProvider.autoDispose<List<AthleteRow>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(athleteServiceProvider).fetchAthletes(club.id);
});

/// Velinin bağlı olduğu sporcular (guardians tablosu üzerinden).
/// Veli, davet kodunu kullandığında bu bağ oluşur.
final myChildrenProvider =
    FutureProvider.autoDispose<List<AthleteRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await client
      .from('guardians')
      .select('athletes(id, first_name, last_name, position, status)')
      .eq('profile_id', uid);
  final out = <AthleteRow>[];
  for (final r in rows as List) {
    final a = (r as Map)['athletes'];
    if (a is Map) {
      out.add(AthleteRow.fromMap(a.cast<String, dynamic>()));
    }
  }
  return out;
});

/// Tekil sporcu (profil için).
class AthleteFull {
  const AthleteFull({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.position,
    this.status = 'active',
    this.birthDate,
    this.license,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? position;
  final String status;
  final DateTime? birthDate;
  final String? license;

  String get fullName => '$firstName $lastName'.trim();
  bool get isActive => status == 'active';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final r = '$f$l'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var a = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      a--;
    }
    return a;
  }
}

extension AthleteDetailQueries on SupabaseAthleteService {
  Future<AthleteFull?> fetchAthlete(String id) async {
    final m = await _client
        .from('athletes')
        .select(
            'id, first_name, last_name, position, status, birth_date, license_number')
        .eq('id', id)
        .maybeSingle();
    if (m == null) return null;
    return AthleteFull(
      id: m['id'] as String,
      firstName: (m['first_name'] as String?) ?? '',
      lastName: (m['last_name'] as String?) ?? '',
      position: m['position'] as String?,
      status: (m['status'] as String?) ?? 'active',
      birthDate: m['birth_date'] == null
          ? null
          : DateTime.tryParse('${m['birth_date']}'),
      license: m['license_number'] as String?,
    );
  }
}

final athleteByIdProvider =
    FutureProvider.autoDispose.family<AthleteFull?, String>((ref, id) {
  return ref.watch(athleteServiceProvider).fetchAthlete(id);
});
