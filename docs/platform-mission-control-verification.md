# Platform Mission Control — 0109

Yerel backend/veri temeli; ekran, abonelik satışı veya canlı yayın içermez.

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
