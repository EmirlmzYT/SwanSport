# Hata düzeltmesini doğrulama

2026-10-07. Yol haritası aşama 3; mevcut hata merkezi ve destek sisteminin
uzantısıdır. 0089 ileri migration ve uygulama/konsol değişiklikleri yerelde hazır.
Bu görev canlı veritabanı, web veya APK yayını yapmaz.

## İş akışı

1. Platform yöneticisi Hata ve Kullanım Merkezi'nde kayıt seçer. Hata kimliği
   kopyalanabilir. **Düzeltildi** düğmesi artık boş durum değiştirmez: yayınlanan
   sürüm/build ve platform zorunludur. Listede **Düzeltme bildirildi** görünür;
   bu, çözümün otomatik doğrulandığı anlamına gelmez.
2. Destek kuyruğunda bir talep bu hata kimliğine bağlanır. Yanlış bağlantı açık
   onayla kaldırılabilir; yazışmalar korunur ve açık talep incelemeye döner.
3. Bağlı açık talepler yeni düzeltmede **yanıt bekliyor** olur. Normal destek
   mesajı ve mevcut `support` bildirimi üretilir; yeni mesaj/bildirim sistemi yoktur.
4. Talep sahibi aynı uygulama/platformda bildirilen sürüm veya sonrasında işlemi
   yeniden dener. **Sorun çözüldü** talebin çözüm teyidini kaydeder; **Sorun devam
   ediyor** talebi incelemeye, teknik hatayı yeniden oluştu durumuna alır.
5. Eski/bilinmeyen sürüm veya farklı platformda teyit düğmeleri kapalıdır; normal
   destek yanıtı kullanılabilir. Sunucu aynı kısıtları ayrıca uygular. Yalnız talep
   sahibi kendi yanıtını verir; ekip kullanıcının yerine teyit veremez.
6. Yeni düzeltmenin kimliği eski formu geçersiz kılar. Aynı sürüm/platform bildirimi
   ve aynı kullanıcı yanıtı tekrar gönderilince mesaj/bildirim çoğalmaz. Yeni
   düzeltme aynı platformda daha düşük sürüme gerileyemez.

## Teknik tekrar ile kullanıcı teyidi ayrı

Mevcut teknik kayıt izni davranışı değişmez. Otomatik gerileme yalnız aynı hata
parmak izi, uygulama ve platformda; bildirilen sürüm/build veya sonrasında ve
bildirimden sonra gerçekleşmiş bir hata için sayılır. Sürüm dizeleri alfabetik
karşılaştırılmaz: dört sayısal parça kullanılır, eksik build 0'dır. `unknown`
ve bozuk metadata çözüm veya gerileme kanıtı sayılmaz. Gecikmiş eski kayıt ve
duplikat event kimliği sayacı artırmaz.

Kullanıcının “devam ediyor” yanıtı sahte bir teknik event üretmez. Başka birinin
teknik tekrarı da önceden çözüm teyidi vermiş kişinin yanıtını değiştirmez.
Konsol ayrıntısında güncel kapsam, teknik tekrar sayısı ve bekleyen/olumlu/olumsuz
teyitler ayrı görünür. Genel sayaçlar bekleyen teyit ve düzeltme sonrası sorunları
ayrıca gösterir. Hiç event gelmemesi tek başına “hata düzeldi” kanıtı değildir.

Her hatanın **bir güncel doğrulama kapsamı** vardır: tek uygulama/platform/sürüm.
Önceki bildirimler `diagnostic_fixes` geçmişinde korunur. Başka platformdaki hatalar
bu kapsamı doğrulamaz veya çürütmez; yeni platform bildirimi güncel kapsamı değiştirir.
Bir kişinin teyidi de bütün kullanıcıların sorununun bittiği anlamına gelmez.

## Yetki, veri ve saklama

- `diagnostic_fixes` yalnız hata kimliği, sürüm, platform, uygulama, bildiren
  yönetici ve teknik tekrar sayısını taşır. İkinci hata/talep sistemi kurulmadı.
