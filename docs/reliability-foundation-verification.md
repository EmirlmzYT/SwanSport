# Güvenilirlik temeli — 2026-10-25

Kullanıcı ilk güvenilirlik paketini yetkilendirdi; Ana Sayfa görünümü ve sosyal
spor ağı odağı korunur. Başlangıçtaki kullanıcı revizyonları korunmuştur.
Bu görev canlı migration, web yayını, mağaza yayını veya gerçek kişilere
deneme bildirimi yapmaz.

## Son davranış

- Yeni hesap silme migration'ı rozet/etkinlik hazırlığı/kilometre taşı ve
  başka kişinin videosundaki onaylayan profil referanslarını anonimleştirir.
  Paylaşım token'ı oluşturan kişi silinince o token iptal edilir. Başka kişinin
  kayıtları silinmez; hesapsız kalan sporcu kaydı ve eski tek yönetici engeli
  korunur. RLS/istemci yazma izinleri genişlemez.
- Push işi cihaz bazında private yönetici-okunur ledger'a yazılır. Yalnız
  açık geçici sağlayıcı retleri sınırlı tekrar edilir; başarılı/sonucu belirsiz
  cihaz otomatik tekrar edilmez. Proje 404'ü token silmez; FCM UNREGISTERED
  ve gerçek web 404/410'u kayıt revizyonu hâlâ aynıysa temizler.
- Göndermeden önce güncel cihaz sahibi/revizyonu, push tercihi, DM engeli,
  veli bağı ve maç takibi/bayrak kapıları tekrar denetlenir. Ledger body,
  token, anahtar veya ham sağlayıcı hata metni saklamaz. pg_net isteğine zaten
  verilmiş bildirim sonradan geri çağrılamaz. `accepted` fiziksel teslim değildir.
- PGlite/pglast sürümleri kilitli; testler build dizinindeki bağımlılıklara
  dayanmaz. SQL parse hatası artık CI'da nonzero exit döndürür. Lokal Test
  Merkezi hem eski dört haneli hem CLI timestamp migration'larını seçer.
- CI yedi Flutter hedefinin tamamını, SQL/JS davranış testlerini, Python
  sözleşmelerini ve iki production web entrypoint'ini kapsar. Android/iOS/
  konsol artifact işleri aynı commit'in bu doğrulamasını bekler. Eski format
  borcu görünür ve bilerek bilgilendirme düzeyindedir; test/analyzer başarısızlığı
  engelleyicidir. Paket testleri asset ve dosya yolları için paket dizininden
  çalışır; root'tan hedef yolu vermek aynı test ortamı değildir.
- Sürüm matrisi source commit/dirty/sürüm/migration hash envanteri üretir;
  kanıt yokken canlı kurulum/cihaz kabulü atamaz. Gerçek kabul senaryoları
  docs/reliability-acceptance.md içinde bekliyor olarak kayıtlıdır.

## Doğrulama

- Hesap silme önce 23503 ile kırmızı; düzeltme sonrası 3/3 geçer.
- Push sınıflandırması önce eksik davranışla kırmızı; düzeltme sonrası 2/2.
- Yetki değişimi testi önce yeniden gönderim sayısında kırmızı; düzeltme
  sonrası push SQL 6/6. Bozuk/eksik yanıtlar da unknown kalır.
- Birleşik dar regresyon: **11/11** Node/PGlite.
- Kademeli yayın uyumluluğu: eski sender'ın bütün FCM 404'lerini gone sayan
  yanıtı token silmemeli. Yeni test önce kırmızı oldu; temizleme yalnız yeni
  açık `retryable=false` sınıflandırmasıyla sınırlandı. Son push paketi bu
  ek senaryoyla **7/7** geçti; bağımsız inceleme bu korumayı da doğruladı.
