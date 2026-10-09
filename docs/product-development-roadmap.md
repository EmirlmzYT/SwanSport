# SwanSport geliştirme yol haritası

2026-10-07. Kullanıcı uygulamaya başlamayı onayladı. Canlı yayın/migration bu görevde yapılmaz.

| Sıra | Teslimat | Tamamlanma ölçütü |
|---|---|---|
| 1 | Sezon açılış sihirbazı | Gerçek sezon, yeni takım, seçilen mevcut sporculardan kadro, isteğe bağlı program ve taslak aidat planı tek işlemde hazırlanır. Yetki, tekrar gönderim ve geri alma testleri geçer. |
| 2 | Çevrimdışı yoklama | Kalıcı cihaz kuyruğu, yalnız elle işaretlenen satırlar, hesap ayrımı, bekleyen kayıt görünümü, sürüm çakışmasını kullanıcıya gösterme ve uygulama kapanıp açılınca kurtarma. |
| 3 | Hata düzeltmesini doğrulama | Hatanın düzeltildiği sürüm, yeniden oluşma ve talep sahibinin çözüm teyidi birbirine bağlanır. |
| 4 | Veli işlem merkezi | Mevcut izin/belge/yanıt akışlarının gerçek bekleyen işleri tek listede gösterilir. |
| 5 | Dönem gelişim raporu | Devam, hedef ve ölçümlerden paylaşılabilir özet; eksik veri görünür; veli/sporcu/yetkili erişimi korunur. |
| 6 | Saha bekleme listesi ve görev devri | Sırada süreli fırsat, iptal ve yetki süresi sunucuda korunur; bildirim/davet akışı gerçek çalışır. |

## İlk aşamanın sözleşmesi

- Giriş: Profil → Yönetim → Sezon Açılışı. Yalnız kulüp yöneticisi.
- `season_setup` bayrağı önce `admins`; kapalıyken giriş ve ekran erişimi kapanır.
  RPC ayrıca kulüp yöneticiliğini ve bayrağı denetler. SSS yeni özellikle birlikte gelir.
- Mevcut `seasons`, `teams`, `team_memberships`, `events`, `fee_plans` kullanılır.
  İşlem tekrarlarını saklayan küçük kayıt dışında ikinci takım/defter/takvim kurulmaz.
- İlk sürüm **yeni takım** açar. Mevcut takımı yeni sezona taşıma sonraki genişletmedir:
  eski kadro okumalarının sezon bazında ayrılması ayrıca doğrulanmalıdır.
- Kadroda giriş profili olmayan sporcular seçilebilir. Sporcu aktif ve aynı kulüpten olmalıdır.
- Sezon en fazla 366 gün; isteğe bağlı ilk program en fazla 91 gün ve sezon sınırları içinde.
  Saatler Türkiye saatidir. Program mevcut `create_event_series` RPC'siyle takıma bağlanır.
  Etkinliklerin mevcut bildirim zinciri çalışır; son kontrolde bu açıklanır.
- Aidat planı isteğe bağlı ve **pasif taslak** oluşturulur. Aidat Yönetimi → Planlar'dan
  etkinleştirilir; atama/tahakkuk aynı bölümde ayrıca yapılır.
  Mevcut burs/indirim/aidat atamaları bu hazırlık işlemine dahil değildir.
- Kaydetmeden önce bütün oluşturulacak kayıtlar ve program adedi gösterilir.
- Bir hata tüm işlemi geri alır. Tekrar gönderimde aynı işlem kimliği aynı sonucu döndürür.
  Aynı kimlikle değişmiş veri kabul edilmez. Kulüp satırı kilidi iki açılışı sıraya koyar.
- Ağ hatasından sonra form kilitli kalır; aynı işlem tekrar sorgulanıp gönderilir.
  Başarısızlığı kesinleşmiş kayıtta düzeltme yapılarak yeni deneme mümkündür.
  İstenirse açıklama sonrası kayıtları kontrol ederek çıkılır. Hazırlık cihazda kalıcı
  saklanmaz; uygulama kapandıktan sonra önce mevcut sezon/takım kontrol edilmelidir.

