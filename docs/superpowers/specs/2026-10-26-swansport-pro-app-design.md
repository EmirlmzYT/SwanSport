# SwanSport Pro Ayrı Uygulama Tasarımı

**Tarih:** 2026-10-26  
**Durum:** Kullanıcı onayı bekliyor  
**Kapsam:** Tasarım ve fazlama; bu belgede ürün kodu değiştirilmez.

## 1. Karar

SwanSport ve SwanSport Pro iki ayrı Flutter uygulaması olacaktır.

- **SwanSport:** spor sosyal ağı ve kişisel sporcu/veli deneyimi.
- **SwanSport Pro:** kulüp, antrenör, federasyon, hakem, muhasebe, tesis ve
  platform operasyonları.
- İki uygulama aynı Supabase projesini, kullanıcı hesabını, veri modelini ve
  `SwanAccess` yetki kaynağını kullanır.
- Bir kişi iki uygulamayı da kullanabilir. Profesyonel rolü bulunması sosyal
  uygulamayı kullanmasını engellemez.
- Pro tamamlanıp gerçek cihazda kabul edilene kadar mevcut SwanSport'tan hiçbir
  özellik, rota veya yönetim girişi kaldırılmaz.

Bu, ayrı bir flavor veya SwanSport'un kopyası değildir. Workspace'e
`apps/swansport_pro` adlı üçüncü gerçek uygulama eklenecektir.

## 2. Ürün sınırı

### SwanSport'ta kalacaklar

- Ana Sayfa/Akış, Keşfet, Mesajlar, Profil ve sosyal ağ özellikleri.
- Sporcu ve velinin kendi hayatına ait kişisel işlemler: kendi/çocuğunun
  takvimi, devam geçmişi, aidat ve belge görünümü, başvurular.
- Profesyonel kullanıcıların normal sosyal kullanıcı olarak yaptığı işlemler.
- Mevcut Ana Sayfa görünümü bu çalışma boyunca değişmez.

### SwanSport Pro'ya taşınacaklar

- Kulüp yönetimi ve kulüp personeli operasyonları.
- Antrenörlük, takım/kadro, antrenman ve yoklama yönetimi.
- Federasyon, MHK, lig, disiplin ve resmi müsabaka operasyonları.
- Hakem görevleri ve maç kokpiti.
- Muhasebe ve mali operasyonlar.
- Tesis/saha operasyonları.
- Yetkili sağlık ve uzman personel operasyonları.
- Platform yöneticisinin mobilde güvenle yapılabilecek işlemleri.

Derin ve yıkıcı platform yönetimi web konsolunda kalabilir. Platform admin
olmak geliştirici arka kapısı değildir; tek otorite yine
`profiles.is_platform_admin` ve veritabanı politikalarıdır.

## 3. Mimari

```text
apps/swansport_app ───────┐
                          ├─ packages/swansport_data ─ Supabase/RLS
apps/swansport_pro ───────┤          │
                          │          └─ SwanAccess (tek yetki hesabı)
apps/swansport_console ───┘

Geçiş süresince:
swansport_app ─┐
               ├─ packages/swansport_pro_features (ortak operasyon UI)
swansport_pro ─┘
```

- Widget'lar doğrudan Supabase çağırmaz; servisler ve provider'lar
  `swansport_data` içinde kalır.
- Yetki hesabı uygulamalarda tekrar yazılmaz. Pro çalışma alanları yalnız
  `SwanAccess` sonucunu sunuma çevirir; RLS/RPC gerçek güvenlik kapısıdır.
- Mevcut operasyon ekranları `swansport_app` içinden yeni uygulamaya
  kopyalanmaz. Taşınacak ekranlar aşamalı olarak ortak
  `swansport_pro_features` paketine çıkarılır ve geçiş süresince iki uygulama
  da aynı kodu tüketir.
- Pro kendine ait router, tema/presentation katmanı ve uygulama kabuğuna sahip
  olur. Sosyal uygulamanın dört branch'li gezinmesi Pro'ya taşınmaz.
