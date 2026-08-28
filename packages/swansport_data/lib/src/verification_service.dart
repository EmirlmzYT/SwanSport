import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Roller & Doğrulama veri katmanı (kişi-düzeyi kimlik + platform onay).
/// ---------------------------------------------------------------------------

class CredentialRow {
  const CredentialRow({
    required this.id,
    required this.kind,
    this.coachLevel,
    required this.status,
    this.note,
    this.personName,
    this.sportName,
  });

  final String id;
  final String kind; // coach | athlete_licensed | athlete_individual
  final int? coachLevel;
  final String status; // pending | approved | rejected
  final String? note;
  final String? personName; // admin listelerinde

  /// Onaylanan branş — federasyon kanalı buna göre belirlenir.
  final String? sportName;

  bool get isCoach => kind == 'coach';

  String get label {
    if (isCoach) {
      final k = '${coachLevel ?? '?'}. Kademe Antrenör';
      return sportName == null ? k : '$sportName · $k';
    }
    // Lisanslı/ferdi ayrımı kulüp üyeliğinden gelir; başvuru kaydındaki tür
    // yalnızca başvuru anını yansıtır.
    final a = kind == 'athlete_individual' ? 'Ferdi Sporcu' : 'Lisanslı Sporcu';
    return sportName == null ? a : '$sportName · $a';
  }

  String get statusLabel => switch (status) {
        'approved' => 'Onaylandı',
        'rejected' => 'Reddedildi',
        _ => 'İnceleniyor',
      };

  factory CredentialRow.fromMap(Map<String, dynamic> m) {
    final prof = m['profiles'];
    String? name;
    if (prof is Map) name = prof['full_name'] as String?;
    return CredentialRow(
      id: m['id'] as String,
      kind: (m['kind'] as String?) ?? 'coach',
      coachLevel: m['coach_level'] as int?,
      status: (m['status'] as String?) ?? 'pending',
      note: m['note'] as String?,
      personName: (name == null || name.isEmpty) ? null : name,
      sportName: (m['sports'] is Map)
          ? (m['sports'] as Map)['name'] as String?
          : null,
    );
  }
}

class PendingClub {
  const PendingClub({required this.id, required this.name, this.city});
  final String id;
  final String name;
  final String? city;
  factory PendingClub.fromMap(Map<String, dynamic> m) => PendingClub(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        city: m['city'] as String?,
      );
}

class VerificationService {
  VerificationService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  /// Doğrulama belgelerinin Storage bucket adı.
  static const String docsBucket = 'verification-docs';

