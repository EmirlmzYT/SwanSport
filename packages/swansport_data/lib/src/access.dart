import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'club_data.dart';
import 'club_staff_operations.dart';
import 'expense_service.dart';
import 'federation_records.dart';
import 'live_match_models.dart';
import 'parent_actions.dart';
import 'saha_operations.dart';
import 'sports_roles_models.dart';
import 'sports_roles_service.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';
import 'turf_service.dart';
import 'verification_service.dart';

enum SwanAction {
  matchFollow,
  clubApplication,
  rsvp,
  message,
  listing,
  reservation,
  partner,
  courtCheckIn,
  publish
}

enum SwanActionDecision {
  allowed,
  accountRequired,
  identityRequired,
  phoneRequired
}

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
    this.accountantClubIds = const {},
    this.guardianAthleteIds = const {},
    this.verificationTier = 'none',
    this.managedTurfFieldIds = const {},
    this.delegatedTurfFieldIds = const {},
    this.sportCredentials = const [],
    this.federationAppointments = const [],
    this.federationRoles = const [],
    this.refereeProfile,
    this.clubStaffRoles = const [],
    this.medicalAuthorityClubIds = const {},
    this.administrativeStatusClubIds = const {},
    this.clubOperationsAuthority = const [],
    this.hasAccount = true,
    this.hasVerifiedIdentity = false,
    this.legacyIdentityClubIds = const {},
  });

  static const SwanAccess none = SwanAccess(
    isPlatformAdmin: false,
    hasAccount: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
  );

  final bool hasAccount;
  final bool hasVerifiedIdentity;
  final Set<String> legacyIdentityClubIds;

  SwanActionDecision decisionFor(SwanAction action) {
    if (!hasAccount) return SwanActionDecision.accountRequired;
    if (action == SwanAction.clubApplication && !hasVerifiedIdentity) {
      return SwanActionDecision.identityRequired;
    }
    if ((action == SwanAction.reservation ||
            action == SwanAction.partner ||
            action == SwanAction.courtCheckIn) &&
        !hasVerificationTier('phone')) {
      return SwanActionDecision.phoneRequired;
    }
    return SwanActionDecision.allowed;
  }

  /// Only these named routes may construct screens without an account.
  static bool isGuestRoute(String? route) {
    final target=Uri.tryParse(route??'');
    if(target!=null && !target.hasScheme && !target.hasAuthority && target.pathSegments.length==2
      && target.pathSegments.first=='canli-mac' && isPublicMatchId(target.pathSegments.last))return true;
    return const {
        '/',
        '/auth',
        '/landing',
        '/akis',
        '/kesfet',
        '/kortlar',
        '/halisahalar',
        '/partner-ara',
        '/oyuncu-aranan',
        '/federasyon-takvimi',
        '/calendar',
        '/yardim',
        '/rehber',
        '/canli-skor',
      }.contains(route);
  }

  bool get isInIdentityWaitingRoom =>
      hasAccount && !hasVerifiedIdentity && legacyIdentityClubIds.isEmpty;

  /// One axis only: membership role, child/guardian and RLS checks still apply.
  bool passesIdentityGateForClub(String clubId) =>
      hasVerifiedIdentity || legacyIdentityClubIds.contains(clubId);

  bool canRequestSportMembership(
    String sportCode, {
    String role = 'athlete',
    DateTime? at,
  }) =>
      hasVerifiedIdentity &&
      (role == 'athlete' || role == 'coach') &&
      sportCredentials.any(
        (credential) =>
            credential.sportCode == sportCode &&
            credential.isValidOn(at ?? DateTime.now()) &&
            (role == 'coach'
                ? credential.kind == 'coach'
                : credential.kind == 'athlete_licensed' ||
                    credential.kind == 'athlete_individual'),
      );

  /// Kimlik doğrulama kademesi: none | location | phone | id.
  ///
  /// Belge doğrulamasından (lisans, antrenörlük) ayrı bir eksen — o belgeler
  /// "ne yapabilirsin"i, bu "gerçek bir insan olduğun ne kadar biliniyor"u
  /// söylüyor. Telefon seviyesi Supabase Auth onayından, kimlik seviyesi onaylı kimlik belgesinden gelir.
  final String verificationTier;

  /// Kademe sıralaması — sunucudaki `verification_rank` ile aynı.
  static int rankOf(String tier) => switch (tier) {
        'id' => 3,
        'phone' => 2,
        'location' => 1,
        _ => 0,
      };

  /// Verilen kademeyi karşılıyor mu?
  bool hasVerificationTier(String minimum) =>
      rankOf(verificationTier) >= rankOf(minimum);

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

  final List<CredentialRow> sportCredentials;
  final List<FederationAppointment> federationAppointments;

  final List<FederationRole> federationRoles;
  final RefereeProfile? refereeProfile;
  final List<ClubStaffRole> clubStaffRoles;
  final Set<String> medicalAuthorityClubIds;
  final Set<String> administrativeStatusClubIds;
  final List<ClubOperationsAuthority> clubOperationsAuthority;
  bool canReadClubInventory(String clubId) => clubOperationsAuthority.any((a)=>a.clubId==clubId&&a.inventoryRead);
  bool canManageClubInventory(String clubId) => clubOperationsAuthority.any((a)=>a.clubId==clubId&&a.inventoryWrite);
  bool canReadClubHealth(String clubId) => clubOperationsAuthority.any((a)=>a.clubId==clubId&&a.healthRead);
  bool canReadClubPlanning(String clubId) => clubOperationsAuthority.any((a)=>a.clubId==clubId&&a.planningRead);
  bool get hasOperationalClubRole => clubOperationsAuthority.any((a)=>a.inventoryRead||a.healthRead||a.planningRead);
  bool get canOpenClubInventory => clubOperationsAuthority.any((a)=>a.inventoryWrite);
  bool get canOpenClubInventoryRead => clubOperationsAuthority.any((a)=>a.inventoryRead);
  bool get canOpenClubHealth => clubOperationsAuthority.any((a)=>a.healthRead);
  bool get canOpenClubPlanning => clubOperationsAuthority.any((a)=>a.planningRead);

  /// Aggregate visibility only. Scoped queries must supply their federation ID;
  /// these role labels never grant the legacy official result-write duties.
  bool get isFederationPresident => federationRoles.any(
      (r) => r.role == FederationRoleKind.president && r.isActive);
  bool get hasActiveFederationRole => federationRoles.any((r) => r.isActive);
  bool get canViewRefereeAssignments => isRefereeCommitteeMember || federationRoles.any(
      (r) => r.role == FederationRoleKind.provincialRep && r.isActive);
  bool get canViewProvincialLeagues => isFederationPresident || federationRoles.any(
      (r) => r.role == FederationRoleKind.provincialRep && r.isActive);
  bool canAssignOfficialsForFederation(String federationId) => federationRoles.any((r) =>
      r.federationId == federationId && r.isActive &&
      (r.role == FederationRoleKind.president || r.role == FederationRoleKind.refereeCommittee));
  bool isProvincialRep(String cityCode, {String? federationId, DateTime? at}) =>
      federationRoles.any((r) =>
        (federationId == null || r.federationId == federationId) &&
        r.isActiveOn(at ?? DateTime.now()) &&
        (r.role == FederationRoleKind.president ||
          (r.role == FederationRoleKind.provincialRep && r.cityCode == cityCode)));
  bool get isRefereeCommitteeMember => isFederationPresident || federationRoles.any(
      (r) => r.role == FederationRoleKind.refereeCommittee && r.isActive);
  bool get isDisciplinaryBoardMember => isFederationPresident || federationRoles.any(
      (r) => r.role == FederationRoleKind.disciplinaryBoard && r.isActive);
  bool get isReferee => refereeProfile?.isActive ?? false;
  bool _hasClubStaffRole(String clubId, ClubStaffRoleKind role) =>
      clubStaffRoles.any((r) => r.clubId == clubId && r.role == role);
  bool isClubPresident(String clubId) => _hasClubStaffRole(clubId, ClubStaffRoleKind.president);
  bool isClubSportingDirector(String clubId) => _hasClubStaffRole(clubId, ClubStaffRoleKind.sportingDirector);
  bool isClubDoctor(String clubId) => isClubMedicalStaff(clubId);
  bool isClubMedicalStaff(String clubId) =>
      _hasClubStaffRole(clubId, ClubStaffRoleKind.doctor) ||
      _hasClubStaffRole(clubId, ClubStaffRoleKind.physiotherapist);
  bool isClubKitManager(String clubId) => _hasClubStaffRole(clubId, ClubStaffRoleKind.kitManager);
  bool get hasMedicalAuthority => medicalAuthorityClubIds.isNotEmpty;
  bool hasMedicalAuthorityForClub(String clubId) => medicalAuthorityClubIds.contains(clubId);
  /// Administrative rest is independent of a physician being present; medical
  /// or disciplinary locks can still only be cleared by the authoritative RPC.
  bool canManageAdministrativeStatus(String clubId) =>
      administrativeStatusClubIds.contains(clubId) || clubOperationsAuthority.any((a)=>a.clubId==clubId&&a.administrativeWrite);

  /// Sport credentials never inherit the club-admin or platform-admin shortcut.
  int coachLevelForSport(String sportCode, {DateTime? at}) {
    var level = 0;
    for (final credential in sportCredentials) {
      if (credential.kind == 'coach' &&
          credential.sportCode == sportCode &&
          credential.isValidOn(at ?? DateTime.now())) {
        final candidate = credential.coachLevel ?? 1;
        if (candidate > level) level = candidate;
      }
    }
    return level;
  }

  bool hasCoachLevelForSport(String sportCode, int minimum, {DateTime? at}) =>
      minimum <= 0 || coachLevelForSport(sportCode, at: at) >= minimum;

  /// Club scope and active membership are checked again by the roster RPC.
  bool isHeadCoachForSport(String sportCode, {DateTime? at}) =>
      isClubAdmin || coachLevelForSport(sportCode, at: at) >= 3;

  bool isAssistantCoachForSport(String sportCode, {DateTime? at}) {
    final level = coachLevelForSport(sportCode, at: at);
    return level == 1 || level == 2;
  }

  bool get canPublishFederationResults => federationAppointments.any(
        (a) => canWriteFederation(
            a.sportCode, a.cityCode, FederationDuty.resultPublisher),
      );

  bool canWriteFederation(
    String sportCode,
    String? cityCode,
    FederationDuty duty, {
    DateTime? at,
  }) =>
      federationAppointments.any(
        (appointment) => appointment.authorizes(
          sportCode,
          cityCode,
          duty,
          at ?? DateTime.now(),
        ),
      );

  /// Onaylanmış sporcu kimliğinin türü: `athlete_licensed` |
  /// `athlete_individual`; sporcu kimliği yoksa null.
  ///
  /// Ayrım korunuyor çünkü ikisinin gördüğü şey farklı: lisanslı sporcu bir
  /// kulübe bağlı olduğu için duyuru ve kadro ekranlarını da görür, ferdi
  /// sporcu görmez.
  final String? athleteKind;

  bool get isVerifiedAthlete => athleteKind != null;
  bool get isLicensedAthlete => athleteKind == 'athlete_licensed';

  /// Onaylanmış en az bir belgesi var mı?
  ///
  /// Veritabanındaki `has_approved_credential()` ile aynı soruyu sorar.
  /// Kişisel malzeme ilanı bu şarta bağlı: karşındakinin kim olduğu belli
  /// olmadan ikinci el alışverişi güven taşımıyor. Buradaki kontrol yalnızca
  /// arayüzü doğru göstermek için — asıl engel `create_listing` içinde.
  bool get hasApprovedCredential => coachLevel > 0 || isVerifiedAthlete;

  /// Muhasebecisi olduğu kulüplerin kimlikleri.
  ///
  /// Muhasebecilik **ayrı bir eksen**: kulüpte görev almak değil, dışarıdan
  /// hizmet vermek. Bu yüzden [isClubStaff]'i etkilemiyor — muhasebeci
  /// kulübün defterini görür ama sporcularını, kadrosunu, yoklamasını görmez.
  /// Aynı kişi hem antrenör hem başka bir kulübün muhasebecisi olabilir.
  final Set<String> accountantClubIds;

  bool get isAccountant => accountantClubIds.isNotEmpty;

  bool isAccountantOf(String? clubId) =>
      clubId != null && accountantClubIds.contains(clubId);

  /// Yönettiği halı sahaların kimlikleri.
  ///
  /// `turf_field_managers`'tan gelir (club_accountants ile birebir aynı
  /// şekil) — bu da courts/club dünyalarından ayrı, üçüncü bir eksen: sahibi
  /// olan, ücretli, dışarıdan bir işletme ilişkisi.
  final Set<String> managedTurfFieldIds;

  bool isTurfManagerOf(String fieldId) => managedTurfFieldIds.contains(fieldId);
  final Set<String> delegatedTurfFieldIds;
  bool canEditTurfOccupancy(String fieldId) =>
      isTurfManagerOf(fieldId) || delegatedTurfFieldIds.contains(fieldId);

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

  /// Matches can_post_for_club: a credential alone does not grant club publishing.
  bool get canPublishClubPosts =>
      clubRole == 'club_admin' || clubRole == 'coach';

  bool get isClubAdmin => clubRole == 'club_admin';

  /// Bağlı çocuklar; kulüp rolünden bağımsız veli görünürlüğü.
  final Set<String> guardianAthleteIds;
  bool get isParent => clubRole == 'parent' || guardianAthleteIds.isNotEmpty;

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
  if (ref.watch(isSupabaseEnabledProvider) &&
      ref.watch(authSessionProvider).valueOrNull == null) {
    return SwanAccess.none;
  }
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return SwanAccess.none;

  final isAdmin = ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
  final creds = ref.watch(myCredentialsProvider).valueOrNull ?? const [];
  final identityGate = ref.watch(myIdentityGateProvider).valueOrNull ??
      const IdentityGateState();

  var level = 0;
  String? athleteKind;
  for (final c in creds) {
    if (!c.isValidOn(DateTime.now())) continue;
    if (c.kind == 'coach') {
      final l = c.coachLevel ?? 1;
      if (l > level) level = l;
    } else if (c.kind.startsWith('athlete')) {
      // Lisanslı, ferdiye üstün gelir: ikisi birden varsa kulübe bağlı olan
      // daha geniş erişim demektir.
      if (athleteKind != 'athlete_licensed') athleteKind = c.kind;
    }
  }

  // Muhasebecilik kendi sorgusundan geliyor, kulüp listesinden türetilmiyor:
  // aynı kulübün hem yöneticisi hem muhasebecisi olan biri için kulüp listesi
  // yalnızca üyeliği gösteriyor ve muhasebeci bayrağı kayboluyordu.
  final accountantClubs =
      ref.watch(myAccountantClubIdsProvider).valueOrNull ?? const <String>{};

  final managedTurfFields =
      ref.watch(myManagedTurfFieldIdsProvider).valueOrNull ?? const <String>{};

  return SwanAccess(
    isPlatformAdmin: isAdmin,
    hasVerifiedIdentity: identityGate.verified,
    legacyIdentityClubIds: identityGate.legacyClubIds,
    clubRole: profile.role,
    coachLevel: level,
    sportCredentials: creds,
    federationAppointments:
        ref.watch(myFederationAppointmentsProvider).valueOrNull ?? const [],
    federationRoles: ref.watch(myFederationRolesProvider).asData?.value ?? const [],
    refereeProfile: ref.watch(myRefereeProfileProvider).asData?.value,
    clubStaffRoles: ref.watch(myClubStaffRolesProvider).asData?.value ?? const [],
    medicalAuthorityClubIds:
        ref.watch(mySportsClubAuthorityProvider).asData?.value.medicalClubIds ?? const {},
    administrativeStatusClubIds:
        ref.watch(mySportsClubAuthorityProvider).asData?.value.administrativeClubIds ?? const {},
    clubOperationsAuthority: ref.watch(myClubOperationsAuthorityProvider).asData?.value ?? const [],
    athleteKind: athleteKind,
    accountantClubIds: accountantClubs,
    guardianAthleteIds:
        ref.watch(guardianAthleteIdsProvider).valueOrNull ?? const {},
    verificationTier: identityGate.verified
        ? 'id'
        : (ref.watch(myVenueVerificationTierProvider).valueOrNull ?? 'none'),
    managedTurfFieldIds: managedTurfFields,
    delegatedTurfFieldIds:
        ref.watch(delegatedTurfFieldIdsProvider).valueOrNull ?? const {},
  );
});

