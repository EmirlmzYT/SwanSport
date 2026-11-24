# SwanSport — ürün işlevleri ve federasyon masaüstü planı

**21 Ekim 2026 — ürün planı.** Amaç: federasyonun günlük işini masaüstünden tamamlayabildiği bir çalışma alanı kurmak; kulüp ve mobil akışlarını bu işlerin devamı haline getirmek.

Bu belge önceki teknik envanterin yerine geçmez. Bu çalışmanın odağı ekranların kullanıcıya yaptırdığı işlerdir. Test, yayın ve altyapı borçları ayrı envanterde kalır. Buradaki **104 madde**, mevcut temellerin genişletilmesi dahil hedef ürün yetenekleridir; 104'ünün de bugün hiç bulunmadığı iddia edilmez.

## Ürün kararı

**Masaüstü federasyon için birincil çalışma yeri olacak.** Toplu veri girişi, takvim düzenleme, görevlendirme, tescil ve belge üretimi burada yapılır. Mobil; görev kabulü, sahadaki maç işlemleri, kulüp/veli yanıtı ve takip için kullanılır.

Federasyonun temel işi şu zincirde tamamlanabilmeli:

**Programı oluştur / içe aktar → eşleştir ve düzenle → tesis ve görevlileri tamamla → kontrol et → yayımla → değişiklikleri yönet → sonuç ve resmi dosyayı tamamla.**

Yalnızca daha çok menü eklemek yeterli değildir. Kullanıcı bir satırdan maçın tamamına ulaşmalı, eksik işi bitirip kaldığı listeye dönebilmelidir.

## Bugünkü görünüm ve “olması gerektiği gibi olmayanlar”

Aşağıdaki gözlemler güncel modül kayıtları, federasyon ekranları ve ilgili kapsam raporlarıyla karşılaştırıldı. Kod indeksi bu yeni dosyalarda güncel sonuç vermedi; kaynaklar doğrudan okundu. Arayüz çalıştırılmadı; görsel kullanım testi yapıldığı iddia edilmez. “Ürün değerlendirmesi” mevcut bir davranışın neden yetersiz kaldığına ilişkin öneridir.

| No | Bugünkü durum / dayanak | Kullanıcıya etkisi | Hedef davranış |
| --- | --- | --- | --- |
| O-01 | Federasyon girişleri MHK, İl Lig & Müsabaka, Disiplin ve Resmi Sonuçlar etrafında; registry'de ayrı federasyon çalışma masası görünmüyor. | Kullanıcı ilk işini bulmak için modülleri gezer. | Yetkili kapsam ve bekleyen işleri gösteren federasyon açılış ekranı. |
| O-02 | İl Lig ekranı fikstür tablosu ve puan durumu sekmesi sunuyor. | Liste var; planı takvim üzerinde hazırlama/düzenleme işi zayıf. | Liste + hafta/ay + tesis görünümü ve düzenleme. |
| O-03 | İncelenen federasyon modüllerinde PDF/Excel program içe aktarma akışı bulunmuyor. | Hazır program sisteme tekrar girilmeyi gerektiriyor. | Dosyadan önerilen kayıtları çıkaran, kontrol ve takvime aktarımı tamamlayan sihirbaz. |
| O-04 | Fikstürün atama olmayan görünümünde satır tıklaması bağlı değil. | Maçın raporu, tesisi ve diğer işleri aynı satırdan açılamıyor. | Her maçın ortak ayrıntı dosyası. |
| O-05 | Görünen fikstür filtreleri il, metin araması ve “yalnız bu hafta” düzeyinde. | Sezon/kategori/lig/tarih aralığıyla yoğun federasyon işi sınırlı. | Kaydedilebilir, birlikte çalışan ayrıntılı filtreler. |
| O-06 | İl seçenekleri “İl 35” gibi kodla gösteriliyor. | Operatörün kodu şehir adına çevirmesi gerekiyor. | İzmir gibi şehir adı; gerekirse kod ikincil bilgi. |
| O-07 | Atama, maçı açıp hakem ve görev seçerek yapılıyor. | Haftanın toplu görev planı ve boşlukları bir bakışta yönetilemiyor. | Haftalık görev matrisi ve toplu atama taslağı. |
| O-08 | İmzalı rapor atama penceresinin içinde açılabiliyor. | Rapor incelemek atama işinin içine gömülüyor. | Ortak maç dosyasında doğrudan Rapor sekmesi. |
| O-09 | Tesis uygunluğu gösteriliyor; kapsam raporu tahsis RPC'sinin bu konsol yazma akışına bağlanmadığını belirtiyor. | Sorun görülebiliyor, aynı yerden tamamlanamıyor. | Tesis talebi/önerisi ve gerçek yetkili tahsis onayı. |
| O-10 | Disiplin ekranı imzalı rapor kartları ve sporcu ceza formu etrafında; itiraz/tebligat/antrenör sevki raporda açık. | Disiplin dosyası uçtan uca yürütülemiyor. | Dosya, savunma, karar, tebligat ve itiraz zinciri. |
| O-11 | İncelenen masaüstü sonuç formunun protokol dallarında voleybol görünmüyor; mobil yayın raporu voleybol set formunu tarif ediyor. | Branş desteği kullanılan ekrana göre ayrışabiliyor. | Branş × işlem × cihaz kapsam matrisi; masaüstünde uygun sonuç formu. |
| O-12 | Puan durumu ekranı grup/eleme/özel bonus kapsamının olmadığını açıkça söylüyor. | Bazı gerçek liglerin kuralı tamamıyla temsil edilemiyor. | Organizasyonun seçilmiş gerçek puan ve sıralama kuralları. |