İlk aşamanın kurulum ve doğrulama ayrıntıları: `docs/season-setup-verification.md`.

## İkinci aşama — çevrimdışı yoklama (yerelde uygulandı)

Kalıcı Sembast dosya/IndexedDB deposu, elle işaretlenen taslaklar, hesabına bağlı
kuyruk, tekrar gönderim, bekleyen kayıt satırı ve açık sürüm çakışması çözümü hazır.
0088 sunucuda atomik sürüm kontrolünü ve işlem/payload eşleşmesini sağlar.
Kapanma/yeniden açılma hem dosya hem gerçek Chrome/IndexedDB üzerinde doğrulandı.
Bayrak canlıda `off` kalır; cihaz ve iki oturum UAT'si yayın kapısıdır.
Ayrıntılar ve sınırlar `docs/offline-attendance-design.md` içinde.

## Üçüncü aşama — hata düzeltmesini doğrulama (yerelde uygulandı)

Hata merkezinde sürüm/platform bildirimi, gerçek tekrar oluşma filtresi ve destek
sahibinin güncel düzeltmeye teyidi eklendi. Bekleyen, çözüldü ve devam ediyor
sonuçları ayrı görünür; eski formlar ve çift gönderimler korunur. İkinci bir hata
veya destek sistemi kurulmadı. Kurulum ve sınırlar `docs/diagnostic-fix-verification.md`.

## Dördüncü aşama — veli işlem merkezi (yerelde uygulandı)

Mevcut veli bağlantılarıyla çoklu çocuk/kulüp etkinlik yanıtları, belge süre
uyarıları ve kendi destek yanıtları tek listede toplandı. Çocuğa özgü belge
geçişi/yükleme, özel dosya erişimi ve iki veli için eski form kontrolü tamamlandı.
Hukuki izin talebi akışı bulunmadığı için sahte izinler üretilmedi.
Kurulum, doğrulama ve sınırlar `docs/parent-action-center-verification.md` içinde.

## Beşinci aşama — dönem gelişim raporu (yerelde uygulandı)

Gerçek tarih aralığındaki etkinlik yoklaması ve uyumlu performans ölçümleri,
açıkça güncel olarak etiketlenen hedef durumu ve görünür veri eksikleri hazır.
Veli/sporcu/personel yetkisi sunucuda korunur. Önizlemeli metin kopyalama,
kimliği isteğe bağlı ekler; erişimi ve veri değişikliğini tekrar kontrol eder.
Kurulum, doğrulama ve sınırlar `docs/development-report-verification.md` içinde.

## Altıncı aşama — saha bekleme listesi ve görev devri (yerelde uygulandı)

Dolu gelecek kort saati için FIFO sıra, beş dakikalık kabul fırsatı, gerçek
rezervasyon/kişi sayısı ve mevcut konum onayı birbirine bağlandı. Eski istemci
sırayı atlayamaz; iptal edilen saat yeniden alınırken geçmiş oyun saklanır.
Halı saha işletmesi, yalnız doluluk düzenlemesini süreli özel davetle devredebilir.
Kalıcı yönetici rolü, kulüp ve mali yetkiler değişmez. Süre, geri alma ve görevi
bırakma sunucuda uygulanır. Ayrıntılar: `docs/saha-operations-verification.md`.

Altı aşamanın yerel uygulaması tamamlandı. Canlı kurulum ve hesap/cihaz UAT'si açık.

## Yayın kapısı

Her aşamada veri/RPC davranış testleri, ilgili widget testleri, analiz ve üretim derlemesi;
sonra seçili hesaplarla canlı UAT. Geri çekme bayrakla yapılır. Migration/yayın ayrıca yürütülür.
