# SwanSport Pro Faz 0–5 Tasarımı

## Amaç

Profesyonel yönetim işlemlerini SwanSport Pro'da liste → detay → işlem → sonuç zinciriyle tamamlamak; SwanSport App'i başvuru, sporcu/veli öz-servisi ve yayımlanmış sonuçların doğal giriş noktası olarak korumak.

## Bağlayıcı ilkeler

- Yetki hesabı yalnız `SwanAccess` ve mevcut sunucu RLS/RPC kontrollerinden gelir.
- Widget doğrudan Supabase çağırmaz; veri sözleşmeleri `swansport_data` içinde kalır.
- Mesleki belge, kulüp üyelik başvurusu ve kulüp evrakı ayrı süreçlerdir.
- Muhasebeciye sporcu kimliği açılmaz; kulüp antrenman branşı federasyon yetkisi değildir.
- Pro'da doğrulanmış karşılık hazır olmadan App'teki çalışan yönetim girişi kaldırılmaz.
- Belge içeriği ve imzalı URL görev kartı, bildirim veya loglara yazılmaz.

## Yaklaşım

Mevcut `swansport_data` servislerini ve `swansport_pro_features` ortak host yapısını genişletmek seçildi. App ekranını Pro içinde kopyalamak veya ikinci karar servisi kurmak reddedildi; iki yaklaşım yetki ve davranış ayrışması üretirdi. Her faz davranış testiyle başlar, ortak Pro chrome/list/detail durumları kullanılır ve eski rotalar uyumluluk için korunur.

## Fazlar

1. Faz 0: Pro mesleki belge liste, detay, korunan önizleme, onay/ret, geçmiş ve branş eşleme; Panel/Görevler sayacı.
2. Faz 1: Panel, Görevler, Takvim, Gelen Kutusu ve Hesapta ortak görsel/gezinti sözleşmesi ve doğrudan hedefler.
3. Faz 2: Kulüp üyelik, evrak, kadro, takım, yoklama ve antrenörlü antrenman zincirleri; App sporcu/veli sonuç paritesi.
4. Faz 3: Veli, finans, tesis, hakem ve federasyon eksik gerçek işlem adımları ile doğrudan görev hedefleri.
5. Faz 4: Doğrulanmış profesyonel işlerde Pro ana işlem noktası; App başvuru/öz-servis ve uyumlu fallback.
6. Faz 5: Rol bazlı uçtan uca kabul, son matris, responsive görseller ve doğrulanmamış cihaz/canlı sınırları.

## Kabul sınırı

Yerel Flutter widget/integration testleri ve izole SQL testleri kanıttır. Fiziksel cihaz, imzalı push ve canlı Supabase dağıtımı ayrıca işaretlenir; yerel başarı bunların kanıtı sayılmaz.
