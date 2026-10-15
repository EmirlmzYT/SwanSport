# Yerel Test Merkezi

Bu merkez canlı hesapların yerine geçmez. Ayrı, yalnız bilgisayarda çalışan Supabase
üzerinde beş gerçek Auth hesabıyla uygulamanın mevcut ekranlarını açar. SQL kopyalama
ve her seferinde şifre yazma gerekmez. Canlı veritabanına veya yayına dokunulmaz.

## Kullanıcı için başlatma

Önce bir defa şu araçların kurulu olması gerekir:

- [Windows için Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/): kurup açın; Docker Engine çalışmalı.
- [Flutter SDK](https://docs.flutter.dev/install): `flutter --version` çalışmalı; Chrome kurulu olmalı.
- Node.js 20+: `node --version` çalışmalı.

Ardından **tools/Test-Merkezini-Ac.cmd dosyasına çift tıklayın**. Alternatif terminal komutu:

```powershell
node tools/start_local_test_center.mjs
```

Betik Supabase CLI 2.121.0'ı npx ile çağırır; ilk çalıştırmada Docker görüntüleri ve
Flutter paketleri indirilir. Birkaç dakika sürebilir. Başarıyla bittiğinde Chrome açılır:

- Uygulama: http://127.0.0.1:55430
- Yerel Supabase Studio: http://127.0.0.1:55423
- Yerel API: http://127.0.0.1:55421

“Yönetici olarak aç”, “Antrenör olarak aç”, “Sporcu olarak aç”, “Muhasebeci olarak aç”
ve “Taraftar olarak aç” düğmelerinden birini seçin. Her ekrandaki **Test Merkezi**
düğmesiyle geri dönüp diğer rolü deneyin. Beş alt sekme değiştirilmez.
Yönetici doğrudan kadroya, antrenör yoklamaya, sporcu aidatlarına, muhasebeci mali
işlere, taraftar akışa açılır; ilgili ekranı menülerde aramanız gerekmez.

Önkoşullar eksikse betik hiçbir DB başlatmadan bunları listeler. Bir hata olursa
pencere açık kalır; hata mesajını paylaşın. “Başarılı kurulum” görülmeden merkez
çalışıyor kabul edilmemelidir.

## Hazır veri ve kısa test sırası

1. Yönetici: `[TEST]` kulübünü, bir kişilik sporcu kadrosunu ve takvimi kontrol edin.
2. Antrenör: hazır antrenmanda yoklama alın; kaydedip geçmişten kontrol edin.
3. Sporcu: yalnız kendi kartını/aidatını kontrol edin; idari yazma yetkisi açılmamalı.
4. Muhasebeci: mali defterde sporcunun adı yerine anonim kod görünmeli; kadro açılamamalı.
5. Taraftar: akış/keşfet gezinmesini ve kulüp yetkilerinin bulunmadığını kontrol edin.

Bir yetişkin sporcu, bir takım/sezon, bir antrenman ve 1500 TL sentetik fatura hazırdır.
Antrenman ve fatura ilk kurulumda oluşturulur; sonraki açılışlar sizin düzenlemelerinizi
silmez. Tarihi geçmiş antrenmanı uygulamadaki takvimden düzenleyebilirsiniz.
Bu bir antrenman oturumu/maç/hakem/uçtan uca ödeme fixture'ı değildir.

## Güvenlik ve mimari

- Ayrı giriş noktası `lib/main_test_center.dart`; üretim varsayılan URL/anahtarını okumaz.
- UI: development + debug + açık opt-in + tam yerel adres birlikte gerekir.
- Veri servisi de `http://127.0.0.1:55421` dışını reddeder; uzak hedef parametresi yoktur.
- Gerçek Auth ile giriş yapılır, gerçek SwanAccess ve RLS kullanılır. Demo rolü temizlenir.
- Hesap değişimi veya giriş hatasında yeni, ebeveynsiz ProviderScope açılır; önceki
  kullanıcının kadro/finans/çevrimdışı sağlayıcı önbelleği yeni role taşınmaz.
- Kurulum sabit Docker konteyner adını ve CLI proje etiketini doğrular; uzak Docker
  context/DOCKER_HOST reddedilir. CLI status çıktısı ve service-role anahtarları yazdırılmaz.
- Yerel public anahtar Flutter'a verilir; service-role Flutter'a veya repoya yazılmaz.
- Migration'lar numara sırasında dosya başına transaction + 15s lock_timeout ile kurulur;
  yerel hash defteri değişmiş migration'ı sessizce yeniden uygulamaz. Test cron işleri kapatılır.
- `fixture.sql` yalnız yerel kurulum marker'ı varken çalışır. Sentetik kimlik/belge
  değerleri yalnız bu atılabilir backend'dedir; gerçek KPS/kimlik doğrulama kanıtı değildir.
  Normal inceleme RPC'si kullanılır, RLS/trigger/legacy kapıları kapatılmaz.
- Yerel fixture onayı için geçici admin yapılmış yönetici transaction bitmeden normal
  kulüp yöneticisine döner. Test kişileri kalıcı platform admini değildir.
- Canlıdaki önceki 45 hesap otomatik silinmez/banlanmaz. Onları kapatmak ayrı canlı işlemdir.

Docker portlarını internete yönlendirmeyin; yerel anahtarlar ve test parolaları sır değildir.
Kurulum dizini `tools/local-test-center` ayrı projedir; hiçbir `link`, `db push`,
uzak DB URL'si veya otomatik `db reset/volume delete` komutu yoktur.

Uygulamayı kapatmak için terminalde Ctrl+C kullanın. Backend'i verileri koruyarak durdurmak:

```powershell
npx --yes supabase@2.121.0 stop --workdir tools/local-test-center
```

`--no-backup` kullanmayın: yerel kayıtlar silinebilir. Sıfırlama otomatik yapılmaz.

Kurulum yaklaşımı: [Supabase resmi yerel geliştirme rehberi](https://supabase.com/docs/guides/local-development/cli/getting-started).

## Doğrulama sınırı

İzole PostgreSQL/C1 fixture ve JS güvenlik testleri, Dart syntax/token kontrolleri
çalıştırılabilir. Gerçek Docker/GoTrue, tüm 118 migration'ın gerçek Supabase imajında
kurulması, Flutter typecheck/widget/build ve Chrome UAT ayrıca doğrulanmalıdır.
Docker ve Flutter SDK olmayan bir bilgisayarda bunlar başarılı sayılmaz.

2026-10-16 yerel doğrulama: toplam 14 JS/PostgreSQL kontrolü (10 mevcut seed
regresyonu + 4 test merkezi kontrolü) geçti. Yerel fixture tekrar kuruldu; gerçek
temel RLS altında antrenör 1 sporcu okurken muhasebeci 0 satır gördü. 593 Dart
dosyasında syntax hatası yok; scoped mobil token kontrolü 24/24, SSS 44/44,
push 42 eşleme ve 118 migration parse temiz. İki Dart birim ve üç widget testi
hazırlandı, fakat Flutter SDK yokluğundan çalıştırılamadı. Başlatıcının gerçek
önkoşul denemesi Flutter SDK/Docker Desktop eksik mesajıyla exit 1 verdi; Docker
başlatma, Chrome, GoTrue ve gerçek Supabase migration uygulaması yapılmadı.
