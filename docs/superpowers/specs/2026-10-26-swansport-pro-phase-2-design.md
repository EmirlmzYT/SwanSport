# SwanSport Pro Faz 2 — Kulüp ve Antrenörlük Tasarımı

**Tarih:** 2026-10-26
**Durum:** Kullanıcı tarafından onaylandı
**Üst tasarım:** `docs/superpowers/specs/2026-10-26-swansport-pro-app-design.md`

## 1. Amaç

Faz 2, kulüp ve antrenörlük operasyonlarını kopyalamadan SwanSport Pro'ya
getirir. Takım/kadro, yoklama, antrenman ve kulüp panelinin operasyon çekirdeği
yeni `packages/swansport_pro_features` paketinde tek kaynak olur. Geçiş boyunca
hem SwanSport hem SwanSport Pro aynı ortak özellik kodunu kullanır; SwanSport'tan
hiçbir rota, menü girişi veya özellik kaldırılmaz ve Ana Sayfa görünümü değişmez.

## 2. Seçilen yaklaşım

Üç yaklaşım değerlendirildi:

1. Bütün ekranları tek seferde taşımak: kısa vadede hızlı, fakat yaklaşık 6 bin
   satırlık birbirine bağlı ekran, rota ve yerel state'i aynı değişiklikte riske
   atar.
2. Pro için ekranları yeniden yazmak: ilk teslimi kolaylaştırır, fakat iki ayrı
   operasyon uygulaması ve zamanla ayrışan yetki/işlev davranışı üretir.
3. **Dikey dilimler:** önce paket ve host sözleşmesi, ardından kadro+yoklama,
   antrenman ve kulüp paneli; her dilim iki uygulamada parite testinden geçer.

Kullanıcı üçüncü yaklaşımı seçti. Bir dilim kabul edilmeden sonraki dilime
geçilmez; her dilim tek başına geri alınabilir.

## 3. Paket ve bağımlılık sınırı

Yeni workspace paketi:

```text
packages/swansport_pro_features
  lib/src/host/          gezinme ve sunum portları
  lib/src/roster/        takım dizini ve kadro operasyonları
  lib/src/attendance/    canlı yoklama ve devam geçmişi
  lib/src/training/      şablon, oturum, sonuç ve oluşturucu
  lib/src/club/          kulüp operasyon paneli
```

Paket yalnız Flutter, Riverpod, `swansport_core`, `swansport_data`,
`swansport_models`, gerektiğinde `swansport_branch_engine` ve mevcut antrenman
QR görünümü için saf UI bağımlılığı `qr_flutter` kullanabilir. Şunlara bağımlı
olamaz:

- `swansport_app` veya `swansport_pro` içindeki herhangi bir dosya;
- uygulamaya özel router, named-route dizesi veya deep-link çözümleyicisi;
- `apps/swansport_app/lib/app/design` ve uygulamaya özel `SwanScaffold`, alt bar,
  header ya da sosyal widget'lar;
- doğrudan Supabase istemcisi veya widget içinden tablo/RPC sorgusu.

Bu sınır bir kaynak sözleşme testiyle korunur. Veri ve yetki kaynağı mevcut
`swansport_data` provider/RPC'leridir; yeni ikinci servis veya yetki hesabı
kurulmaz.

## 4. Host sözleşmesi

Ortak paket uygulama kabuğunu sahiplenmez. Her iki uygulama aşağıdaki iki
adaptörü sağlar:

- `ProFeatureNavigator`: takım, sporcu, antrenman oturumu/sonucu ve devam
  geçmişi gibi hedefleri tipli metotlarla açar; paket route dizesi bilmez.
- `ProFeatureChrome`: başlık, geri, güvenli alt boşluk ve bildirim/snackbar gibi
  host davranışlarını sağlar; ortak içerik kendi başına ikinci bir alt gezinme
  üretmez.

Paket, hostların renk değeri uydurmasını önlemek için kendi küçük semantik
sunum sözleşmesini (`background`, `surface`, `line`, `ink`, `inkMuted`,
`accent`, `danger`, `warning`, `success`) taşır. SwanSport adaptörü mevcut
mobil tokenlarını, Pro adaptörü kendi temasını bu anlamlara eşler. Ham kullanıcı
rolü veya renk üzerinden yetki kararı verilmez.

Pro ayrıca ikinci seviye kulüp bağlam seçicisini uygular. Seçenekler mevcut
`selectedClubIdProvider`/`activeClubProvider` ve kullanıcının yetkili kulüp
kapsamından gelir; seçici yeni yetki üretmez. Operasyon rolü Pro Kulüp alanını
açsa bile aktif üyelik gerektiren kadro/yoklama işlemleri yoksa Panel bunu hata
veya boş veri gibi değil, “bu kulüpte bu işlem için aktif yetkin yok” olarak
gösterir.

## 5. Dikey dilimler

### Dilim A — Paket sınırı, kadro ve yoklama

