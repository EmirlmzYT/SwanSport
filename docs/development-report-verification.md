# Dönem gelişim raporu — yerel uygulama ve doğrulama

2026-10-07. Canlı migration, dağıtım ve commit yapılmadı.

## Davranış ve veri sözleşmesi

- Profil → Yönetim → Gelişim Raporu (`/gelisim-raporu`). Sporcu detayından,
  performans ekranından ve velinin çocuk kartından aynı sporcuya doğrudan açılır.
- Tarih aralığı varsayılan son 90 gün; en fazla 366 gün ve geleceğe uzanamaz.
  Tarihler Türkiye takvimidir. Mevcut yoklama, performans ve hedef tabloları
  kullanılır; ikinci performans defteri veya kalıcı rapor/snapshot tablosu yoktur.
- Devam yalnız etkinliğe bağlı, sporcunun mevcut kulübüyle eşleşen kayıtları sayar.
  Dönem `events.starts_at` tarihinden belirlenir; çevrimdışı kaydın sonradan
  senkronlanması onu başka döneme taşımaz. Başlamamış etkinlik sayılmaz.
- Oran `(katıldı + geç geldi) / (katıldı + geç geldi + gelmedi)` şeklindedir.
  İzinli kayıtlar paydaya girmez. Payda yoksa oran bilinmiyor; sahte yüzde sıfır
  üretilmez. Kaydedilmemiş yoklamalar devamsızlık sayılmaz. Etkinliksiz eski
  kayıtlar `taken_at` tarihine göre ayrıca sayılır, hiçbir orana katılmaz.
  Eski takım kadrosunun tarihçesi bulunmadığı için beklenen katılım uydurulmaz.
- Ölçümler `test_date` ile döneme süzülür; kategori + test adı + birim +
  düşük/yüksek değer yönü birlikte eşleşmeden karşılaştırılmaz. İlk/son ölçüm
  tarih, oluşturma zamanı ve kimlikle kararlı sıralanır. Tek ölçüm değişim
  göstermez. Sıfır/negatif başlangıçtan yüzdelik gelişim türetilmez; ham değerler
  görünür. Ölçüm yönü lehte/aleyhte metni testin tanımlı yönüne dayanır.
- Hedef ilerlemesinin tarihçesi yoktur. Bu nedenle dönem sonuna kadar açılmış
  hedeflerin **rapor oluşturma anındaki güncel durumu** gösterilir; seçilen
  dönemin son günündeki ilerleme gibi sunulmaz. Başlık ve oran dışında özel
  notlar, değerlendirici veya sağlık verisi rapora eklenmez.
- Eksik ölçüm, ikinci ölçüm, hedef, yoklama ve etkinliksiz kayıt açıkça gösterilir.
  Ağ/erişim hatası boş başarılı rapor gibi sunulmaz; tekrar denenebilir.
- Sporcu listesi sunucuda yetkiyle süzülür, Türkçe arama ve 40 kayıtlık sayfalama
  kullanır. Ekran doğrudan Supabase sorgulamaz; ortak veri servisi kullanılır.

## Erişim ve metin kopyalama

0091 mevcut `can_view_athlete_performance` yetkisini kullanır: kendisi, gerçek
veli bağlantısı ve yetkili kulüp personeli. Profil hesabı olmayan çocuklar da
kapsanır. Saf muhasebecilik sportif erişim sağlamaz; ayrıca veli olan muhasebeci
kendi çocukları için normal veli yetkisini kullanır. Bulunmayan ve yetkisiz
sporcu aynı erişim hatasını verir. PUBLIC/anon execute kapalıdır; her definer
RPC oturumu, yetkiyi ve `development_report` bayrağını kendisi denetler.

Metin önizlemesinde ad ve kulüp varsayılan kapalı; kullanıcı isteyerek ekleyebilir.
Panoya kopyalamadan önce RPC yeniden çağrılır. Veli bağlantısı/yetki/bayrak
kaldırılmışsa veya ağ hatası varsa pano yazılmaz. Veri fingerprint'i değişmişse
önizleme güncellenir; ikinci kopyalama eylemi gerekir. Fingerprint bir yetki
anahtarı değildir. Oturum değişirken pencere kapanır; bekleyen eski isteğin
sonucu panoya yazılamaz. Çift tıklama tek yeniden doğrulama isteği üretir.