- Lokal migration isim seçimi: kırmızı→yeşil **1/1**.
- Mobil: **618/618**; konsol: **107/107**; data: **510/510**.
- Core **26/26**, models **1/1**, design-system **7/7**, motor **197/197**.
- Python **10/10**, SSS **52/52**, push rota **42 eşleme/kayıp yok**;
  genel JS revizyon sözleşmesi **5/5**; mobil release **1.0.4+61** geçer.
- Yeni SQL dahil migration parse: **138 dosya, hata yok**.
- Değişen workflow'lar actionlint 1.7.7 ile hatasız (shellcheck hariç).
- Mobil UI sözleşmesi **24/24** temiz; eski büyük/küçük harf beklentisi güncel
  `yeni` metnine uyarlandı, ekran değiştirilmedi.
- App ve konsol production entrypoint web build'leri geçti (71,9s / 54,3s).
  Bunlar yayınlanmadı; build yapılandırma olmadan startup-error davranışını
  içerir, gerçek backend/cihaz kabulü iddiası değildir.
- İlk genel analiz **0 hata/1 uyarı** verdi; kullanılmayan import adı çıkarıldı.
  Son genel analiz **exit 0, 0 hata/0 uyarı**, 4.813 mevcut stil/deprecation
  info ile geçti (`--no-fatal-infos`); bu sıfır lint borcu iddiası değildir.
  Toplu SQL/JS ilk koşusu fixture güncellenmeden başlatıldığı için 310 geçti/
  4 eski-fixture hatası verdi. Son kaynakla aynı kayıt/teslim/izin senaryoları
  ve yeni migration seçimi birlikte **12/12** geçti; bu hatalar ürün arızası
  olarak kapatılmadı. Kaynak sabitlendikten sonra tam koşu tekrar başlatıldı;
  sabit kaynakla son tam koşu **317/317**, sıfır hata/skip, exit 0 olarak
  tamamlandı (557s). Sonradan eklenen eski-sender uyumluluğu ayrıca 7/7
  paketinde doğrulandı. Npm temiz kurulum (`npm ci`) da geçti.

## Bağımsız inceleme

Salt okunur bağımsız inceleme hesap silme, push ACL/state machine, cihaz
devri ve CI kapsamını denetledi; önemli/kritik bulgu bildirmedi. Son eklenen
DM/veli/maç tercihi kontrolleri de eski 0040/0104/0118 sözleşmelerine karşı
tekrar incelendi. Genel is_followed kontrolü event-alt-tercihini ayrı seçmez;
mevcut 60 saniye canlı pencere/60 saniye backoff kuralında canlı tekrar zaten
süresi dolarak kapanır. Bu sınır değiştirilirse event kategorisi ayrıca taşınmalı.

## Kurulum ve gerçek kabul sınırı

Yeni dosyalar: 20261025042357_account_deletion_lifecycle.sql,
20261025042446_push_delivery_tracking.sql,
20261025042546_reliability_help_coverage.sql. Eski migration'lar korunur.
Bu dosyalar henüz bu görevde canlıya uygulanmadı.

PGlite gerçek PostgreSQL davranışını izole eder; GoTrue, PostgREST,
pg_net background worker, pg_cron ve iki eşzamanlı PostgreSQL oturumu değildir.
Docker/fiziksel telefon bu oturumda bulunmadığından gerçek kulüp/cihaz kabulü
yapılmadı. Staging'de pg_net response erişimi, cron kaydı/dakikalık yürütme,
ACL, eşzamanlı worker ve Android/iOS teslimi ayrıca tamamlanır. pg_cron
olmayan ortamda backend scheduler kurulmadan teslim takibi tamam sayılmaz.
Hukuki saklama politikası veya tüm tarihsel hesap silme ilişkilerinin denetimi
bu dar 0132 regresyonunun kanıtı olarak sunulmaz.

Yerel Flutter günlükleri `build/reliability-*` ve uygulama build dizinlerinde,
Node günlükleri `/tmp/swansport-reliability-*` altındadır; kişisel veri içermez.
