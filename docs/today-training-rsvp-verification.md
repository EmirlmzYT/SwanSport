# Bugünkü antrenman katılım kartı — 2026-10-20

Ana akışta hızlı erişimin altında, yalnız ilgili sporcu/veli hesabında ve
bugünkü planlı antrenman varsa kompakt bir kart gösterilir. Saat, varsa gerçek
bitiş saati, kulüp/çocuk ve yer bilgisi ile Katılacağım / Katılamayacağım
seçenekleri bulunur. Birden fazla antrenman varsa diğerleri açılabilir.
Yanıt önceden seçilmez; sunucu yenilemesi doğrulamadan başarı gösterilmez.
Kaydetme sırasında düğmeler kilitlenir; hata/çakışma durumunda kart korunur.

Tek kaynak mevcut events ve event_rsvps tablolarıdır. Takvim, veli merkezi ve
antrenörün RSVP özeti aynı yanıtı okur. Gerçek attendance kayıtları yazılmaz.
Events kaydı olmayan canlı antrenman oturumuna sahte bir plan/RSVP üretilmez.

## Yetki ve zaman

- 0133 my_today_training_rsvps yalnız Auth kullanıcısının aktif sporcu kaydı
  veya gerçek guardians ilişkisi üzerinden okur. Platform admin, antrenör veya
  muhasebeci olmak başkaları adına işlem açmaz.
- Bugün Europe/Istanbul günüdür; oturumun/device'ın zaman dilimi kullanılmaz.
  Yalnız training türü, aynı kulüp ve varsa gerçek takım üyeliği kabul edilir.
  Bitmiş antrenmanlar gizlenir; bitiş bilinmiyorsa süre uydurulmaz.
- Mevcut sport_training_sessions bayrağı SQL ve ekranda korunur. Veli yolu
  ayrıca mevcut parent_hub bayrağını ister; SSS aynı antrenman anahtarına bağlıdır.
- respond_today_training başlangıç saatini, scope'u, Auth'u ve bayrakları
  tekrar denetler. İlgili satır kilitleri sonrası deadline yeniden kontrol edilir.
  Yanıt değişikliği tam sunucu timestamp'i ile iyimser sürüm denetimi kullanır;
  sporcu/iki veli aynı kaydı sessizce ezemez. Aynı seçimi tekrar göndermek
  idempotent'tir. Eski not alanı korunur.
- PUBLIC/anon RPC izinleri kaldırılmıştır; event_rsvps doğrudan istemciye açılmaz.
- Provider 30 saniyede yenilenir. Kart, sunucu zamanını monotonic Stopwatch ile
  ilerletir; başlangıç sonrası düğmeler kaldırılır. Son söz sunucuya aittir.
- Snapshot hesap ID'siyle bağlanır; önceki hesaptan kalan AsyncValue yeni
  hesapta çizilmez. Geç yazma yanıtı yeni hesabın önbelleğini yenilemez.

## Doğrulama ve sınırlar

- 26 mobil odaklı test geçti: yeni kart (8), hızlı erişim, feed oturum ve
  modernizasyon regresyonları. Ek gerçek fontlu açık/koyu render 2/2 geçti.
- Veri/veli testleri 9/9 geçti: tipli yük, UTC dönüşümü, hassas timestamp
  korunması, dar RPC adları/parametreleri ve kapalı kaynağın okunmaması.
- 0133 gerçek 0001/0003/0033 şema kaynaklarıyla izole PostgreSQL/PGlite'da
  iki kez uygulandı; 5/5 senaryo geçti. Öz/veli/başkasının UUID'si, hesapsız
  çocuk, kulüp/takım, gün/tür/deadline, bayraklar, geçersiz durum, stale timestamp,
  idempotence, doğrudan tablo/anon ACL ve SSS tekilliği kontrol edildi.
- 0133 migration parse geçti. Değişen kaynak analizinde hata/uyarı yok;
  stil info önerileri bulunabilir. Yeni bütün proje regresyonu koşulmadı;
  önceki genel koşunun 13 kapsam dışı başarısızlığı hâlâ ayrı konudur.
- Genel SSS kontrolünün önceden görülen federation_bulletin [admins]
  eşleştirme eksiği bu görev kapsamında değiştirilmedi.
- Aynı anda iki gerçek GoTrue/PostgREST oturumuyla yarış testi ve gerçek
  sporcu hesabıyla canlı UAT yapılmadı. PGlite testleri bu kabulün yerine geçmez.
- **0133 canlı Supabase'e uygulanmadı.** Yerel web mevcut backend ayarlarını
  kullandığından gerçek hesapların yeni RPC'leri kullanması için migration'ın
  ilgili backend'e uygulanması gerekir. Yönetici hesabında örnek öğrenci veya
  sentetik antrenman eklenmez. Canlı veri/yayın değişikliği yapılmadı.

Görsel çıktılar (yalnız sentetik test verisi):
build/quick-access-verification/today-training-light.png ve today-training-dark.png.
Yeniden üretmek için mobil test dosyasını --dart-define=CAPTURE_TODAY_TRAINING=true
ile çalıştır.
