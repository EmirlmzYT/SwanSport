# Güvenilirlik temeli uygulama planı

> **For agentic workers:** Use superpowers:executing-plans; execute sequentially and verify each deliverable.

**Goal:** Hesap silme hatasını kapatmak, testleri tekrar üretilebilir yapmak ve yayın/kabul durumunu açıkça izlemek; bildirim teslimini güvenilirleştirmek.
**Architecture:** Eski migration'lar korunur. İlişkisel yaşam döngüsü ve push takibi yeni migration'larla eklenir. Var olan notifications, push tercihi ve gizlilik kapıları korunur. Test bağımlılıkları tools altında kilitlenir; CI tam Flutter ve SQL/JS kontrollerini çalıştırır.
**Tech Stack:** Flutter/Dart, PostgreSQL/Supabase, Cloudflare JavaScript, Node test/PGlite, Python/pglast.
**Spec:** Kullanıcının 2026-10-25 analizdeki ilk paketi onayı; Ana Sayfa görünümü ve sosyal spor ağı odağı korunur.

## Global Constraints
- Ana Sayfa, ortak gezinme ve sosyal görünüm değiştirilmez.
- Başlangıçtaki commit edilmemiş işler korunur; canlı SQL/deploy ve gerçek kişilere test bildirimi yok.
- RLS, muhasebeci/çocuk gizliliği ve mevcut bayrak kapıları korunur.
- Yeni migration CLI ile oluşturulur; eski kaynaklar yeniden yazılmaz.
- Fiziksel cihaz/gerçek kullanıcı kabulü otomatik test diye sunulmaz.

## Review Focus
- Hesap silme başka kişinin videosunu, sporcu kaydını veya mali/resmi geçmişini silmemeli.
- Tek aktif kulüp yöneticisinin silinme engeli ve yetkisiz çağrı reddi korunmalı.
- Push tekrarları başarılı cihazlara ikinci bildirim üretmemeli; belirsiz teslim kesin başarısız sayılmamalı.
- Eski hesaba ait cihaz yeni hesaba geçtiyse eski teslim cihazı silmemeli veya yeni hesaba özel içerik göndermemeli.
- CI eksik bağımlılık/başarısız SQL parse durumunda gerçekten başarısız olmalı.

## Tasks
- [x] 1. tools/package.json + lock ve Python requirements ile PGlite/pglast kurulumunu sabitle; build importlarını paket importuna çevir.
- [x] 2. Hesap silme regresyonunu gerçek 0132 tablo tanımları/eski RPC ile önce kırmızı çalıştır; yeni migration ile bağlı kayıt yaşam döngüsünü düzelt; tek yönetici/anon/başka hesap/geçmiş koruma testlerini geçir.
- [x] 3. Genel revizyon testlerini güncel header/aktif üyelik sözleşmesine uyumla; mesaj silme tipografisini mevcut SwanType jetonuna geçir. Ana Sayfa kaynakları değişmez.
- [x] 4. Push sonuçlarını izleme, güvenilir token sınıflandırması ve sınırlı tekrar davranışını testle ekle; ACL/tercih/hesap devri/çift teslim sınırlarını doğrula.
- [x] 5. CI tam mobil/konsol/paket testleri, SQL/JS, Python kapıları ve web derlemelerini kapsasın; bağımlılıklar kilitli olsun.
- [x] 6. Sürüm matrisi üretimi ve gerçek rol/cihaz kabul kayıt şablonu ekle; üretim durumu bilinmeyen alanları açıkça bilinmiyor olarak tut.
- [x] 7. İlgili tam regresyon, analiz ve web derlemelerini çalıştır; bağımsız salt okunur son inceleme; doğrulama raporu ve vardiya defteri güncellemesi.

## Execution notes
- Mevcut çalışma alanındaki kullanıcı revizyonları test edilen kaynağın parçasıdır; başka checkout'a taşınmayacak ve bu görev dışında commit edilmeyecek.
- Gerçek kulüp/cihaz kabulü için senaryolar ve otomatik karşılıkları hazırlanacak; fiziksel test sonucu uydurulmayacak.
