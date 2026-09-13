# Mobil sürüm yayımlama

Sürümün tek kaynağı `apps/swansport_app/pubspec.yaml` içindeki
`version: major.minor.patch+build` alanıdır. Bu değeri artır, `main`e al ve
**tam olarak** `v<version>` etiketi oluştur.

Örnek: `version: 0.4.1+12` için etiket `v0.4.1+12` olmalı.

```bash
git tag v0.4.1+12
git push origin v0.4.1+12
```

Etiket iki workflow çalıştırır:

- **Release Android APK:** imzalı APK üretir, GitHub Release'e yükler.
  Android uygulamasının açılıştaki güncelleme mekanizması bu Release'i okur.
- **Build iOS IPA and optionally release to TestFlight:** Sideloadly ile
  kurulabilen unsigned IPA'yı her zaman üretir ve sürüm etiketinde GitHub
  Release'e ekler. Apple signing bilgileri tanımlıysa ayrıca imzalı IPA
  üretip TestFlight'a yollar.

## GitHub Actions ayarları

**Settings → Secrets and variables → Actions** altında şunları tanımla.

### Secrets

| Ad | Değer |
| --- | --- |
| `SUPABASE_URL` | Production Supabase URL |
| `SUPABASE_ANON_KEY` | Production anon key |
| `ANDROID_KEYSTORE_BASE64` | Yayın `.jks` dosyasının Base64 içeriği |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore parolası |
| `ANDROID_KEY_ALIAS` | Anahtar adı |
| `ANDROID_KEY_PASSWORD` | Anahtar parolası |
| `GOOGLE_SERVICES_JSON_BASE64` | Android `google-services.json` dosyasının Base64 içeriği |
| `APPSTORE_CERTIFICATES_FILE_BASE64` | Apple Distribution `.p12` dosyasının Base64 içeriği |
| `APPSTORE_CERTIFICATES_PASSWORD` | `.p12` parolası |
| `APPSTORE_API_PRIVATE_KEY` | App Store Connect `.p8` dosyasının tam metni |

### Variables

| Ad | Değer |
| --- | --- |
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |
| `APPSTORE_API_KEY_ID` | App Store Connect API Key ID |

Apple Developer/App Store Connect tarafında önce `com.swansport.app` Bundle
ID'sini ve uygulama kaydını oluştur. API anahtarına TestFlight yükleme yetkisi
ver. Workflow, `IOS_APP_STORE` provisioning profile'ını API ile indirir.

Apple secret ve variable değerleri opsiyoneldir. Eksik olduklarında workflow
hata vermez; TestFlight adımlarını atlar ve unsigned IPA üretmeye devam eder.

`workflow_dispatch`, unsigned IPA'yı mevcut uygulama sürümünün GitHub
Release'ine ekler. TestFlight yüklemesi yalnızca sürüm etiketiyle olur; aynı
iOS build numarası yanlışlıkla yeniden TestFlight'a yollanmaz.
