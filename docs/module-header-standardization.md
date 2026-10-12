# Partner Bul AppBar standardı

42 ikincil, modül ve alt ekran opt-in `swanModuleAppBar(context, title:, actions:)` kullanır.
Factory gerçek AppBar üretir: palette bg/ink, h3, elevation/scrolledUnder 0,
sol hizalı tek satır başlık, yalnız Navigator.canPop olduğunda geri düğmesi.
Ana sosyal/dashboard/kapak yüzeyleri (A grubu) ve Partner Bul değiştirilmedi.

Mevcut çalışan aksiyonlar korunur: saha yakınlık/partner, ilan verme (_create),
kulüp başvurusu, organizasyon oluşturma, banka/mali kuyruk, takım ekleme, ayarlar,
yoklama, belge yükleme, yardım, kampanya açma ve okundu/tercihler.
Pazaryeri sepet servisi olmadığından sahte düğme eklenmedi; mevcut arama ve İlan Ver korunur.

İlanlar, ilan ver, mağaza başvurusu, dayanışma & fon, tesisler, tesis rezervasyonu,
saha işlemlerim, gizlilik & güvenlik, veli işlem merkezi, davet kodu, medikal merkez,
ekipman tuning, ters işlem, muhasebeci defteri, oturum sonucu, ileti ayrıntısı,
etkinlik detayı, raporlar ve kullanıcı ayrıntısı dahil tüm sayfalarda SwanPageHeader
yerine swanModuleAppBar standardına geçildi.

Yerel kontroller: 42 source/header sözleşmesi, Dart parse, 41 rota/giriş
statik eşliği, Group A diff boş, SSS 39/39, push 40 kayıpsız, SQL 5/5,
diff temiz. Regresyon testleri 42 ekranı doğrulayacak şekilde güncellendi.
