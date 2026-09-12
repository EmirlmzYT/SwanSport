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
- **Release iOS to TestFlight:** imzalı IPA üretir ve TestFlight'a yollar.
  iOS güncellemeleri TestFlight/App Store üzerinden dağıtılır.

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

`workflow_dispatch` artifact üretir; GitHub Release ve TestFlight yüklemesi
sadece sürüm etiketiyle olur. Aynı iOS build numarasını yanlışlıkla yeniden
TestFlight'a yollamaz.
