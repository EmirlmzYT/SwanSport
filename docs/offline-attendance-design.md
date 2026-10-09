# Çevrimdışı yoklama — uygulanan sözleşme

2026-10-07. Yerel uygulama ve 0088 migration hazır; canlıya uygulanmadı.
`offline_attendance` bayrağı **off** kalır. Eski cihaz-saatiyle son yazanı seçme
önerisi geçersizdir; sunucu sürümü ve açık kullanıcı kararı kullanılır.

## Kullanıcı akışı

1. İnternet ve yetki varken Yoklama ekranında etkinlik seçilir, **Çevrimdışına
   hazırla / güncelle** ile gerçek kadro alınır. Bu düğme özellik bayrağını sorar;
   sunucu da bayrak ve aktif kulüp personeli yetkisini denetler.
2. Yalnız antrenörün dokunduğu satırlar cihazda kalıcı taslak olur. RSVP
   “katılacak” yanıtıdır; hiçbir zaman otomatik gerçek yoklamaya dönüşmez.
3. **İşaretleri kuyruğa al** taslakları tek yerel işlemde gönderim kaydına çevirir.
   Etkinlik başına bir çözülmemiş işlem bulunur; işlem beklerken satırlar kilitlenir.
4. Ana Sayfa bekleyen gönderim ve cihaz taslağı sayısını gösterir. Yoklama
   ekranında bekliyor, gönderiliyor, reddedildi, duraklatıldı ve çakıştı ayrı görünür.
   Yalnız RPC'nin doğruladığı satırlar “sunucuda doğrulandı” sayılır.
5. Bağlantı hatasında aynı `op_id` ve değişmeyen payload tekrar gönderilir.
   Sunucudaki aynı işlem tekrar uygulanmaz. Kesin reddedileni tekrar denemek veya
   açık onayla bırakıp güncel kadrodan yeniden işaretlemek mümkündür. Bırakılan
   işaretler yerel geçmişte tutulur; belirsiz gönderim bu yolla bırakılamaz.
6. Çakışmada sunucudakini kabul etmek yeni yazma yapmaz. Kendi işaretini uygulamak
   kadroyu yeniden alır, güncel sürümle **yeni** işlem üretir. Kadro/uygunluk tekrar
   kontrol edilir. Çevrimiçi akışın belirsiz sonucunda kayıtları kontrol ederek
   çıkış vardır; bu çıkış sunucudaki kaydı silmez.

## Dört depo/çatışma kararı

| Konu | Karar |
|---|---|
| Depo | Sembast 3.8.11; native uygulama destek dizininde `attendance-v1.db`, webde Sembast Web 2.4.6 / IndexedDB. |
| Kalıcılık | Native yazma sıralanır, transaction ardından `db.compact()` atomik dosya yenilemesi beklenir. IO transaction tek başına disk yazmasını beklemez. Webde IndexedDB transaction commit beklenir. |
| Saat ve iki cihaz | `marked_at` bilgi olarak kalır; saati büyük olan kazanmaz. Sunucu `version` eşleşmezse çakışma döner, kullanıcı karar verir. |
| Saklama | Kadro hazırlığı 7 gün; hesap başına 20 etkinlik, kadro başına 200 sporcu, 100 çözülmemiş işlem. Yedi günden eski gönderimler ve beş başarısız deneme duraklatılır, otomatik silinmez. En fazla 100 tamamlanmış işlem geçmişi tutulur. |

Kadro süresi bitince yeni çevrimdışı işaret yapılamaz; önceden yazılmış taslak ve
kuyruk korunur. Hazırlanmış, aynı hesaba ait kadro internet yokken yedi günlük
süre içinde kullanılabilir; bağlantı hatası yeni bir özelliği açmaz. Sunucu
bayrağı/yetkiyi yeni gönderimde tekrar denetler. Bayrak kapatıldıktan sonra
önceden tamamlanmış işlemin sonucunu tekrar almak yeni yazma yapmaz.

## Veri ve yetki

- Widget Supabase sorgulamaz; tüm servis, kuyruk ve Riverpod sağlayıcıları ortak
  `swansport_data` içindedir. `/attendance` ve eski ekran importu korunur.
- Her cache/taslak/işlem `actor_id` ile ayrılır. Hesap değişince eski worker durur;
  gönderim RPC'si yerel actor ile `auth.uid()` eşleşmesini ayrıca zorlar.
  Çıkışta sessiz veri silinmez; aynı hesap yeniden açınca bekleyen işini görür.
- Sunucu aktif personel, etkinlik, aktif sporcu, aynı kulüp, takım kadrosu ve
  uygunluğu denetler. Muhasebeci kadro RPC'sine erişmez. Hesapsız sporcu desteklenir.
