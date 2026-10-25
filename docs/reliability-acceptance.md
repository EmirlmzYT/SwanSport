# Günlük akış ve cihaz kabulü

Bu liste gerçek kullanıcı/cihaz kabulü içindir. Tamamlanmış sayılmaz; tarih,
uygulama build'i, ortam ve kişisel veri içermeyen sonuç/kanıt eklenir. Sentetik
fixture veya widget override sonucu gerçek hesap kabulünün yerine yazılmaz.
Ana Sayfa düzeni bu çalışma kapsamında değiştirilmez.

2026-10-25'te GitHub Actions `40212637923`, temiz migration zinciri üzerinde
beş gerçek GoTrue oturumu ve PostgREST/RLS ile altı sentetik Aşama 2 akışını
geçti. Bu kanıt widget override değildir; yine de fiziksel cihaz ve gerçek kişi
UAT'sinin yerine geçmez.

| Senaryo | Beklenen sonuç | Otomatik karşılık | Gerçek kabul |
|---|---|---|---|
| Üye daveti → sporcu → takım → takvim | Aynı kulüp ve doğru kişi; hesapsız çocuk kadroda kalır | Gerçek Auth/RLS ile bağlı sporcu, çift kayıt reddi ve takım bağı geçti | Fiziksel UAT bekliyor |
| Antrenör günlük yoklama, offline kapanış ve tekrar açılış | Yalnız işaretlenen satırlar; kuyruk hesap bazlı; tekrar gönderim tekil | offline_attendance veri/widget/SQL | Bekliyor |
| İki cihaz aynı yoklamayı değiştirir | Çakışma açıkça gösterilir; son yazan sessizce kazanmaz | İki bağımsız GoTrue oturumu: 1 uygulama + 1 açık çakışma; retry idempotent geçti | Fiziksel UAT bekliyor |
| Veli iki çocuk/iki kulüp | Her çocuğun doğru takvimi/belgesi; ilişki kaldırılınca erişim kapanır | Gerçek davet/redeem ve canlı bağ kaldırma sonrası erişim kesilmesi geçti | Fiziksel UAT bekliyor |
| Muhasebeci aidat/defter | Mali kayıt görünür; sporcu adı/sağlık bilgisi dönmez | Gerçek ledger satırı yalnız `athlete_ref`; ham sporcu adı RLS ile 0 satır geçti | Fiziksel UAT bekliyor |
| Aynı cihazda A → B hesabı | Liste/tercih/önbellek ve kayıt doğru hesaba geçer | console_account_scope, push_delivery_sql | Bekliyor |
| DM gönder/oku/engelle | Doğru sıra, mesaj rozeti temizlenir, zil çift saymaz | Gerçek REST yaz/oku, mesaj bildirimi ayrımı ve engel sonrası ret geçti | Fiziksel UAT bekliyor |
| Rozet/etkinlik hazırlığı/video onayından sonra hesap sil | Silme tamamlanır; başka kişinin geçmişi kalır; tek yönetici önce devir ister | account_deletion_sql | Bekliyor |
| Android/iOS ön plan, arka plan, kapalı uygulama push | Tek bildirim; doğru hesap/rota; hassas detay yok | push_ios + match_following fixture; fiziksel teslim ayrıca | Bekliyor |
| FCM proje hatası, UNREGISTERED ve geçici 503 | Proje hatasında token korunur; gerçek ölü token temizlenir; sınırlı retry | push_delivery + push_delivery_sql | Bekliyor |
| Yanıt kaybolur, cihaz başka hesaba geçer | Unknown yeniden gönderilmez; yeni kayıt silinmez | push_delivery_sql | Bekliyor |

## Yerel ve staging yürütme

İzole Test Merkezi için `docs/local-test-center.md` kullanılır. Docker/Flutter
gereklidir; test fixture'ları canlıya taşınmaz. Gerçek GoTrue/PostgREST/RLS
akışları önce bu ortamda, sonra açıkça yetkilendirilmiş staging kullanıcılarıyla
denenir. Başkasının canlı hesabı kullanılmaz, gerçek kişilere yapay bildirim
gönderilmez. Docker kabulü CI'da tamamlandı; fiziksel cihaz kabulü yapılmadı.

Push staging kabulünde ayrıca net._http_response -> ledger geçişi, cron'un
dakikada çalışması, preference/feature kapıları ve iki worker'ın SKIP LOCKED
davranışı gerçek PostgreSQL bağlantılarında doğrulanır. PGlite net/cron fixture'ı
bu uzantıların gerçek worker'ını başlatmaz.
