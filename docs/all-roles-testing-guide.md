# SwanSport — canlı ortamda ayrılmış rol testi hesapları

## Ne yapar, ne yapmaz?

`supabase/seed/full_roles_test_seed.sql` artık 12 birleşik aktör yerine **45 ayrı hesap** hazırlar.
Her YENİ hesabın şifresi **`test1234`**. Adresler `@test.swansport.invalid` ile biter;
gerçek kişilere e-posta gönderilmez. `.invalid` adresinde şifre sıfırlama/e-posta alma çalışmaz.
Hesapların e-posta onayı seed tarafından verilir; bu **kimlik doğrulaması değildir**.
`auth.users`, email `auth.identities` ve `profiles` birlikte oluşturulur.

**45 hesap = 45 aktif yetki demek değildir.** Kimlik/branş belgesi isteyen roller,
onay olmadan açılmaz. Sonuç tablosu `AKTİF`, `ATANDI`, `BEKLİYOR`, `ATLANDI` durumlarını açıklar.
Başhakem hesabı açmak, o hesabı otomatik bir maça atamak değildir.

Canlı kimlik sisteminde 1 TCKN = 1 profil kuralı vardır. Aynı kişinin kimliğini 45 test
hesabına onaylamak mümkün değildir. Tamamen kurgusal 45 kimlikle tüm yazma senaryolarını
denemek için ayrı test Supabase ortamı gerekir. Canlı seed bu kuralı delmez.

Eski seed'in gerçek görünümlü e-postaları, genel kulüp/federasyon adı eşleştirmeleri,
uydurma tablo/sütunları ve mevcut hesap şifresini ezmesi kaldırıldı. Eski seed önceden
çalıştırıldıysa oluşturduğu hesaplara/verilere **dokunulmaz**, onlar v2 kapsamına alınmaz.

## Çalıştırma

1. Veritabanı/Auth yedeği alın. Bu dosya migration değildir; otomatik deploy/reset'e eklemeyin.
2. SQL Editor'de dosyanın **tamamını** açın. `v_confirmation` değerini
   `'CANLI_TEST_HESAPLARINI_ONAYLIYORUM'` yapın. İlk hali güvenlik hatasıyla durur.
3. İlk çalıştırmada diğer seçenekleri kapalı bırakın. Tek atomik `DO` içinde 45 hesap,
   `[TEST]` isimli pending kulüp, pending mağaza ve pasif saha oluşturulur.
4. Sonuç tablosunu saklayın; e-posta, hedef rol, kurulum sonucu, UUID, gerçek kimlik/admin
   durumu ve giriş banı döner. `ATANDI` geçmiş işlem sonucudur; rolün süre/iptalini de kontrol edin.
5. Önce `taraftar@test.swansport.invalid` / `test1234` ile gerçek giriş deneyin.
   SQL testleri GoTrue token üretimi veya cihaz girişini kanıtlamaz. Giriş hatasında Auth
   loglarını inceleyin; SQL Editor'e yapıştırıp yeniden çalıştırmak şifreyi sıfırlamaz.

Kurulum tek `DO` statement'ıdır; geçici tablo bloğun içinde oluşturulur. Sonuç SELECT'i
Auth'taki yalnız raporlama amaçlı `seed_setup_result` metadata alanını okur; başka
oturumda çalıştırılabilir. Bu metadata yetki kaynağı değildir. Yalnız SELECT çalıştırılırsa
hesap kurulmaz, mevcut sonuçlar listelenir. Kurulum için bütün `DO ... $seed$;` bloğu gerekir.

Bir adım hata verirse DO'nun tamamı geri alınır. İstemci eski transaction'ı açık bırakırsa
önce `rollback;` çalıştırıp hatayı giderin. Migration eksikse seed onu kurmaya çalışmaz.

### Seçenekler

| Değişken | Varsayılan | Anlamı |
|---|---|---|
| `v_enable_platform_admin` | `false` | Yalnız test admin hesabına **global** platform yetkisi verir. |
| `v_enable_federation_roles` | `false` | 6 federasyon rolü, 4 resmî işlem ataması ve 9 TEST hakem profili kurar. |
| `v_federation_id` | `null` | Yukarıdaki seçenek açıkken mevcut, seçilen branşa ait federasyon UUID'si gerekir. |
| `v_reviewer_id` | `null` | Kulüp üyeliği için mevcut, gerçekten kimliği onaylanmış platform admin UUID'si. |
| `v_sport` / `v_city` | `futbol` / `34` | Önceden var olan referans değerleri; yeni branş/il uydurulmaz. |

