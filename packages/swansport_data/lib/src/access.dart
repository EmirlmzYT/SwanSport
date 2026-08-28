import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'club_data.dart';
import 'supabase_athletes.dart';
import 'verification_service.dart';

/// Bir kişinin SwanSport'taki konumu — tek kaynak.
///
/// Bu sınıf, "kim neyi görebilir" sorusunun **veri tarafı** cevabıdır.
/// Mobil uygulama ve masaüstü konsolu farklı ekranlar gösterir ama ikisi de
/// bu hesaba dayanır.
///
/// Neden burada: bu mantık eskiden iki yerde ayrı ayrı yazılıydı —
/// uygulamada `realRoleRoutesProvider`, konsolda `consoleAccessProvider`.
/// İkisi de aynı kaynaklardan (`profiles.role` + onaylanmış belgeler)
/// hesaplıyordu ama ayrı kodlardı; biri değişince diğeri sessizce geride
/// kalırdı. Kademe eşiği gibi bir kural değiştiğinde iki uygulamanın farklı
/// davranması, hata olarak ancak kullanıcı fark ettiğinde ortaya çıkardı.
///
/// **Bu yalnızca görünürlük hesabıdır.** Yetkiyi veritabanı belirler; RLS
/// politikaları ve `security definer` fonksiyonlar son sözü söyler. Buradaki
/// bayraklara bakıp bir düğmeyi gizlemek güvenlik değildir.
class SwanAccess {
  const SwanAccess({
    required this.isPlatformAdmin,
    required this.clubRole,
    required this.coachLevel,
    required this.athleteKind,
  });

  static const SwanAccess none = SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
  );

  /// Platform yöneticisi mi (`profiles.is_platform_admin`).
  final bool isPlatformAdmin;

  /// Kulüpteki görevi: club_admin | coach | official | athlete | parent | member.
  /// Kulübü yoksa null.
  final String? clubRole;

  /// Onaylanmış **en yüksek** antrenör kademesi; antrenör değilse 0.
  ///
  /// Belgeden gelir, beyandan değil: `profile_credentials` içinde
  /// `kind='coach'` ve `status='approved'` olan satırlar.
  final int coachLevel;

  /// Onaylanmış sporcu kimliğinin türü: `athlete_licensed` |
  /// `athlete_individual`; sporcu kimliği yoksa null.
  ///
  /// Ayrım korunuyor çünkü ikisinin gördüğü şey farklı: lisanslı sporcu bir
  /// kulübe bağlı olduğu için duyuru ve kadro ekranlarını da görür, ferdi
  /// sporcu görmez.
  final String? athleteKind;

  bool get isVerifiedAthlete => athleteKind != null;
  bool get isLicensedAthlete => athleteKind == 'athlete_licensed';

  /// Kulüpte görev alıyor mu?
  ///
  /// İki yoldan biri yeter: kulüpteki rolü ya da onaylanmış antrenörlük
  /// belgesi. Belge şart, çünkü rol güncellenmiyor — kimlik onaylandığında
  /// hiçbir yer `profiles.role`'ü değiştirmiyor.
  bool get isClubStaff =>
      coachLevel > 0 ||
      switch (clubRole) {
        'club_admin' || 'coach' || 'official' => true,
        _ => false,
      };

  bool get isClubAdmin => clubRole == 'club_admin';
  bool get isParent => clubRole == 'parent';

  /// Kademe eşiğini karşılıyor mu?
  ///
  /// Kulüp yöneticisi kademeye bakılmaksızın geçer: kulübün sahibi, kendi
  /// kulübünün tesisini yönetememezlik edemez.
  bool hasCoachLevel(int minimum) =>
      minimum <= 0 || isClubAdmin || coachLevel >= minimum;
}

/// Kişinin erişim profili.
///
/// Üç kaynağı birleştirir; herhangi biri henüz yüklenmemişse elindekiyle
/// hesaplar (menüyü boş göstermektense eksik göstermek daha az yanıltıcı).
final swanAccessProvider = Provider<SwanAccess>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return SwanAccess.none;

  final isAdmin = ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
  final creds = ref.watch(myCredentialsProvider).valueOrNull ?? const [];

  var level = 0;
  String? athleteKind;
  for (final c in creds) {
    if (c.status != 'approved') continue;
    if (c.kind == 'coach') {
      final l = c.coachLevel ?? 1;
      if (l > level) level = l;
    } else if (c.kind.startsWith('athlete')) {
      // Lisanslı, ferdiye üstün gelir: ikisi birden varsa kulübe bağlı olan
      // daha geniş erişim demektir.
      if (athleteKind != 'athlete_licensed') athleteKind = c.kind;
    }
  }

  return SwanAccess(
    isPlatformAdmin: isAdmin,
    clubRole: profile.role,
    coachLevel: level,
    athleteKind: athleteKind,
  );
});
