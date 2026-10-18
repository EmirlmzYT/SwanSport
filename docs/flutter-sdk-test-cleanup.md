# Flutter SDK test temizliği — 2026-10-17

Flutter 3.47.7 / Dart 3.13.5 ile daha önce yalnız syntax kontrolü yapılmış
kaynaklar gerçek test derleyicisinde çalıştırıldı. Canlı SQL, yayın, commit,
push veya IPA/APK üretimi yapılmadı.

## Düzeltmeler

- Scroll testi gerçek BuildContext kullanır. Alt gezinmenin Tooltip'i uzun
  basış seçimini yutmaz; beş hedef, dokunuş ve hesap kapıları korunur.
- Lig seçici ve tablo kardeşlerinde anahtarlar ayrıdır. Rezervasyondaki
  CheckboxListTile kendi Material yüzeyinde doğru ink alır.
- Branş sheet'i aktif kulübün yüklenmesini bekler, başarısız kaydı korur;
  başarılı pop, PopScope güncellendikten sonra gerçekleşir.
- Mesaj ekranı fixture/dispose durumunda servis başlatmaz; kanal üyeliği
  yenileme hatası mevcut sohbet listesini düşürmez. Pazaryeri kartı yalnız
  gerçekten gerektiğinde servisi kurar.
- Hakem rol sağlayıcıları AsyncValue yüklenme zarfı yerine Session değerini
  izler: null → null geçişi bekleyen Future'ı boşa çıkarmaz; hesap değişimi
  ve token yenilemesi yeniden değerlendirilir. SwanAccess/RLS değişmedi.
- Takip göstergesi oturumsuzken false döner. Maç takip düğmesi hesap kapısı
  açıkken dönen spinner bırakmaz; opsiyonel haptic başarılı RPC'yi bekletmez.
- Widget testlerinin gerçek Supabase JSON isolate kurulumu/disposal'ı
  runAsync alanındadır; fixture Auth yenileme zamanlayıcısı kapalıdır.
  Riverpod dispose işleri test saatiyle açıkça tamamlanır.
- Haber kartı listede ölçülür; arama testleri EditableText ile aynı etiketi
  taşıyan gerçek satırı ayırır. Güncel başlıklar ve telefon normalizasyonu
  korunur; güvensiz URL, yetki, retry ve çocuk kapsamı testleri silinmedi.
- Kullanılmayan importlar, gereksiz null kontrolleri ve belirsiz generic
  çağrılar temizlendi. Stil/info önerileri topluca bastırılmadı.

## iOS kaynak sözleşmesi

Android ile birlikte iOS FCM desteği ve APNs token bekleme kapısı bağlıdır.
Info.plist arka plan modları, üç Xcode yapılandırmasında entitlement/APNs
ortamı ve GoogleService-Info.plist resource kaydı tamamlandı.
CI Firebase hazırlığını her iki derlemeden önce çağırır. Mevcut unsigned
sideload fallback'i açık uyarıyla korunur; sahte plist'in bundle kimliği
vardır. İmzalı build, gerçek Firebase secret yoksa dosya yazmadan durur.
Unsigned IPA/free Apple hesabı için fiziksel APNs teslimi iddia edilmez.

## Doğrulama

- Mobil tam Flutter koşusu: 480 test, sıfır hata.
- Ortak veri katmanı: 504 test, sıfır hata.
- Konsol: 82 test, sıfır hata.
- Branş motoru 197 ve core 26 test bu SDK ile geçti; bu paketler değiştirilmedi.
- Analiz: sıfır error, sıfır warning; 4213 mevcut info/stil önerisi kalır.
  `flutter analyze --no-pub --no-fatal-infos` ile kontrol edilir.
- Mobil syntax 609 dosya / 24 kaynak sözleşmesi, SSS 44/44, push 42 kayıpsız,
  genel senkronizasyon 5/5, iOS kaynak/config 5/5, push gönderici 5/5.
- Windows Developer Mode kapalı: pub get paketleri çözdü ama plugin symlink
  hazırlığı uyardı. Testler `--no-pub` ile çalışır. Android SDK/Xcode yok;
  Android/iOS build ve gerçek cihaz performans/teslim testi yapılmadı.

Yeni SDK'nın gerektirdiği bağımlılık çözümü pubspec.lock içinde tutulur;
bağımlılık sürüm yükseltme kampanyası veya canlı ortam değişikliği değildir.
