# Saha işlemleri doğrulaması

2026-10-08. Altıncı yol haritası aşaması yerelde uygulandı. Canlı migration,
dağıtım ve gerçek hesap/cihaz UAT yapılmadı.

## Kort bekleme listesi

Dolu gelecek saat için kişisel FIFO sıra; bir hesap en fazla bir canlı bekleme
kaydında bulunabilir. Konum doğrulaması, yasak ve aktif oyun denetimleri mevcut
kort kurallarıyla birlikte uygulanır. Saat boşalınca sıradaki uygun kişiye en
fazla beş dakika, saat başlayana kadar kabul fırsatı verilir. Bildirim mevcut
bildirim sistemine yazılır ve `/saha-islemlerim` ekranına yönlenir.

Fırsat otomatik rezervasyon değildir. Mevcut kişi sayısı/oyuncu arama formu
kullanılır; kullanıcı kabul edince mevcut `claim_slot` gerçek sırayı oluşturur.
Korta varınca mevcut konum ve check-in akışı sürer. Formu kapatmak kayıt veya
başarı bildirimi üretmez. Fırsat süresi dolarsa sıra ilerler; kişi listeden
çıkınca sıradaki kişiye hemen geçer. Dakikalık cron ve kişisel liste okumaları
bekleme durumunu ilerletir; istemci listeyi 30 saniyede yeniler.

İptal edilen saatin eski tekil kısıtı yeni rezervasyonu engelliyordu. Yeni
kısmi benzersiz indeks canlı `claimed|active|done` kayıtlarını korur; iptal ve
süresi dolmuş oyunlar, oyuncuları ve geçmişleri silinmeden saat yeniden alınır.
Eski iptal kaydı tekrar aktifleştirilemez. Eski istemciyle sıra atlama, çift
alım ve aynı hesabın aktif oyun sınırı sunucu tetikleyicileriyle korunur.

Kort yazılarında global transaction kilidi satır/index kilidinden önce alınır;
statement tetikleyicisi eski yazı ve cron yollarını da kapsar. MVP için global
sıralama seçildi: yüksek trafik altında gecikme/kapasite ayrıca ölçülmelidir.
Gerçek iki oturumlu PostgreSQL yarış ve deadlock deneyi henüz yapılmadı.

## İşletme sahası için geçici doluluk görevi

Halı saha sistemi doluluk panosudur; kort rezervasyonu ile birleştirilmedi.
Kalıcı saha yöneticisi 1–168 saatlik özel davet oluşturur. Davet en fazla 24
saatte kabul edilir; görev ömrü oluşturma anında başlar, kabul edilince uzamaz.
Kod rastgele UUID'dir, liste RPC'sinde yayımlanmaz; tablo yalnız veren/alanın
kendi kayıtlarını okuyabildiği RLS ile korunur. Alıcı kodu Saha İşlemlerim
üzerinden kabul eder ve aktif görevin Sahayı aç düğmesiyle gerçek panoya geçer.

Geçici kişi yalnız ileri tarihli, açık saatlerdeki doluluğu düzenleyebilir.
Kalıcı yöneticilik, tekrar devir, kulüp, sporcu ve mali yetki verilmez.
`is_turf_manager` kalıcı yöneticiliği ifade etmeye devam eder. Süre bitimi,
verenin kalıcı yetkisinin kalkması, bayrağın kapanması ve geri alma yazma
hakkını sunucuda keser. Alıcı görevi bırakabilir. Süreler kilit beklemesinden
sonra duvar saatiyle denetlenir; arayüz yenilenmesi bir yetki kontrolü değildir.
Doluluk yazılarında aktör sunucudan alınır, değişiklik izi tetikleyiciyle tutulur;
notun içeriği denetim tablosuna kopyalanmaz. RLS nedeniyle sıfır satır silinmesi
  istemcide başarı sayılmaz; doluluğun gerçekten değiştiği kontrol edilir.

Davet oluştururken aynı işlem kimliğiyle ağ hatası sonrası tekrar gönderim
aynı kodu döndürür; farklı payload reddedilir. İlk denemeden sonra form süresi
kilitlenir. Form kapanınca işlem kimliği cihazda saklanmaz; yeniden açmadan
önce mevcut görev listesi kontrol edilir, gereksiz davet geri alınabilir.
Görev listesi 40 kayıtlık sayfalıdır ve eşit tarihlerde kimlikle sıralanır.

## Kademeli açılış ve kurulum

