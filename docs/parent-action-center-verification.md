# Veli işlem merkezi — yerel uygulama ve doğrulama

2026-10-07. Canlı migration, dağıtım ve commit yapılmadı.

## Davranış

- Profil → Yönetim → Veli İşlem Merkezi ve Veli Paneli → İşlemler.
  `/veli-izinleri` eski adresi korunur; `/veli-bagla` davet kodu ekranıdır.
- Mevcut `parent_hub` bayrağı hem girişlerde hem ekranda hem yeni RPC'lerde
  kontrol edilir. 0090 mevcut yayın kademesini değiştirmez; yeni kurulumda admins.
- Gerçek `guardians` bağlantıları okunur. Çocuklar farklı kulüplerden gelebilir;
  `athletes.profile_id` gerekli değildir. Aynı bağlantının tekrar kaydedilmesi
  işi çoğaltmaz. Kulüp görevlisi olmak, başkasının çocuğunu bu listeye sokmaz.
- `SwanAccess.isParent` artık kulüp rolüne ek olarak gerçek veli bağlantısını
  da kullanır. Antrenör + veli ve muhasebeci + veli aynı hesapta çalışır;
  muhasebecilik sportif erişim sağlamaz.
- Önümüzdeki 60 günün, ilgili çocuğun kulüp/takımına ait, henüz yanıtlanmamış
  veya belirsiz etkinlikleri gösterilir. Aktif olmayan sporcu için RSVP açılmaz.
  Katılacak / katılamayacak / belirsiz yanıtı mevcut `event_rsvps` tablosuna yazılır.
  Bu **yoklama veya hukuki izin değildir**. Gerçek bir izin talebi tablosu/akışı
  yoktu; sahte talepler oluşturulmadı. Mevcut sporcu RSVP imzası korunur.
- Sunucuya gönderilen `response_at` metni mikro saniyeleriyle korunur.
  Başka veli/sporcu değiştirmişse eski form farklı kararın üzerine yazamaz.
  Aynı kararın tekrarı kayıt tarihini değiştirmez. Etkinlik başlamışsa veya
  veli bağlantısı kaldırılmışsa yazma reddedilir.
- Süresi dolan veya 30 gün içinde dolacak çocuk belgeleri gösterilir.
  Bunlar süre uyarısıdır; yeni bir belge talebi sistemi değildir. Aynı bilinen
  türde daha yeni, doğrulanmış ve 30 günden fazla geçerli/süresiz belge eski
  uyarıyı kaldırır. Doğrulanmamış yeni belge, eski uyarıyı gizlemez.
- Belge ekranı çocuğun kulübü + sporcu kimliğiyle açılır; velinin aktif
  kulübüne bağlı değildir. Yüklenen her tür belge o çocuğa bağlanır.
  Veli görünümünde doğrulama/silme düğmeleri yoktur. Dosya bağlantısı özel
  bucket'tan 1 saat geçerli imzalı URL olarak alınır; mevcut kopyalama akışı
  kullanılır. Yükleyici görsel seçer; desteklenmeyen PDF/10MB iddiası kaldırıldı.
- Tarih taşması (31 Şubat), yükleme hatası ve RPC hatası başarılı kayıt gibi
  kapanmaz. Tür/sahip/dosya işlem menülerindeki ListTile gerçek Material yüzeyi
  kullanır. Uzun çocuk adı ortak başlıkta dar ekrana sığar.
- Yalnızca talep sahibinin `awaiting_user_response` durumundaki kendi destek
  talepleri gösterilir. Açma mevcut `TicketThreadScreen` yazışmasına gider;
  durum/yanıt/düzeltme teyidi mevcut destek akışından yürür. Çocuk filtresi bu
  kişisel talepleri başka bir çocuğun talebiymiş gibi sınıflandırmaz.
- Ana Sayfa'da mevcut TodayTasks sınırı (en fazla üç kart) korunur; merkez
  için bir toplam kartı eklenir. Boş veri başarı olarak uydurulmaz; ağ hatası
  ayrı görünür ve tekrar denenebilir. Çocuk yoksa gerçek davet koduna gider.

## Özel dosya erişimi