Bu teslimat paylaşılabilir **düz metin** üretir; PDF, herkese açık URL veya
sunucuda saklanan dışa aktarım dosyası oluşturmaz. Kopyalanmış metin ve ekran
görüntüsü sonradan geri çağrılamaz. Rapor doğal dilde kişisel tavsiye üretmez.

## Doğrulama

- 9 veri testi: katılımın bilinmeyen hali, eksik payload, kimlik seçimi,
  Türkçe sayılar/tarih, ölçüm yönü/tek ölçüm/sıfır taban, güncel hedef açıklaması,
  gerçek RPC parametreleri ve kapalı backend.
- 10 widget testi: gerçek bayrak kapısı, dar ekran, sunucu arama/sayfalama,
  hata/tekrar deneme, kimlik tercihi, yeniden yetkilendirme, erişim hatasında
  kopyalamama, değişen önizleme, çift tık ve oturum kapanırken geç yanıt.
- 7 gerçek PostgreSQL/PGlite senaryosu: gerçek mevcut yetki fonksiyonlarıyla
  sporcu/hesapsız çocuk/veli/personel ve muhasebeci/yabancı kulüp ayrımı;
  Türkiye tarih sınırı ve geç senkron; birim/kategori/yön ayrımı; boş/izinli
  oranı; güncel hedef/fingerprint; bayrak/anon/tarih/tekrar migration;
  Türkçe arama ve 40/7 kayıt sayfalaması.

- Tam Flutter regresyonu: 280 app + 321 data + 46 console = 647 test.
- Son kaynakla 25 ilgili uygulama/gezinme testi ve 13 veri/bayrak testi tekrar geçti.
- Değişen 14 kaynak/test dosyası analizi: 0 bulgu. Tam proje ilk taramasında
  önceden var olan 5 kapsam dışı uyarı ve diğer dosyalardaki stil bildirimleri
  görüldü; tam proje analizi temiz diye rapor edilmedi.
- 91 migration parse, SSS 37/37, bildirim rotaları 37, tanılama kataloğu
  119 rota / 455 işlem / 333 kaynak. Diff-check temiz.
- İki uygulama da açıkça `main_production.dart` + `env/prod.json` ile üretim web
  derlemesinden geçti: app 470,7 saniye, console 364,6 saniye. Önceden var olan
  CupertinoIcons font uyarısı sürüyor; derleme hatası yok. App üretim paketinde
  `development_report` anahtarı 14 kez bulunuyor; gerçek ekran/giriş kapıları
  derlemeye dahil, yalnız kullanılmayan sabit olarak kalmadı.

Graf indeksi yeni/değişen dosyalarda güncel değildi; ilgili kaynaklar ayrıca
okundu. Davranış sonuçları indeksin eksikliğinden çıkarılmadı.

## Canlı kurulum ve sınırlar

0091 dosya başına transaction içinde, 15 saniye yerel lock_timeout ile uygulanır.
Migration yeni bayrağı `admins` seviyesinde başlatır, mevcut seviyeyi değiştirmez.
Dart anahtarı, SQL bayrağı, SSS ve ekran/giriş kapıları birlikte gelir.
`testers` veya `everyone` yayını için gerçek hesaplı UAT tamamlanmalıdır.

Canlı UAT: kendi sporcu hesabı; farklı kulüplerde çocuklar; hesapsız çocuk;
veli bağlantısını kaldırma; saf muhasebeci; ayrıca veli olan muhasebeci;
kulüp personeli; Türkiye gece tarih sınırı; büyük kadro arama/sayfalama;
rapor açıkken ölçüm değişikliği; oturum kapanması; gerçek cihaz panosu ve
web tarayıcısında Clipboard API. PGlite testleri gerçek Supabase/PostgREST ve
cihaz panosu doğrulamasının yerine geçmez. Canlı tarayıcı/Android UAT yapılmadı.