  // ----- Başvuru (kişi kendi kimliğini oluşturur) -----
  /// Antrenörlük başvurusu. Branş burada seçilir çünkü antrenörlük belgesi
  /// zaten branşa özeldir ("Yüzme 2. Kademe") — platform hangi branşta
  /// onayladıysa federasyon kanalı da o branşa göre açılır.
  Future<String> submitCoachCredential(int level, {String? sportCode}) async {
    final row = await _c
        .from('profile_credentials')
        .insert({
          'profile_id': _uid,
          'kind': 'coach',
          'coach_level': level,
          if (sportCode != null && sportCode.isNotEmpty) 'sport_code': sportCode,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Sporcu doğrulama başvurusu.
  ///
  /// Lisanslı/ferdi ayrımı seçilmez: kişi bir kulübe bağlıysa lisanslı,
  /// değilse ferdi sporcudur. Kayıt anındaki duruma göre belirlenir; görünen
  /// etiket her zaman güncel üyelikten türetilir.
  ///
  /// Branş burada da sorulur: lisans her zaman bir branşa aittir ("Yüzme
  /// ferdi sporcusu"). Ferdi olmak branşsız olmak demek değil — kulüpsüz
  /// olmak demek.
  Future<String> submitAthleteCredential({String? sportCode}) async {
    final membership = await _c
        .from('club_memberships')
        .select('club_id')
        .eq('profile_id', _uid!)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    final hasClub = membership != null;
    final row = await _c
        .from('profile_credentials')
        .insert({
          'profile_id': _uid,
          'kind': hasClub ? 'athlete_licensed' : 'athlete_individual',
          if (sportCode != null && sportCode.isNotEmpty) 'sport_code': sportCode,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Bir dosyayı Storage'a yükler, kaydedilen storage yolunu döner.
  /// Yol formatı: `{uid}/{zaman}_{docType}.{uzantı}` (RLS bunu kullanıcının
  /// kendi klasörüyle sınırlar).
  Future<String> uploadDocument({
    required String docType,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Oturum bulunamadı');
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'bin';
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_$docType.$ext';
    await _c.storage.from(docsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// Yüklenen belge yollarını bir kimlik başvurusuna (veya kulübe) bağlar.
  Future<void> attachDocuments({
    required String ownerType, // 'credential' | 'club'
    required String ownerId,
    required List<({String docType, String storagePath})> docs,
  }) async {
    if (docs.isEmpty) return;
    await _c.from('verification_documents').insert([
      for (final d in docs)
        {
          'owner_type': ownerType,
          'owner_id': ownerId,
          'doc_type': d.docType,
          'storage_path': d.storagePath,
          'uploaded_by': _uid,
        },
    ]);
  }

  Future<List<CredentialRow>> myCredentials() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('profile_credentials')
        .select('id, kind, coach_level, status, note, sports(name)')
        .eq('profile_id', uid)
        .order('submitted_at', ascending: false);
    return (rows as List)
        .map((r) => CredentialRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<bool> isPlatformAdmin() async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _c
        .from('profiles')
        .select('is_platform_admin')
        .eq('id', uid)
        .maybeSingle();
    return (row?['is_platform_admin'] as bool?) ?? false;
  }

  // ----- Veli davet kodu -----
  Future<String> createGuardianInvite(String athleteId) async {
    final res = await _c
        .rpc('create_guardian_invite', params: {'p_athlete': athleteId});
    return res as String;
  }

  Future<void> redeemInvite(String code) async {
    await _c.rpc('redeem_invite_code', params: {'p_code': code});
  }

  // ----- Platform onay paneli -----
  Future<List<CredentialRow>> pendingCredentials() async {
    final rows = await _c
        .from('profile_credentials')
        // profile_credentials → profiles arasında iki bağlantı var
        // (başvuran: profile_id, inceleyen: reviewed_by). Başvuranı istiyoruz.
        .select('id, kind, coach_level, status, note, sports(name), '
            'profiles!profile_credentials_profile_id_fkey(full_name)')
        .eq('status', 'pending')
        .order('submitted_at');
    return (rows as List)
        .map((r) => CredentialRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<PendingClub>> pendingClubs() async {
    final rows = await _c
        .from('clubs')
        .select('id, name, city')
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List)
        .map((r) => PendingClub.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Bir başvuruya/kulübe bağlı belgeleri, 1 saat geçerli imzalı URL'lerle döner
  /// (yalnızca yetkili görebilir; platform admin tüm belgeleri okuyabilir).
  Future<List<({String docType, String url})>> documentsFor(
      String ownerType, String ownerId,) async {
    final rows = await _c
        .from('verification_documents')
        .select('doc_type, storage_path')
        .eq('owner_type', ownerType)
        .eq('owner_id', ownerId)
        .order('uploaded_at');
    final out = <({String docType, String url})>[];
    for (final r in rows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final url = await _c.storage
          .from(docsBucket)
          .createSignedUrl(m['storage_path'] as String, 3600);
      out.add((docType: m['doc_type'] as String, url: url));
    }
    return out;
  }

  /// Kimlik başvurusunu sonuçlandırır.
  ///
  /// [coachLevel] ve [sportCode] verilirse başvurudaki değerin yerine geçer:
  /// belge, kişinin yazdığından farklı çıktığında yöneticinin reddedip
  /// "yeniden başvur" demesi yerine doğrusuyla onaylayabilmesi için.
  Future<void> reviewCredential(
    String id,
    bool approve, {
    String? note,
    int? coachLevel,
    String? sportCode,
  }) async {
    await _c.rpc('review_credential', params: {
      'p_cred': id,
      'p_approve': approve,
      if (note != null) 'p_note': note,
      if (coachLevel != null) 'p_coach_level': coachLevel,
      if (sportCode != null && sportCode.isNotEmpty) 'p_sport_code': sportCode,
    },);
  }

  Future<void> approveClub(String id) async {
    await _c.rpc('approve_club', params: {'p_club': id});
  }

  Future<void> rejectClub(String id, {String? note}) async {
    await _c.rpc('reject_club',
        params: {'p_club': id, if (note != null) 'p_note': note},);
  }
}

// =============================== Provider'lar ==============================
final verificationServiceProvider = Provider<VerificationService>((ref) {
  return VerificationService(ref.watch(supabaseClientProvider));
});

/// Kişinin kendi kimlik başvuruları.
///
/// Yalnızca doğrulama ekranı değil, menü görünürlüğü de buna bakıyor
/// (`realRoleRoutesProvider`), o yüzden backend kapalıyken boş dönmeli —
/// aksi halde her ekranda gereksiz bir hata üretirdi.
final myCredentialsProvider =
    FutureProvider.autoDispose<List<CredentialRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <CredentialRow>[]);
  }
  return ref.watch(verificationServiceProvider).myCredentials();
});

final isPlatformAdminProvider = FutureProvider<bool>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(false);
  return ref.watch(verificationServiceProvider).isPlatformAdmin();
});

final pendingCredentialsProvider =
    FutureProvider.autoDispose<List<CredentialRow>>((ref) {
  return ref.watch(verificationServiceProvider).pendingCredentials();
});

final pendingClubsProvider =
    FutureProvider.autoDispose<List<PendingClub>>((ref) {
  return ref.watch(verificationServiceProvider).pendingClubs();
});