Bu tablo gizlilik veya görev sınırlarının kaldırılmasını önermez. Tesis tahsisini federasyon personeli talep edebilir; kesin tahsis için mevcut tesis yetkisi korunur. MHK ataması ile resmi sonuç tescili farklı işlerdir. Ortak maç dosyasında yalnız kişinin yetkili olduğu sekme ve işlemler bulunur.

Kaynaklar:
- [apps/swansport_console/lib/app/modules/module_registry.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/lib/app/modules/module_registry.dart>)
- [apps/swansport_console/lib/features/federation/referee_assignments_screen.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/lib/features/federation/referee_assignments_screen.dart>)
- [apps/swansport_console/lib/features/federation/provincial_leagues_screen.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/lib/features/federation/provincial_leagues_screen.dart>)
- [apps/swansport_console/lib/features/federation/disciplinary_board_screen.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/lib/features/federation/disciplinary_board_screen.dart>)
- [apps/swansport_console/lib/features/federation/federation_results_screen.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/lib/features/federation/federation_results_screen.dart>)
- [apps/swansport_console/lib/features/federation/league_standings_panel.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/lib/features/federation/league_standings_panel.dart>)
- [docs/federation-console-phase-4-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/federation-console-phase-4-verification.md>)
- [docs/federation-publishing-center-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/federation-publishing-center-verification.md>)
- [docs/league-standings-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/league-standings-verification.md>)

## Önerilen masaüstü düzeni

Sol menüde işlemler gruplanır; kullanıcıya yetkili olduğu gruplar gösterilir:

1. **Çalışma Masası** — bugünkü program, eksik görevler, bekleyen işler.
2. **Organizasyonlar** — sezonlar, ligler, turnuvalar, katılımcılar.
3. **Takvim & Fikstür** — program, PDF/Excel aktarımı, toplu değişiklik.
4. **Tesis Planlama** — doluluk, tahsis talepleri, onaylar.
5. **MHK & Görevliler** — müsaitlik, atama matrisi, kabul/değişiklik.
6. **Tescil & Başvurular** — kulüp, lisans/vize, transfer.
7. **Müsabaka Merkezi** — maç dosyaları, raporlar, sonuçlar.
8. **Disiplin Dosyaları** — sevk, savunma, karar, itiraz.
9. **Yayın Merkezi** — resmi program, duyuru, bülten.
10. **Belgeler & Raporlar** — çıktılar, arşiv, operasyon raporları.

