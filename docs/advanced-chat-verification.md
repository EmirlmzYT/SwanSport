# Gelişmiş DM ve sohbet deneyimi

2026-10-18. Kaynak tabanı `cf1e7b7` (header46 + chat), çalışma dalı
`codex/advanced-chat-header46`. Eski preview dalı birleştirilmedi.

## Uygulama

- DM kişi başlığında mevcut konuşma verisinden gerçek avatar/baş harf,
  profil bağlantısı, ad ve sohbet içi arama; boş durumda kişi kartı.
- `ChatItem` yalnız presentation adaptörüdür; domain/RPC imzaları değişmez.
  Mesajlar ID ile tekilleştirilip timestamp+ID ile kararlı sıralanır.
- Ortak `ChatTimeline` ve `ChatMessageBubble` DM/topluluklarda kullanılır.
  Aynı gönderen/aynı gün/en fazla beş dakika gruplama; paylaşım kartları
  grup başlatır. Gün ayraçları Bugün/Dün/Türkçe tarih, saat HH:mm.
- Gönderiliyor/Gönderildi/Okundu/Gönderilemedi gerçek yerel/server alanlarından
  üretilir. Cihaz teslimi bilinmediğinden İletildi durumu yoktur.
- Uzun basışta gerçek mesaj metnini kopyala; başarısız yerel mesajda açık
  tekrar gönder. Paylaşım kaynağından kopyalama için veri çekilmez.
- Yüklenmiş mesajlarda Türkçe arama, orijinal Unicode metinde vurgulama,
  sonuç sayacı/önceki/sonraki ve kapatma. ID bazlı seçim tazelemede korunur.
  Liste lazy kalır; uzak değişken yükseklikli arama hedefi viewport adımlarıyla
  monte edilip ensureVisible ile kesin konumlanır. Yeni navigasyon/dispose
  önceki işlemi iptal eder. Tüm geçmişte sunucu araması eklenmedi.
- Ters liste son mesajdayken yeni mesajı izler. Geçmiş okunuyorsa görünür
  satır anchor'ı korunur ve Yeni mesajlar düğmesi çıkar. Klavye padding'i
  ikinci kez eklenmez; okuma konumu klavyede sıfırlanmaz.
- DM açılışındaki bütün-konuşma read RPC ve onun eski fallback'i kaldırıldı.
  Yalnız foreground/current route viewport'uyla kesişen gelen okunmamış ID'ler
  mevcut mark_messages_read RPC'sine gider. Cache alanındaki görünmeyenler
  işaretlenmez. Başarısızlıkta sonraki görünürlük olayında tekrar denenebilir;
  kontrolsüz timer yoktur. Topluluğun mevcut kanal-okunma sözleşmesi değişmez.
- Taslak, başarısız mesaj ve tekrar gönderim korunur; async dönüşler dispose
  sonrası controller/ref/setState kullanmaz. Gönderim beklerken yeni metin
  yazılabilir; önceki isteğin dönüşü yeni taslağı silmez.

## Testler ve görsel kabul

- Yeni 16 birim/widget/görsel test: grup sınırları, sıralama, Unicode/Türkçe
  arama, tarih/saat/durum, kopyalama/retry, görünürlük, eski mesaj okunurken
  realtime ekleme, lazy arama navigasyonu, taslak/dispose, profil, arama kapatma,
  background/kapalı rota, kaynak gizliliği ve klavye yeniden boyutlanması.
- İlgili veri regresyonu (dm + social/lifecycle): **37/37**.
- Nihai tam mobil regresyon: **526/526**, exit 0. Yerel kanıt logu
  `swan-advanced-verified-full.log`; yeni 16 test ayrıca 16/16 geçti.
- Değişen kaynak/test analizi `--no-fatal-infos`: 0 error / 0 warning;
  stil info'lar korunur, analiz tümüyle sıfır bulgu değildir.
- Mobil syntax 620 dosya/0 hata, token 24/24, SSS 44/44, push 42 kayıpsız,
  git diff --check temiz.

Altı sentetik ekran görüntüsü `docs/design/advanced-chat/` altında. Tam DM
açık/koyu ve 320/393 genişlikte büyük metinli konuşma sahneleri render edilip
görsel incelendi. Testte gerçek bundled MaterialIcons fontu açıkça yüklenir;
üretim font/asset yapılandırması değişmez. Gerçek hesap/mesaj kullanılmadı.

## Değişmezler ve sınırlar

Ortak floating header, SwanScaffold, alt bar, FeedScreen, StitchFeedTopBar,
konsol, Firebase/iOS workflow, veri katmanı ve sürüm başlangıçla birebir
aynıdır (git diff boş). Widget'ta yeni doğrudan Supabase sorgusu yok.
Yeni bağımlılık, migration, RLS/RPC/public API yok. Sesli/görüntülü arama,
ses kaydı, yanıt/tepki/düzenleme/silme veya çevrimiçi durumu eklenmedi.

Fiziksel iPhone FPS/klavye/görsel ve iki gerçek hesapla mesaj teslimi ayrıca
denenmelidir. Widget testleri gerçek cihaz kabulü değildir. Main'e merge,
canlı SQL/web dağıtımı veya yeni IPA bu görevde yapılmadı.
