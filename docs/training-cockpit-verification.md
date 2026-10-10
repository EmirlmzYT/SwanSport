# Canlı antrenman kokpiti — 2026-10-10

## Uygulanan davranış

- Mevcut `/antrenman-oturumu` ve `/antrenman-sonuc` rotaları, tek ekranda sporcu/antrenör dallanması korunur.
- `BranchDrillPad` dört arketipi seçer. Hedefte X/M halkaları ve eski sayısal ScorePad; denemede branşa uygun drill seçimi, başarı/hata ve yüzde; turda zaman damgasından kronometre, mesafe ve SPLIT; rallide winner, basit hata ve ace düğmeleri vardır. Mevcut protokol ace'i winner toplamında saklar; arayüz bunu açıkça belirtir.
- Bir set tek drill/tur taşır. Deneme başladıktan sonra drill değiştirilemez. Tur kaydı sonraki setle ilerler; henüz ölçülmeyen tur veya girilmeyen sonuç sıfır performans gibi sunulmaz.
- Taslak sayaçlar `swansport_data` Riverpod sağlayıcısındadır; sunucu yenilemesi taslağı silmez. Başarısız kayıt metrikleri korur; bekleyen istek sırasında tekrar gönderim kapanır. Hesap değişimi taslak sağlayıcısını yeniden kurar.
- Kronometre arka planda geçen süreyi zaman damgasından hesaplar; duraklatma süreyi dondurur. Sunucunun `paused_at` değeri aşama geri sayımına taşınır. Duraklatılmış ve kilitli set girişleri kapalıdır. Faz değişimi animasyon ve hafif haptik verir; süre bitmesi otomatik aşama geçirmez. Süresiz kişisel aşama da elle ilerletilebilir.
- Kulüp personeli katılan sporcuyu seçerek hızlı etiket veya özel not gönderir. Mevcut `submit_coach_drill_note` RPC'si ve oturum günlüğü kullanılır. Başarısız notta metin korunur; kişisel ve kapanmış oturumda not paneli açılmaz.
- Sporcu ekranı ve personel sonuç rotasında arketipe uygun karne vardır: deneme/başarı/drill dağılımı; en iyi/ortalama tur/mesafe/geçmiş; hedef toplamı/ok ortalaması; ralli/winner/hata. Tamamlanan personel oturumundan sonuç ekranı açılabilir.
- Canlı/review oturumları veri katmanında 3 saniyelik yenilemeyle aşama, katılımcılar, setler, notlar ve sonuçları günceller; sağlayıcı bırakıldığında zamanlayıcı iptal edilir. Tamamlanan oturumda yenileme durur.

## Veri ve güvenlik sınırları

Yeni tablo, skor RPC'si veya rol hesabı yok. `TrainingSessionService` mevcut RPC'leri kullanır. Karne sorgusu açık sütun listesiyle mevcut `training_sets` RLS'inden geçer; sporcu adını sorguya eklemez. Widget Supabase çağırmaz. Saf Dart motoruna Flutter/Supabase bağımlılığı eklenmedi. Mevcut 0105 sunucu doğrulaması, yetki ve kilit davranışı korunur.

0106 yalnız mevcut özelliğe bağlı üç SSS kaydı ekler; yayın kademesini değiştirmez. Kullanıcının çalışma alanındaki generated metadata ve `docs/ROADMAP_FEDERATION_AND_IDENTITY.md` bu çalışmaya alınmadı.

## Doğrulama kanıtı

Son tam paket koşuları:

| Komut | Sonuç | Yerel log |
|---|---:|---|
| data: `flutter --no-version-check test --no-pub` | 393 geçti | `build/cockpit-data-full-final.log` |
| app: `flutter --no-version-check test --no-pub --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=` | 351 geçti | `build/cockpit-app-full-final.log` |
| console: `flutter --no-version-check test --no-pub` | 50 geçti | `build/cockpit-console-full.log` |
| `node --test tools/training_archetypes_sql_test.mjs` | 17 gerçek PostgreSQL davranış senaryosu geçti | `build/cockpit-sql-tests.log` |
| `python tools/check_migrations.py` | sorunlu dosya 0; 0106 dahil | `build/cockpit-migrations.log` |
| `python tools/check_faq.py` | 39/39 bayrak kapsamı | terminal çıktısı |

Toplam **794 Flutter testi**, bunun **27'si yeni** (21 uygulama, 6 veri). Dört arketipin açık/koyu ve 320px / 1.5 yazı ölçeği görünümleri; gerçek sayaç→tipli yük→servis bağlantısı; X/M; ace; lap geçmişinde null skor; başarısız kaydın korunması/çift tıklama; kilit/duraklama; yardımcı antrenörün hızlı ve özel notu; tamamlanan oturum ve lap sonuç rotası test edildi. Oturum isteği ekran kapandıktan sonra tamamlandığında yenileme zamanlayıcısı oluşturulmadığı ayrıca doğrulandı.

Genel `flutter analyze packages/swansport_data apps/swansport_app apps/swansport_console`: **0 hata, 5 önceki uyarı**, stil info bulguları var. Uyarılar eski role_context_switcher/marketplace importları, konsol count değişkeni, marketplace Map tipi ve social_and_lifecycle test List tipiyle ilgilidir. Yeni altı Dart kaynak/test dosyasının son dar analizi bulgusuz; mevcut entegrasyon dosyaları 0 hata/0 uyarı ve 98 stil info. Loglar `build/cockpit-full-analyze.log`, `build/cockpit-new-analyze-final.log`, `build/cockpit-integration-analyze.log`.

Gerçek AppTheme ve MaterialIcons ile dört 430px ekran görüntüsü üretildi; yerel `build/cockpit_*.png` görsel kontrolünden geçti. Geçici görüntü üretim testi kaldırıldı, bu görseller regresyon golden'ı olarak sayılmadı.

Kod grafiği 7 Ekim kaydı olduğundan değişen/yeni dosyalarda eskiydi; kapsam kontrolünden sonra kararlar doğrudan güncel kaynak okuması ve çalışan testlerle doğrulandı.

## Canlı kullanım önkoşulları

Bu görev canlı Supabase veya Cloudflare'ı değiştirmedi. Yeni kokpitin sunucu protokolü için **0105**, yardım metinleri için **0106** canlıda uygulanmalı; dosya başına ayrı transaction ve 15s lock_timeout korunmalı. Yeni istemci bundan sonra yayımlanmalı. Fiziksel cihazdaki haptik ve arka plan dönüşü ayrıca denenmeli.

Gönderilmemiş sayaç/tur taslağı uygulama belleğindedir; uygulamanın tamamen sonlandırılmasında kalıcı kurtarma veya çevrimdışı gönderim kuyruğu bu fazın kapsamı değildir. SSS bu ayrımı anlatır.