- Workspace paketi ve bağımlılık sözleşme testi kurulur.
- Takım dizini ortak pakete çıkarılır; ekip arama/filtreleme ve yönetici için
  takım oluşturma davranışı korunur.
- Canlı yoklama ve devam geçmişi birlikte erişilebilir olur, fakat mevcut
  karara uygun olarak iki ayrı ekran kalır. Sekme değiştirerek kaydedilmemiş
  işaretlerin kaybolacağı bir birleşim yapılmaz.
- Çevrimdışı kuyruk, `op_id`, belirsiz sonuç ve iyimser sürüm çakışması mevcut
  `swansport_data` akışından aynen kullanılır.
- SwanSport'un mevcut rotaları aynı görünür davranışla ortak ekranı açar;
  Pro'da Kulüp/Antrenörlük çalışma alanından Panel ve Görevler girişleri açılır.

### Dilim B — Takım kadrosu ayrıntısı

- Kadro listeleme, sporcu ekleme/bağlama, takım değiştirme ve mevcut resmi kadro
  projeksiyonları ortak pakete çıkarılır.
- Sosyal sohbet ve kişisel sporcu profili paket içine gömülmez. Bunlar tipli
  host hedefleri olarak kalır; host hedefi sunmuyorsa ilgili aksiyon görünmez.
- Muhasebeci veya yalnız belge sahibi serbest antrenör, aktif kulüp kapsamı
  olmadan kadro yazma işlemi göremez. RLS/RPC gerçek kapı olmaya devam eder.

### Dilim C — Antrenman

- Şablon listesi, oluşturucu, canlı oturum, sonuç ve branşa özgü drill pad'leri
  ortak pakete çıkarılır.
- `swansport_branch_engine` tek branş protokol kaynağıdır; arketip veya metrik
  matematiği UI paketinde yeniden yazılmaz.
- Canlı oturumun geçici sayaç/state davranışı korunur; hesap, kulüp veya çalışma
  alanı değişiminde önceki taslak yeni bağlama taşınmaz.
- Eski SwanSport antrenman route/deep-link sözleşmeleri adaptörde korunur.

### Dilim D — Kulüp paneli ve Pro entegrasyonu

- 2.072 satırlık mevcut kulüp kokpiti tek hamleyle kopyalanmaz. Operasyon
  özetleri ve Faz 2 hedeflerine giden kartlar ortak, küçük bölümlere ayrılır.
- Faz 3–4 modüllerine ait federasyon, mali, tesis, sağlık ve platform kartları
  taşınmaz; SwanSport'taki mevcut girişleri korunur, Pro'da “yakında” veya hiç
  görünmeme davranışı üst tasarımdaki faz sınırına uyar.
- Pro Panel seçili Kulüp/Antrenörlük alanına göre ortak özet ve hızlı aksiyonları
  gösterir. Pro Görevler yalnız Faz 2'de gerçek veri kaynağı olan yoklama/kadro
  işlerini gösterir; Takvim ve Gelen Kutusu bu fazda mevcut güvenli placeholder
  durumunu korur.

## 6. Yetki, bağlam ve state

- Üst alan görünürlüğü yalnız `SwanAccess`ten gelir.
- Kulüp operasyonları aktif `club_admin`/`coach` üyeliği veya mevcut açık
  operasyon rolü ister; yalnız onaylı antrenör belgesi Kulüp alanını açmaz.
- Antrenörlük alanındaki kişisel mesleki görünüm, bağlı olmadığı kulübün kadro
  veya yoklama verisine erişim vermez.
- Aktif kulüp ve spor bağlamı mevcut kapsamlı provider'lardan gelir. Hesap,
  çalışma alanı veya kulüp değişiminde bağlama bağlı provider/local state
  sıfırlanır.
- Ortak özellik subtree'si `(userId, workspace, clubId)` anahtarıyla yeniden
  kurulur ve bağlama bağlı provider'lar açık invalidate listesiyle temizlenir.
  `IndexedStack` içinde mounted kalan eski feature state'i yeni çalışma alanına
  taşınamaz.
- Canlı yoklama host çapında dirty-state koordinatörüne kaydolur. Kullanıcı
  çalışma alanı/kulüp değiştirirse veya geri çıkarsa kaydedilmemiş işaretler için
  onay istenir; switcher doğrudan state'i yok edemez.
- UI gizleme güvenlik sayılmaz; mevcut RLS/RPC kontrolleri gevşetilmez. Faz 2
  için yeni veritabanı veya ikinci Auth kaynağı kurulmaz.

## 7. Rota ve geri davranışı

- SwanSport'un `/takim-kadro`, `/attendance`, `/antrenman-oturumu`,
  `/antrenman-sonuc`, `/antrenman-sablonlari`, `/antrenman-olustur` ve
  `/antrenmanlarim` sözleşmeleri silinmez.
- Pro kendi router'ında tipli hedefler kullanır; sosyal uygulamanın dört branch
  geçmişini taklit etmez.
