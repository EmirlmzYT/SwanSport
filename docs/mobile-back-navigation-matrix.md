# SwanSport mobil geri gezinme matrisi

Tarih: 2026-11-09  
Kapsam: `apps/swansport_app`

## Kaynak ve işaretler

Önceki “102 ekran” tablosu aktif checkout içinde dosya olarak bulunamadı.
Aktif `swansport_app.dart` yeniden ölçüldü: 82 statik rota, 28 açık dinamik
rota ve desenle çözülen Swan ID/maç/hakem rotaları var. Dosya adında `screen`
veya `page` bulunmayan hedefler de bu matrise dahildir.

- **A:** widget testiyle gerçekten açılıp geri davranışı çalıştırıldı.
- **S:** aktif kod, rota fabrikası ve ortak başlık üzerinden statik doğrulandı.
- **F:** fixture ekranı açıldı; gerçek ağ veya kullanıcı işlemi yapılmadı.
- **D:** fiziksel Android/web tarayıcı UAT gerektiriyor.

## Ortak davranış

| Giriş | Gezinme türü | Görünen kontrol | Beklenen dönüş | Kanıt |
|---|---|---|---|---|
| Uygulama içi push | Alt ekran | `Geri dön` | En yakın gerçek Navigator yığınında bir adım | A |
| Development doğrudan URL/yenileme | GoRouter + legacy bridge | `Geri dön` | Rota ailesinin güvenli üst hedefi | A |
| Production/Test Center doğrudan rota | Navigator 1 | `Geri dön` | Güvenli üst hedef; replacement ile döngüsüz | A |
| Android sistem geri | Mevcut geçmiş | Sistem hareketi | PopScope/taslak koruması yetkili kalır | A/D |
| Ana sekme kökü | Shell root | Alt sekme; geri oku yok | Mevcut shell davranışı | A |
| Modal/panel | Modal | `Kapat` veya `Vazgeç` | Modal sonucu korunarak kapanır | S/F |

## Ana ve özel akışlar

| Rota/giriş | Ekran türü | Üst hedef | Sonuç |
|---|---|---|---|
| `/`, `/auth`, `/landing` | Giriş/public kapı | Yok | S |
| `/rehber` | İlk kurulum | Akışın kendi çıkış sözleşmesi | S |
| `/demo-rol` | Geliştirme kapısı | Yok | S |
| `/akis`, `/kesfet`, `/mesajlar`, `/profil` | Ana sekme kökleri | Yok | A |
| zorunlu güncelleme | Uygulama kapısı | Güncelleme/çıkış sözleşmesi | S |
| yetki/hesap kapıları | Erişim kapısı | Önceki rota veya tanımlı CTA | S |

## Mesajlar ailesi

Her satır Development GoRouter, legacy Navigator ve ortak geri politikasıyla
eşleştirilmiştir.

| Rota | Giriş | Üst hedef | Sonuç |
|---|---|---|---|
| `/sohbet` | Mesaj listesi, profil, bildirim, doğrudan link | `/mesajlar` | A |
| `/topluluk` | Mesajlar/topluluk listesi, doğrudan link | `/mesajlar` | S |
| `/topluluklar` | Eski link/push | `/mesajlar` topluluk sekmesi | A |
| `/swan-asistan` | Mesajlar | `/mesajlar` | S |

## Keşfet ailesi

| Rota | Ekran/giriş | Üst hedef | Sonuç |
|---|---|---|---|
| `/ara` | Keşfet araması | `/kesfet` | A |
| `/bildirimler` | Üst bildirim erişimi | `/kesfet` | S |
| `/kulupler` | Keşfet -> Kulüpler | `/kesfet` | F |
| `/kulup-profil`, `/kulup-detay` | Liste/arama/bildirim -> kulüp | `/kesfet` | F |
| `/kortlar`, `/halisahalar` | Keşfet -> Sahalar | `/kesfet` | F |
| `/partner-ara`, `/oyuncu-aranan` | Keşfet -> Partner Bul | `/kesfet` | A/F |
| `/pazaryeri`, `/urun` | Keşfet -> Pazaryeri -> ürün | `/kesfet` | S |
| `/ilanlar`, `/ilan-ver`, `/magaza-basvuru` | Keşfet/pazaryeri | `/kesfet` | S |
| `/antrenor-bul` | Keşfet -> Antrenör bul | `/kesfet` | S |
| `/organizasyonlar` | Keşfet -> organizasyon | `/kesfet` | S |
| `/canli-skor`, `/canli-mac/:id` | Keşfet/push/deep link | `/kesfet` | S |
| `/federasyon`, `/federasyon-merkezi`, `/federasyon-takvimi` | Keşfet/push | `/kesfet` | S |
| `/swan-id/dogrula/:token` | QR/deep link | `/kesfet` | S |

## Profil ve operasyon ailesi