Her kategoriye boş bir ekran açmak yerine ilgili teslimatta gerçek işi tamamlayan sayfa eklenir. Sezon/branş/il bağlamı sayfalar arasında korunur.

## İlk somut özellik: PDF'den takvim oluşturma

### Kullanıcının yapacağı işlem

1. Takvim & Fikstür → **İçe Aktar**.
2. PDF/Excel dosyasını bırakır; varsa ilgili sezon/lig/kategori seçilir.
3. Sistem maçları/etkinlikleri ve tarih-saatleri otomatik çıkarır.
4. Kullanıcı kaynak belge ile çıkarılan satırları yan yana görür.
5. Sistem kulüp/takım/tesis isimlerini mevcut kayıtlara eşler. Belirsiz eşleşme seçime açılır.
6. Kullanıcı yalnız eksik/şüpheli satırları süzer; tablo içinde düzeltir.
7. Sistem aynı takım/saat ve tesis aralıklarını kontrol eder; kesin olmayan uygunluğu açık belirtir.
8. Önizleme otomatik olarak takvimde günlere yerleşir.
9. **Seçilenleri Takvime Aktar** ile gerçek resmi takvim taslakları oluşur.
10. Yetkili kişi **Yayımla** der; ilgili kulüp/mobil görünümü ve bildirimler aynı kayıtlara bağlanır.
11. Düzeltilmiş PDF gelirse “Yeni kayıt / değişen kayıt / aynı kayıt” farkıyla güncelleme hazırlanır.

PDF'yi sadece dosya olarak arşive eklemek bu özelliğin tamamlanması değildir. Çıkarılan program gerçek takvim ve müsabaka işlerine bağlanmalıdır.

### Örnek deneyim

Kullanıcı U16 lig programı içeren dosyayı yükler. Sistem örneğin:
- 24 satır çıkarır.
- 21 satırı mevcut takım ve tesisle eşleştirir.
- 2 satırda takım adının hangi kayıt olduğunu sorar.
- 1 satırda saat bulunmadığını işaretler.

Kesin eşleşen satırlar önceden takvimde yerleşir. Kullanıcı belirsiz üç satırı düzeltir; seçili kayıtları aktarır. Sayılar örnek senaryodur, güncel üretim verisi değildir.

### İlk sürüm sınırı ve ikinci adım

- **İlk teslim:** metin tabanlı PDF + standart Excel/CSV; maç/tarih/saat/katılımcı/tesis alanları, eşleştirme, önizleme, tekrar yüklemede mükerrer koruması.
- **Hemen sonraki genişletme:** taranmış PDF için OCR, farklı federasyon şablonları ve çok sayfalı birleşik tablolar. Taranmış dosya ilk teslimde desteklenmiyorsa anlaşılır biçimde tanınır; boş başarı sonucu üretilmez.
- Tarihi olmayan “3. hafta” satırı lig haftasıyla eşlenir veya kullanıcıdan tarih istenir; tarih uydurulmaz.
- Okunamayan isim adına otomatik yeni resmi kulüp/takım açılmaz.
- Aynı dosyayı iki kez yüklemek aynı müsabakayı iki kez oluşturmaz.
- Yeni PDF mevcut programı değiştiriyorsa, yayımlanmış eski kayda sessizce yazılmaz; değişiklik süreci açılır.
- Kaynak PDF özel notlar içeriyorsa yalnız onaylanan takvim alanları kamuya gider.
- İlk ürün odağı genel belge sohbeti veya her tür PDF'yi anlamak değil, federasyon programını gerçek kayda dönüştürmektir.

### İlk teslim tamamlandı sayılınca

Örnek gerçek formatlı program, elle maçları tekrar yazmadan günlere yerleşir; hatalı satırlar düzeltilebilir; aynı dosya tekrarında mükerrer oluşmaz; yayımlama sonrası kulüp ve mobil aynı programı görür; sonraki program değişikliği ilgili kişilere doğru yansır.

## İşlev listesi

Etiketler bu belgedeki öneri sırasıdır. Özellikler mevcut işlevleri genişletebilir. Uygulamaya geçişte her maddenin mevcut kapsamı yeniden karşılaştırılır.