**Uyarı:** `test1234` ve bu dosyadaki hesap adları sır değildir. Platform admini veya
federasyon başkanı/MHK hesabını bu şifreyle canlıda açık bırakmak gerçek veriyi riske atar.
Hassas seçenekler özellikle varsayılan kapalıdır. Açacaksanız kısa kontrollü test yapın,
sonrasında aşağıdaki kapatma dosyasını çalıştırın. Tercihen hassas testleri staging'de yapın.

Federasyon üyelikleri/işlem atamaları ilk kurulumda 7 günle sınırlıdır; **hakem profili ve
platform admini kendiliğinden sona ermez.** Yeniden çalıştırma süre uzatmaz, iptal edilmiş
atamayı/banı açmaz. Seçeneği `false` yapmak eski yetkiyi kaldırmaz; kapatma dosyasını kullanın.
Federasyon başkanı/MHK mevcut federasyonun gerçek verisini görebilir; test kulübü izolasyonu
bu global yetkileri sınırlandırmaz. Resmî işlem atamaları seçilen il ofisiyle sınırlıdır.

### Gerçek kimlik kapısı

Kulüp üyelikleri ancak ilgili hesap gerçek kimlik ve gerekli branş/kademe belgelerini
normal inceleme yolundan tamamladıktan sonra, `v_reviewer_id` doldurulup seed yeniden
çalıştırıldığında atanır. Kod gerçek `_c1_require_member` ve üyelik trigger'larını kullanır.
1. kademe hesabı aynı branştaki aktif 5. kademe test hesabını süpervizör alır.

Seed **şunları yapmaz**:

- TCKN yazmak, sahte kimlik/lisans onaylamak veya `identity_gate_legacy` üretmek.
- RLS/trigger kapatmak ya da herkesi platform admini yaparak rollerin farkını yok etmek.
- Test hesabına telefon doğrulaması vermek; SMS kapısı bağımsız kalır.
- Kimliği olmayan veliye çocuk bağlamak veya çocuk/sağlık gizliliğini açmak.
- Üretim `feature_flags` kademelerini değiştirmek. `admins` özellikler normal test
  hesaplarına açılmaz; `testers` yayını ayrıca SSS ve kontrollü tester kaydı gerektirir.

**Doktor/fizyoterapist etiketi tıbbi izin değildir.** Aktif üyelikten sonra yönetici normal
yetkilendirme yoluyla sağlık izni vermelidir. Muhasebeciye kulüp üyeliği verilmez.

## Hesaplar

Aşağıdaki her kısa ada `@test.swansport.invalid` ekleyin. Yeni hesapların ortak şifresi `test1234`.

| Grup | Hesap kısa adları |
|---|---|
| Platform | `platform-admin` |
| Temel kulüp | `kulup-yoneticisi`, `kulup-gorevlisi`, `federasyon-temsilcisi` |
| Antrenör kademeleri | `antrenor-1`, `antrenor-2`, `antrenor-3`, `antrenor-4`, `antrenor-5` |
| Sporcu / veli | `lisansli-sporcu`, `ferdi-sporcu`, `veli` |
| İhtisas | `kulup-baskani`, `sportif-direktor`, `doktor`, `fizyoterapist`, `malzeme-sorumlusu`, `medya-sorumlusu` |
| Federasyon | `federasyon-baskani`, `yonetim-kurulu`, `genel-sekreter`, `il-temsilcisi`, `mhk`, `disiplin-kurulu` |
| Resmî işlem | `sonuc-yayimlayici`, `program-yayimlayici`, `lisans-tescil`, `kulup-tescil` |
| Maç görevleri | `bashakem`, `yardimci-hakem-1`, `yardimci-hakem-2`, `dorduncu-hakem`, `masa-hakemi`, `gozlemci` |
| Diğer hakem kademeleri | `aday-hakem`, `il-hakemi`, `uluslararasi-hakem` — maç görevi hesapları ulusal kademededir |
| Mali | `muhasebeci` |
| Saha | `saha-yoneticisi`, `saha-nobetcisi` |
| Mağaza | `magaza-sahibi`, `magaza-yoneticisi` |
| Topluluk | `topluluk-uyesi`, `topluluk-gorevlisi` |
| Standart | `taraftar` — misafir için oturumu kapatın; misafir Auth hesabı oluşturulmaz |