- Ortak özellik içinden geri dönüş host adaptörüne gider. Pro'da geri, seçili
  çalışma alanındaki önceki Pro ekranına; SwanSport'ta mevcut route yığınına
  döner.
- Deep-link/notification route'ları bu fazda yeniden hedeflenmez; push Faz 5'tir.

Korunan SwanSport rota listesi `/teams` ve `/devam-durumu` rotalarını da içerir.
`/takim-kadro` içindeki `{id, name}` argümanı tipli host DTO'suna çevrilir;
adaptör dış sözleşmedeki map argümanını geriye uyumlu biçimde çözmeye devam eder.
Devam geçmişindeki `/calendar` aksiyonu SwanSport'ta mevcut hedefi açar; Pro
Takvim Faz 2'de placeholder olduğu için Pro adaptörü bu aksiyonu göstermeyebilir.

## 8. Hata, yükleme ve veri bütünlüğü

- Her ortak ekranda yükleniyor, hata, boş ve yetkisiz durumları ayrıdır.
- Ağ hatası “kayıt yok” veya “yetkin yok” gibi gösterilmez.
- Yoklama belirsiz sonucu aynı `op_id` ile güvenli yeniden deneme davranışını
  korur; çakışma otomatik ezilmez.
- Kaydedilmemiş yoklama, ekran/alan/hesap değişiminden önce açık uyarı verir.
- Widget'lar ham `PostgrestException` metnini kullanıcıya göstermemeli; veri
  katmanındaki güvenli hata sınıflandırmasını veya mevcut genel mesajı kullanır.

## 9. Özellik bayrakları

Bayraklar güvenlik değil kontrollü geçiş kapısıdır; RLS/RPC değişmez. Faz 2
eşlemesi şöyledir:

- takım/kadro: mevcut `team_hub`;
- antrenman: mevcut `sport_training_sessions`;
- çevrimdışı yoklama modu: mevcut `offline_attendance`;
- Pro Panel/Görevler birleşik antrenör alanı: mevcut `coach_workspace`;
- temel çevrimiçi yoklama: yeni `attendance_operations`.

`attendance_operations` mevcut kullanıcı davranışını daraltmamak için ilk SQL
satırında `everyone` başlar. Diğer mevcut bayrakların audience değerleri bu fazda
değiştirilmez; özellikle `offline_attendance=off`, `coach_workspace=admins` ve
`sport_training_sessions=admins` korunur. Her anahtar SQL satırı, Dart sabiti,
sync testi, SSS girdisi ve iki hostta gerçek `featureEnabledProvider` kontrolüyle
kanıtlanır. SwanSport'ta kapalı geçiş bayrağı mevcut rotayı silmez; kabul edilene
kadar mevcut uygulama davranışı güvenli fallback olarak kalır. Pro'da kapalı
bayrak ilgili kartı/aksiyonu göstermez veya açık “yakında” durumu verir.

## 10. Test ve kabul

Her dilimin kabulü:

- ortak paketin `swansport_app`/`swansport_pro` kaynaklarına ve doğrudan
  Supabase'e bağımlı olmadığını doğrulayan sözleşme testi;
- aynı fixture/provider override ile iki hostta eş işlev ve yetki sonucu;
- rota, geri, hesap değişimi ve seçili kulüp state sıfırlama testleri;
- çalışma alanı/kulüp değişiminde kirli yoklamanın uyarılması ve onaydan sonra
  state/provider temizlenmesi;
- 320 px genişlik ve 2.0 text scale taşma kontrolü;
- mevcut SwanSport route/navigation testleri ve Pro testlerinin tamamı;
- `swansport_data` erişim/yoklama/antrenman regresyonları;
- Android, web ve unsigned iOS CI build kapıları.

Faz 2 tamamlandı denebilmesi için dört dilimin tümü iki uygulamada çalışmalı,
production Auth paketiyle yetkili hesapta kadro/yoklama/antrenman akışları açılmalı
ve SwanSport Ana Sayfa görünümünde kaynak farkı olmamalıdır.

## 11. Kapsam dışı

- SwanSport'tan yönetim özelliklerini kaldırmak (Faz 6).
- Federasyon/hakem (Faz 3), muhasebe/tesis/uzman/platform (Faz 4).
- Push, uygulama hedefi migration'ı ve notification deep-linkleri (Faz 5).
- Yeni Supabase projesi, kullanıcı kopyalama veya ayrı Auth havuzu.
- Sessiz cross-app SSO ve mağaza imzalı dağıtım.

## 12. Geri dönüş

Her dilim ayrı commit ve host adaptörüyle teslim edilir. Bir dilim sorun çıkarırsa
SwanSport'un önceki route builder'ı geri bağlanabilir veya Pro giriş kartı
kapatılabilir; veri şeması ve mevcut ekran kaynakları silinmediği için geri
dönüş veri kaybı üretmez. Faz 2 kabulünden önce eski ekran dosyaları yalnız
ortak pakete taşınmış karşılıkları iki hostta kanıtlandıysa kaldırılır.