### Federasyon çalışma masası

**Beklenen sonuç:** Masaüstünü açınca hangi işin beklediğini görüp doğrudan tamamlayabilmek.

- [ ] **ÜR-001** — Bugünün müsabakaları, atanmayı bekleyen görevler ve sonucu beklenen maçlar tek açılış ekranında.
- [ ] **ÜR-002** — Yetkili olunan federasyon, branş, sezon ve ilin üstte görünür seçimi.
- [ ] **ÜR-003** — Her sayaca tıklayınca ilgili filtrelenmiş iş listesine geçiş.
- [ ] **ÜR-004** — Son tarihi yaklaşan başvurular ve eksik evrakların ayrı iş listesi.
- [ ] **ÜR-005** — İl temsilciliği, MHK, tescil ve kurul işleri için göreve uygun başlangıç görünümü.
- [ ] **ÜR-006** — Yetkili personelin bir işi üstlenmesi, devretmesi ve bekleme nedenini belirtmesi.
- [ ] **ÜR-007** — Son yapılan takvim/yayın değişikliklerinin anlaşılır etkinlik akışı.
- [ ] **ÜR-008** — Kaydedilmiş görünümler: örneğin İzmir U16 basketbol, bu hafta, hakemi eksik.

### PDF / Excel takvim içe aktarma

**Beklenen sonuç:** Federasyonun elindeki mevcut programı tekrar yazmadan sistemde kullanılabilir takvime dönüştürmek.

- [ ] **ÜR-009** — PDF, XLSX ve CSV dosyasını İçeri Aktar alanına bırakabilme; dosya türüne uygun okuma.
- [ ] **ÜR-010** — PDF'den tarih, gün, saat, branş, kategori, takımlar ve tesis bilgisini satırlara çıkarma.
- [ ] **ÜR-011** — Metin içermeyen taranmış PDF'yi tanıyıp OCR ile okuma; ilk sürümde destek sınırını açık gösterme.
- [ ] **ÜR-012** — Kaynak PDF solda, çıkarılan program sağda olacak şekilde sayfa/satır karşılaştırması.
- [ ] **ÜR-013** — Gün/ay/yıl belirsizliğinde sezon ve tarih biçimini kullanıcıya bir kez seçtirme.
- [ ] **ÜR-014** — Resmi kulüp/takım adlarıyla kısaltmaları eşleştirme; belirsiz isimleri kullanıcıya seçtirme.
- [ ] **ÜR-015** — Salon/saha adını gerçek tesis kaydına eşleştirme; bilinmeyen tesisi metinden kesin müsait saymama.
- [ ] **ÜR-016** — Tarih-saat eksikliği, aynı takımın eşzamanlı maçı ve tekrar satırlarını işaretleme.
- [ ] **ÜR-017** — İçe aktarım öncesi düzenlenebilir tablo ve takvim önizlemesi; hatalı satırları ayrı filtreleme.
- [ ] **ÜR-018** — Seçilen doğrulanmış satırları tek işlemle resmi takvim taslağına aktarma; herkese yayın ayrı adım.
- [ ] **ÜR-019** — Aynı dosya veya düzeltilmiş PDF tekrar yüklendiğinde yeni/değişen/aynı satır farkını gösterme.
- [ ] **ÜR-020** — İçe aktarım geçmişinden kaynağa ve oluşturulan kayıtlara ulaşma; yayımlanmış değişiklikleri düzeltme/iptal sürecine bağlama.

### Müsabaka takvimi ve toplu planlama

**Beklenen sonuç:** Fikstürü yalnız okumak yerine günlük çalışma ekranında düzenlemek.

