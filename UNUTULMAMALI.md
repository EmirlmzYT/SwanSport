# Unutulmamalı

Bu dosya, SwanSport geliştirilirken bilinçli olarak sonraya bırakılan ancak
ürün canlıya hazırlanırken mutlaka tekrar ele alınması gereken işleri tutar.
Yeni bir konu ertelendiğinde kararın son hâli ve yeniden başlama koşulu buraya
eklenir.

## Ödeme ve işlem komisyonu modeli

**Durum:** Şimdilik ertelendi. Uygulamanın temel ürün geliştirmesi tamamlandıktan
sonra ele alınacak.

### Kararlaştırılan model

- SwanSport gelirini ağırlıklı olarak uygulama içindeki işlemlerden alınan
  komisyonla kazanacak.
- Veliye ödeme sırasında ek hizmet bedeli çıkarılmayacak.
- Örnek akışta veli kulübe 1.500 TL öder; SwanSport'un KDV dâhil 50 TL hizmet
  bedeli kulübün tahsilatından düşülür ve kulübün brüt hakkedişi 1.450 TL olur.
- Ödeme kuruluşu maliyeti ile SwanSport komisyonu ayrı kalemler olarak
  saklanacak ve gösterilecek.
- Kesin oran; minimum/maksimum komisyon, ödeme kuruluşu maliyeti ve işlem
  hacmi görüldükten sonra belirlenecek. Değerlendirilecek başlangıç formülü:
  `%3,33`, en az 10 TL ve en fazla 50 TL.
- İade yapıldığında komisyonun ve ödeme kuruluşu maliyetinin nasıl ele
  alınacağı sözleşmede ve sistemde açıkça tanımlanacak.

### Başlamadan önce gerekenler

- Mali müşavirle şahıs işletmesi veya limited şirket seçimini netleştirmek.
- Genç girişimci kazanç istisnası ve Bağ-Kur durumunu kontrol ettirmek.
- Yazılım, platform ve aracılık/komisyon gelirine uygun faaliyet kodlarını
  belirlemek.
- Lisanslı ödeme kuruluşlarından pazaryeri veya split ödeme teklifi almak.
- Kart komisyonu, kulübe aktarım süresi, iade, ters ibraz ve alt üye işyeri
  doğrulama koşullarını karşılaştırmak.
- Kulüp sözleşmesi, komisyon faturası, KVKK metinleri ve iade koşullarını
  hazırlatmak.

### Uygulamada yapılacaklar

- Sağlayıcıdan bağımsız ödeme arayüzü ve sunucu adaptörü.
- Kulüp şirket, yetkili, vergi ve doğrulanmış IBAN kaydı.
- Veli aidat ödeme ekranı ve indirilebilir makbuz.
- Komisyon hesabının yalnız sunucuda yapılması.
- İmzalı webhook doğrulaması ve idempotent işlem kaydı.
- Brüt tutar, KDV, SwanSport komisyonu, sağlayıcı maliyeti, kulüp net
  hakkedişi, iade ve sağlayıcı işlem kimliğini ayrı saklayan değişmez defter.
- Kulüp hakkediş/mutabakat ekranı ve platform yönetim ekranı.
- İade, iptal, ters ibraz ve başarısız ödeme akışları.
- Mission Control üzerinden işlem türüne göre komisyon kuralı ve acil kapatma
  anahtarı.
- Muhasebeci ekranlarında mevcut sporcu gizliliğinin korunması.

### Değişmez sınırlar

- SwanSport kart verisi tutmayacak; sağlayıcının güvenli ödeme sayfası veya
  SDK'sı kullanılacak.
- Para elle SwanSport hesabında toplanıp kulüplere gönderilmeyecek; lisanslı
  ödeme kuruluşunun pazaryeri/split ödeme altyapısı kullanılacak.
- Ödeme sağlayıcısı ve sözleşme kesinleşmeden üretim ödeme kodu yazılmayacak.
- Eski işlemler, komisyon oranı sonradan değiştiğinde yeniden hesaplanmayacak;
  işlem anındaki kuralın kopyası korunacak.

### Yeniden başlama koşulu

Şirket/vergi düzeni netleştiğinde ve en az iki lisanslı ödeme kuruluşundan
yazılı teklif alındığında bu başlık yeniden açılacak. İlk canlı kapsam yalnız
kulüp aidatı tahsilatı, komisyon, hakkediş, mutabakat ve iade olacaktır.

## Kimlik ve iletişim doğrulama

**Durum:** Yerel temeller kısmen mevcut. Sağlayıcı hesapları, kurumsal KPS
yetkisi ve canlı uçtan uca kabul tamamlanmadan üretimde tamamlanmış sayılmayacak.

### Doğrulama sırası

