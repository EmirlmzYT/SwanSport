import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// Syntax/checksum only. This is NEVER proof of identity or age.
bool isValidNationalId(String value) {
  if (!RegExp(r'^[1-9][0-9]{10}$').hasMatch(value)) return false;
  final d = value.split('').map(int.parse).toList();
  final odd = d[0] + d[2] + d[4] + d[6] + d[8];
  final even = d[1] + d[3] + d[5] + d[7];
  return (odd * 7 - even) % 10 == d[9] &&
      (odd + even + d[9]) % 10 == d[10];
}

const _identityEndpoint = 'https://swansport.pages.dev/api/verify-tckn';

/// Yerel Türk telefon biçimlerini ve uluslararası önekleri E.164'e hazırlar.
String normalizePhoneNumber(String input) {
  var cleaned = input.replaceAll(RegExp(r'[\s\(\)\-\.]'), '');
  if (cleaned.startsWith('00')) {
    cleaned = '+${cleaned.substring(2)}';
  } else if (cleaned.startsWith('0') && cleaned.length == 11) {
    cleaned = '+90${cleaned.substring(1)}';
  } else if (!cleaned.startsWith('+') && cleaned.length == 10 && cleaned.startsWith('5')) {
    cleaned = '+90$cleaned';
  } else if (!cleaned.startsWith('+') && cleaned.isNotEmpty) {
    cleaned = '+$cleaned';
  }
  return cleaned;
}

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
    this.sportCode,
    this.expiresOn,
  });

  final String id;
  final String kind; // identity | coach | athlete_licensed | athlete_individual
  final int? coachLevel;
  final String status; // pending | approved | rejected
  final String? note;
  final String? personName; // admin listelerinde

  /// Onaylanan branş — federasyon kanalı buna göre belirlenir.
  final String? sportName;
  final String? sportCode;
  final DateTime? expiresOn;

  /// Legacy null expiry stays valid. Day boundaries match PostgreSQL Turkey time.
  bool isValidOn(DateTime instant) {
    if (status != 'approved') return false;
    if (expiresOn == null) return true;
    final local = instant.toUtc().add(const Duration(hours: 3));
    return !DateTime.utc(expiresOn!.year, expiresOn!.month, expiresOn!.day)
        .isBefore(DateTime.utc(local.year, local.month, local.day));
  }

  bool get isCoach => kind == 'coach';

  String get label {
    if (kind == 'identity') return 'Kimlik';
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
      sportCode: m['sport_code'] as String?,
      expiresOn: DateTime.tryParse(m['expires_on'] as String? ?? ''),
      personName: (name == null || name.isEmpty) ? null : name,
      sportName:
          (m['sports'] is Map) ? (m['sports'] as Map)['name'] as String? : null,
    );
  }
}

/// Server-owned identity state; declarations and platform roles do not supply it.
class IdentityGateState {
  const IdentityGateState({
    this.verified = false,
    this.legacyClubIds = const {},
  });

  final bool verified;
  final Set<String> legacyClubIds;

  factory IdentityGateState.fromMap(Map<String, dynamic> map) =>
      IdentityGateState(
        verified: map['identity_verified'] == true,
        legacyClubIds: Set.unmodifiable(
          (map['legacy_club_ids'] as List? ?? const []).whereType<String>(),
        ),
      );
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
  VerificationService(this._c, {http.Client? httpClient, Uri? identityEndpoint,
    void Function()? onIdentityVerified})
      : _httpClient = httpClient,
        _identityUri = identityEndpoint ?? Uri.parse(_identityEndpoint),
        _onIdentityVerified = onIdentityVerified;
  final SupabaseClient _c;
  final http.Client? _httpClient;
  final Uri _identityUri;
  final void Function()? _onIdentityVerified;

  Future<bool> mernisAvailable() async {
    final token = _c.auth.currentSession?.accessToken;
    if (token == null || _uid == null) return false;
    try {
      final res = await (_httpClient?.get(_identityUri,
        headers: {'Authorization': 'Bearer $token'}) ?? http.get(_identityUri,
        headers: {'Authorization': 'Bearer $token'})).timeout(const Duration(seconds: 12));
      return res.statusCode == 200 && (jsonDecode(res.body) as Map)['available'] == true;
    } catch (_) { return false; }
  }