- [ ] **ÜR-021** — Aylık, haftalık, günlük, liste ve tesis bazlı takvim görünümleri.
- [ ] **ÜR-022** — Maçı sürükleyerek gün/saat değiştirme; değişikliği taslakta önizleyip etkilenen tarafları gösterme.
- [ ] **ÜR-023** — Çoklu maç seçerek tarih, saat, tesis veya haftayı birlikte değiştirme.
- [ ] **ÜR-024** — Saat çakışması ve aynı takımın yetersiz dinlenme aralığını görünür uyarıya dönüştürme.
- [ ] **ÜR-025** — Ertelenen maçlar için tarihsiz bekleyenler alanı ve yeniden planlama.
- [ ] **ÜR-026** — Yağış/tesis kapanması gibi durumda belirli gün veya tesisteki maçları topluca erteleme.
- [ ] **ÜR-027** — Takvim değişikliklerinde önce/sonra görünümü ve ilgili kulüplere değişiklik özeti.
- [ ] **ÜR-028** — Seçili lig/il/hafta için yazdırılabilir PDF ve Excel program çıktısı.

### Sezon, lig ve fikstür kurma

**Beklenen sonuç:** Bir organizasyonu baştan sona masaüstünden kurabilmek.

- [ ] **ÜR-029** — Sezon → branş → yaş/kategori → lig/turnuva → katılımcı adımlarını bağlayan sihirbaz.
- [ ] **ÜR-030** — Katılım başvurusu, eksik bilgi isteme ve kabul/red iş listesi.
- [ ] **ÜR-031** — Grup, devre, tur, saha ve müsait gün tercihleriyle fikstür taslağı üretme.
- [ ] **ÜR-032** — Tek/çift devre ve eleme formatlarını açık seçimle oluşturma.
- [ ] **ÜR-033** — Kura sonuçlarının kaydı ve önceki taslağı karşılaştırma.
- [ ] **ÜR-034** — Tatil, sınav dönemi ve kulüplerin bildirdiği kapalı günleri planlamada kullanma.
- [ ] **ÜR-035** — Fikstür yayını öncesi son kontrol ve kulüplerin programı inceleyebileceği önizleme.
- [ ] **ÜR-036** — Önceki sezonun yapısını kopyalarken sonuç ve tarihsel kararları taşımama.

### Tesis ve salon planlama

**Beklenen sonuç:** Programı gerçek tesis, süre ve işletici onayıyla bağlamak.

- [ ] **ÜR-037** — Tesisleri sütun, saatleri satır gösteren doluluk panosu.
- [ ] **ÜR-038** — Maça tesis önerisi ve tesis sahibi yetkiliden tahsis/onay isteme.
- [ ] **ÜR-039** — Kesin tahsis, talep, reddedilen ve bekleyen durumların ayrı görünmesi.
- [ ] **ÜR-040** — Branş uyumu, kapasite ve saha bölümü gibi planlamayı etkileyen özellikler.
- [ ] **ÜR-041** — Bakım/kapalı saat ve müsabaka öncesi-sonrası hazırlık aralığı yönetimi.
- [ ] **ÜR-042** — Tesis değişince program, görevliler ve kulüp duyurusunu aynı akıştan güncelleme.

### MHK ve görevli yönetimi

**Beklenen sonuç:** Haftanın bütün görevlerini tek masada planlamak.

- [ ] **ÜR-043** — Haftalık maç × görev matrisi; eksik görevlerin doğrudan görünmesi.
- [ ] **ÜR-044** — Hakem müsaitlik ve mazeret takvimi; göreve önerilmeden önce durumu görme.
- [ ] **ÜR-045** — Lisans, branş, klasman ve tanımlanmış atama kurallarına göre aday filtreleme.
- [ ] **ÜR-046** — Saat, seyahat ve tanımlanmış çıkar çatışması uyarıları.
- [ ] **ÜR-047** — Toplu atama taslağı ve yetkilinin kontrolünden sonra görevleri gönderme.
- [ ] **ÜR-048** — Görevi kabul etmeyen veya yanıtlamayan kişiye alternatif önerme.
- [ ] **ÜR-049** — Görev değişikliğinin eski/yeni kişiye ve ilgili müsabakaya açık yansıması.
- [ ] **ÜR-050** — Hakem görevlendirme yazısı, haftalık görev listesi ve kişisel görev çıktısı.

### Tescil, lisans ve transfer masası

**Beklenen sonuç:** Başvuruyu farklı ekranlarda aramadan tamamlamak.

