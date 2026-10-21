# Ortak fotoğraf seçimi — 2026-10-18

- Ortak kaynak paneli: kamera veya sistem fotoğraf seçicisi; masaüstünde galeri/dosya.
- iOS kamera ve fotoğraf kullanım açıklamaları Info.plist içinde. Android sistem kamera Intent ve Photo Picker yolunu kullanır; geniş depolama izni eklenmez.
- Profil fotoğrafına dokunma, profil/kapak düzenleme, gönderi, kulüp görselleri, malzeme ilanı, fiş/dekont ve Belge Kasası ortak akışı kullanır.
- Gönderide kalan kapasite kadar çoklu seçim (toplam 8), önizleme, yakınlaştırma, sıralama, kaldırma ve açık onay.
- Mobil seçimde 1600 px sınırı ve yüzde 85 kalite; web canvas ile JPEG dönüşümü korunur. Önizleme öncesi 10 MB ve çözülebilir görsel kontrolü.
- İzin reddi açıklanır, mobil cihaz ayarlarını açma yolu sunulur. İptal yükleme başlatmaz. Paralel seçici açılması engellenir.
- Yükleme mevcut veri servisleri üzerinden; RPC/RLS/özellik bayrakları değişmedi.

## Yerel kanıt

- Ortak medya modülü, profil ekranı ve yeni test dosyası: dart analyze, 0 bulgu.
- Fotoğraf seçim testleri ve veli/belge regresyonu: 12/12 geçti.
- iOS plist kamera/fotoğraf açıklamaları Python plistlib ile doğrulandı.

## Sınırlar

Gerçek iPhone/Android kamera, sınırlı fotoğraf erişimi ve ayarlardan geri dönüş fiziksel cihazda denenmedi. Önizleme yakınlaştırması kaydedilen fotoğrafı kırpmaz. Android işletim sistemi kamera açıkken uygulama sürecini sonlandırırsa taslak seçimini kurtarma ayrıca ele alınmalıdır. Tarayıcı kamera seçeneği cihaz/tarayıcı capture desteğine bağlıdır.