1. Kullanıcı kayıt olur ve e-posta adresini doğrular.
2. Telefon numarası SMS OTP ile doğrulanır.
3. Gerçek kişi kimliği, gerekli izin ve kurumsal sağlayıcı hazır olduğunda
   MERNİS/KPS üzerinden doğrulanır.
4. Sporcu, antrenör ve diğer uzmanlık rolleri kimlik doğrulamasından ayrı
   olarak belge incelemesiyle onaylanır.
5. Çocuk sporcularda giriş hesabı zorunlu tutulmaz; veli bağlantısı ve mevcut
   çocuk gizliliği kuralları korunur.

### E-posta doğrulaması

- Supabase Auth e-posta doğrulaması üretim alan adı ve gerçek gönderici
  adresiyle yapılandırılacak.
- Doğrulama bağlantısı uygulamaya güvenli deep link ile dönecek; localhost
  veya geliştirme alan adına yönlenmeyecek.
- Yeniden gönderim, süre dolumu, daha önce kullanılmış bağlantı ve e-posta
  değiştirme akışları açık hata mesajlarıyla ele alınacak.
- Oturum açma ile e-posta doğrulanmış olma durumu aynı kabul edilmeyecek.
- E-posta doğrulanmadan hassas kulüp ve ödeme işlemleri açılamayacak; izin
  kararı yalnız arayüzde değil sunucuda da uygulanacak.

### Telefon doğrulaması

- Gerçek SMS sağlayıcısı seçilecek ve Supabase Auth telefon OTP akışına
  bağlanacak.
- Türkiye numaraları E.164 biçiminde (`+90...`) tekilleştirilecek.
- OTP süresi, yeniden gönderme bekleme süresi, deneme sınırı ve kötüye
  kullanım limiti sunucu tarafında uygulanacak.
- Test kodları ve mock SMS yalnız marker kontrollü yerel Test Merkezi'nde
  kullanılacak; canlıya taşınmayacak.
- Telefon değişikliğinde yeni numara doğrulanmadan eski doğrulama kanıtı
  aktarılmayacak.
- Telefon doğrulaması kimlik, yaş veya sporcu/antrenör rolü kanıtı sayılmayacak.

### MERNİS/KPS doğrulaması

- Canlı otomatik doğrulama yalnız yetkili kurumsal KPS erişimi veya sözleşmeli
  ve hukuken uygun bir sağlayıcıyla açılacak.
- Eski açık SOAP uç noktası ve test mock'u gerçek kimlik onayı sayılmayacak.
- Ad, soyad, doğum tarihi ve TCKN doğrulama isteği istemciden doğrudan kamu
  servisine gönderilmeyecek; korumalı sunucu adaptöründen geçecek.
- TCKN düz metin olarak log, analitik, hata mesajı veya istemci projeksiyonuna
  yazılmayacak. Mevcut private HMAC/tekillik ve erişim sınırları korunacak.
- Doğum tarihi eksikse yapay tarih üretilmeyecek.
- Başarılı sağlayıcı yanıtı yalnız service role tarafından tamamlanacak;
  istemci kendi kimliğini doğrulanmış olarak işaretleyemeyecek.
- Sağlayıcı kapalı veya belirsiz cevap verdiğinde kimlik otomatik onaylanmayacak;
  mevcut manuel belge incelemesine yönlendirilecek.
- Doğrulama işlem kimliği, sağlayıcı, zaman, sonuç ve hata sınıfı denetim izi
  olarak tutulacak; hassas ham yanıt saklanmayacak.

### Ortak güvenlik ve ürün kuralları

- E-posta, telefon, kimlik ve sportif rol dört ayrı kanıttır; biri diğerinin
  yerine geçmez.
- Hassas işlemler gerekli doğrulama seviyesini `SwanAccess` ve sunucu
  yetkilendirmesi üzerinden denetler.
- Özellik bayrakları güvenlik kontrolü olarak kullanılmaz.
- Ham TCKN, OTP, Auth tokenı ve sağlayıcı sırları analitiğe veya istemci
  loglarına girmez.
- Hesap kurtarma, numara/e-posta değişikliği, tekrar deneme, destek ve manuel
  inceleme akışları canlı kabul testine dâhil edilir.

### Yeniden başlama koşulu

- Üretim e-posta göndericisi ve yönlendirme alan adı hazır olmalı.
- Gerçek SMS sağlayıcısı hesabı, maliyetleri ve üretim anahtarları hazır olmalı.
- MERNİS/KPS için kurumsal yetki veya uygun sağlayıcı sözleşmesi bulunmalı.
- KVKK aydınlatma, açık rıza gereksinimi, saklama süresi ve silme prosedürü
  hukuk danışmanı tarafından gözden geçirilmeli.
- Çocuk, yetişkin, veli, antrenör ve çoklu rol hesaplarıyla yerel ve gerçek
  cihaz uçtan uca kabul testi tamamlanmalı.