- [ ] **ÜR-051** — Kulüp tescili, lisans/vize ve transfer için ayrı iş kuyrukları.
- [ ] **ÜR-052** — Başvuruda tamamlanan/eksik belge ve inceleme notlarının tek dosyada toplanması.
- [ ] **ÜR-053** — Kulüpten düzeltme isteme; başvuru sahibine hangi alanın neden eksik olduğunu gösterme.
- [ ] **ÜR-054** — Toplu başvuru incelemesinde yalnız uygun kayıtları seçip karar verebilme.
- [ ] **ÜR-055** — Transferin kaynak/hedef/aile adımlarını ve yetkili son kararını aynı zaman çizelgesinde görme.
- [ ] **ÜR-056** — Karar sonrası lisans, kulüp kaydı ve ilgili bildirimlerin sonucunu tek tamamlanma ekranında görme.

### Disiplin dosyası

**Beklenen sonuç:** Ceza formundan bütün bir dosya sürecine geçmek.

- [ ] **ÜR-057** — Rapor → sevk → savunma → kurul incelemesi → karar → tebligat → itiraz akışı.
- [ ] **ÜR-058** — Sporcu yanında kuralları tanımlanmış antrenör/görevli hedefi desteği.
- [ ] **ÜR-059** — Dosya ekleri, taraf yazıları ve görüşme geçmişini yetkili dosya görünümünde toplama.
- [ ] **ÜR-060** — Karar şablonları, ilgili kural/madde seçimi ve açık yürürlük tarihi.
- [ ] **ÜR-061** — İtiraz kararı veya düzeltmeyi önceki kaydı silmeden yeni işlem olarak bağlama.
- [ ] **ÜR-062** — Özel dosyadan ayrı hazırlanıp kontrol edilen kamu bülteni önizlemesi.

### Maç dosyası ve sonuç merkezi

**Beklenen sonuç:** Bir maçla ilgili işleri tek ayrıntı sayfasında bitirmek.

- [ ] **ÜR-063** — Maçın program, tesis, görevliler, esame, canlı olay, rapor ve sonuç sekmeleri.
- [ ] **ÜR-064** — Sonuç bekleyen, raporu eksik, incelemede ve yayımlanmış müsabakaları ayrı listeler.
- [ ] **ÜR-065** — Hakem raporundan gelen sonucu önceden doldurma; yetkili kişi farkları görüp tescil eder.
- [ ] **ÜR-066** — Bütün desteklenen branşlarda masaüstü ve mobil sonuç kapsamının açık ve tutarlı olması.
- [ ] **ÜR-067** — Bireysel branşlarda Excel derece/seri/kulvar içe aktarma ve hatalı satır düzeltme.
- [ ] **ÜR-068** — Eski/yeni sonuç karşılaştırması ve hangi tablo/sicilin etkileneceğinin önizlemesi.
- [ ] **ÜR-069** — Hükmen sonuç, yarıda kalma ve yeniden oynama için branşa uygun karar akışları.
- [ ] **ÜR-070** — Onaylı maç dosyası ve sonuç cetvelinin PDF çıktısı.

### Lig tablosu ve branş kuralları

**Beklenen sonuç:** Tablonun federasyonun gerçek organizasyon kuralını uygulaması.

- [ ] **ÜR-071** — Puan, sıralama ve eşitlik kurallarını organizasyon kurulurken görünür seçme.
- [ ] **ÜR-072** — Grup bazlı tablo ve gruptan çıkma durumunu birlikte gösterme.
- [ ] **ÜR-073** — İkili/çoklu averaj ve set puanı gibi organizasyona özgü kuralları destekleme.
- [ ] **ÜR-074** — Puan cezasının hangi karara dayandığını yetkili görünümde gösterme.
- [ ] **ÜR-075** — Playoff/eleme ağacı ve üst tura çıkma görünümü.
- [ ] **ÜR-076** — Canlı geçici tablo ile tescilli kesin tabloyu anlaşılır ayırma.

### Yayın, duyuru ve resmi yazışma

**Beklenen sonuç:** Federasyonun yaptığı değişikliği tek yerden kulübe ve kamuya ulaştırmak.

