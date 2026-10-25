# Günlük akış ve cihaz kabulü

Bu liste gerçek kullanıcı/cihaz kabulü içindir. Tamamlanmış sayılmaz; tarih,
uygulama build'i, ortam ve kişisel veri içermeyen sonuç/kanıt eklenir. Sentetik
fixture veya widget override sonucu gerçek hesap kabulünün yerine yazılmaz.
Ana Sayfa düzeni bu çalışma kapsamında değiştirilmez.

| Senaryo | Beklenen sonuç | Otomatik karşılık | Gerçek kabul |
|---|---|---|---|
| Üye daveti → sporcu → takım → takvim | Aynı kulüp ve doğru kişi; hesapsız çocuk kadroda kalır | athlete_account_link, access, identity_membership testleri | Bekliyor |
| Antrenör günlük yoklama, offline kapanış ve tekrar açılış | Yalnız işaretlenen satırlar; kuyruk hesap bazlı; tekrar gönderim tekil | offline_attendance veri/widget/SQL | Bekliyor |
| İki cihaz aynı yoklamayı değiştirir | Çakışma açıkça gösterilir; son yazan sessizce kazanmaz | offline SQL sürüm senaryoları; gerçek iki bağlantı ayrıca | Bekliyor |
| Veli iki çocuk/iki kulüp | Her çocuğun doğru takvimi/belgesi; ilişki kaldırılınca erişim kapanır | parent_actions, coach_guardian SQL/veri | Bekliyor |
| Muhasebeci aidat/defter | Mali kayıt görünür; sporcu adı/sağlık bilgisi dönmez | finance_rpc ve console_today/ledger testleri | Bekliyor |
| Aynı cihazda A → B hesabı | Liste/tercih/önbellek ve kayıt doğru hesaba geçer | console_account_scope, push_delivery_sql | Bekliyor |
| DM gönder/oku/engelle | Doğru sıra, mesaj rozeti temizlenir, zil çift saymaz | chat_order, community_chat_order, dm, inbox testleri | Bekliyor |
| Rozet/etkinlik hazırlığı/video onayından sonra hesap sil | Silme tamamlanır; başka kişinin geçmişi kalır; tek yönetici önce devir ister | account_deletion_sql | Bekliyor |
| Android/iOS ön plan, arka plan, kapalı uygulama push | Tek bildirim; doğru hesap/rota; hassas detay yok | push_ios + match_following fixture; fiziksel teslim ayrıca | Bekliyor |
| FCM proje hatası, UNREGISTERED ve geçici 503 | Proje hatasında token korunur; gerçek ölü token temizlenir; sınırlı retry | push_delivery + push_delivery_sql | Bekliyor |
| Yanıt kaybolur, cihaz başka hesaba geçer | Unknown yeniden gönderilmez; yeni kayıt silinmez | push_delivery_sql | Bekliyor |

## Yerel ve staging yürütme

İzole Test Merkezi için `docs/local-test-center.md` kullanılır. Docker/Flutter
gereklidir; test fixture'ları canlıya taşınmaz. Gerçek GoTrue/PostgREST/RLS
akışları önce bu ortamda, sonra açıkça yetkilendirilmiş staging kullanıcılarıyla
denenir. Başkasının canlı hesabı kullanılmaz, gerçek kişilere yapay bildirim
gönderilmez. Buradaki oturumda Docker ve fiziksel cihaz bulunmadığından bu
satırlar otomatik olarak doldurulmamıştır.

Push staging kabulünde ayrıca net._http_response -> ledger geçişi, cron'un
dakikada çalışması, preference/feature kapıları ve iki worker'ın SKIP LOCKED
davranışı gerçek PostgreSQL bağlantılarında doğrulanır. PGlite net/cron fixture'ı
bu uzantıların gerçek worker'ını başlatmaz.