- Ortak operasyon paketi uygulama router'ına, `app/design` katmanına veya
  uygulamaya özel widget'lara bağımlı olmaz. Ortak ekranlar navigation portları
  ve sunum jetonları üzerinden çalışır; her uygulama kendi route/deep-link
  adaptörünü sağlar. Faz 2'de ilk ekran çıkarılmadan önce bu bağımlılık sınırı
  sözleşme testiyle korunur.

## 4. Pro gezinmesi ve çalışma alanları

Pro'nun sabit alt navigasyonu:

1. **Panel** — seçili çalışma alanının özeti ve acil işler.
2. **Görevler** — onay, yoklama, atama, rapor ve bekleyen işlemler.
3. **Takvim** — antrenman, maç, görev ve tesis planı.
4. **Gelen Kutusu** — Pro kapsamlı bildirim ve mesajlar.
5. **Hesap** — çalışma alanı, hesap değiştirme, çıkış ve SwanSport'a geçiş.

Üstte çalışma alanı seçici bulunur:

- Kulüp
- Antrenörlük
- Federasyon
- Hakemlik
- Muhasebe
- Tesis
- Platform

Tek erişimi olan kişide alan otomatik seçilir. Birden fazla erişimi olan kişi
alanlar arasında geçer. Her alanın ayrıca kulüp/federasyon/tesis bağlamı varsa
ikinci bir bağlam seçici kullanılır. Seçim yetki vermez; yalnız kullanıcının
zaten sahip olduğu erişimler arasında filtreleme yapar.

| Alan | `SwanAccess` görünürlük koşulu | Kapsam kaynağı |
|---|---|---|
| Kulüp | `hasActiveClubStaffMembership || hasOperationalClubRole` | Yetkili kulüp provider'ları |
| Antrenörlük | `coachLevel > 0` veya aktif `clubRole == 'coach'` | Onaylı branş belgeleri ve aktif kulüp kapsamı |
| Federasyon | `canOpenFederationOperations` | Aktif rol/atama federasyonları |
| Hakemlik | `isReferee` | Aktif hakem profili ve kabul edilmiş görevler |
| Muhasebe | `isAccountant` | `accountantClubIds` |
| Tesis | `canOpenTurfCenter` | Yönetilen/delege edilen saha kimlikleri |
| Platform | `isPlatformAdmin` | Platform kapsamı |

Yalnız onaylı antrenör belgesi olan, aktif kulüp üyeliği olmayan kişi
**Antrenörlük** alanına girebilir; kişisel mesleki görünümünü görür fakat kulüp
operasyonları açılmaz. Doktor, fizyoterapist, malzemeci ve sportif direktör gibi
uzman personel ayrı üst alan oluşturmaz; yalnız yetkili olduğu kulüp kapsamında
**Kulüp** alanındaki ilgili modülü görür.

Alan görünürlüğü `SwanAccess`ten, alan içindeki çoklu kulüp/federasyon/tesis
seçenekleri ise mevcut kapsamlı provider'lardan gelir. Oturum, hesap veya üst
çalışma alanı değiştiğinde seçili bağlam ve alana bağlı provider state'i
geçersiz kılınır; önceki hesabın ya da alanın verisi yeni ekranda tutulmaz.

Profesyonel erişimi olmayan hesapta boş veya kırık panel yerine açıklayıcı bir
ekran gösterilir: hesap değiştir, çıkış yap veya SwanSport'u aç.

## 5. Kimlik, paket ve oturum

- Başlangıç kimlikleri: Android `com.swansport.pro`, iOS
  `com.swansport.pro`, görünen ad `SwanSport Pro`, sürüm `0.1.0+1`.
- Aynı Supabase Auth kullanıcı havuzu kullanılır; hesap ve veriler bölünmez.
- İlk sürümde kullanıcı iki uygulamada da ayrı giriş yapar. Mobil işletim
  sistemi düzeyinde sessiz oturum paylaşımı/SSO ilk sürümün önkoşulu değildir.
