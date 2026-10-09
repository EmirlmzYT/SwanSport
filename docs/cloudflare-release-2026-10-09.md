# Cloudflare üretim yayını — 2026-10-09

Kullanıcının açık yayın talebiyle tamamlandı.

- Proje: `swanspor`; üretim dalı `main`. `swansport` isimli diğer proje
  `swansport-aqi.pages.dev` adresidir; bu yayında kullanılmadı.
- Uygulama: https://swansport.pages.dev/
- Konsol: https://swansport.pages.dev/konsol/
- Sabit dağıtım: https://05b28ac9.swansport.pages.dev/
- Dağıtım kimliği: `05b28ac9-15ed-4172-9020-c6eb078cb129`.

665 Flutter testi, 10 SQL senaryosu ve iki başarılı üretim derlemesinden gelen
paketler kullanıldı. Derlemeden sonra değişen lib kaynağı bulunmadı. Uygulamanın
eski `build/web/konsol` kopyası dışlanıp güncel konsol ayrı release klasörüne
alındı. `/konsol/` base href korunur; mevcut Pages Functions çalışma dizininden
paketlendi. Wrangler Functions derlemesini, 8 yeni/88 mevcut dosyayı, Functions
bundle yüklemesini ve Deployment complete sonucunu doğruladı. Üretim dağıtım
listesinde yeni kimlik `Production/main` olarak kayıtlı.

Paket SHA256:
- App: `87337110de63eecf10b729052027474224655cd12e5cf1463ff6cfc183e4ae55`
- Console: `679f2142993fae2fd31fceeef4ea270d77624aa2c1d2a898c7b4e0fe1f94d526`

HTTP doğrulamasının sınırı: bu bağlantıda üretim ve sabit pages.dev adreslerinin
HTTPS isteği TLS hatası veriyor; HTTP isteği `aidiyet.esb.org.tr/landpage`
adresine yönleniyor. Bu nedenle canlı HTML, derin bağlantı, JS hash eşleşmesi
ve fonksiyon HTTP yanıtı doğrulanamadı. Cloudflare dağıtım başarısı ile canlı
uygulama işlev testi aynı sonuç olarak raporlanmadı.

Supabase migration bu Cloudflare yayınında uygulanmadı. Yeni bayraklı özellikler
sunucu kurulumuna kadar açılmayabilir. Gerçek hesap/cihaz ve eşzamanlı oturum
UAT'si açık. Git commit veya push yapılmadı; çalışma ağacı korunarak yayımlandı.
