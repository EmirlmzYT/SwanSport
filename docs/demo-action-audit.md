# Demo verileri ve eylem denetimi — 6 Ekim 2026

Bu çalışma mobil/web uygulamasının kullanıcıya açık ekranlarındaki sabit örnek kayıtları, iş yapmadan başarı gösteren kontrolleri ve yanlış rota bağlantılarını temizler. Gerçek veri bulunmadığında boş durum gösterilir; okuma hatası boş kayıt veya başarı olarak sunulmaz.

## Gerçek veriye bağlanan akışlar

| Alan | Son davranış |
|---|---|
| Sporcu kartı ve kadro | Gerçek kadro, sporcu kartı ve uygunluk durumları; mevcut ekleme, hesaba bağlama ve veli daveti korunur. |
| Performans | Kayıtlı testler, hedefler ve antrenman geçmişi; sabit nabız, hız, puan ve ilerleme grafikleri kaldırıldı. |
| Antrenman şablonu | Branş ve sunucunun kabul ettiği yapılandırmayla mevcut `createProtocol` çağrısı; çift gönderim engeli ve gerçek hata/başarı sonucu. |
| Belgeler | Yetkili belge listesi, gerçek detay ve imzalı dosya bağlantısı; sahte kapasite, sürüm ve e-imza göstergeleri kaldırıldı. |
| Takvim ve yoklama | Gerçek etkinlikler ve kadro; takvimden seçilen etkinlik yoklamaya taşınır. Kaydedilmemiş yoklama işaretleri korunur. |
| Duyurular | Gerçek kayıtlar, Türkçe arama ve sabitlenen duyurular filtresi. |
| Sahalar | Gerçek kort/halı saha listesi ve çalışan detay bağlantıları; uydurma doluluk saatleri, rezervasyon başarısı ve IoT anahtarları kaldırıldı. |
| Takım kadrosu | Gerçek isim ve kayıtlı forma numarası; yaş, mevki, lisans, maç skoru ve katılım tahminleri kaldırıldı. Takıma ekleme/çıkarma ve sporcu kartı korunur. |
| Arama ve bağlantılar | Gerçek profil/konum bilgileri; doğrulama, çevrim içi, U18 ve lisans rozetleri kayıtsız kişilere uygulanmaz. |
| Muhasebe | `acc_ledger` üzerinden maskeli sporcu kodları ve sayfalama. Sporcu isimlerine erişim eklenmedi. |
| Mali özet ve bağış | Gerçek toplamlar; sıfır değerler örnek parayla değiştirilmez. Mali özetin tüm dönemleri kapsadığı açıkça yazılır. |
| Paylaşım | Gerçek fotoğraf, metin, etiket ve sunucu görünürlüğü. Varsayılan görünürlük sunucuya bırakılarak çocuk gizliliği korunur. |
| Mesajlar | Gerçek metin gönderimi, tekrar deneme ve kaynakta doğrulanan paylaşılan içerik. Sahte ses kaydı, arama ve dosya gönderimi kaldırıldı. |
| Ayarlar ve gizlilik | Gerçek tema/dil tercihi, bildirim aboneliği, engelleme, parola ve hesap işlemleri. Çalışmayan cihaz/GPS/biyometrik düğmeleri kaldırıldı. |
| Açılış | Oturum varsa akış; oturum yoksa ilk kullanım tanıtımı veya giriş ekranı. Demo rolü girişte yalnızca geliştirme araçları açıkken gösterilir. |

## Kaldırılan veya kapatılan prototipler

Beslenme, hazırlık/RPE, ekipman ayarı, rezervasyon ve dönem ters kaydı ekranlarında gerçek iş akışı olmadığı için örnek kayıt ve sahte kaydetme kaldırıldı. Eski rotalar açıklama ve ilgili çalışan ekrana bağlantıyla korunur. Sepet yerine mevcut pazaryeri, sıralama yerine kişinin gerçek antrenman geçmişi açılır.

