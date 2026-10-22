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
