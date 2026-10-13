# Faz 5 — Kulüp ihtisas operasyonları: yerel doğrulama

Tarih: 2026-10-14. Canlı migration, deploy, commit veya push yapılmadı.

## Kapsam

- 0114, stok ve zimmet tablolarını dar RLS ile açar. Yazılar yalnız yetkili RPC üzerinden, stok satırı kilidi ve atomik audit ile gerçekleşir. Aynı işlem kimliğiyle tekrar stok tüketmez; hasarlı/kayıp iade yalnız bir kez düşülür.
- İhtisas rolü aktif kulüp üyeliğiyle birlikte değerlendirilir. Muhasebeci tek başına envanter, zimmet veya sporcu verisi okuyamaz; operasyon projeksiyonları üye/sporcu referanslarını maskeler.
- SwanAccess sunucudan gelen kulüp operasyon yetkilerini tek kaynak olarak kullanır. Mobil Profil > Yönetim ve masaüstündeki envanter, sağlık ve sportif planlama ekranları bu kapsama ve `club_staff_operations` bayrağına bağlıdır. Bayrak başlangıçta `admins` seviyesindedir.
- Doktorsuz kulüpte idari dinlendirme korunur. İdari kaldırma tıbbi kilidi kaldırmaz. Tıbbi açma/kaldırma mevcut sağlık yetkisine bağlıdır; doktor etiketi tek başına yeterli değildir. Teşhis veya özel doktor notu eklenmez.
- İdari dinlenme yeni esame ve canlı oyuncu değişikliğinde sunucuda denetlenir; farklı branş lisansı eski ana lisansın süresinin dolması üzerinden bu kilidi aşamaz.
- Sportif planlama mevcut takım, lisans, yoklama ve gelişim raporu sözleşmelerini kullanır. Genel performans/sağlık okuma yetkisi genişletilmez. Konsolda 900px koruması ve mobilde beş alt sekme korunur.

## Kontroller

- `python tools/check_migrations.py`: 114 dosya, sıfır parse hatası.
- `python tools/check_faq.py`: 41/41.
- `python tools/check_push_routes.py`: 41 eşleme, kayıp yok.
- `python tools/check_mobile_ui_tokens.py --syntax`: 563 Dart dosyası, sıfır syntax hatası; 17/17 kaynak jeton sözleşmesi temiz.
- SQL regresyonu `node --test tools/club_staff_operations_sql_test.mjs`: **74/74 geçti** (68 mevcut ve altı yeni senaryo). Yeni senaryolar stok/idempotence, aktif ihtisas/sağlık, sportif kapsam, audit rollback, muhasebeci/RLS ve idari-medikal kilit ayrımını kapsar.
- Mission Control SQL regresyonu **5/5 geçti**. `git diff --check` temizdir.
- 12 yeni Dart/widget senaryosu hazırdır. Flutter/Dart SDK bu ortamda bulunmadığından **test/analyze/build/format çalıştırılamadı**. Syntax kontrolü typecheck veya widget doğrulaması değildir.

## Açık sınırlar / üretim kabulü

- Transfer talebi iş akışı mevcut şemada yoktur. Ekran bunu açıkça belirtir ve yalnız mevcut tamamlanmış resmi transfer kayıtlarını gösterir; talep kuyruğu uygulanmış sayılmaz.
- İade zimmet satırının tüm miktarı içindir. Kısmi iade, onarım, stok artırma ve emekliye ayırma düzenleme ekranları bu teslimde yoktur.
- Gönderilmemiş veya sonucu belirsiz işlemin yeniden deneme taslağı RAM'dedir; çevrimdışı/güç kaybı kalıcılığı garanti edilmez.
- Yeni uygunluk kontrolü mevcut kilitli esameyi yeniden yazmaz, daha önce katılmış sporcuyu otomatik çıkarmaz.
- Envanter okuması sunucu sayfalaması olmadan çalışır; büyük kulüp yük testi gereklidir.
- PGlite testleri tek bağlantılıdır. Gerçek iki oturumlu yarış, PostgREST/RLS, rol iptali sırasında işlem, cihaz ve görsel taşma UAT'si yapılmadı. Global operasyon kilidinin üretim yükü ayrıca ölçülmelidir.
- Flutter SDK ile data/app/console testleri, analyze ve Web/cihaz derlemeleri geçmeden tam üretim kabulü verilmez.
