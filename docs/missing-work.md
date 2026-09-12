# SwanSport eksik işler

Bu liste test çalıştırmalarını içermez; ürün ve operasyon işlerini takip eder.

## Kullanıcıya açılmadan önce

- RSS haber görsellerini gerçek cihazda kontrol et; `swanspor.pages.dev` köprüsü ve `/api/rss-image` proxy'si kullanılıyor.
- Çevrimdışı yoklama akışını uygulamaya al: kuyruk deposu, `op_id` idempotency, sürüm çakışması uyarısı ve hata ekranı.
- Tesis rezervasyon veri modelini ekle; tesis çakışması şu an hesaplanamıyor.
- SSS yönetim ekranını konsola ekle; içerik şu an doğrudan veritabanından yönetiliyor.
- Ölü push token'larını 404/410 yanıtında pasifleştirip temizle.

## Canlı hesap ve dağıtım işleri

- Android FCM servis hesabını uygulamanın kullandığı Firebase `swanspor` projesiyle eşleştir.
- Release keystore oluşturup güvenli biçimde `android/key.properties` ile bağla.
- Halı saha ekleme, yönetici daveti ve doluluk akışını gerçek verilerle kullanıma al.
- `0039` ve `0040` migration'larının canlı kurulumunu ve sohbet rezervasyon isteğini tamamla.
- Online ödeme sağlayıcısı, KVKK metni ve Supabase e-posta doğrulama ayarını tamamla.

## Ürün kapsamı

- Çevrimdışı yoklama bayrağını kapalıdan açmadan önce veri kaybı ve çakışma kararlarını netleştir.
- Antrenman oturum motorunu gerçek hesaplarla doğruladıktan sonra yayın kademesini yükselt.
- Muhasebeci görünümünü ayrı bir muhasebeci hesabıyla kontrol et; sporcu adlarının RPC'lerden sızmadığını koru.
- Kort partner araması için farklı kulüp/şehir/branş senaryolarını çalıştır.
- Tesis bakım, rezervasyon ve gelir ilişkisini finans raporlarına bağla.
