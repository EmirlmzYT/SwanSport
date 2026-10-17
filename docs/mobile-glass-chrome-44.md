# Mobil cam gezinme — 0.5.15+44

2026-10-18. Kullanıcının tasarım kararları: bütün mobil ekranlarda ortak
Instagram düzeni/hafif iOS cam etkisi; kenarlardan boşluklu yuvarlak yüzen
alt bar; yalnız ikonlar; bar içinde hafif belirgin cam +. Aşağı kaydırırken
üst bar gizlenir/alt bar küçülür, yukarı kaydırınca açılır. Üst başlıkların
mevcut bilgi/aksiyon yerleşimi korunur. Klavyede gezinme gizlenir; yazılmamış
formlar ve liste konumu korunur. Kaydırılmayan ekranlar sabittir.

## Kaynak ve kapsam

- Taban, main değil, +43 iOS açılış düzeltmesini içeren `db26aab`.
  Çalışma `codex/mobile-glass-chrome` dalında ayrı managed worktree'dedir;
  kullanıcının eski main checkout'u ve yerel değişiklikleri korunur.
- Kod grafiği list/search/coverage araçları Transport closed döndürdü;
  yapı doğrudan güncel kaynak ve testlerle doğrulandı. UI becerisinin
  uidotsh kaynağı mevcut kaynak listesinde yok; yeni paket/servis kurulmadı.
- `SwanChrome` bütün yeni ölçü/hareket değerlerinin tek kaynağıdır.
  Açık/koyu renkler mevcut `SwanPalette` üzerinden gelir; yeni renk paleti yok.
- `SwanGlassSurface`: sınırlı blur, tek ince kenar, hafif gölge. Yüksek kontrast
  veya azaltılmış harekette opak yüzey; azaltılmış harekette animasyon yok.
  Bu Flutter cam yorumudur; Apple native Liquid Glass materyali değildir.
- `SwanBottomNav`: dört rota + oluşturma işlemi korunur. 60 → 48 mantıksal
  pikselde küçülür; beş eşit yuva ve en az 48 dokunma alanı vardır. Etiketler
  görsel olarak kaldırılmıştır ama seçili durum/isim/eylem Semantics'te kalır.
  Tooltip uzun basışla sekme kaydırma hareketini ele geçirmez. Hesap kapıları,
  oluşturma alt sayfası ve iOS yatay/uzun basış seçimi korunur.
- `SwanScaffold`: ekran başına controller; scroll notification'larını tüketmez,
  iç/yatay/ters mesaj listesi/ballistic/programatik hareketi izlemez. Aynı
  ekranda küçük hareketlere histerezis uygulanır. Üst bar, mevcut aksiyon,
  başlık, alt sekme, drawer ve arama slotları korunarak cam yüzeye alınır.
  Gizleme sırasında sabit yüksekliğinde yerleştirilir ve kırpılır; içindeki
  metin sıkıştırılmaz. Gizliyken pointer/semantics kapalıdır.
- Mevcut feature Scaffold çağrıları ortak kabuğa geçti. Mevcut alt gezinmesi
  olmayan sohbet/formlara zorla menü eklenmedi. Kaydet gibi gezinme dışındaki
  bottomNavigationBar'lar kendi boyutu/klavye davranışını korur.
- Ana Akış, Keşfet, Mesajlar ve Profil'in mevcut başlıkları ortak üst bar
  yuvasına taşındı; filtre, rozet, QR/ayarlar ve yeni sohbet aksiyonları korunur.
  Ana Akış'ın ikinci bağımsız scroll controller'ı kaldırıldı.
- Konsol, veri katmanı, RLS, SQL, özellik bayrakları ve native Firebase
  davranışı değiştirilmedi. +43 güvenli Firebase önizleme yolu korunur.

## Görsel ve davranış doğrulaması

Gerçek Flutter bileşenlerinin açık/koyu, geniş/küçülmüş render'ları
`build/glass-previews/` içindedir; üretim seed verisi değildir. Material
ikon fontu ve mevcut yerel Google Fonts yüklenerek görüntüler incelenir.
Keşfet'in mevcut fixture ekranı ayrıca
`apps/swansport_app/build/design-review/explore.png` üretir.

İlk tam koşu, animasyon sırasında özel başlığın küçülen constraint ile
sıkıştırıldığını ve büyük yazıda Mesajlar başlığının sarıldığını yakaladı.
Sabit yerleşim + kırpma ve bounded başlık ile düzeltildi. İkon-only gezinme
testleri görünür yazı yerine erişilebilir Tooltip hedefini kullanır; erişim
reddi ve gerçek aksiyon testleri korunur. İlgili beş dosya: 49/49 geçti.

Nihai tam koşu, analiz, web build ve iOS CI sonuçları teslimde kaydedilecek.
Yerel Flutter 3.44.7 / Dart 3.12.2; iOS CI +43'teki 3.47.7 ile çalışır.
Yerel SDK'nın ürettiği bağımlılık çözümü/Windows plugin dosyaları ürün
değişikliği olarak alınmaz; pakete yeni bağımlılık eklenmedi.

## Kabul sınırı

Gerçek iPhone kaydırma hissi, blur GPU maliyeti, VoiceOver ve klavye/çentik
cihaz kabulü ayrı testtir. Widget render'ı fiziksel cihaz kabulü değildir.
Bu tasarım denemesi main'e merge, canlı SQL, üretim web yayını veya
TestFlight yüklemesi yapmaz. Önizleme IPA kullanıcı tarafından imzalanır.

## Son yerel doğrulama

- Nihai mobil tam koşu: **495/495**, çıkış 0; `glass-app-verified.log`.
- Ana/özel başlık, takvim, sporcu detayı ve UI alt kümesi 44/44 geçti.
- Analiz: **0 error, 0 warning**, 3626 mevcut info; `--no-fatal-infos`
  ile çıkış 0 (`glass-analyze-verified.log`). Info'lar bastırılmadı.
- Yeni 14 chrome senaryosu, 320/393 genişlik, açık/koyu/büyük yazı, 48dp,
  form+klavye durumu, doğal başlık ölçümü/ara animasyon kareleri, uzun
  kaydet barı, çentik/home indicator ve yüksek kontrastı kapsar.
- PNG önizlemeleri gerçek widget render'ıdır:
  [açık](design/mobile-glass/light-expanded.png),
  [koyu](design/mobile-glass/dark-expanded.png),
  [küçülmüş açık](design/mobile-glass/light-compact.png),
  [küçülmüş koyu](design/mobile-glass/dark-compact.png).
  Arka plan sunumu yalnız test örneğidir; üretim içerik tasarımı değişmez.
- iOS önizleme CI: https://github.com/EmirlmzYT/SwanSport/actions/runs/39074187665
  Kaynak `d1bf27f`, sürüm `0.5.15+44`, preview_only=true. Bu kontrol
  noktasında derleme sürüyor; başarısı ve IPA doğrulaması ayrıca kaydedilir.