- 0088, 0065'in RPC imzalarını korur. Etkinlik ve işlem kilidi + koşullu sürüm
  güncellemesi iki isteğin sessizce birbirini ezmesini önler. Doğrudan eski
  istemci güncellemesi de trigger ile sürümü artırır.
- Aynı actor/op farklı etkinlik veya farklı payload için kullanılamaz. Eski,
  hash'i olmayan işlem kayıtları yalnız saklanmış sonucu tekrar döndürür.
- Mevcut 0032 denetim trigger'ı korunur; tekrar gönderim ikinci denetim satırı
  üretmez. Takımsız etkinlik aktif kulüp kadrosunu alır; çok sezonlu takım
  üyeliği aynı sporcuyu çoğaltmaz.
- Web sekmeleri yerel transaction/30 saniyelik lease ile gönderimi paylaşır.
  Ağ isteği 10 saniyede zaman aşımına uğrar. Uygulama açıkken 30 saniyelik
  kontrol ve artan bekleme uygulanır; kapalı uygulamada OS arka plan servisi yoktur.
- Yerel kayıt parola, token veya teşhis içermez. Cihazın uygulama alanında ad ve
  kadro bulunduğu için ortak cihazda oturum açmak depodaki fiziksel veriyi silmez.
  Sunucuya ulaşmadan yetki iptali eski cache'e anında yansıtılamaz; süreli cache
  bu sınıra sahiptir. Sunucu erişim reddi alındığında cache ekran için kullanılmaz.

## Doğrulama

- 12 veri davranış testi: dokunulan satır, hesap ayrımı, sürümün korunması,
  aynı kimlikle tekrar, beş hata/eski işlem, iki worker lease'i, güncel sürümle
  çakışma çözümü, yazmasız kabul, kesin reddi bırakma, native kapanma/açılma,
  disk bariyeri hatasında ağ gönderiminin engellenmesi; kayıp yanıttan sonra yetki reddi gelince önceki işlemin belirsiz kalması.
- 1 gerçek Chrome/IndexedDB testi: transaction, kapat/aç, aynı işlem kimliği ve
  hesap ayrımı. `tools/test_offline_attendance_web.ps1` yeniden çalıştırır.
  Flutter 3.44.7 Windows test sunucusunun CanvasKit yol hatası için yalnız test
  süresince SDK'daki aynı yerel dosyaları test dizininden servis eder ve kaldırır.
- 6 widget testi: RSVP otomatik yazılmaz, belirsiz sonuç aynı kimlikle tekrar
  denenir, ağsız hazırlanmış kadro ve kuyruk, reddedilen işlemi açık onayla
  bırakma, çevrimiçi çıkış ve Ana Sayfa durumu. 360px ekran kontrol edilir.
- 8 PGlite/PostgreSQL davranış testi gerçek 0088 ve 0032 denetim fonksiyonlarını
  çalıştırır: kadro, idempotency/hash, sürüm, kısmi çakışma, izinler, bayrak,
  sağlık/bozuk payload ve migration'ın yeniden uygulanması.

Tam regresyon: **257 uygulama + 300 veri + 43 konsol = 600 Flutter testi** geçti.
Yeni kaynak analizi 0 bulgu; migration parse 88/88, SSS 36/36, push rotaları 37,
katalog senkronu ve diff kontrolü başarılı. Üretim web derlemesi başarılı;
ayrıca 1 Chrome/IndexedDB ve 8 SQL testi geçti. Sonuçlar TEAM_BOARD.md'de kaydedilir. SQL fixture'ları
bütün Supabase şemasını veya gerçek iki PostgreSQL oturumunu temsil etmez.
Kapat/aç testleri ani güç kaybı/fsync garantisi değildir. Fiziksel Android cihazda
uygulamayı zorla kapatma, gerçek iki cihaz/sekme, oturum yenileme, yetki iptali,
çakışma ekranı ve bildirim UAT'si canlı açılıştan önce yapılmalıdır.

## Yayın sırası

0088 dosya başına transaction ve `lock_timeout=15s` ile uygulanır; mevcut migration
paketleme kuralına uyulur. Uygulama paketi yayınlanır; SSS satırı aynı migration'dadır.
Bayrak yalnız seçili gerçek hesap/cihaz UAT'sinden sonra `admins`/`testers` aşamasına
geçirilir. Bu görev canlı SQL, APK veya web yayını yapmaz. Çalışma commit edilmedi.
Uygulama verisini silmek, kaldırmak veya web site depolamasını temizlemek yerel
kuyruğu kaybettirir; sunucuya gitmeyen kayıt için bulut yedeği yoktur.
