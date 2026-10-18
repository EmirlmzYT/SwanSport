# Chat arayüzü yenilemesi — 2026-10-18

Sohbet listesi öneri şeridinden arındırıldı. Ortak sekmeler Tüm Mesajlar /
Birebir / Topluluklar; eski initialTab=1 topluluk filtresini açar.
Liste Türkçe ad araması ve son mesaja göre sıralama kullanır. Antrenörler
etiketi kaldırıldı: önceki filtre aslında bütün birebir sohbetleri gösteriyordu.

Birebir ve topluluk sohbetleri ortak SwanChatComposer kullanır; boş veya
yalnız boşluk içeren mesaj gönderilemez, multiline ve en az 48dp gönder
hedefi vardır. Klavye boşluğu ikinci kez eklenmez. Mesaj balonları mobil
palet yüzeyleri ve radius/space jetonlarıyla sadeleştirildi. Mevcut DM
pending/failed retry, okunma, paylaşım ve topluluk ek paylaşma yolları korunur.
Okunma çağrısı başarısızlığı ekran açılışını bozmaz.

Gerçek kayıt/oynatma yapmayan topluluk mikrofonu ve sahte oynatma sayacı
kaldırıldı. Eski “Sesli Mesaj” metinleri metin olarak okunabilir; gerçek
ses dosyası motoru eklenmedi. Yeni backend özelliği veya gizlilik yetkisi yok.

## Doğrulama

- Composer açık/koyu, 320px, boşluk doğrulama ve temizleme testleri dahil
  gezinme/eski rota/OpenChat/mobil taşma regresyonu: 41/41.
- Değişen üç Dart kaynak analizi: 0 error / 0 warning; stil info mevcut.
- Mobil token sözleşmesi 24/24; 611 Dart syntax, 0 hata.
- SSS 44/44; push 42 kayıpsız; git diff --check temiz.

Gerçek iki hesapla canlı mesaj teslimi, iPhone klavye/görsel kabulü ve web
görsel kabulü yapılmadı. Mevcut Supabase sorguları/RLS değişmedi; canlı SQL,
deploy veya bu chat değişikliklerini içeren yeni IPA oluşturulmadı.