Canlı/üretim uygulamasında örnek rapor, yapılandırma ve tipli performans detay rotaları prototip kayıtları göstermez. Rapor/yapılandırma menü girişleri kaldırıldı; eski bağlantılar güvenli açıklama ekranında karşılanır. Geliştirme ortamındaki fixture modelleri, mevcut testler için korunur. Bunlar canlı veri değildir.

Profil, mali gider, duyuru ve takvim bağlantılarındaki yanlış rota adları düzeltildi. Sahte PRO, doğrulanmış hesap ve çevrim içi işaretleri kaldırıldı.

İlan görsellerindeki ekspertiz mührü, garanti, dolap/konum ve kusursuz kondisyon iddiaları kaldırıldı. Bağış ekranındaki sabit isim/tutar akışı yerine mevcut gerçek destekçi listesi kullanılır.

## Doğrulama

- Uygulama: **232 test başarılı** (`flutter test --no-pub --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY= --reporter expanded`).
- Ortak veri katmanı: **251 test başarılı** (`flutter test --no-pub --reporter expanded`).
- Konsol: **40 test başarılı** (uygulamayla aynı boş derleme tanımlarıyla).
- Workspace analizi: **0 hata, 5 kapsam dışı uyarı**. Mevcut stil/lint bildirimleri nedeniyle analiz çıkış kodu sıfır değildir; sonuç “tamamen temiz analiz” olarak sunulmaz. Değiştirilen kaynaklarda uyarı yok.
- `git diff --check`: başarılı.
- Üretim web derlemesi başarılı; Supabase yapılandırması ve antrenman bayrağı pakette doğrulandı. Önceki konsol paketinin dosya özeti korunuyor.
- Cloudflare: **Deployment complete**. [Bu dağıtım](https://e2f698b3.swansport.pages.dev), [üretim adresi](https://swansport.pages.dev).
- Android: **0.5.1+16**, başarılı release derlemesi. [Release](https://github.com/EmirlmzYT/SwanSport/releases/tag/v0.5.1%2B16), [APK](https://github.com/EmirlmzYT/SwanSport/releases/download/v0.5.1%2B16/app-release.apk). GitHub asset durumu `uploaded`; dosya boyutu ve SHA-256 yerel paketle eşleşir.
- APK imza SHA-256: `6da57755e82f50e0804010df82bed862e2813a4ba433be72741e4c8e821915bb`; önceki APK ve kılavuzla aynı. Android sürüm kodu 16, sürüm adı 0.5.1 olarak paket içinden doğrulandı.
- Ayrıntılı kanıtlar `apps/swansport_app/build/demo-audit/` altında. Kaynak değişiklikleri çalışma alanında; commit oluşturulmadı.

Uygulama testleri çevrimdışı ve tekrarlanabilir çalışmak için boş `SUPABASE_URL` / `SUPABASE_ANON_KEY` derleme tanımlarıyla koşulur. Üretim derlemesi ise `env/prod.json` ile yapılır; test tanımları yayına taşınmaz.

Yeni regresyonlar: boş oturumda sahte GPS gösterilmemesi, maskeli defterin ikinci sayfası, sıfır mali değer ve hata ayrımı, canlı ortamda fixture raporunun ve demo girişinin kapalı olması, şablon kaydının gerçek servisi beklemesi ve çift gönderimi önlemesi, kayıtlı sahada hayali rezervasyon/IoT gösterilmemesi, takım kadrosunda hayali biyografi üretilmemesi ve Türkçe arama. Üyelikten gelen kulüp adına paylaşım yetkisi ayrıca test edilir.

Canlı hesaplarla uçtan uca görsel deneme ve fiziksel Android cihaz denemesi yapılmadı. Önceki tarayıcı erişim reddi aşılmadı. Veritabanı şeması değiştirilmedi; mevcut RPC ve RLS sözleşmeleri kullanıldı. Yapısal indeks üretilemediği için ilgili kaynaklar doğrudan okunup arandı; tam grafik kapsamı iddia edilmez.
