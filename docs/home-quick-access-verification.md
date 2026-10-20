# Ana sayfa hızlı erişim — 2026-10-20

Ana akıştaki Hızlı erişim alanı en fazla dört hedef gösterir. Varsayılanlar
SwanAccess görevlerinden seçilir. Düzenle ve Ayarlar → Ana sayfa → Hızlı erişim
aynı editörü açar: ekleme, kaldırma, sürükleme/yukarı ok ile sıralama,
gizleme, varsayılana dönme ve açık Kaydet işlemi vardır. Kaydetmeden dönmek
tercihleri değiştirmez. Gizlenen alan Ayarlar üzerinden yeniden açılır.

Tercihler SharedPreferences içinde sürümlü hesap anahtarıyla yalnız bu cihazda
saklanır; cihazlar arası eşitleme yoktur. null seçim görev varsayılanlarını,
boş liste bilinçli boş seçimi temsil eder. Hatalı kayıt varsayılana döner.
Hesap değişimi farklı provider/editör state'i kullanır. Yazma başarısızsa
editör hata gösterir, kaydedilmemiş taslak korunur.

Katalog sunum katmanındadır; IconData veri paketine taşınmaz. SwanAccess ve
mevcut mobil rota projeksiyonu kullanılır; eski rota setinde bulunmayan
muhasebeci/veli/hakem/sporcu hedefleri kendi SwanAccess koşullarıyla süzülür.
Antrenman, veli, gelişim ve hakem hedefleri mevcut featureEnabledProvider
kapılarından geçer. Her render kayıtlı ID'leri güncel izinli katalogla kesiştirir;
kayıtlı kısayol yetki veya kapalı özellik açamaz. Muhasebecilik tek başına
yoklama/kadro/antrenman hedefi sunmaz. Yeni RPC, RLS veya yetki eklenmedi.

Ortak QuickActions kullanılır; ana sayfa tek ortak yüzeyde dört kompakt
ikon/etiket gösterir; dar ekran/büyük yazıda iki sütuna iner. Ayrı kart
çerçeveleri kaldırılmış, başlık body boyutuna indirilmiştir.
Kartlar ortak palet, tipografi ve biçim jetonlarını kullanır;
Material/InkWell klavye odağı ve button semantics sağlar. Eski rotalar ve
beş öğeli alt gezinme korunur.

## Doğrulama

- İlk odaklı hızlı erişim/gezinme/feed koşusu: 30/30 geçti.
- Son hızlı erişim koşusu: 10/10; ayrıca gerçek fontlarla açık/koyu widget
  renderı 2/2 geçti. 320px ve 1.6 metin ölçeği kontrolü dahil.
- Yerleşim devamında iki sütunlu hizalama sonrası 10/10 tekrar geçti;
  güncel yerel sayfada eşit kartlar ve yatay etiketler görsel olarak doğrulandı.
- Kompakt devamında 10/10 tekrar geçti; normal metin ölçeğinde tüm bölümün
  150px'i aşmaması doğrulandı. Yerel gerçek akışta dört hedefin tek yüzeyde
  aynı hizada görünmesi kontrol edildi.
- Mobil tam koşu: 583 geçti, 13 başarısız. Başarısız dosyalar:
  explore_layout_test (duyuru), mobile_ui_cleanup_test (ham token/rozet),
  mobile_glass_chrome_test ve reference_header_test (header beklentileri).
  Tam suite temiz değildir; bu çalışma bu ekranları değiştirmez. Başlangıç
  kaynağında ayrı karşılaştırmalı koşu yapılmadığından neden ataması yapılmaz.
- Değişen kaynak analizinde hata/uyarı yok; stil info önerileri vardır.
- 0132 SSS migration parse geçti. Mevcut 0069 faq_entries tablo tanımıyla
  izole PGlite PostgreSQL'de iki kez çalıştırıldı; tek aktif everyone satırı
  ve /settings hedefi doğrulandı. Canlı veritabanına uygulanmadı.
- Genel SSS denetimi federation_bulletin [admins] için yardım eşleştirme
  eksikliği raporluyor; bu görev özellik bayraklarını değiştirmez.
- Genel mobil token betiği değişmeyen profil/mesaj/sporcu/bildirim ekranları
  için 8 bulgu raporladı; bu kontrol de bütünüyle temiz değildir.
- Gerçek geliştirme web uygulaması localhost:8080 üzerinde derlenip tarayıcıda
  onboarding ekranına ulaştı. Canlı hesapla role göre uçtan uca kabul yapılmadı.
  Yeni iOS/Android paketi ve üretim yayını yoktur.

## Yerelde açma

apps/swansport_app dizininde:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 -t lib/main_development.dart --no-pub
```

http://127.0.0.1:8080 üzerinden hesabına giriş yapınca Ana Sayfa alanı görünür.
Bu geliştirme girişi mevcut compile-time backend ayarlarını kullanır.