- [ ] **ÜR-077** — Takvim, fikstür, sonuç ve disiplin bültenlerini tek yayın merkezinde yönetme.
- [ ] **ÜR-078** — Haftalık bülteni seçili maç ve kararlardan otomatik taslak oluşturma.
- [ ] **ÜR-079** — Erteleme/iptal duyurusunu doğrudan ilgili maçtan hazırlama.
- [ ] **ÜR-080** — Kulüp/il/kategori bazlı hedef kitle ve gönderim önizlemesi.
- [ ] **ÜR-081** — Yayın sonrası önceki sürüme, düzeltmeye ve ilgili kayda ulaşma.
- [ ] **ÜR-082** — Mobil, web ve indirilebilir PDF'de aynı yayımlanmış veriyi kullanma.

### Belge, arşiv ve federasyon raporları

**Beklenen sonuç:** Masaüstünden gerçek belge üretmek ve geçmişe kolay erişmek.

- [ ] **ÜR-083** — Kurum başlığı/logosu ve numarasıyla maç programı, görevlendirme ve karar belgesi şablonları.
- [ ] **ÜR-084** — Sezon/il/lig/tarih/evrak türüyle arama yapılabilen yetkili arşiv.
- [ ] **ÜR-085** — PDF/Excel çıktısında uygulanan filtrelerin başlıkta görünmesi.
- [ ] **ÜR-086** — Takvim doluluğu, eksik görevlendirme ve bekleyen sonuçları gösteren operasyon raporu.
- [ ] **ÜR-087** — Hakem görev yükünü tarih/branş/il kapsamında karşılaştırma.
- [ ] **ÜR-088** — Kulüp katılımı ve sezon ilerleyişini gerçek kayıtlarla gösterme.

### Kulüp masaüstünde ürün genişletmeleri

**Beklenen sonuç:** Kulüp personelinin yoğun veri girişini kolaylaştırmak.

- [ ] **ÜR-089** — Excel kadro aktarımında sütun eşleme, mükerrer kontrolü ve kayıt önizlemesi.
- [ ] **ÜR-090** — Sporcu dosyasında takım, veli, belge, devam ve resmi geçmişi yetkiye göre birleştirme.
- [ ] **ÜR-091** — Sezon açılışını kadro, program ve aidat taslağıyla tek hazırlık alanına toplama.
- [ ] **ÜR-092** — Toplu veli daveti ve eksik belge istemeyi seçili kadro üzerinden yürütme.
- [ ] **ÜR-093** — Antrenörün haftalık programını tesis ve takım çakışmalarıyla hazırlaması.
- [ ] **ÜR-094** — Aidat durumunu doğru alıcıya bağlayan veliye özel hatırlatma ve ödeme özeti.
- [ ] **ÜR-095** — Malzeme teslim/iade işlerini sporcu/personel dosyasından da başlatma.
- [ ] **ÜR-096** — Federasyon talepleri ve kulübün yanıt beklediği işleri ortak başvuru kutusunda görme.

### Mobilde günlük kullanım genişletmeleri

**Beklenen sonuç:** Veli, sporcu ve antrenörün masaüstünde hazırlanan işlere kolay yanıt vermesi.

- [ ] **ÜR-097** — Veli için bugünkü çocuk programı, yanıt ve son tarihlerin tek kısa akışı.
- [ ] **ÜR-098** — Program değiştiğinde eski/yeni saat ve gerekiyorsa yeniden katılım yanıtı.
- [ ] **ÜR-099** — Sporcu için kişisel antrenman/maç takvimi ve izinli gelişim karnesi.
- [ ] **ÜR-100** — Antrenörün bugünkü kadro, yoklama ve seans notuna tek yerden ulaşması.
- [ ] **ÜR-101** — Belge eksiğini açıklayan görev kartından doğrudan ilgili yüklemeye geçiş.
- [ ] **ÜR-102** — Kulüp/federasyon başvurusunun kimde beklediğini anlaşılır adımlarla takip etme.
- [ ] **ÜR-103** — Maç ve kulüp takibinde yalnız başlangıç/sonuç gibi tercihleri ayrı seçebilme.
- [ ] **ÜR-104** — Resmi takvimde favori lig/takım/branşı kaydedip sonraki ziyarette aynı görünümü açma.

