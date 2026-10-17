# Şeffaf üst cam — 0.5.16+45

2026-10-18. Kullanıcı +44 alt menüyü onayladı; üst barın daha şeffaf ve
kaydırma hareketinin daha akıcı olmasını istedi.

## Değişiklik

- Ortak üst cam dolgusu %84–88 opak tek yüzeyden yukarıdan aşağıya
  açıkta %60 / %52 / %6, koyuda %74 / %68 / %6 yüzey rengi geçişine dönüştü. Üst blur 20'den 12'ye indi.
  Alt kapsülün dolgusu, blur'u, boyutu ve düğmeleri değişmedi.
- Ana Sayfa, Keşfet, misafir Keşfet, Mesajlar ve Profil `scrollUnderHeader`
  kullanır. İçerik camın arkasından geçer; başlangıç mesafesi listenin kendi
  içinde `SwanHeaderSpacer` ile sağlanır. Çentik yüksekliği bir kez eklenir.
- Bu ekranlarda üst bar yalnız translate/clip ile gizlenir. Animasyon liste
  viewport yüksekliğini veya scroll offset'ini değiştirmez. Cam ve başlık
  animasyon builder'ının sabit child'ıdır. Gereksiz opacity/saveLayer yoktur.
- Diğer ekranlar da daha şeffaf ortak materyali alır; mevcut form/kaydet
  düzenlerinin yerleşim sözleşmesi korunur. Scroll-under kullanılacak yeni
  ekranda spacer liste/sliver içinde olmalıdır; dışarıdaki padding değildir.
- Yüksek kontrast ve azaltılmış hareket opak fallback'i, klavye davranışı,
  hesap kapıları, rozetler ve +43 native Firebase koruması korunur.
- Kod grafiği ana checkout'un eski indeksidir; yeni kabuk dosyalarında
  coverage missing olduğundan bu değişiklik güncel worktree kaynağıyla
  doğrulandı. UI becerisinin uidotsh kaynağı mevcut değil; mevcut Flutter
  bileşenleri/tasarım jetonları kullanıldı.

## Doğrulama

Odaklı 20 test geçti. Viewport/scroll offset/ekrandaki satır konumu, gizleme
ve açılmanın her animasyon karesinde sabit kalır. Opak fallback, iki tema,
dar ekran, büyük metin, header aksiyonları, klavye, form taslağı ve gezinme
testleri bulunur. Çentikli scroll-under ve gerçek widget PNG'leri de kapsanır.

Mobil analiz 0 error / 0 warning (3673 stil info) ile exit 0. İlk tam turda 496/497 geçti; çevrimdışı yoklama senaryosu tek başına yeniden çalıştırıldığında dosyanın 6/6 testi geçti. Tam tur düşük paralellik ile yeniden çalışıyor; +45 macOS önizleme derlemesi hazırlanıyor.
Bu rapor cihazda FPS ölçümü veya native Apple Liquid Glass kullanımı iddia
etmez. Fiziksel iPhone GPU/akıcılık/görsel kabulü ayrıca yapılmalıdır.
Canlı SQL, main, Cloudflare ve TestFlight yayını bu değişikliğe dahil değildir.
