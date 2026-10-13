# SwanSport — Faz 2: Ortak Veri Katmanı (`swansport_data` & `SwanAccess`) Codex Uygulama Şartnamesi

**Tarih:** 2026-10-13
**Kapsam:** `packages/swansport_data` içinde 0110 şemasına uygun domain modelleri, Supabase servisleri, Riverpod sağlayıcıları ve merkezi `SwanAccess` yetkilendirme motorunun kurulması.

---

## 1. Mimari Prensipler ve Değişmezler (Invariants)

1. **`swansport_data` Arayüze Asla Bağlanmaz:**
   - Pakette `IconData`, `Color`, Flutter widget'ları veya UI teması yer alamaz.
   - Yalnızca saf Dart modelleri, Riverpod provider'ları ve Supabase RPC çağrıları bulunur.
2. **Yetki Hesabı Tek Merkezdedir (`SwanAccess`):**
   - Mobil uygulama rota kümesini, masaüstü konsolu ise modül listesini doğrudan `SwanAccess` üzerinden hesaplar.
   - İki uygulama için ayrı ayrı rol hesabı yapılamaz.
3. **Doktor Esnekliği Sözleşmesi:**
   - `can_verify_medical` aktif izni olan sağlık görevlisi için `hasMedicalAuthority` bayrağı döner.
   - Doktorsuz kulüplerde antrenör veya yönetici için idari durum yönetimi açık kalır.
4. **Muhasebeci ve Çocuk Gizliliği Korunur:**
   - Hakem esame kartı ve modellerinde TC kimlik no, veli telefonu veya özel tıbbi teşhis alanları yer alamaz.

---

## 2. Oluşturulacak ve Güncellenecek Dosyalar

### A. Yeni Domain Modelleri (`packages/swansport_data/lib/src/sports_roles/`)
1. **`sports_role_models.dart`**:
   - `FederationRole`: `id`, `federationId`, `profileId`, `role` (enum: `president`, `boardMember`, `generalSecretary`, `provincialRep`, `refereeCommittee`, `disciplinaryBoard`), `cityCode`, `startsOn`, `endsOn`, `isActive`.
   - `RefereeProfile`: `id`, `profileId`, `licenseNumber`, `badgeTier` (enum: `candidate`, `provincial`, `national`, `international`), `sportCode`, `cityCode`, `isActive`.
   - `MatchOfficial`: `id`, `matchId`, `profileId`, `duty` (enum: `headReferee`, `assistantReferee1`, `assistantReferee2`, `fourthReferee`, `tableOfficial`, `observer`), `status` (enum: `assigned`, `accepted`, `declined`, `replaced`), `declineReason`, `assignedAt`, `respondedAt`.
   - `MatchLineupApproval`: `id`, `matchId`, `participantId`, `side` (enum: `home`, `away`), `starterAthleteIds`, `substituteAthleteIds`, `verifiedBy`, `verifiedAt`, `isLocked`.
   - `ClubStaffRole`: `id`, `clubId`, `profileId`, `role` (enum: `president`, `sportingDirector`, `doctor`, `physiotherapist`, `kitManager`, `mediaOfficer`), `assignedAt`.

### B. Yeni Servis ve Sağlayıcılar (`packages/swansport_data/lib/src/sports_roles/sports_roles_service.dart`)
1. **`SportsRolesService`**:
   - `fetchMyFederationRoles()` -> `federation_roles` tablosundan aktif rolleri çeker.
   - `fetchMyRefereeProfile()` -> `referee_profiles` tablosundan hakem profilini çeker.
   - `fetchMyRefereeMatches({String? status})` -> `my_referee_matches` RPC'sini çağırır.
   - `respondMatchAssignment(String officialId, bool accept, {String? reason})` -> `respond_match_assignment` RPC'sini çağırır.
   - `verifyMatchLineup(String matchId, List<String> homeRoster, List<String> awayRoster, {String? notes, List<String>? homeSubs, List<String>? awaySubs})` -> `referee_verify_lineup` RPC'sini çağırır.
   - `fetchAcceptedMatchOfficials(String matchId)` -> `accepted_match_officials` RPC'sini çağırır.
   - `fetchMatchLineupApprovals(String matchId)` -> `match_lineup_approvals` tablosundan maçın kilitli esamelerini çeker.
   - `fetchMyClubStaffRoles()` -> `club_staff_roles` tablosundan kulüp ihtisas kadrolarını çeker.

