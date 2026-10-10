# Antrenör kademesi ve veli resmi sonuç hattı — yerel doğrulama

2026-10-10. Canlı SQL, Git push ve deploy yapılmadı. Başlangıçtaki kullanıcı dosyaları (`docs/ROADMAP_FEDERATION_AND_IDENTITY.md`, veri paketinin `.flutter-plugins-dependencies` dosyası) commit kapsamına alınmadı.

## Uygulanan davranış

- `SwanAccess.isHeadCoachForSport` onaylı, aynı branşa ait ve süresi geçmemiş 3–5. kademe belgesini veya aktif kulüp yöneticisi bağlamını kullanır. `isAssistantCoachForSport` aynı branşta 1–2. kademeyi tanımlar. Beyan edilen profil rolü, toplam kademe ve platform yöneticiliği branş belgesinin yerine geçmez.
- 0104, mevcut `federation_publish_roster` RPC'sini genişletir. Yazıcı ilgili kulübün aktif yöneticisi veya aynı branşta 3+ belgesi olan aktif antrenörü olmalıdır. C1 kimlik/geçiş hakkı, çocuğun veli bağı, takım/lisans/uygunluk, gerekçe ve iyimser sürüm kontrolleri korunur. Sadece federasyon program görevi esame yazma yetkisi vermez. Sonuç, lisans ve tescil yazma yetkileri yine federasyon görevlerine aittir.
- Mevcut takım kadrosu ekranı resmi esameyi okur; yardımcı antrenör kilit uyarısı görür, yetkili kişi mevcut takım sporcularını seçip gerekçeyle yeni resmi revizyon oluşturur. Önceki kadro UUID'leri korunur ve kullanıcı isterse açıkça çıkarır. Normal takım atamaları, antrenman yoklaması ve drill notu akışları bu sınıra sokulmadı.
- Sonuç sürümü güncellenince, yayımlanan revizyonun dondurulmuş kadrosundaki küçük/bilinmeyen doğum tarihli sporcuların gerçek, hesabı bağlı velilerine `notifications` satırı eklenir. Çocuk/veli/revizyon başına tekildir. 18. doğum günü reşit sayılır. Başka kardeşler veya kulüp sporcuları bildirim kadrosuna eklenmez.
- Bildirim, sonuç ve otomatik CV aynı işlemde kalır; CV hatası hepsini geri alır. Mevcut bildirim → `push_on_notification` → Cloudflare → FCM/Web Push taşıyıcısı kullanılır. Telefon tercihi kapalıysa uygulama içi bildirim kalır. Mesajlar ayrı gelen kutusu/sayaç sözleşmesinde kalır.
- Bildirim bağlantısı kendi özel bildirim kimliğiyle tarihsel sonuç revizyonunu açar; varsa daha yeni revizyon uyarısı gösterilir. Veli takvimi doğrudan güncel resmi sonuç + dondurulmuş kadro + canlı veli bağından okunur; **bildirimi silmek takvim kartını silmez**. Takvim bağlantısı güncel çocuk/maç karnesini açar. Ortak resmi kaynak kartı kullanılır; düzenleme/silme yoktur.
- Galibiyet yeşil, mağlubiyet/DQ kırmızı; beraberlik ve DNF ayrı etiketlidir. Bireysel seri derecesi genel maç galibiyeti gibi gösterilmez. Sayısal karne yalnız ilgili çocuğun derecesini içerir; tam kadro, sağlık, TCKN, lisans ve başka çocuk adları verilmez.
- Realtime ve ön plandaki FCM alınışı resmi CV, kaynak, bildirim sayacı ve takvim sağlayıcılarını geçersiz kılar. Kaçan olaylar için 30 saniyelik yenileme yedeği vardır. Yetki her RPC'de yeniden denetlenir. Veli bağı kaldırılınca bildirim listesi ve özel sonuç okumaları kapanır.
- Yeni tablo yoktur. Bildirim tablosuna yalnız revizyon referansı ve tekil indeks eklenir. Anon/PUBLIC bildirim tablo izinleri kapalıdır. Resmi bildirim payload'ı istemciden değiştirilemez; okundu işaretleme dar, sahip kontrollü RPC'den geçer.

## Test kanıtı

Yerel günlükler Git dışında `build/coach-guardian-*` altındadır.

| Kontrol | Sonuç / günlük |
|---|---|
| Tüm swansport_data Flutter testleri | 375 geçti — `data-complete.log` |
| Tüm uygulama Flutter testleri | 330 geçti — `app-complete.log`; test ortamında SUPABASE_URL / SUPABASE_ANON_KEY boş define |
| Tüm konsol Flutter testleri | 50 geçti — `console-full.log` |
| Core / tasarım Flutter testleri | 26 + 2 geçti — `core-test.log`, `design-test.log` |
| Saf Dart motor / model testleri | 134 + 1 geçti — `engine-test.log`, `models-test.log` |
| Gerçek SQL temel / C1 / 0104 davranışları | 39 senaryo — `sql-complete.log` |
| Public ve resmi sonuç SQL regresyonları | 49 geçti — `public-official-sql.log` |
| Genel Flutter analiz | 0 hata, 5 önceki kapsam dışı uyarı, 3032 info — `analyze-complete.log` |
| Üretim app web build | Geçti — `app-build-complete.log` |
| Üretim konsol web build | Geçti — `console-build.log` |
| 0104 PostgreSQL parse | Geçti |
| Bildirim rotaları / SSS | 40 rota korunur; 39/39 bayrak yardım kapsamı |

Toplam Flutter: **783**. Saf Dart: **135**. SQL: **88 koşu, 56 farklı senaryo** (temel senaryolar dosyalardan tekrar çalışır).

SQL testleri izole PGlite/PostgreSQL üzerinde gerçek 0001/0002/0004, üyelik/invite yolları, 0094–0104 fonksiyonlarını çalıştırır. FCM testi mevcut push tetikleyicisini, sahte `net.http_post` taşıyıcısına verilen yükle denetler: yalnız doğru velinin `fcm` cihazı, doğru özel rota, tercih kapalıyken gönderim olmaması ve işlem geri alınması kontrol edilir. Bu gerçek cihaz teslimi testi değildir. Test altyapısında ilgisiz Supabase/pg_net/Vault parçaları azaltılmıştır.

## Yayın öncesi kalan işletim doğrulaması

0104 canlıya uygulanmadı. Yeni istemci bu RPC'lere bağlıdır; migration olmadan yayımlanmamalıdır. Mevcut Vault push anahtarı, Cloudflare FCM servis hesabı, cihaz aboneliği ve kullanıcı bildirim izniyle fiziksel cihazda ön plan / arka plan / kapalı uygulama teslimi ayrıca doğrulanmalıdır. İki gerçek PostgreSQL oturumunda eşzamanlı belge iptali/roster yayını testi yapılmadı. Mevcut CupertinoIcons font uyarısı app build'de devam eder.

Önceki beş analiz uyarısı: role_context_switcher ve marketplace_screen kullanılmayan importları; konsolda marketplace count; marketplace_service raw Map; social_and_lifecycle_test List tür çıkarımı. Bu görevde bu dosyalar değiştirilmedi.
