# MERNİS/KPS — güvenli, kapalı yerel altyapı

2026-10-14. Bu teslim canlı NVİ doğrulaması değildir. Kullanıcının kurumsal KPS
erişimi bulunmadığı için üretim sağlayıcısı kapalıdır; eski public SOAP endpoint'i
kullanılmaz. Kaynak: [NVİ duyurusu](https://tckimlik.nvi.gov.tr/?v=1.0.23).

## Güven sınırı

`Flutter → /api/verify-tckn → doğrulanmış Auth kullanıcısı → rolling limit →
yetkili kurumsal sağlayıcı → service_role RPC → mevcut 0100 kimlik kapısı`.

- `complete_identity_verification(uuid,text,int)` yalnız `service_role` için
  açılır. İlk UUID doğrulanmış Auth yanıtından alınır; request'teki profile ID
  yok sayılır. Eski iki parametreli güvensiz imza düşürülür. Kullanıcı ve platform
  admin bu RPC'yi çağırmaz; admin mevcut belge inceleme RPC'sini kullanır.
- SQL provider çağrısı yapmaz ve NVİ sonucunu kendi başına doğrulayamaz.
  Tamamlama anahtarına sahip backend güven köküdür. Anahtar sızıntısı bu güveni
  bozar; mümkün olan en dar dağıtım ve sır yönetimi gerekir.
- Mevcut C1 tetikleyicisine yalnız işlem/credential/profile bağlı özel capability
  eklenir; kullanıcı GUC'si, editable profil alanı veya genel service_role ham
  tablo yazısı onay yolu değildir. Capability başarılı işlem sonunda silinir;
  hata durumunda onay ve audit birlikte rollback olur.
- Mevcut credential kimlik/profil unique indexleri korunur. Aynı onay yeniden
  çağrıldığında ikinci audit oluşturulmaz. Doğrulanmış numara değiştirilemez.
- Checksum UI, proxy ve SQL'de kontrol edilir; **kimlik ispatı değildir**.
  Kurumsal kayıt eşleşmesi de biyometrik kimlik veya hesap sahibinin fiziksel
  belgeye sahip olduğunun ispatı değildir.

## Üretimde kapalı sağlayıcı / testler

`functions_helpers/identity-verification.js` provider sınırını ve HTTP motorunu
taşır. `resolveKpsProvider` her durumda kapalı sağlayıcı döndürür. Yalnız
`KPS_ENDPOINT` / `KPS_CREDENTIALS` tanımlamak servisi açmaz. `mock`/istek alanı/
ortam bayrağıyla kimlik onayı üretilemez. Testlerde enjekte edilen sağlayıcı
gerçek kimlik bilgisi kullanmaz; mock türü tamamlama RPC'sine erişemez.

Kurumsal erişim alındıktan sonra gerçek WSDL/işlem, sertifika veya token akışı,
kimlik seri numarası gereksinimi ve güvenilir yanıt bağlama sözleşmesine göre
**ayrı bir adaptör geliştirme ve UAT** gerekir. Bu teslim eski SOAP isteği,
canlı XML ayrıştırma veya varsayımsal KPS protokolü üretmez. Adaptör ad/soyadı
Türkçe büyük harfe çevrilmiş olarak alır; XML kullanılacaksa ayrıca XML escape
ve güvenli XML ayrıştırma zorunludur. Provider 15 saniyede timeout olur.

## Proxy ve gizlilik

- Auth token `/auth/v1/user` üzerinden doğrulanır; anon kullanıcı reddedilir.
  Backend URL yalnız yapılandırılmış HTTPS origin'dir. Kullanıcı token'ı provider
  veya completion RPC'sine gönderilmez; service key istemciye dönmez.
- Gövde 4KB ve üç saniye okuma sınırındadır. HTTP upstream timeout 10 saniye,
  provider timeout 15 saniyedir. Hatalarda upstream body, anahtar, TCKN, ad veya
  doğum yılı echo edilmez; kimlik verisi loglanmaz.
- GET yalnız `{available: bool}` döner. POST kapalı sağlayıcıda 503, mismatch'te
  422, limitte 429 döner; yalnız backend tamamlandığında `{success: true}` vardır.
- CORS yalnız swansport.pages.dev, swansport.com.tr ve www.swansport.com.tr için
  açıktır; native çağrı Origin olmadan çalışabilir. Başka domain gerektiğinde
  açık allowlist güncellemesi gerekir. Yanıtlar `no-store` kullanır.
- Kullanıcı ve Cloudflare'in `CF-Connecting-IP` değeri ayrı domain'li HMAC-SHA256
  anahtarlarına çevrilir. Proxy forwarded IP'yi kullanıcı body/header alternatifinden
  almaz. DB tüm Worker instance'ları için son 60 saniyede kullanıcı **veya IP**
  başına beş girişe izin verir. Checksum hatası veya kapalı sağlayıcı KPS denemesi
  sayılmaz. Başarısız sağlayıcı çağrısı da limit tüketir.
- Private limit tablosu yalnız HMAC anahtarı ve zamanları taşır. Bir günden eski
  satırlar sonraki başarılı denemelerde en fazla 100'er temizlenir; trafik yokken
  kesin 24 saatlik silinme garantisi yoktur. Üretim saklama politikası ayrıca
  belirlenmelidir. HMAC sırrının rotasyonu geçici olarak limit sayaçlarını sıfırlar.
- Yeni doğrulanmış TCKN yalnız mevcut `profile_credentials.verified_national_id`
  alanına yazılır. Anon/auth bu sütunu SELECT edemez; uygulamanın açık alan
  listeli credential sorguları korunur. Genel profiles/athletes alanlarına,
  esameye, sosyal payload'a veya audit'e yeni TCKN yazılmaz. Eski beyan alanları
  temizlenmez/taşınmaz; bu teslim tüm eski veri akışlarının KVKK denetimi değildir.
- Audit yalnız profile/credential referansı, eylem ve zaman taşır; clinical data,
  TCKN, ad, token, doğum yılı içermez. Public/admin okuma izni açılmaz.
- Hiçbir profiles/athletes doğum tarihi yazılmaz; yıl yaş ispatı olarak kullanılmaz.
  0100/çocuk koruma ve branş lisansı kapıları değişmez.

## Veri katmanı / ekran

`VerificationService.verifyWithMernis` kullanıcı token'ıyla yalnız HTTPS proxy'ye
gider; UI Supabase çağırmaz. Başarı callback'i `myCredentialsProvider`,
`myIdentityGateProvider` ve `myVenueVerificationTierProvider` yeniler. Hesap/token
değişince geç başarı kabul edilmez. Taslaklar yalnız widget RAM'indedir; hesap
değişiminde controller'lar dispose olur. Sunucuya giden devam eden istek eski
hesap için tamamlanabilir; yeni hesapta başarı gösterilmez.

Kimlik sekmesi availability kapalıyken hassas inputları toplamaz; mevcut manuel
belge yükleme/0100 `review_credential` yolu aynen kalır. Servis açıldığında dört
input, checksum ve busy koruması kullanılır. Görünür onay yerel mock bayrağından
değil sunucu kimlik kapısından gelir; manuel onay da aynı göstergeyi kullanır,
bu nedenle ekran yanlış biçimde "MERNİS onayladı" demez.

## Yapılandırma ve yayın önkoşulları

Sırlar repo, Flutter dart-define, sohbete veya örnek JSON'a konmaz. İleride
kullanıcı Cloudflare secret alanlarında `SUPABASE_SERVICE_ROLE_KEY`,
`IDENTITY_RATE_HMAC_SECRET` (en az 32 karakter), kurumsal `KPS_CREDENTIALS` ve
gereken sertifikaları kendisi tanımlar. `SUPABASE_URL`, `SUPABASE_ANON_KEY` ve
`KPS_ENDPOINT` ortam yapılandırmasıdır. Bu görev hiçbir sırrı üretmez, istemez,
okumaz veya dağıtmaz. Mevcut endpoint ve anahtarların HTTPS/dar izin kullanması
dağıtımda doğrulanmalıdır.

Gerçek adaptör, kurumsal yetki, KVKK aydınlatma/işleme dayanağı, gerekli aktarım
ve saklama değerlendirmesi, Cloudflare log/analytics redaksiyon incelemesi ve
gerçek PostgREST/RLS/iki oturum/cihaz UAT yapılmadan otomatik doğrulama açılmaz.
Bu belge hukuki uygunluk sertifikası değildir.

## Yerel doğrulama

- SQL: `node --test tools/mernis_identity_sql_test.mjs`: **38/38 geçti**; dört yeni
  0115 senaryosu + 34 mevcut foundation/C1 regresyonu. Son tam koşu temiz.
- Proxy: `node --test tools/mernis_proxy_test.mjs`: 7/7; kapalı/mocked provider,
  auth, Türkçe casing, boyut/format, HMAC, hedef bağlama, mismatch/rate/DB hata
  redaksiyonu ve domain CORS kontrolü.
- 115 migration parse; SSS 41/41, push 41 kayıp yok; 566 Dart syntax ve 18/18
  scoped mobil token kaynakları; `git diff --check` temiz.
- Yedi veri ve dört widget regresyon testi hazır. Flutter SDK bulunamadığından
  iki paket test çağrısı çalışmadı; typecheck/analyze/build/format/görsel kabul
  verilmez. Syntax kontrolü derleme veya widget çalıştırması değildir.
- SQL fixture PGlite tek bağlantıdır; eşzamanlı iki oturum ve gerçek Cloudflare
  runtime/Functions derlemesi, canlı KPS/sertifika/XML testi yapılmadı.
- Yalnız yerel kod/SQL ve stage; commit/push/deploy/canlı SQL yapılmadı.