| Rotalar | Ekran/giriş | Üst hedef | Sonuç |
|---|---|---|---|
| `/hesap`, `/settings`, `/gizlilik` | Profil -> Ayarlar zinciri | `/profil` | S |
| `/kulup-yonetim`, `/kulup/malzeme-zimmet`, `/kulup/saglik-takibi`, `/kulup/kadro-planlama` | Profil yönetim | `/profil` | A/S |
| `/athletes`, `/sporcu-performans`, `/takim-kadro`, `/teams` | Yönetim/sporcu alanları | `/profil` | S |
| `/athlete-detail` | Sporcu listesinden veya doğrudan detay | `/athletes` | A |
| `/attendance`, `/devam-durumu`, `/calendar`, `/etkinlik-detay`, `/announcements`, `/communication-detail` | Operasyon/listeden detay | `/profil` | S |
| `/documents`, `/document-detail`, `/dogrulama` | Profil belgeleri | `/profil` | S |
| `/finans`, `/gider-ekle`, `/mali-isler`, `/aidatlarim`, `/ters-islem`, `/muhasebeci-defter` | Profil/mali işler | `/profil` | S |
| `/antrenmanlarim`, `/antrenman-oturumu`, `/antrenman-sonuc`, `/antrenman-sablonlari`, `/antrenman-olustur` | Profil/antrenman | `/profil` | S |
| `/facilities`, `/rezervasyon`, `/saha-islemlerim` | Profil/yönetim tesisleri | `/profil` | S |
| `/medical-center`, `/veli-izinleri`, `/veli-bagla` | Profil/sağlık/veli | `/profil` | S |
| `/performance-analytics`, `/hazirbulunusluk`, `/ekipman-tuning`, `/gelisim-raporu` | Profil/performans | `/profil` | S |
| `/performance-test-session`, `/performance-team-detail`, `/performance-development-plan`, `/performance-review-session` | Analitik detay | `/profil` | S |
| `/performance-match-detail`, `/performance-training-detail`, `/performance-position-detail` | Analitik detay | `/profil` | S |
| `/performance-test-session-editor`, `/performance-development-plan-editor`, `/performance-self-assessment-editor`, `/performance-review-session-editor` | Korumalı editör | `/profil`; taslak PopScope öncelikli | A/S |
| `/hakem/gorevler`, `/hakem/esame/:id`, `/hakem/canli/:id`, `/hakem/rapor/:id` | Profil/hakem push/deep link | `/profil` | S |
| `/kaydedilenler`, `/bagis`, `/basvurular`, `/yardim`, `/destek` | Profil kişisel işlemler | `/profil` | S |

## Genel/administratif hedefler

Bu eski hedeflerde özgül bir üst aile tanımlı değilse en az ayrıcalıklı güvenli
hedef `/akis` kullanılır. Normal uygulama içi girişte gerçek geçmiş her zaman
bu fallback'ten önce gelir.

| Rota | Hedef | Sonuç |
|---|---|---|
| `/home-command`, `/dashboard` | `/akis` | S |
| `/onay-paneli`, `/admin-user-detail`, `/federasyon-yetkili`, `/haber-kaynaklari` | `/akis` | S |
| `/configuration`, `/configuration-module`, `/sezon-acilisi`, `/reports`, `/report-detail` | `/akis` | S |
| `/sepet`, `/musabaka-simulasyonu`, `/liderlik`, `/beslenme`, `/yaris-detay` | `/akis` | S |
| `/mac-kartim/:id`, `/resmi-sonuc?...` | `/akis` | S |

## Modal ve diyalog envanteri

| Giriş | Kontrol | Veri kaybı davranışı | Sonuç |
|---|---|---|---|
| Yorumlar | Kapat ikonu | Gönderim/taslak durumu korunur | F/S |
| Gönderi oluşturma | Kapat + `Düzenlemeye devam et / Vazgeç` | PopScope ve dış kapanma aynı korumayı kullanır | A/S |
| Profil düzenleme | `Vazgeç / Bitti` | Kaydetmeden çıkış açık | F/S |
| Kulüp filtreleri | `Vazgeç / Sonuçları göster` | Uygulanmamış filtre taslağı atılır | F |
| Kulüp üyelik başvurusu | Modal geri/kapatma | Hatalı gönderimde metin korunur | A/F |
| Seçim ve onay diyalogları | `Vazgeç` ve anlamlı ana eylem | Modal dönüş değeri korunur | S |

## Uçtan uca zincirler

| Zincir | Statik | Otomatik | Fixture açılışı | Fiziksel UAT |
|---|---:|---:|---:|---:|
| Keşfet -> Arama -> ziyaretçi profili | geçti | kısmi | geçti | bekliyor |
| Bildirim -> ilgili içerik | geçti | mevcut rota testleri geçti | kısmi | gerçek push bekliyor |
| Mesajlar -> sohbet | geçti | geri fallback testi geçti | kısmi | bekliyor |
| Keşfet -> Partner Bul | geçti | doğrudan GoRouter testi geçti | geçti | bekliyor |
| Keşfet -> Sahalar | geçti | mevcut saha testleri geçti | geçti | bekliyor |
| Kulüpler -> kulüp detayı -> başvuru | geçti | 32 ilgili test geçti | geçti | bekliyor |
| Profil -> Ayarlar | geçti | mevcut rota testleri geçti | kısmi | bekliyor |

## Doğrulanamayanlar

- Fiziksel Android geri hareketi ve gerçek tarayıcı geçmişi bu çalışma
  ortamında cihaz/tarayıcı entegrasyon testi olmadan gözlenmedi; widget düzeyi
  `handlePopRoute`, GoRouter ve Navigator 1 yolları ayrı test edildi.
- Gerçek push, auth, kulüp başvurusu ve üretim verisi kullanılmadı.
- Yönetici/finans/hakem rotalarının çoğu erişim gerektirdiğinden kod ve rota
  fabrikası üzerinden statik doğrulandı; yetki yükseltilmedi.