0092 ardından 0093, dosya başına transaction ve 15 saniye yerel lock_timeout
ile uygulanır. İki bayrak (`court_waitlist`, `turf_delegation`) yeni kurulumda
`admins` seviyesinde başlar, mevcut seviyeyi değiştirmez. SQL/Dart anahtarları,
SSS, gerçek giriş/ekran kapıları birlikte vardır. İç profil-bayrak yardımcısı
anon/authenticated/PUBLIC'e açık değildir; mevcut `my_feature_flags` tester,
kulüp ve platform yöneticisi anlamlarını korur.

Girişler: Profil > Yönetim > Saha İşlemlerim; kort detayında Bekleme listem;
saha detayında Saha görevlerim. Görev devret yalnız kalıcı yöneticide görünür.
Eski rotalar, beş alt gezinme öğesi ve Ana Sayfa kart sınırı korunur.
Tüm gösterilen saatler Türkiye UTC+3; RPC'lere gerçek an UTC ile gönderilir.

## Doğrulama

- Gerçek PostgreSQL/PGlite: 10 senaryo geçti (9 kapsam senaryosu + uzatma regresyonu). FIFO/timeout/iptal; eski istemci,
  tarihi koruma ve tekrar alım; konum/yasak/aktif oyun; RLS ve yardımcı izni;
  davet idempotency/tek alıcı; yazma atfı/denetim; süre/yetki/flag geri alma;
  anonim erişim; migration tekrarları/bildirim rotaları; 40/5 sayfalama;
  erken uzatma reddi, kişi sayısının korunması ve tekrar uzatmanın aynı sonucu vermesi.
- SQL: 93 migration parse, 39/39 özellik SSS kapsamı, 39 bildirim eşlemesi
  ve eski eşlemelerin korunması geçti. Katalog: 120 rota / 478 işlem / 336 kaynak.
- Flutter: 290 app + 329 data + 46 console = 665 test geçti. Yeni saha akışları,
  gerçek RPC parametreleri, hata/iptal ve sıfır satır silme davranışı kapsamda.
  Çevrimdışı yoklama testi sabit 100ms varsayımı yerine başarısız gönderimin
  gerçek kuyruk sonucunu bekler; pending durumunu gönderim öncesi saymaz.
- Değişen kaynakların 16 öğelik analizi: 0 bulgu. Bu sonuç tam projede önceden
  var olan bütün analiz bulgularının giderildiği anlamına gelmez.
- App üretim web derlemesi `main_production.dart` + `env/prod.json` ile
  başarılı: 360,7 saniye. Üretim paketinde her iki bayrak anahtarı 5'er tam
  eşleşmeyle, `/saha-islemlerim` rotasıyla birlikte mevcut.
- Console üretim web derlemesi `main_production.dart` + `env/prod.json` ve
  `/konsol/` taban yolu ile başarılı: 112,8 saniye. Diff-check ve yeni dosya
  boşluk kontrolü temiz.
- Önceden mevcut CupertinoIcons font uyarısı sürüyor; bu turda giderilmedi.

Graf indeksi değişen/yeni kaynakları kapsamıyordu; ilgili canlı kaynaklar
ayrıca okundu. Tam proje analizinde önceden mevcut kapsam dışı bulgular olabilir;
değişen kaynak analizi ayrıca raporlanır.

Canlı UAT: iki hesapla aynı kort saati yarış/iptal; teklif sürerken başka
oyuna kabul; eski istemci; gerçek push ve derin bağlantı; konum/check-in;
kapasite ve uzatma; davet kodunun gerçek cihaz panosuna kopyalanması;
kabul formu açıkken süre/yetki bitimi; görev geri alma sırasında açık doluluk
formu; oturum değişimi; 360px ekran ve ağ kopması. PGlite/sahte HTTP/widget
testleri gerçek Supabase/PostgREST, cihaz ve eşzamanlı oturum testlerinin yerine
geçmez. Canlıya yayımlandı veya cihaz UAT'si tamamlandı iddiası yok.


## 2026-10-09 Cloudflare yayını

Kullanıcı talebiyle uygulama ve konsol üretime yayımlandı; Cloudflare dağıtımı
`05b28ac9-15ed-4172-9020-c6eb078cb129` olarak onayladı. Canlı Supabase migration
uygulanmadı. Bu ağdaki ESB yönlendirmesi/TLS hatası nedeniyle canlı HTTP ve
gerçek hesap/cihaz UAT doğrulaması tamamlanamadı. Ayrıntılar
`docs/cloudflare-release-2026-10-09.md` içinde.
