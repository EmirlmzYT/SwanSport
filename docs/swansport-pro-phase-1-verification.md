# SwanSport Pro Faz 1 Doğrulama Raporu

**Tarih:** 2026-10-26  
**Uygulayıcı:** Gemini Worker (Subagent-Driven TDD)  
**Denetçi:** Codex Supervising Agent  
**Durum:** Faz 1 tamamlandı; Gemini teslimi Codex tarafından bağımsız olarak
denetlendi, bulunan açıklar kapatıldı ve yerel kapılar yeniden yeşil çalıştırıldı.

---

## 1. Kapsam ve Temel Kararlar

- `apps/swansport_pro` bağımsız Flutter uygulaması olarak kuruldu.
- Android namespace & application ID: `com.swansport.pro`
- iOS Bundle ID: `com.swansport.pro`
- Görünen ad: `SwanSport Pro`
- Sürüm: `0.1.0+1`
- `apps/swansport_app` kaynaklarına, rotalarına veya Ana Sayfasına kesinlikle dokunulmadı (`git diff -- apps/swansport_app` boştur).
- Doğrudan Supabase çağrısı yapan widget bulunmamaktadır; oturum yönetimi `AccountSessionService` üzerinden yürütülmektedir.
- Çalışma alanı çözücü yalnızca `SwanAccess` yetkilerine dayanır (`proWorkspacesFor`).
- Oturum değişimi `SwanAccess` kaynaklarının tamamını geçersiz kılar; önceki
  hesabın önbelleğe alınmış platform/muhasebe/federasyon yetkisi taşınmaz.
- Yetki kaynakları yüklenirken erişim reddi gösterilmez. Yükleme ve sorgu hatası,
  gerçek "profesyonel erişim yok" sonucundan ayrı durumlardır.
- Ortam adı ve debug bayrağı bilinmeyen değerlerde development'a düşmez;
  başlangıç yapılandırması hem development hem production'da fail-closed'dur.
- Hesap ekranındaki `SwanSport'u Aç` eylemi gerçek üretim web adresini
  (`https://swansport.pages.dev/`) sistem URL açıcısıyla açar.

---

## 2. Çalışma Alanları & Yetki Eşlemesi

`proWorkspacesFor(SwanAccess)` aşağıdaki 7 çalışma alanını sabit sırada çözümler:

1. **Kulüp** (`ProWorkspace.club`): `hasActiveClubStaffMembership || hasOperationalClubRole`
2. **Antrenörlük** (`ProWorkspace.coaching`): `coachLevel > 0 || clubRole == 'coach'`
3. **Federasyon** (`ProWorkspace.federation`): `canOpenFederationOperations`
4. **Hakemlik** (`ProWorkspace.referee`): `isReferee`
5. **Muhasebe** (`ProWorkspace.accounting`): `isAccountant` (`accountantClubIds.isNotEmpty`)
6. **Tesis** (`ProWorkspace.facility`): `canOpenTurfCenter` (`managedTurfFieldIds` veya `delegatedTurfFieldIds`)
7. **Platform** (`ProWorkspace.platform`): `isPlatformAdmin`

Onaylı antrenör belgesi olan ancak aktif kulüp personeli olmayan kullanıcı yalnızca Antrenörlük alanını görür; Kulüp alanı açılmaz. Tek çalışma alanı varsa seçici butonu gizlenir; çoklu alanda kullanıcı serbestçe geçiş yapabilir. Oturum veya hesap değiştiğinde önceki kullanıcının seçimi sıfırlanır.

---

## 3. Doğrulama Kanıtları

### A. Python Sözleşme Testleri
```bash
python -m unittest tools.pro_app_contract_test -v
```
**Sonuç:** 8/8 PASS.
- `test_android_identity_and_label`: PASS (`com.swansport.pro` / `SwanSport Pro`)
- `test_ios_identity_and_display_name`: PASS (`com.swansport.pro` / `SwanSport Pro`)
- `test_pro_pubspec_structure_and_dependencies`: PASS
- `test_root_workspace_contains_pro_exactly_once`: PASS
- `test_pro_has_no_firebase_or_push_artifacts`: PASS
- `test_ci_workflow_includes_pro`: PASS
- `test_build_pro_preview_workflow_contract`: PASS
- `test_open_swansport_action_uses_real_supported_fallback`: PASS

### B. Bağımlılık & Lockfile
```bash
flutter pub get --enforce-lockfile
```
**Sonuç:** `Got dependencies!` (Exit code: 0).

### C. Statik Kod Analizi ve Formatlama
```bash
dart format --output=none --set-exit-if-changed apps/swansport_pro/lib apps/swansport_pro/test
cd apps/swansport_pro && flutter analyze --no-pub --no-fatal-infos
```
**Sonuç:**
- Format: değişen Dart dosyaları biçimli, 0 değişiklik.
- Analyzer: `No issues found! (ran in 4.8s)` (Exit code: 0).

### D. Birim, Widget ve Erişilebilirlik Testleri
```bash
cd apps/swansport_pro && flutter test --no-pub
```
**Sonuç:** 43/43 PASS (Exit code: 0).
- `test/pro_workspace_test.dart`: 10/10 PASS (rol/kademe eşleme, tekillik ve sıra garantisi)
- `test/pro_workspace_controller_test.dart`: 6/6 PASS (otomatik seçim, hesap değişimi sıfırlaması)
- `test/pro_bootstrap_test.dart`: fail-closed başlangıç, bilinmeyen ortam/bayrak
  reddi ve lifecycle izolasyonu PASS.
