# Chat yenilemesi iOS önizlemesi — 0.5.15+47

2026-10-18: Kullanıcı chat yenilemesini IPA olarak istedi.

Dal codex/ios-startup-fix-0.5.14-43. Kullanıcı build numarasını 47 olarak
düzeltti; önceki 44 koşusu teslim edilmeden iptal edildi.

Chat arayüzü kapsamı docs/chat-ui-refresh.md içindedir. Önceki Firebase
açılış koruması korunur: gerçek config yoksa push kapalı, native Firebase
kayıtları guarded, final IPA'da GoogleService-Info.plist bulunmaz.

Yerel doğrulama: iOS config/paket/native guard 7/7; chat/rota/mobil taşma
ve Firebase-disabled push testleri 45/45. Main, tag/release, web, canlı SQL
ve TestFlight değişmez. Cihaz açılış/görsel kabulü yeni IPA kurulunca yapılır.

Kaynak: b914e6737c729db4271f811e230e1c689ec50540.
Başarılı macOS koşusu: https://github.com/EmirlmzYT/SwanSport/actions/runs/39129343931
Artifact ID: 12136883294.

SwanSport-0.5.15+47-unsigned.ipa İndirilenler'e kopyalandı. Boyut
13,486,198 byte. ZIP CRC, Runner executable, sürüm 0.5.15/build 47 ve
Firebase config yokluğu doğrulandı. İki kopya SHA-256 eş:
851dfaf5932621d409dcb60989d6c77c951c87cb224dddc1282219546ef8fd8b

Gerçek iPhone kurulumu/açılışı henüz doğrulanmadı.