- `support_tickets` mevcut hata/düzeltme kimliği ve kullanıcı cevabıyla genişletildi.
  Yeni tablo RLS açık ve PUBLIC/anon/authenticated doğrudan erişimi kapalıdır.
- Yeni/replaced definer RPC'ler kendi yetkisini doğrular. Genel kullanıcıya yalnız
  kendi talebinin sınırlı düzeltme özeti döner; başka oturumların teknik kayıtları
  veya yönetici kimliği dönmez. Mesajın `is_staff` değeri istemciden alınmaz.
- Standart `set_support_status` kullanıcının tek başına “çözüldü” yazmasına izin
  vermez. Yeni teyit RPC'sindeki istisna yalnız ekipçe bildirilmiş **güncel**
  düzeltme için, sahip/sürüm/platform koşulları sağlanınca mümkündür.
- Kullanıcının sürümü istemci metaverisidir; bu, cihaz yazılımına kriptografik
  doğrulama değildir. İnsan teyidi ve izinli teknik kayıt ayrı kanıtlardır.
- Bütün düzeltme/bağlantı/yanıt işlemleri issue → ticket kilit sırasını izler.
  Eski RPC imzaları korunur; yeni işlemler ayrı adlarla eklenir.
- Ham hata metni, form verisi veya teşhis bu akışa eklenmez. Teknik eventler
  mevcut 30 günlük saklamaya tabidir. Bekleyen teyidi olan açık talebin hata özeti
  90 günlük silinmeden korunur; kapatıldığında normal silme kuralına geri döner.
  Böylece teyit bekleyen bir kullanıcı sessizce kopuk forma bırakılmaz.

## Doğrulama ve kurulum

- Gerçek 0086 + 0089 SQL, PGlite/PostgreSQL içinde çalıştırılır:
  `node --test tools/diagnostics_sql_test.mjs tools/diagnostic_fix_sql_test.mjs`.
  Yeni dosyada 9 senaryo: izin/idempotency, sürüm kapsamı/zaman/duplikat,
  bildirim geçmişi, destek bağı, sahip/güncel sürüm, devam eden hata, eski form,
  saklama ve yanlış bağlantıyı kaldırma.
- 6 veri testi sayısal karşılaştırma, ortam kapısı ve gerçek RPC sözleşmelerini;
  4 mobil widget testi teyit/çift gönderim, eski sürüm, hata/tekrar deneme ve
  backend olmayan durumda normal desteği doğrular.
- Konsolun 3 hata merkezi testi güncel sürüm/platform formunu da kapsar; 3 yeni
  destek paneli testi yetki, bağlama/kaldırma ve boş bildirim formunu doğrular.
- Tam regresyon, analiz, katalog/SSS/migration ve iki üretim web derlemesi
  sonuçları `.ai-team/TEAM_BOARD.md` içine yazılır.

0089 dosya başına transaction ve 15 saniyelik lock timeout kuralıyla uygulanır.
Önce migration, sonra her iki uygulama paketi yayınlanmalıdır; eski konsolun
sürümsüz “resolved” çağrısı ileri migration tarafından bilerek reddedilir.
Canlıdan önce iki gerçek hesap, eski/yeni build, bildirim rotası, gerçek iki
PostgreSQL oturumu ve Android güncelleme akışı denenmelidir. SQL fixture'ları
bütün Supabase şeması veya çok oturumlu yarış testi değildir. Çalışma commit edilmedi.


Son yerel doğrulama: **261 uygulama + 306 veri + 46 konsol = 613 Flutter testi**;
10 mevcut tanılama ve 9 yeni düzeltme SQL senaryosu geçti. Değişen 11 kaynak/test
analizinde 0 bulgu; 89 migration parse, 36/36 SSS, 37 push rotası, katalog senkronu
ve diff-check başarılı. İki web paketi açık `lib/main_production.dart` girişinden
üretim ortamıyla derlendi (uygulama 72,3s, konsol 62,9s). Test ortamının boş backend
ayarı bu derlemelere taşınmadı. Fiziksel Android/canlı iki hesap UAT yapılmadı.
