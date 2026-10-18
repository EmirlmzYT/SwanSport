# Chat yenilemesi — güncel +46 tabanı

2026-10-18. Başlangıç 954fc4c (0.5.17+46), dal
codex/chat-refresh-on-header46. Eski preview dalı merge edilmedi; yalnız
chat değişiklikleri üç yönlü karşılaştırmayla uyarlandı.

## Korunanlar

SwanScaffold, SwanFloatingHeader, SwanBottomNav, feed_screen ve
stitch_feed_widgets kaynakları başlangıçla birebir aynı. Mesajlar ekranının
floating header/header spacer/scroll-under sözleşmesi korunur. Yeni composer
chat ekranlarının mevcut SwanScaffold kabuğu içinde kalır. Sürüm değişmedi.
Auth, SwanAccess, veri servisi, RPC ve RLS değiştirilmedi.

## Chat

- Öneri şeridi yerine gerçek konuşma listesi; son mesaja göre sıralama.
- Tümü / Birebir / Topluluklar; Türkçe ad araması ve eski initialTab=1 desteği.
- Uzun etiketler için ortak SwanPillTabs; büyük metin/dar ekranda sarılmaz.
- Sade, ekran genişliğine uyumlu mesaj balonları; mevcut okunma/retry/paylaşım.
- Ortak multiline composer, boş/boşluk mesajı engeli, 48dp gönder hedefi.
- Topluluk gönderimi sonrası dispose edilmiş controller'a dokunulmaz;
  beklerken yazılan yeni metin silinmez. Okunma hatası açılışı düşürmez.
- Gerçek ses kaydetmeyen mikrofon ve sahte oynatma sayacı kaldırıldı;
  eski ses metinleri düz metin olarak kalır. Gerçek ses motoru eklenmedi.

## Doğrulama

İlk odaklı header/chat/rota kontrolleri 65/65. Son eklenen arama/Türkçe
eşleme/sıralama/eski topluluk sekmesi/header sözleşmesi kontrolleriyle dar
koşu 22/22. İlk eşit bölünmüş sekme testi büyük yazıda Flutter TextPainter
assertion üretti; SwanPillTabs sonrasında başarılı. Önceki tam mobil koşu
508/508; nihai kaynakla tam koşu sonucu aşağıya kaydedilir.

Değişen kaynak analizi 0 error/0 warning (stil info mevcut). 616 Dart syntax,
24/24 token sözleşmesi, SSS 44/44, push 42 kayıpsız, diff temiz.

Canlı SQL, deploy ve yeni IPA yok. Gerçek iPhone görsel/klavye kabulü ve iki
hesapla canlı mesaj teslimi henüz yapılmadı. Yerel widget/derleme testleri
cihazda test edilmiş gibi sunulmaz.

Nihai mobil tam regresyon: **510/510 başarılı**, exit 0.
Log: yerel geçici swan-chat46-final-tests.log. Ortak header/alt bar/feed
kaynakları için 954fc4c'a karşı git diff boş olarak tekrar doğrulandı.