Veli daveti, süreli saha devri, uygun topluluğa katılım ve community staff ataması normal
işlemlerden tamamlanır. Maç görevleri MHK tarafından **test maçı** üzerinde atanmalıdır;
seed gerçek fikstüre görev eklemez. Resmî sonuç/rapor/discipline/aidat satırı oluşturmaz.
Test mağazası pending, saha pasiftir; genel satış/saha listesine otomatik yayımlanmaz.
Tam uçtan uca senaryo ve sporcu/takım/esame/maç fixture'ı bu canlı seed'in kapsamında değildir.

## Tekrar çalıştırma ve kapatma

UUID + e-posta + Auth `raw_app_meta_data.seed_owner` birlikte doğrulanır. Sadece e-posta
eşleşmesi bir hesabın test hesabı olduğunu kanıtlamaz. Çakışmada tüm işlem durur.
Mevcut test hesabının şifresi, banı, düzenlenmiş profil adı ve incelemeleri korunur.
Silinmiş bir test hesabı tekrar oluşturulabilir; tekrar çalıştırmayı kapatma yerine kullanmayın.

`supabase/seed/disable_full_roles_test_accounts.sql` yalnız v2 işaretli hesapları hedefler:

1. `v_confirmation = 'TEST_HESAPLARINI_KAPAT'` yapın.
2. Aktif kulüp üyelikleri varsa gerçek, kimliği onaylı platform admin UUID'sini
   `v_reviewer_id` alanına yazın.
3. Dosyanın tamamını çalıştırın: hesaplar banlanır, admin/federasyon/hakem/sağlık/muhasebe/
   saha yetkileri kapatılır, aktif kulüp üyelikleri askıya alınır; test mağazası askıya alınır.
4. Auth refresh token ve session kayıtları varsa silinir. **Önceden verilmiş JWT'ler expiry'ye
   kadar geçerli kalabilir.** Bu işlem token anında iptal garantisi değildir. Kritik rol
   kontrolleri sunucudaki canlı kayıtlardan düşer; test bitiminde JWT ömrünü de hesaba katın.

Hesaplar veya iş kayıtları silinmez; tarihsel veriyi bozmadan tekrar incelemek mümkündür.
Kapatma sonrası yeniden açma bilinçli yönetici işlemidir; seed banı/askıyı kaldırmaz.
Sonradan elle verilmiş community/store üyelikleri de ayrı incelenmelidir; kapatma her
olası elle verilmiş ilişkiyi temizleyen evrensel hesap silme aracı değildir.

## Yerel doğrulama

```bash
node --test tools/full_roles_seed_sql_test.mjs
python tools/check_faq.py
python tools/check_push_routes.py
git diff --check
```

Test PostgreSQL/WASM üzerinde gerçek temel DDL ve C1 trigger'larını çalıştırır; Auth
tabloları azaltılmış fixture'dır. GoTrue giriş, MFA/parola politikası, canlı migration
durumu, e-posta teslimi ve mobil/konsol UAT bu testin kanıtı değildir. Canlıda otomatik
SQL veya deployment yapılmadı.

2026-10-15 yerel sonuç: 9/9 izole PostgreSQL testi; 118 migration söz dizimi,
SSS 44/44, push 42 eşleme ve diff kontrolü temiz. Yeni parolalar bağımsız bcrypt
salt ile yazılır. İlk dar fixture koşusundaki eksik maç FK hedefi düzeltildi;
son koşu gerçek C1 üyelik/süpervizör ve kapatma sırasını da doğruladı.

SQL Editor düzeltmesi sonrası son koşu 10/10: kurulum ve kapatma DO blokları
tek başına autocommit ile yürütüldü, geçici tabloların silindiği doğrulandı;
sonuç sorguları buna rağmen ayrı statement olarak başarıyla çalıştı.
