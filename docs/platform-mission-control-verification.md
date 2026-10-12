# Platform Mission Control — 0109

Yerel backend/veri temeli; ekran, abonelik satışı veya canlı yayın içermez.

## 2026-10-12 — İstemci entegrasyonu

Bu bölüm önceki backend fazının üzerine eklenen UI kapsamını anlatır.
Konsolda `/mission-control` platform-admin modülü ve beş sekme hazır:
marka/duyuru, komisyonlar, plan düzenleme/ekleme/aktiflik, şalterler/bayraklar,
son 50 audit satırı ve mevcut teşhis merkezi özeti. Her ayar kartı ayrı
kaydedilir; marka ve duyuru için atomik bir iki-ayar RPC'si yoktur.
Formlar doğrulanır; taslaklar sekme ve config yenilemesinde korunur.
Controller dispose, çift gönderim ve dispose sonrası async cevap koruması var.
Yeni paket insert kullanır: aynı kodlu paketi sessizce upsert ile ezmez;
var olan paket ID'siyle upsert edilir. Sunucu unique/RLS kuralları değişmez.

Mobil FeedScreen, misafir dahil bakım görünümünü platform admin dışına
uygular. Bu uygulama-geneli veya sunucu erişim kapısı değildir. Public config
aktif abonelik sırasında 30 saniyede bir yenilenir, timer dispose edilir;
pull-to-refresh de config'i yeniler. Yenileme hatasında son bilinen ayar
korunur; ilk yükleme hatasında backend'de bakım varmış gibi iddia edilmez.
Broadcast üç severity'yi destekler. Kapatma bu ekran oturumuna aittir; mesaj
değişince veya bandı kapatıp yeniden açınca tekrar gösterilir.

İzole SQL regresyonu yine 5/5, SSS 39/39, push 40 eşleme kayıpsız ve statik
41 mobil rota/giriş eşliği başarılı. UI/route/provider için 9 yeni regresyon
testi hazır; önceki new-plan HTTP sözleşmesi insert davranışına güncellendi.
10 değişen/yeni Dart dosyası sözdizimi kontrolünden geçti. Flutter SDK yok:
widget/module/navigation/provider testleri, analyze/build ve cihaz görsel
UAT çalıştırılamadı. Canlı SQL/deploy/commit/push yapılmadı.

- `platform_settings` tamamıyla genel veridir. Sır, token, özel iletişim veya
  kişisel veri saklanmaz. Public RPC beş bilinen anahtarı projekte eder;
  tablo SELECT izni ise kullanıcı talimatı gereği tüm satırlara açıktır.
- Aktif planları herkes, pasifleri yalnız platform admin okur. Ayar ve plan
  INSERT/UPDATE/DELETE işlemleri RLS ile platform admin ister.
- RPC ile ve doğrudan tabloyla yapılan admin değişiklikleri aynı transaction
  içinde trigger audit üretir. Actor/timestamp sunucudan gelir. Audit uygulama
  rolleri için append-only'dir; yalnız admin SELECT okuyabilir.
- Seed tekrar uygulanınca yönetici değişikliklerini silmez. Yıllık ücretler
  belirtilmediğinden şema varsayılanı `0` korunur; ticari bir ücretsiz yıllık
  abonelik taahhüdü değildir. Features boş, badge null başlar.
- Kill-switch, maintenance, komisyon ve yayın alarmı değerleri **yalnızca
  kayıt altyapısıdır**. Signup, ödeme veya marketplace RPC'lerinde henüz
  uygulanmaz. Bunların yaptırımını bu migration sağlıyor diye sunmayın.
- Provider hataları gerçek AsyncError olarak kalır. Fixture modunda gerçek
  fiyat uydurulmaz; audit provider yerel admin kapısıyla hiç sorgu başlatmaz.
  Asıl yetki kaynağı RLS/RPC'dir. Başarılı yazı üç provider'ı geçersiz kılar.

## Doğrulama

`node --test tools/platform_mission_control_sql_test.mjs`: 5/5 gerçek izole
PostgreSQL senaryosu geçti. Anon/member/admin rol değiştirme, RPC izni,
pasif planlar, idempotent seed, doğrudan audit, actor sahteciliği, rollback,
append-only log ve hatalı JSON/numeric/target kontrollerini kapsar.
İlk koşuda anon UPDATE için yanlışlıkla sıfır satır bekleyen test başarısızdı;
doğru sözleşme privilege reddi olarak düzeltildi, son koşu 5/5 geçti.

`python tools/check_migrations.py`: 109 migration parse edildi, sorunlu dosya 0.
`python tools/check_faq.py`: 39/39 yardım kapsamı.
`git diff --check`: temiz.

`packages/swansport_data/test/platform_mission_control_test.dart`: 10 model,
provider ve HTTP sözleşme testi hazır. Flutter SDK bulunmadığından bu testler,
analyze ve derleme çalıştırılamadı. Sözdizimi kontrolü runtime kanıtı değildir.
Canlı migration, gerçek Supabase oturumu, çok oturumlu yarış ve UI UAT yok.
