# Mobil UI temizliği — 2026-10-12

## Kapsam

Görevde belirtilen 11 ekran: Profil, Bildirimler, Mesajlar, Arama, Pazaryeri,
Yoklama Geçmişi, Kulüp Finansı, Takım Kadrosu, Sporcular, Keşfet ve Kulüp Ayarları.
Konsol, veri servisleri, migration/RLS, rota tanımları ve diğer feature dosyaları
değiştirilmedi. Bu rapor uygulamanın bütün ekranlarının hatasız olduğunu iddia etmez.

- 76 ham GoogleFonts çağrısı ve kalan iki ham TextStyle çağrısı SwanType'a taşındı.
  Mevcut tipografi ölçeği korunur; kronometre için aynı başlık ailesinde tabular
  rakamları kullanan SwanType.stopwatch eklendi.
- Bu ekranlarda ham hex, siyah/beyaz, kTeal ve SwanColors.textSecondary yerine
  mobil palet kullanılır. Yeni onAccent/shadow jetonları ortak palettedir;
  koyu tema gölgesi saydamdır. Açık tema accentFill mevcut koyu aksiyon tonuyla
  eşlendi: küçük beyaz etiketlerde hesaplanan kontrast 5.39:1 (önce 4.05:1).
- Profil kimlik satırı ve sosyal sayaç sütunları sınırlı genişlik alır.
  İşlevsiz açılır ok ve sahte hikâye halkaları kaldırıldı; bağlantı, takip,
  profil düzenleme/paylaşım, gönderi ve kayıtlı rutin eylemleri korunur.
- Bildirim rozeti unreadNotificationsProvider'ı okur, sıfırda gizlenir.
  Tek okundu eylemi AppBar'dadır. Önceden var olan açılışta okundu işaretleme
  davranışı korunur; başarısız olduğunda yakalanmamış async hata üretmez.
- Mesaj başlığı/sohbet adları, arama başlıkları ve fiyat satırları flex/ellipsis
  ile sınırlandı. Yatay filtrelerde loose flex ve min-width Row kullanılır;
  yoklama filtresi Expanded içinde kaydırılır.
- Aramadaki yalnız Snackbar gösteren QR/kamera ve filtre ikonları kaldırıldı.
  Gerçek arama, kategori sorgusu, kişi/kulüp filtreleri ve yönlendirmeler korunur.
- Pazaryeri'nin verisiz indirim, kalite test garantisi ve ücretsiz dolap teslimat
  vaatleri kaldırıldı. Mağaza/bireysel etiketi gerçek ilan tipinden gelir;
  favori için kapak rozetinin yanında yer ayrılır. İlan/favori/filtre davranışı sürer.
- Finans snapshot/metric kartları sabit yükseklikli grid yerine genişliğe göre
  1–3 sütunlu, içerik yüksekliğine uyarlanan Wrap kullanır. Dönem seçimi ve
  onay/tahsilat/plan işlemleri korunur.
- Yüzen alt gezinmeli ana listelerde alt boşluk SwanSpace.xl * 5 = 120 px.
  Alt gezinmesi olmayan sohbet mesajları/diğer iç listeler bu kurala zorlanmadı.

## Doğrulama

| Kontrol | Sonuç |
| --- | --- |
| python tools/check_faq.py | 39/39 |
| python tools/check_push_routes.py | 40 eşleme, kayıp yok |
| node tools/platform_mission_control_sql_test.mjs | İzole PostgreSQL 5/5 |
| python tools/check_mobile_ui_tokens.py | 11/11 kapsam sözleşmesi |
| Aynı komut --syntax | 537 Dart dosyası, parse hatası yok |
| node build/feed-contract-qa.cjs | 41 mobil rota/giriş paritesi, statik |
| git diff --check | Temiz |

`--syntax` gerçek Dart tree-sitter ayrıştırıcısını kullanır; tree_sitter ve
tree_sitter_dart gerektirir. Bu makinede PYTHONPATH=build/dart-syntax-check ile
çalıştırıldı. Basit parantez sayımı yerine yorum/string/interpolation sözdizimi de
ayrıştırılır. Bu denetim tip çözümlemesi veya Flutter derlemesi **değildir**.

`test/mobile_ui_cleanup_test.dart` 19 regresyon senaryosu hazırlar: açık/koyu
temada 320px ve 1.3 metin ölçeği, gerçek 0/17 bildirim sayacı/okundu aksiyonu,
uzun mesaj/profil adları, arama, yüksek fiyatlar, finans ve yoklama filtresi;
ayrıca kaynak jetonu ve kontrast sözleşmesi.

Flutter test ve analyze çağrıları SDK bulunamadığı için çalışmadı. Bu 19 testin,
navigation_test.dart, merged_routes_test.dart ve mevcut swan_contrast_test.dart
testlerinin geçtiği iddia edilmez. Gerçek render overflow, görsel QA, formatter,
analiz ve üretim derlemesi Flutter bulunan ortamda tamamlanmalıdır:

```bash
cd apps/swansport_app
flutter test test/mobile_ui_cleanup_test.dart test/navigation_test.dart test/merged_routes_test.dart test/swan_contrast_test.dart
flutter analyze
```

Yalnız görev dosyaları stage edilir; commit/push/deploy veya canlı SQL yok.
Başlangıçtaki tools/scan_ui_code_smells.py ve tools/__pycache__ korunur ve stage edilmez.