  Future<({bool success, String? error})> verifyWithMernis({
    required String nationalId, required String firstName, required String lastName,
    required int birthYear,
  }) async {
    if (!isValidNationalId(nationalId) || firstName.trim().isEmpty || lastName.trim().isEmpty
        || firstName.length > 100 || lastName.length > 100 || birthYear < 1900
        || birthYear > DateTime.now().toUtc().year) {
      return (success: false, error: 'Kimlik bilgilerinizi kontrol edin.');
    }
    final uid = _uid;
    final token = _c.auth.currentSession?.accessToken;
    if (uid == null || token == null) return (success: false, error: 'Lütfen giriş yapın.');
    try {
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
      final body = jsonEncode({'national_id': nationalId, 'first_name': firstName.trim(),
        'last_name': lastName.trim(), 'birth_year': birthYear});
      final res = await (_httpClient?.post(_identityUri, headers: headers, body: body)
        ?? http.post(_identityUri, headers: headers, body: body)).timeout(const Duration(seconds: 50));
      if (_uid != uid || _c.auth.currentSession?.accessToken != token)
        return (success: false, error: 'Oturum değişti. Lütfen tekrar deneyin.');
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data is Map && data['success'] == true) {
        _onIdentityVerified?.call();
        return (success: true, error: null);
      }
      // Never render an arbitrary upstream body that could echo private data.
      return (success: false, error: switch (res.statusCode) {
        401 => 'Lütfen yeniden giriş yapın.',
        400 => 'Kimlik bilgilerinizi kontrol edin.',
        422 => 'Girilen bilgiler nüfus kütüğüyle uyuşmuyor.',
        429 => 'Çok fazla deneme yaptınız. Bir dakika sonra tekrar deneyin.',
        409 => 'Kimlik bu hesapta doğrulanamıyor. Belge incelemesini kullanın.',
        _ => 'Otomatik doğrulama kullanılamıyor. Belgenizi incelemeye gönderebilirsiniz.',
      });
    } catch (_) {
      return (success: false, error: 'Doğrulama tamamlanamadı. Belge incelemesini kullanabilir veya tekrar deneyebilirsiniz.');
    }
  }

  String? get _uid => _c.auth.currentUser?.id;

  /// Doğrulama belgelerinin Storage bucket adı.
  static const String docsBucket = 'verification-docs';

  /// Server-owned tier. Never infer verification from an editable profile.
  Future<String> venueVerificationTier() async {
    if (_uid == null) return 'none';
    final result = await _c.rpc<dynamic>('my_venue_verification_tier');
    return result == 'id' || result == 'phone' ? result as String : 'none';
  }

  Future<void> requestPhoneVerification(String phone) async {
    if (_uid == null) throw StateError('Oturum bulunamadı');
    final normalized = normalizePhoneNumber(phone);
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(normalized)) {
      throw ArgumentError('Geçerli bir telefon numarası yazın. Örnek: 0532 123 45 67 veya +90 532 123 45 67');
    }
    await _c.auth.updateUser(UserAttributes(phone: normalized));
  }

  Future<void> confirmPhoneVerification(String phone, String code) async {
    if (_uid == null) throw StateError('Oturum bulunamadı');
    final normalized = normalizePhoneNumber(phone);
    final cleanCode = code.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^[0-9]{6}$').hasMatch(cleanCode)) {
      throw ArgumentError('SMS ile gelen 6 haneli kodu yazın.');
    }
    await _c.auth
        .verifyOTP(phone: normalized, token: cleanCode, type: OtpType.phoneChange);
  }

  Future<IdentityGateState> identityGate() async {
    if (_uid == null) return const IdentityGateState();
    final result = await _c.rpc<dynamic>('my_identity_gate');
    return IdentityGateState.fromMap(
      (result as Map).cast<String, dynamic>(),
    );
  }

  /// Uses the existing verification_documents attachment/upload workflow.
  Future<String> submitIdentityCredential() async {
    if (_uid == null) throw StateError('Oturum bulunamadı');
    final existing = await _c
        .from('profile_credentials')
        .select('id,status')
        .eq('profile_id', _uid!)
        .eq('kind', 'identity')
        .maybeSingle();
    if (existing != null) {
      if (existing['status'] == 'pending') return existing['id'] as String;
      throw StateError(existing['status'] == 'approved'
          ? 'Kimliğin zaten onaylı.'
          : 'Kimlik başvurun reddedilmiş. Yeniden inceleme için destek ekibine başvur.');
    }
    final row = await _c
        .from('profile_credentials')
        .insert({'profile_id': _uid, 'kind': 'identity'})
        .select('id')
        .single();
    return row['id'] as String;
  }

  // ----- Başvuru (kişi kendi kimliğini oluşturur) -----
  /// Antrenörlük başvurusu. Branş burada seçilir çünkü antrenörlük belgesi
  /// zaten branşa özeldir ("Yüzme 2. Kademe") — platform hangi branşta
  /// onayladıysa federasyon kanalı da o branşa göre açılır.
  Future<String> submitCoachCredential(
    int level, {
    String? sportCode,
    DateTime? expiresOn,
  }) async {
    _requireNewCredential(sportCode, expiresOn);
    final row = await _c
        .from('profile_credentials')
        .insert({
          'profile_id': _uid,
          'kind': 'coach',
          'coach_level': level,
          if (sportCode != null && sportCode.isNotEmpty)
            'sport_code': sportCode,
          'expires_on': expiresOn!.toIso8601String().substring(0, 10),
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
  Future<String> submitAthleteCredential({
    String? sportCode,
    DateTime? expiresOn,
  }) async {
    _requireNewCredential(sportCode, expiresOn);
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
          if (sportCode != null && sportCode.isNotEmpty)
            'sport_code': sportCode,
          'expires_on': expiresOn!.toIso8601String().substring(0, 10),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static void _requireNewCredential(String? sport, DateTime? expiry) {
    if (sport == null || sport.isEmpty || expiry == null) {
      throw ArgumentError('Yeni belge için branş ve bitiş tarihi zorunlu.');
    }
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
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$docType.$ext';
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
        .select(
          'id, kind, coach_level, status, note, sport_code, expires_on, sports(name)',
        )
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
    final res = await _c.rpc<dynamic>('create_guardian_invite',
        params: {'p_athlete': athleteId});
    return res as String;
  }

  Future<void> redeemInvite(String code) async {
    await _c.rpc<dynamic>('redeem_invite_code', params: {'p_code': code});
  }

  // ----- Platform onay paneli -----
  Future<List<CredentialRow>> pendingCredentials() async {
    final rows = await _c
        .from('profile_credentials')
        // profile_credentials → profiles arasında iki bağlantı var
        // (başvuran: profile_id, inceleyen: reviewed_by). Başvuranı istiyoruz.
        .select(
            'id, kind, coach_level, status, note, sport_code, expires_on, sports(name), '
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
    String ownerType,
    String ownerId,
  ) async {
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
    String? nationalId,
    DateTime? expiresOn,
  }) async {
    await _c.rpc<dynamic>(
      'review_credential',
      params: {
        'p_cred': id,
        'p_approve': approve,
        if (note != null) 'p_note': note,
        if (coachLevel != null) 'p_coach_level': coachLevel,
        if (sportCode != null && sportCode.isNotEmpty)
          'p_sport_code': sportCode,
        if (nationalId != null) 'p_national_id': nationalId,
        if (expiresOn != null)
          'p_expires_on': expiresOn.toIso8601String().substring(0, 10),
      },
    );
  }

  Future<void> approveClub(String id) async {
    await _c.rpc<dynamic>('approve_club', params: {'p_club': id});
  }

  Future<void> rejectClub(String id, {String? note}) async {
    await _c.rpc<dynamic>(
      'reject_club',
      params: {'p_club': id, if (note != null) 'p_note': note},
    );
  }
}

// =============================== Provider'lar ==============================
final verificationServiceProvider = Provider<VerificationService>((ref) {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return VerificationService(ref.watch(supabaseClientProvider), onIdentityVerified: () {
    if (disposed) return;
    ref.invalidate(myCredentialsProvider);
    ref.invalidate(myIdentityGateProvider);
    ref.invalidate(myVenueVerificationTierProvider);
  });
});

final mernisAvailabilityProvider = FutureProvider.autoDispose<bool>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return false;
  if (ref.watch(authSessionProvider).valueOrNull == null) return false;
  return ref.watch(verificationServiceProvider).mernisAvailable();
});

/// Kişinin kendi kimlik başvuruları.
///
/// Yalnızca doğrulama ekranı değil, menü görünürlüğü de buna bakıyor
/// (`realRoleRoutesProvider`), o yüzden backend kapalıyken boş dönmeli —
/// aksi halde her ekranda gereksiz bir hata üretirdi.
final myCredentialsProvider =
    FutureProvider.autoDispose<List<CredentialRow>>((ref) {
  ref.watch(authSessionProvider);
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

/// Guest/fixture mode is closed without constructing a live Supabase client.
final myIdentityGateProvider = FutureProvider.autoDispose<IdentityGateState>(
  (ref) {
    if (!ref.watch(isSupabaseEnabledProvider)) {
      return const IdentityGateState();
    }
    ref.watch(authSessionProvider);
    ref.watch(myCredentialsProvider);
    return ref.watch(verificationServiceProvider).identityGate();
  },
);

/// Fail closed while loading/error; re-read when authentication changes.
final myVenueVerificationTierProvider =
    FutureProvider.autoDispose<String>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return 'none';
  if (ref.watch(authSessionProvider).valueOrNull == null) return 'none';
  return ref.watch(verificationServiceProvider).venueVerificationTier();
});
