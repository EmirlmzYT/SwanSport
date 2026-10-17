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

Son tam mobil tur **498/498** geçti (`flutter test --no-pub --concurrency 2`).
İlk iki tam turda eski offline yoklama testi, DB yazısı tamamlandığı halde
Riverpod/Sembast snapshot'ı henüz widget'a ulaşmadığı için başarısız oldu;
tek başına 6/6 geçti. Test şimdi asıl UI durumunu sınırlı süreyle bekler;
assertion kaldırılmadı, yoklama ürün/veri kodu değiştirilmedi. Son tam turda
bu senaryo da geçti. Log: `build/header-full-tests-verified.log`.

Tam mobil analiz `--no-fatal-infos` ile exit 0: 0 error / 0 warning,
3673 stil info. Son değişen 10 dosyanın hedefli analizi de exit 0: 0 error /
0 warning (265 info). Genel PR CI varsayılan fatal-infos kapısı nedeniyle ayrı
olarak kırmızıdır; önceki +44 sınırı sürer, bütün CI yeşil denmez.

## iOS +45

macOS CI success: https://github.com/EmirlmzYT/SwanSport/actions/runs/39076241788
Ürün kaynağı `480c6c43f41bba21f0714788ce25d81c7c63b2bf`.
Sonraki değişiklik yalnız test bekleme koşulu ve bu kanıtlardır.
Artifact `SwanSport-iOS-0.5.16+45-unsigned`, ID `12116668530`.

- IPA version/build: 0.5.16 / 45; bundle `com.swansport.app`.
- ZIP CRC temiz; Runner executable var.
- Firebase config, xcent ve Runner imzası yok; +43 koruması korunur.
- Dosya 13,483,830 byte.
- SHA256 `463ddc393e56e11b59026c80ad69383e7a8df11625bf6cf35892d511efcc87da`.
- Masaüstü kopyası aynı hash ile doğrulandı: `SwanSport-0.5.16+45-unsigned.ipa`.
- Yerel kanıt `build/header-ipa-verification.json`.

Gerçek Flutter cam bileşenlerinden, örnek arka planla üretilmiş açık/koyu
PNG'ler `docs/design/mobile-glass-45/` altındadır; üretim verisi değildir.

Bu rapor cihazda FPS ölçümü veya native Apple Liquid Glass kullanımı iddia
etmez. Fiziksel iPhone GPU/akıcılık/görsel kabulü ayrıca yapılmalıdır.
Canlı SQL, main, Cloudflare ve TestFlight yayını bu değişikliğe dahil değildir.
