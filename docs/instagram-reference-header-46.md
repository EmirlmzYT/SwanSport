# Instagram video referanslı üst gezinme — +46

2026-10-18. Kullanıcının sağladığı 8.52 saniye / yaklaşık 60 fps iPhone
kaydından sabit, kaydırılan ve yeniden açılan üst bölüm incelendi. Video,
hesap adları ve çıkarılan kareler repoya/harici servise yüklenmez.

## Referans ve uygulama

- Videoda boydan boya buzlu/tintli panel yoktur. Önceki +45 tam genişlik
  tint gradyanı kaldırıldı. İçerik üst bölümün arkasından görünür.
- Başlık ortada ve kompakt; arkasında kapsül/panel bulunmaz. SwanSport
  markası mevcut Sora ailesinde mevcut 22 adımını kullanır; Instagram logosu
  kopyalanmaz. Mission Control adı/logo kaynağı korunur.
- Soldaki + mevcut SwanAccess.publish kapısından sonra aynı oluşturma
  sheet'ini açar. Sağda SwanSport bildirim ve mesaj işlevleri/gerçek ayrı
  okunmamış sayaçları korunur. 36 görünen daire / 48 dokunma hedefi.
- Sosyal akışın iki modu artık başlığın açılır menüsündedir. Tümü/Takip
  seçimi aynı provider'ları süzer; ölü ok veya ikinci filtre sistemi yoktur.
- Keşfet, Mesajlar ve Profil aynı ortalı başlık/yuvarlak kontrol dilini
  kullanır. Profil kartı/ayarlar ve Yeni Sohbet aksiyonları bağlı kalır.
- Ortak üst kenar difüzyonu, sınırlandırılmış ve çakışmayan beş dar blur
  bandıyla azalır. Son bandın sigma değeri .3'tür; düz panelin sert alt
  kesimi ve dolgu rengi yoktur. Bu sürekli/native UIGlassEffect değildir;
  Flutter içinde kademeli bir yaklaşım ve fiziksel GPU ölçümü ayrı kabuldür.
- +45'te test edilen sabit scroll-under viewport, kaydırma eşiği,
  translate/clip, klavye ve form koruması sürer. Alt menü kaynağı değişmedi.
- Yüksek kontrast/azaltılmış hareket opak fallback'i vardır. Başlık
  okunurluğu için hafif metin gölgesi; küçük kontrollerde yerel yüzey tonu.

Kod grafiği ana checkout'un eski indeksindedir; coverage missing/changed
olan dosyalar worktree kaynağından doğrulandı. UI uidotsh kaynağı mevcut
olmadığından mevcut Flutter/tasarım jetonları kullanıldı.

## Kanıt

- İlgili 30 test geçti. Önceki 54 odaklı kontrol de geçti.
- 7 yeni video referansı testi: iki tema / 320 ve 393 genişlik / büyük
  metin, gerçek orta hizalama, çakışmayan 48 hedefler, iki akış seçimi,
  misafir oluşturma kapısı ve piksel düzeyinde tam genişlik dolgu yokluğu.
- Gerçek Flutter üst barı ve örnek arka planla PNG'ler
  `docs/design/mobile-header-46/` altındadır. Üretim verisi içermez.
- Tam mobil regresyon ve son analiz sürüyor; +46 macOS preview hazırlanıyor.

Canlı SQL, Cloudflare/main veya TestFlight yayını yok. +43 native Firebase
açılış koruması ve unsigned önizlemede push kapalı olma sözleşmesi korunur.
Gerçek iPhone'da estetik/FPS kabulü yapılmış sayılmaz.