0005 bucket politikası yalnız yükleyici/platform yöneticisini okuyordu. Bu,
veli belge satırını görebilse bile kulübün yüklediği dosyayı açmasını engelliyordu.
0090 `vdoc_read_athlete_vault` SELECT politikası gerçek sporcu belgesi + gerçek
kulüp ilişkisi + `can_view_document` şartıyla bu bağlantıyı tamamlar.

Kimlik başvurusu dosyaları kapsama girmez: yalnız kasa yükleyicisinin
`<yükleyici-uuid>/belge_<zaman>.<uzantı>` biçimi kabul edilir. Belgede
`uploaded_by` ve yol sahibi eşleşmelidir. Doğrudan tablo yazma yolu da
`guard_vault_file_association` tetikleyicisiyle korunur: dosya bağlayan kişi
kendi kasa yolunu kullanır; yükleyici sunucuda belirlenir; sporcu ilgili kulübe
ait olmalıdır. Dosya/kişi/kulüp ilişkisinin değişmediği normal doğrulama işlemi
engellenmez. Tarih/isim güncellemesi ve dosyasız metadata kaydı korunur.

Geçmişte yükleyicisi bilinmeyen veya beklenen kasa biçimini taşımayan özel
dosyalar bu ek politikadan erişim kazanmaz; mevcut yükleyici/admin erişimi
korunur. Kaynak belge/veli bağlantısı kaldırılınca yeni imzalı URL alınamaz.
Daha önce verilen URL mevcut bir saatlik süresine kadar geçerlidir.

## Doğrulama

- 6 veri testi: gerçek RPC adresi/gövdesi, timestamp hassasiyeti, çoklu rol,
  kapalı backend, çocuk belge filtresi ve hata yayılımı.
- 9 widget testi: bayrak, yüklenme/hata/yeniden deneme, davet bağlantısı,
  çocuk filtresi, çift tık, başarısız/başarılı RSVP, doğru kulübe belge geçişi,
  gerçek destek yazışması, belge sahibinin bağlanması, tarih ve form hata davranışı.
- 8 gerçek PostgreSQL/PGlite senaryosu: çoklu kulüp/çocuk, takım ve tarih
  kapsamı, eski/yanıtlanmış kayıtların elenmesi, yetkisiz/geçmiş/inaktif/null
  yazmalar, veli kaldırma, eski form/aynı karar tekrarı, kapalı bayrak/anon/doğrudan
  tablo izinleri, tekrar migration, doğrulanmış yeni belge ve Storage SELECT RLS.
- Tam Flutter testleri: 270 app + 312 data + 46 console = 628.
- 90 migration parse; SSS 36/36; bildirim rotaları 37; tanılama kataloğu
  118 rota / 453 işlem / 330 kaynak.
- Değişen 11 kaynak/test dosyasının analizi: 0 bulgu. Son kaynakla 15 ilgili
  widget/gezinme testi ayrıca geçti. Konsol main_production.dart üretim derlemesi
  geçti (52,3 saniye); uygulama son kaynakla main_production.dart üretim
  derlemesinden geçti (59,4 saniye). İki derlemede de önceden var olan
  CupertinoIcons font uyarısı sürüyor; derleme hatası yok.

Graf indeksinin değişen/yeni kaynaklarda güncel olmaması nedeniyle kaynaklar
ayrıca okundu; davranış sonucu indeks yokluğu üzerinden çıkarılmadı.

## Canlı kurulum ve kalan sınırlar

0090 dosya başına transaction ve 15 saniye yerel lock_timeout ile uygulanır.
Sonra iki uygulama üretim girişlerinden derlenir. `parent_hub` kademesi bu
migration tarafından yükseltilmez. SSS aynı bayrakla ilişkilidir.

Canlı UAT: iki farklı kulüpte kardeşler; giriş profili olmayan çocuk; aynı
çocuğa iki veli; ayrıca antrenör olan veli; saf muhasebeci; veli bağlantısı
kaldırma; kulüp yüklediği belgeye imzalı URL; kimlik belgesinin kapalı kalması;
yanıt sonrası listeden düşme; gerçek mobil dosya seçme ve ağ kesintisi.
PGlite ayrı bağlantılı iki Postgres oturumu değildir; eşzamanlı yarış ve gerçek
Supabase Storage imzalama ayrıca canlıda doğrulanmalıdır. Canlı tarayıcı/Android
UAT ve yayın bu görevde yapılmadı.
