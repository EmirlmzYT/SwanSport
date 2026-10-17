# Akışta kaydırmaya duyarlı gezinme

2026-10-17: Yalnız hesaplı Ana Akış kapsamındadır. Aşağı yönde içerikte
ilerleyince alt çubuk 62'den 48 dp'ye iner; etiketler görsel olarak kalkar,
beş hedef ve erişilebilir etiketler kalır. Ters yönde kaydırma tekrar açar.
24/12 dp histerezis küçük hareketlerde titreşimi önler. Yatay/iç listeler,
ballistic hareket ve kenar taşması normalde durumu değiştirmez; en üste
dönmek açar. State route-local ve dispose edilir; veri/yetki kaynağı değildir.

Marka + gerçek InboxActions rozetleri ve iki akış filtresi aynı floating
SliverAppBar içindedir; aşağı ilerlerken çıkar, geri kaydırınca görünür.
Tek başlık filtre çakışmasını önler. Üst/alt yüzeyler sınırlı alanda blur ve
tema duyarlı opaklık kullanır. Yüksek kontrast/hareket azaltma opak yüzeye
geçer; hareket azaltmada nav animasyonu ve header snap kapanır.

SwanBottomNav parametresizdir. Diğer ekranlar ve misafir vitrini sabit kalır;
sekme rotaları, oluşturma/giriş kapıları ve kaydırarak seçim korunmuştur.
Bu Flutter cam/blur yorumudur, Apple'ın native Liquid Glass materyali değildir.

Doğrulama: 608 Dart syntax sıfır hata, 24/24 mobil kaynak sözleşmesi,
SSS 44/44, push 42 kayıpsız, mevcut genel senkronizasyon 5/5 ve diff temiz.
Üç Flutter regresyon testi eklendi; SDK yokluğunda çalıştırılmadı. Syntax
typecheck değildir. Cihazdaki animasyon, blur maliyeti, dar ekran/büyük yazı,
rozet dokunuşları ve gerçek iPhone hissi yeni derlemede ayrıca denenmelidir.
Canlı SQL/deploy, APK/IPA derlemesi, commit veya push yapılmadı.

SDK doğrulaması (aynı gün, sonraki temizlik): Flutter 3.47.7 kuruldu.
Kaydırma bildirimleri testi gerçek BuildContext ile derlenir; Tooltip uzun
basış jestini ele geçirmez. Üç scroll testi ve mevcut alt gezinme scrub
testleri tam mobil koşuda geçti. İlk teslimdeki SDK sınırlaması giderildi;
gerçek iPhone/blur performansı ve IPA kabulü hâlâ yapılmadı.