- Pro'nun auth callback/deep-link şeması ayrı tanımlanır; sosyal rotalar Pro
  router'ına zorla yönlendirilmez.
- Ortamlar sosyal uygulamayla aynı `development/staging/production`
  ayrımını kullanır, fakat Pro'nun build ve release işi ayrıdır.

## 6. Push ve deep-link güvenliği

Mevcut `push_subscriptions` kaydı `web|fcm` taşıyıcısını bilir ama
`social|pro` uygulama hedefini bilmez. Ayrıca bir kullanıcının bütün cihaz
aboneliklerine bütün bildirimler gönderilir. Bu yapı iki uygulama için aynen
kopyalanmayacaktır.

Pro push açılmadan önce:

- aboneliğe geriye uyumlu, varsayılanı `social` olan `app_target`
  (`social`, `pro`) eklenir;
- kayıt RPC'si hedefi doğrular ve saklar;
- bildirim olayı hedef/kategori politikasına göre doğru aboneliklere gider;
- her hedef kendi Firebase/APNs yapılandırmasına ve deep-link haritasına sahip
  olur;
- aynı hesap iki uygulamada yüklüyken yanlış uygulamanın açılmadığı test edilir.
- teslim/retry kaydı hedef uygulamayı saklar ve yeniden denemede aynı hedefi
  doğrular.

`register_push_subscription` parametre imzası değiştirilirken eski istemcinin
çalışması korunur: eski imza uyumlu wrapper olarak tutulur veya açıkça düşürülüp
tek imza bırakıldığı PostgREST katalog testinde doğrulanır. HTTP 300 üreten çift
imza bırakılamaz.

Bu tamamlanana kadar Faz 1 Pro uygulamasında push kapalıdır; uygulama içi veri
yenileme kullanılabilir.

## 7. Fazlar

### Faz 1 — Ayrı Pro temeli

- `apps/swansport_pro` workspace uygulaması ve bağımsız paket kimlikleri.
- Aynı Supabase ortamlarıyla giriş/çıkış ve hesap değiştirme.
- `SwanAccess` tabanlı Pro uygunluk kapısı ve çalışma alanı çözücü.
- Beş sekmeli Pro kabuğu, çalışma alanı seçici ve rol bazlı başlangıç panelleri.
- Faz 1'de **Panel** ve **Hesap** işlevseldir; **Görevler**, **Takvim** ve
  **Gelen Kutusu** güvenli “yakında” durumudur. Mevcut sosyal/profesyonel ayrımı
  olmayan bildirim listesi Pro Gelen Kutusu'nda gösterilmez.
- No-access, yükleniyor, hata ve boş durumları.
- Her rol, çoklu rol ve rolesiz hesap için testler.
- Android, iOS ve web derleme kapıları; ayrı CI artefaktları.
- Push'suz iOS önizlemesinde native messaging kaydı kapalıdır; sahte Firebase
  yapılandırması kullanılmaz ve son IPA'da `GoogleService-Info.plist` bulunmaz.
- Push yok, yönetim ekranı taşıması yok, SwanSport'tan çıkarım yok.

**Kabul:** Aynı staging hesabı iki uygulamaya ayrı ayrı girebilir; Pro yalnız
gerçek erişim alanlarını gösterir; rolesiz hesap operasyon göremez; mevcut
SwanSport regresyonları ve Ana Sayfa görünümü değişmez. Android APK, unsigned
iOS preview IPA ve web build artefaktı üretilir; Faz 1'de Pro web deploy/ayrı
host zorunlu değildir. “SwanSport'u aç” yalnız desteklenen native deep-linkte
uygulamayı açar, aksi durumda mağaza/web adresini gösterir; web'de açıklayıcı
bağlantı olarak davranır.

### Faz 2 — Kulüp ve antrenörlük

- Ortak operasyon UI paketinin kurulması.
- Kulüp paneli, takım/kadro, antrenman, yoklama ve temel kulüp işlemlerinin
  ortak pakete çıkarılması.
- Aynı ekranların geçiş süresince SwanSport ve Pro'da çalışması.
- Rota, provider state ve geri gezinme parite testleri.

