# Mobil paketler — 1.0.1+58

Kullanıcı 20 Ekim 2026'da son değişikliklerle IPA ve APK'nın GitHub'a yüklenmesini istedi. Kaynak `codex/home-quick-access`, ürün değişiklikleri `f3e71af` ve sürüm artışıdır.

- Android: mevcut yayın anahtarıyla imzalı APK; son yayımlanan APK ile sertifika eşliği kontrol edilir.
- iOS: Apple imza/config bilgileri depoda olmadığı için unsigned IPA; Sideloadly/AltStore ile kullanıcı tarafından imzalanır. Firebase native açılış koruması ve config yokluğu doğrulanır. TestFlight yüklemesi yapılmaz.
- Önceki beş iş akışının test kanıtları `club-workflows-roadmap.md` içindedir. 0134–0138 migrationları bu yayın talebi kapsamında canlıya uygulanmaz. Yeni sunucu akışları canlı backend üzerinde çalışmış sayılmaz; transfer bayrağı admins başlar.
- Üretim web dağıtımı ve başlangıçtaki iki Windows generated dosyası bu pakete dahil değişiklik değildir.

## Paket doğrulaması

İki CI koşusu aynı `e4d568c6b44e607db5412f79de6bc86dc2f69d8c` kaynağında başarılı:

- Android: https://github.com/EmirlmzYT/SwanSport/actions/runs/39361484082 — artifact 12237357365.
- iOS: https://github.com/EmirlmzYT/SwanSport/actions/runs/39361486738 — artifact 12237587909.
- Python iOS Firebase/native guard/paket kapısı 7/7 geçti.

| Dosya | Byte | SHA-256 |
| --- | --- | --- |
| SwanSport-1.0.1+58.apk | 80053226 | 5024eba1c9f918eaca170c9253574bcc092bd767e7f705ba81c9b7667d62ebd6 |
| SwanSport-1.0.1+58-unsigned.ipa | 13988096 | a5d82fe451a3bde07fe53539d22a6e6ccdcb33687cd00c098c27a5e2efb1f0e1 |

Her iki ZIP CRC kontrolü geçti. Google'ın resmî Maven deposundan alınan apksig 9.0.1 ile APK'nın v2 imzası kriptografik doğrulandı. Sertifika SHA-256 değeri `6da57755e82f50e0804010df82bed862e2813a4ba433be72741e4c8e821915bb`; GitHub'daki önceki 0.5.26+56 APK ile eş. Önceki APK'nın dosya SHA-256 değeri GitHub release digest'iyle ayrıca karşılaştırıldı.

Android binary manifest ve iOS Info.plist: 1.0.1 / 58, `com.swansport.app`. IPA'da Runner executable/Mach-O ve uygulama imzasının yokluğu doğrulandı; GoogleService-Info.plist ve xcent dosyası yoktur. Bu, fiziksel iPhone'da açılış veya APNs teslim kabulü değildir. İnceleme araçları ve ikili dosyalar ignore edilen `build/mobile-release-58` altındadır.

## Yayın sonucu

Yayın tamamlandı ve GitHub `latest` kaydı `v1.0.1+58` olarak doğrulandı. İki paketin ve SHA256SUMS dosyasının sunucudaki byte/digest değerleri yerel dosyalarla eşleşiyor; release hedefi tam `e4d568c6b44e607db5412f79de6bc86dc2f69d8c` commit'idir. Draft ve prerelease değildir.

- Sürüm: https://github.com/EmirlmzYT/SwanSport/releases/tag/v1.0.1%2B58
- APK: https://github.com/EmirlmzYT/SwanSport/releases/download/v1.0.1%2B58/SwanSport-1.0.1%2B58.apk
- IPA: https://github.com/EmirlmzYT/SwanSport/releases/download/v1.0.1%2B58/SwanSport-1.0.1%2B58-unsigned.ipa

Canlı SQL, web deploy ve TestFlight yapılmadı. Yerel önizleme sunucusunun varlığı mobil cihaz kurulumu kabulü değildir.
