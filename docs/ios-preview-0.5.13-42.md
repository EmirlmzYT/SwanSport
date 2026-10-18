# iOS önizleme — 0.5.13+42

2026-10-17: Kullanıcının deneme IPA talebiyle hazırlanmıştır.

- Kaynak dal: `codex/ios-preview-0.5.13-42`
- Derlenen commit: `87c81a1dd413a4c4267c1bad02b19d4f8dff9869`
- Flutter: 3.47.7 stable (yerel test SDK'sıyla aynı)
- Başarılı macOS koşusu: https://github.com/EmirlmzYT/SwanSport/actions/runs/39059075399
- Artifact: `SwanSport-iOS-0.5.13+42-unsigned`, ID `12110462108`
- IPA: `SwanSport-0.5.13+42-unsigned.ipa`
- Boyut: 13,511,266 byte
- SHA-256: `34b1b08b24834532e8d96cd96370f6ad241ccc87072185bb4cebd4344fde4061`

IPA içindeki binary Info.plist ile kısa sürüm `0.5.13`, build `42`, bundle
`com.swansport.app` doğrulandı. Runner executable mevcut, ZIP CRC kontrolü
temiz, uygulamanın CodeResources imzası yok. Arka plan modları fetch ve
remote-notification olarak paket içinde doğrulandı. Kopya yerel İndirilenler
klasörüne bırakıldı; repo içi arşiv `build/ios-preview/0.5.13+42/` altındadır.

`workflow_dispatch` için `preview_only=true` kullanıldı; Apple dağıtım
imzası/TestFlight çalıştırılmadı. Main'e merge/push, release tag, web deploy,
veritabanı migration veya canlı SQL yok. Yalnız bu önizleme dalı push edildi.

Sideloadly/AltStore ile kullanıcı tarafından imzalanarak kurulur. Bu macOS
derleme/paket doğrulamasıdır; gerçek iPhone görsel/performans testi veya APNs
teslim kanıtı değildir. Ücretsiz Apple hesabına push desteği vaat edilmez.

Kaynak test sonuçları ve kalan platform sınırları:
`docs/flutter-sdk-test-cleanup.md` (mobil 480, data 504, konsol 82; analiz
sıfır error/warning). Bu raporun sonraki commit'i yalnız teslim kaydıdır;
IPA kaynağı yukarıdaki 87c81a1 commit'idir.
