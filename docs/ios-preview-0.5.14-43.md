# iOS açılış düzeltmesi — 0.5.14+43

2026-10-18: Kullanıcının iPhone'undan yalnız Runner 0.5.13/42 çökme
kayıtları okundu. Native exception stack FIRInstallations validateAPIKey →
FIRMessaging → FIRApp.configure → FLTFirebaseCorePlugin.register gösterdi.
Kişisel cihaz kayıtları depoya eklenmedi.

## Düzeltme

- Gerçek config yokken artık sahte Firebase API anahtarı üretilmez.
- Xcode kaynak referansını karşılayan disabled plist son IPA'dan çıkarılır.
- Firebase Core ve Messaging native kayıtları gerçek yapılandırma dosyası
  varsa yapılır. Diğer eklentiler değişmez. GeneratedPluginRegistrant
  Flutter tarafından üretildikten sonra Xcode precompile adımı idempotent
  guard ekler; beklenen iki kayıt bulunamazsa build başarısız olur.
- IOS_FIREBASE_ENABLED=false ile önizlemedeki bütün Dart push girişleri
  Firebase'e erişmeden unsupported/null/empty döner. Android değişmez.
- Paket doğrulayıcı config kapalıyken dosyanın yokluğunu, açıkken gerçek
  config biçimini ve bundle ID uyumunu denetler. İmzalı build config ister.

## Yerel doğrulama

- Python iOS config/native guard/paket kapısı: 7/7.
- Flutter push testleri: normal 4/4, Firebase-disabled 4/4.
- Flutter hesaplı açılış ve gezinme: 10/10.
- Mobil tam regresyon: 481/481.
- Push gönderici: 5/5; SSS 44/44; push rota 42, kayıp yok.
- Değişen Dart dosyaları analiz: 0 error/warning, 7 stil info.
- git diff --check temiz.

## Derleme ve sınırlar

Kaynak: db26aabceb3f9f26d26559abc91c2fd6ce12b496,
codex/ios-startup-fix-0.5.14-43 dalı.
macOS koşusu: https://github.com/EmirlmzYT/SwanSport/actions/runs/39070009001

Main, tag/release, canlı SQL, web veya TestFlight değişmez. Önizlemede
Firebase config yoksa push kapalıdır; sahte çalışan bildirim vaat edilmez.
Derleme/paket doğrulaması iPhone açılış kabulü değildir. Son cihaz kabulü
kullanıcının yeni IPA'yı aynı Apple hesabıyla imzalayıp açmasına bağlıdır.

## Artifact sonucu

macOS koşusu başarıyla tamamlandı; artifact ID 12115320206.
IPA: SwanSport-0.5.14+43-unsigned.ipa (13,488,233 byte).
SHA-256: e47e4ba2c5c7b8be3ef55c922556038508aa5d6d2a7744e7ba5a500de0c10ec8

İndirilenler'e kopyalandı; iki kopyanın hash'i eşleşiyor. IPA ZIP CRC temiz;
Runner executable, sürüm 0.5.14/build 43 ve com.swansport.app doğrulandı.
GoogleService-Info.plist pakette yok. CI Firebase-disabled modu ve paket
doğrulama kapısının geçtiği logdan doğrulandı. Gerçek iPhone açılışı henüz
denenmedi; kullanıcı aynı imza hesabıyla mevcut kurulum üstüne yükleyecek.