2. **Riverpod Provider'ları**:
   - `myFederationRolesProvider`: `FutureProvider<List<FederationRole>>`
   - `myRefereeProfileProvider`: `FutureProvider<RefereeProfile?>`
   - `myRefereeMatchesProvider`: `FutureProvider.family<List<RefereeMatchSummary>, String?>`
   - `matchLineupApprovalsProvider`: `FutureProvider.family<List<MatchLineupApproval>, String>`
   - `acceptedMatchOfficialsProvider`: `FutureProvider.family<List<AcceptedMatchOfficial>, String>`
   - `myClubStaffRolesProvider`: `FutureProvider<List<ClubStaffRole>>`

### C. `SwanAccess` Genişletmesi (`packages/swansport_data/lib/src/access.dart`)
`SwanAccess` sınıfına aşağıdaki alanlar ve metotlar eklenir:
```dart
final List<FederationRole> federationRoles;
final RefereeProfile? refereeProfile;
final List<ClubStaffRole> clubStaffRoles;

// Federasyon Yetkileri
bool get isFederationPresident =>
    federationRoles.any((r) => r.role == FederationRoleKind.president && r.isActive);

bool isProvincialRep(String cityCode) =>
    isFederationPresident ||
    federationRoles.any((r) =>
        r.role == FederationRoleKind.provincialRep &&
        r.cityCode == cityCode &&
        r.isActive);

bool get isRefereeCommitteeMember =>
    isFederationPresident ||
    federationRoles.any((r) => r.role == FederationRoleKind.refereeCommittee && r.isActive);

bool get isDisciplinaryBoardMember =>
    isFederationPresident ||
    federationRoles.any((r) => r.role == FederationRoleKind.disciplinaryBoard && r.isActive);

// Hakemlik
bool get isReferee => refereeProfile != null && refereeProfile!.isActive;

// Kulüp İhtisas Rolleri
bool isClubPresident(String clubId) =>
    clubStaffRoles.any((r) => r.clubId == clubId && r.role == ClubStaffRoleKind.president);

bool isClubSportingDirector(String clubId) =>
    clubStaffRoles.any((r) => r.clubId == clubId && r.role == ClubStaffRoleKind.sportingDirector);

bool isClubMedicalStaff(String clubId) =>
    clubStaffRoles.any((r) =>
        r.clubId == clubId &&
        (r.role == ClubStaffRoleKind.doctor || r.role == ClubStaffRoleKind.physiotherapist));

bool isClubKitManager(String clubId) =>
    clubStaffRoles.any((r) => r.clubId == clubId && r.role == ClubStaffRoleKind.kitManager);
```

`swanAccessProvider` içinde:
- `ref.watch(myFederationRolesProvider)`
- `ref.watch(myRefereeProfileProvider)`
- `ref.watch(myClubStaffRolesProvider)` izlenerek `SwanAccess` nesnesi üretilir.

---

## 3. Doğrulama ve Test Adımları
1. `packages/swansport_data/test/sports_roles_test.dart` birim testi yazılır.
   - `SwanAccess` hiyerarşi testi: Federasyon Başkanının il temsilcisi yetkisini otomatik karşılaması.
   - Doktorsuz kulüpte antrenör yetkisinin bozulmaması testi.
   - Hakem profili ve maç atama serileştirme testleri.
2. `melos run analyze` veya `flutter test` ile tip ve sözdizimi doğrulaması yapılır.