## Teslimat sırası — her aşama kullanılabilir bir iş bitirir

| Teslimat | Kullanıcının elde edeceği sonuç | İlgili işler |
| --- | --- | --- |
| 1. Federasyon takvim masası + dosyadan program | Bir örnek gerçek program dosyası okunur, kontrol edilir, günlere yerleşir ve yayımlanır. Ortak maç ayrıntısının temel hali ve gerekli lig/kapsam seçimi bu teslimata dahildir. | PDF/Excel içe aktarma; temel çalışma masası; maç ayrıntısı |
| 2. Gerçek planlama ekranı | Kullanıcı programı takvimde düzenler, toplu erteleme yapar, tesis talebi ve kulüp duyurusunu tamamlar. | Takvim, tesis ve duyuru akışları |
| 3. Haftalık MHK masası | Haftanın maçlarına müsait görevliler atanır; ret/yanıtsız görevler tamamlanır; görev yazıları alınır. | MHK matrisi, müsaitlik ve görev çıktıları |
| 4. Organizasyon kurma ve başvuru masası | Sezon/lig hazırlanır; katılımcılar, lisans/vize ve transfer işleri dosyadan sonuçlandırılır. | Lig sihirbazı, tescil ve transfer |
| 5. Müsabaka ve kurul dosyası | Rapor, tescil, karar/itiraz ve kamu bülteni ilgili maçtan tamamlanır. | Sonuç merkezi, disiplin ve yayın |
| 6. Branş derinliği ve kurumsal raporlar | Gerçek lig kuralları, bireysel derece aktarımı, arşiv ve belge şablonları tamamlanır. | Puan/eleme kuralları, çıktı ve rapor |
| 7. Kulüp ve mobil devamı | Federasyonun başlattığı işler kulüp, veli ve sporcu tarafında anlaşılır yanıt akışına dönüşür. | Kulüp masaüstü ve mobil genişletmeleri |

Süre tahmini uygulama planında yapılır; PDF örnekleri ve ilk hedef branş görülmeden gün/hafta taahhüdü verilmez. İlk hedef, bir federasyonun bir ilde bir lig programını dosyadan yönetebilmesidir; ülke çapında bütün branşları aynı anda tamamlamak ilk teslim şartı değildir.

## Ürün tutarlılığı kuralları

- Bir maç; takvimde, hakem görevinde, kulüp ekranında ve sonuçta aynı müsabaka olarak yaşar.
- Resmi programı genel kulüp etkinliği olarak ikinci kez üretme; mevcut resmi kayıtlar kullanılır.
- Aynı il/branş/sezon seçimi ekrandan ekrana unutulmaz.
- Listede görülen soruna tıklanınca çözümün yapılabildiği ekran açılır.
- Toplu işlemden önce etkilenecek kayıtlar; sonrasında tamamlanan ve tamamlanmayanlar görünür.
- Kullanıcı “yayımla” dediğinde hedef kitle ve oluşacak görünüm anlaşılırdır.
- Bir tabloyu filtrelemek veri/işlem yetkisi vermez; görev kapsamları korunur.
- Ortak masaüstü deneyimi, her sporun skor/format kurallarını aynı sayısal kalıba zorlamaz.
- Okundu, teslim, kabul, resmi onay ve hukuki izin farklı ürün durumlarıdır.
- Yeni ekran, mevcut servisi ve iş kaydını tamamlar; paralel takvim/sonuç/tescil defteri kurulmaz.

## Bu planın dışında tutulanlar

Önceki teknik envanterdeki test, SDK, CI, yayın, imza ve operasyon kontrol listesi burada tekrar edilmedi. Bu belge bir uygulama başlatma veya canlıya yazma talimatı değildir; ürün kapsamı ve kullanıcı akışı planıdır. Kod ve canlı sistem bu çalışmada değiştirilmedi.

