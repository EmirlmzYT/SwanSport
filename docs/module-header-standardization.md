# Partner Bul AppBar standardı

20 B/C/D ekranı opt-in `swanModuleAppBar(context, title:, actions:)` kullanır.
Factory gerçek AppBar üretir: palette bg/ink, h3, elevation/scrolledUnder 0,
sol hizalı tek satır başlık, yalnız Navigator.canPop olduğunda geri düğmesi.
Ana sosyal/dashboard/kapak yüzeyleri (A grubu) ve Partner Bul değiştirilmedi.

Mevcut çalışan aksiyonlar korunur: saha yakınlık/partner, ilan verme, kulüp
başvurusu, organizasyon oluşturma, banka/mali kuyruk, takım ekleme, ayarlar,
yoklama, belge yükleme, yardım ve okundu/tercihler. Pazaryeri sepet servisi
olmadığından sahte düğme eklenmedi; mevcut arama ve İlan Ver korunur.

Sahalar ve finans sekmeleri body başında token padding ile, pazaryeri
sekmesi ListView ilk öğesinde SwanSegmentedTabs ile sunulur. Finans
Borçlar/Ödemeler/Planlar sayısı ve marketplace sellerType davranışı korunur.
Kulüp finansı/çocuk belge kapsamı açıklaması gövdede kalır. Eski ham
font/renk içeren gövde kartları bu header görevinin kapsamı dışında kaldı;
yeni AppBar koduna ham font/hex eklenmedi.

Yerel kontroller: 20 source/header sözleşmesi, 22 Dart parse, 41 rota/giriş
statik eşliği, Group A diff boş, SSS 39/39, push 40 kayıpsız, SQL 5/5,
diff temiz. Üç yeni regresyon testi (20 ekran kaynak sözleşmesi + açık/koyu
root/push geri ve aksiyon davranışı) hazır. Flutter SDK yok: widget,
navigation/merged_routes, analyze/build ve görsel QA çalıştırılamadı.
Canlı SQL/deploy/commit/push yapılmadı.