### Faz 3 — Federasyon, hakem ve resmi müsabaka

- Federasyon konsolu, lig/atama/disiplin akışları.
- Hakem görevleri, esame, canlı maç ve rapor akışları.
- Mevcut private RLS kapsamları ve immutable kayıt sözleşmelerinin korunması.

### Faz 4 — Muhasebe, tesis, uzman personel ve platform

- Muhasebeci gizliliğini koruyan mali operasyonlar.
- Tesis/saha, envanter/zimmet, sağlık ve uzman personel operasyonları.
- Mobilde güvenli platform işlemleri; geri kalanları web konsoluna yönlendirme.

### Faz 5 — Bildirim, dağıtım ve kabul

- `app_target` tabanlı push migration'ı ve iki uygulamaya ayrı Firebase/APNs.
- Pro deep-link ve bildirim yönlendirme matrisi.
- Ayrı Android APK/AAB ve iOS IPA hatları.
- Staging migration, temiz kurulum, çoklu rol ve gerçek cihaz UAT.
- Ekran/rota/işlev parite matrisi ve rollback provası.

### Faz 6 — SwanSport'u sadeleştirme

Yalnız Faz 2–5 kabul edildikten ve kullanıcı ayrıca onay verdikten sonra:

- SwanSport'taki yönetim menüsü girişleri kaldırılır.
- Pro'ya taşınmış yönetim rotaları kontrollü biçimde yönlendirilir veya
  kaldırılır; dış deep-link uyumluluğu ayrıca korunur.
- Sosyal ağ ve kişisel sporcu/veli self-service alanları kalır.
- Ortak paketler nedeniyle iki uygulamanın aynı operasyon koduna bağlı olması
  sonlandırılır; yalnız gerçekten ortak bileşenler paylaşılır.

## 8. Test ve güvenlik kapıları

Her fazda aşağıdakiler zorunludur:

- `SwanAccess` rol/credential tuzakları için birim testleri.
- Yeni veya taşınan her modülde beş noktalı feature flag sözleşmesi: SQL satırı,
  Dart sabiti, sync testi, SSS kaydı ve iki uygulamadaki gerçek
  `featureEnabledProvider` kapısı.
- Widget'tan doğrudan Supabase çağrısı olmaması.
- RLS/RPC kontrollerinin UI görünürlüğünden bağımsız doğrulanması.
- Muhasebecinin sporcu kimliğini görememesi.
- Çocuk/veli, sağlık ve resmi maç gizlilik sözleşmelerinin korunması.
- Mevcut SwanSport, console, data ve migration regresyonlarının geçmesi.
- İlgili platform build'leri ve en az staging cihaz kabulü.

## 9. Geri dönüş ve güvenli geçiş

- Faz 1–5 eklemeli ilerler; sosyal uygulamadan silme yapılmadığı için geri
  dönüş Pro dağıtımını kapatmak kadar basittir.
- Migration'lar idempotent ve geriye uyumlu hazırlanır.
- Ortak pakete çıkarılan her özellik önce iki uygulamada parite test edilir.
- Faz 6 tek büyük silme değildir; modül bazlı kabul ve ayrı geri dönüş noktaları
  kullanır.

## 10. Başlangıçta bilinçli olarak ertelenenler

- Uygulamalar arası sessiz SSO.
- Pro için push bildirimi.
- SwanSport'tan herhangi bir yönetim özelliği kaldırma.
- Ana Sayfa veya sosyal gezinme tasarımını değiştirme.
- Backend'i iki Supabase projesine ayırma.

## 11. İlk uygulama teslimi

Onaydan sonraki ilk uygulama işi yalnız Faz 1'dir. Sonucu, kurulabilen ayrı bir
SwanSport Pro kabuğu, ortak hesapla giriş, doğru çalışma alanlarının görünmesi
ve iki uygulamanın birbirini bozmadan CI'dan geçmesidir. Operasyon ekranlarının
taşınması Faz 2 ile başlar.