/// Rol, üyelik veya oturum değiştiğinde `swanAccessProvider` ve onu besleyen
/// tüm sağlayıcıları topluca geçersiz kılar (invalidate).
void invalidateSwanAccessProviders(void Function(ProviderOrFamily) invalidate) {
  final providers = <ProviderOrFamily>[
    currentProfileProvider,
    activeClubProvider,
    isPlatformAdminProvider,
    myCredentialsProvider,
    myIdentityGateProvider,
    myAccountantClubIdsProvider,
    myManagedTurfFieldIdsProvider,
    delegatedTurfFieldIdsProvider,
    myFederationAppointmentsProvider,
    myFederationRolesProvider,
    myRefereeProfileProvider,
    myClubStaffRolesProvider,
    mySportsClubAuthorityProvider,
    myClubOperationsAuthorityProvider,
    guardianAthleteIdsProvider,
    myVenueVerificationTierProvider,
  ];
  for (final p in providers) {
    invalidate(p);
  }
}

extension SwanAccessRefX on Ref {
  /// SwanAccess'i besleyen tüm profil, üyelik ve yetki provider'larını yeniler.
  void invalidateSwanAccess() => invalidateSwanAccessProviders(invalidate);
}

extension SwanAccessWidgetRefX on WidgetRef {
  /// SwanAccess'i besleyen tüm profil, üyelik ve yetki provider'larını yeniler.
  void invalidateSwanAccess() => invalidateSwanAccessProviders(invalidate);
}