- `test/pro_auth_test.dart`: login, yükleme/hata/no-access ayrımı, hesap değişiminde
  tüm ortak erişim girdilerinin geçersiz kılınması ve doğrudan Supabase çağrısı
  bulunmaması PASS.
- `test/pro_shell_test.dart`: 6/6 PASS (5 sabit rota ve sekme, switcher, hesap çıkışı ve kullanıcı değişimi)
- `test/pro_accessibility_test.dart`: 2/2 PASS (320px + text scale 2.0 taşma kontrolü, 48x48 tıklama alanı)

### E. Web Prod Derleme
```bash
cd apps/swansport_pro && flutter build web --release --no-pub -t lib/main_production.dart --dart-define=APP_ENV=production --dart-define="SUPABASE_URL=https://staging.swansport.internal" --dart-define="SUPABASE_ANON_KEY=test-anon-key" --no-wasm-dry-run
```
**Sonuç:** `Built build/web (34.8s)` (Exit code: 0). Cupertino ikon fontu için
zararsız bir asset uyarısı üretildi; derleme çıktısı oluştu.

### F. Ortak Veri Katmanı Regresyonu
```bash
cd packages/swansport_data && flutter test test/access_test.dart --no-pub
```
**Sonuç:** 14/14 PASS.

### G. Kaynak Sınırı
```bash
git diff -- apps/swansport_app
```
**Sonuç:** Boş (0 değişiklik).

### H. GitHub Android/iOS Önizleme Kabulü

- GitHub Actions: [Build SwanSport Pro Preview #40254315897](https://github.com/EmirlmzYT/SwanSport/actions/runs/40254315897)
- Sonuç: Pro doğrulama, Android release APK ve unsigned iOS preview işlerinin
  üçü de `success`.
- Ön sürüm: [SwanSport Pro Phase 1 Preview 0.1.0+1](https://github.com/EmirlmzYT/SwanSport/releases/tag/swansport-pro-phase1-preview-0.1.0-1)
- APK: 53,176,986 byte; SHA-256
  `215e19df64e65804457c2d4ae54d417445f36b1a94240518117b43c01aca345d`
- IPA: 7,624,966 byte; SHA-256
  `768f8e310c5c13481c754e8ab2a23de3ec17e446aa007c8d448cecadab23e01b`
- Her iki arşiv CRC kontrolünden geçti. IPA `com.swansport.pro`, `SwanSport Pro`,
  `0.1.0+1` değerlerini taşır ve `GoogleService-Info.plist` içermez.
- Bu ilk paket staging Auth'a bağlıdır. Staging projesinde kullanıcı olmadığı
  doğrulandığından gerçek SwanSport hesabıyla giriş kabulü için kullanılmaz.

### I. Production Auth Hesap Kabul Paketi (`0.1.0+2`)

- Gerçek hesapları staging'e kopyalamak yerine iki uygulamanın aynı production
  Supabase/Auth kaynağını kullanması kararı korundu.
- `tools/production_target.py` yalnız bilinen production proje adresini kabul
  eder; eksik, farklı veya staging hedefinde build fail-closed durur.
- GitHub Actions: [Production Preview #40256268977](https://github.com/EmirlmzYT/SwanSport/actions/runs/40256268977)
- Sonuç: production hedef doğrulaması, analyzer, 43/43 Pro testi, sözleşme
  testleri, Android APK ve unsigned iOS IPA işlerinin tamamı `success`.
- Ön sürüm: [SwanSport Pro 0.1.0+2 Production Auth Preview](https://github.com/EmirlmzYT/SwanSport/releases/tag/swansport-pro-v0.1.0%2B2-r2)
- APK: 53,176,986 byte; SHA-256
  `80d726df05595924c4ca88159deaa270949a443c94b7a99023422ca1bfc77450`
- IPA: 7,625,106 byte; SHA-256
  `d23de9b46b938527ec13bd1979e9f75978e3d4313826061ce96f8d623af74e78`
- İki pakette de yalnız production Supabase URL'si bulundu; staging URL'si yok.
  Arşiv CRC'leri temiz. IPA `com.swansport.pro`, `SwanSport Pro`, `0.1.0+2`
  taşır ve Firebase plist içermez.
- Bu işlem migration, SQL apply, kullanıcı kopyalama veya production veri yazımı
  yapmadı; yalnız istemci build hedefini mevcut ortak Auth'a bağladı.

---

## 4. Kalan Sınırlar ve Bilinçli Olarak Yapılmayanlar

- **Operasyon Modülleri:** Faz 1 kapsamında operasyon ekranları taşınmamıştır; Görevler, Takvim ve Gelen Kutusu güvenli "Yakında" durumundadır. Sosyal veri kaynakları sorgulanmaz.
- **Push & Bildirim:** Push altyapısı, `app_target` migration'ı ve APNs/FCM bildirimleri Faz 5 kapsamındadır.
- **Canlı Yayın:** Canlı SQL migration, üretim deploy'u, imzalı mağaza paketleri ve cross-app silent SSO Faz 1'e dahil değildir.
- **İmzalama sınırı:** `0.1.0+2` APK debug anahtarıyla imzalı production-bağlantılı
  önizlemedir; Play Store yayını değildir. IPA imzasız önizlemedir; TestFlight/
  App Store dağıtımı veya fiziksel cihaz kabulü değildir. Mağaza dağıtımları
  gerçek Android/Apple yayın imzası ister.
