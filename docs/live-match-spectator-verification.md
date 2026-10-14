# Canlı Maç & Skor Takip Merkezi — yerel doğrulama

2026-10-14. 0116 + saf veri katmanı + mobil entegrasyon yerelde hazırdır.
Canlı SQL, deploy, commit veya push yapılmadı.

## Veri ve gizlilik sözleşmesi

- `public_live_matches(text,text)`, `match_public_live_state(uuid)` ve
  `match_public_roster(uuid)` yalnız `official AND is_public` programların
  scheduled/played maçlarını projekte eder. Bilinmeyen, özel ve iptal edilmiş
  maç detayları aynı null sonucu verir. Program yayını geri alınınca yeni
  sorgular kapanır. UUID yetki değildir.
- Kaynak journal/esame/athletes tablolarına yeni anon/auth SELECT verilmez.
  İç yardımcılar PUBLIC/anon/authenticated'a kapalıdır. Public RPC'ler anon ve
  authenticated'a açık, salt okunurdur; yazıcılar ve mevcut audit/RLS değişmez.
- Hakem olay motoru kopyalanmaz: 0112 `_referee_state` hesapları kullanılır,
  yalnız güvenli alanlar açıkça seçilerek döndürülür. Private `report_notes`,
  rapor revizyonu, disiplin sevk notları, decline_reason, actor/operation/profile/
  athlete UUID'leri, sağlık bilgisi, lisans, TCKN ve veli telefonu yoktur.
  Maç UUID'si ve olay sıra numarası gezinme/chronology içindir.
- Timeline yalnız score/card/substitution/period_end olaylarından oluşur.
  Undo ve geri alınmış olay görünmez; gerçek kırmızı kart olayı görülebilir,
  özel disiplin sevki veya rapor gerekçesi görülemez. Hakem künyesi mevcut
  accepted_match_officials isim/görev whitelist'idir; declined kişi/mazeret yoktur.
- Kadro yalnız kilitli match_lineup_approvals ilk kadro/yedek snapshot'ından
  gelir; sonradan turnuva kadrosuna girenler eklenmez. Veli izin kaynağı depodaki
  gerçek `athlete_publicity` + yaşayan `guardians` bağıdır, şartnamedeki var
  olmayan guardian_child_consents tablosu değildir. Rızasız/itirazlı veya doğum
  tarihi bilinmeyen çocuk adı `sporcu` olarak maskelenir. Kısmi adla sızıntı yoktur.
  18. yaş gününde mevcut 0098 yetişkin kuralı geçerlidir.
- İsmi göstermek için gerçek branş kaydı ve halen maçın katılımcı kulübüyle
  ilişki aranır. Silinmiş/transfer olmuş sporcuda isim/mevki/forma bilgisi
  açılmaz. Forma/mevki mevcut sporcu kaydından okunur; kişisel alanlar tarihsel
  kopya olarak saklanmaz. Sonradan değişen forma/mevki donmuş metadata değildir.
- Seyirci özel esame, sağlık veya muhasebe kaynağına erişim kazanmaz. Kamuya
  yayımlanmış whitelist, herkes için aynı public okuma sözleşmesidir.

## Skor, takvim ve saat

- Başlamamış maç skoru null'dır; örnek takım/skor veya sahte 0–0 üretilmez.
  Devam eden maç, iki kilitli esame ve etkili hakem olayları gerektirir.
- Kesinleşmiş skor her zaman güncel resmi sonuç revizyonundan gelir; eski
  journal toplamı resmi düzeltmenin üstüne yazılmaz. Geçersiz/eksik eski sonuç
  protokolü public_program_result tarafından reddedilmişse detay da kapanır.
- Teniste ana skor **set galibiyeti** sayısıdır, oyun toplamı değildir. Bitmiş
  setler ve canlı güncel setin oyun sayıları ayrıca gösterilir. Diğer sayı/gol
  branşları mevcut motorun +1 kayıtlarını yansıtır; motor değiştirilmez.
- Günün maçları sunucunun Türkiye gününe göre belirlenir. Bitenler son 48 saat
  içindeki **güncel sonuç revizyon zamanı** ile seçilir; maç başlangıcının eski
  olması yeni kesinleşmiş sonucu dışlamaz. Canlılar bu aralık dışında da
  motor açıkken görünür. Unutulmuş açık müsabaka istemcide tahminle kapatılmaz.
- Liste sunucuda sport/city filtreli, en fazla 200 kayıttır. Mobil branş seçimi
  sunucu filtreli provider'a geçer; sadece ilk 200 kayıt üzerinde yerel branş
  süzmesi yapılmaz. Sekmeler bu sınırlı listeyi böler; tüm geçmiş/pagination yoktur.
- Saat `server_now + clock_started_at + elapsed_seconds` snapshot'ına dayanır.
  Cihaz duvar saati yerine monotonic Stopwatch yalnız görüntüyü ilerletir.
  Pause/final durumda akmaz; sonucun oluşma anında aktif eski clock da durdurulur.
  Ağ gecikmesi kadar görüntü gecikmesi mümkündür; bu NTP kesinliği iddiası değildir.

## Provider, rota ve mobil UI

- Tüm yeni provider deklarasyonları açık Riverpod tiplerine sahiptir. Ortak
  listede 30s, canlı detayda 10s, scheduled/final/error detayda 30s, aktif kadro
  sekmesinde 10s yenileme vardır. Timer istek tamamlandıktan sonra kurulur;
  dispose timers'ı kapatır ve geç istek dispose sonrası timer açmaz.
  Bu polling'dir; raw Realtime aboneliği yoktur.
- Saat ticker'ı dispose/arka plan lifecycle'da durur. Data polling, widget
  aboneliği yaşarken arka planda/örtülmüş rotada sürebilir; tam foreground-only
  networking bu teslimde yoktur. Üretimde pil/yük testi gerekir.
- Yetki/izin iptali her SQL okumada yeniden kontrol edilir. İstemci revocation'ı
  sonraki poll'de (görünüme göre 10–30s + ağ süresi) görür; anlık silinme garantisi
  verilmez. Hata/null sonucu eski isimli ekranı sürekli tutmaz.
- `/canli-skor` üç sekme/branş chipleri, `/canli-mac/<UUID>` skor/saat/set/
  timeline/kadro/künye ekranıdır. SwanAccess yalnız doğrulanmış UUID desenli
  public detail URL'sini misafire açar; özel `/hakem/...` kapıları değişmez.
- Keşfet/misafir keşfi ve Feed bağlantıları vardır. Feed en fazla **bir** gerçek
  canlı kart + merkez kısayolu gösterir. Beş alt sekme değişmez. Gerçek kulüp
  arma yolu post-media URL'sine çevrilir; image error generic shield'e düşer.
- Mevcut SwanPalette/SwanType/SwanSpace/SwanRadius ve standart module AppBar /
  SwanSegmentedTabs kullanılır. Hiçbir widget Supabase sorgusu yapmaz.
- `live_match_hub` admins başlar; SQL/Dart/SSS/sync-test ve gerçek ekran/giriş
  kapıları birlikte vardır. Feature flag yayın görünürlüğüdür, public veri
  yetkilendirmesi değildir; güvenlik bağımsız official/is_public kapısıdır.
- Yeni notification türü, push üretimi veya maç abonelik sistemi eklenmedi.
  Mevcut 41 push eşlemesi korunur; public named/deep routes ve giriş noktaları
  navigation regresyonuna eklenmiştir. Push validator yalnız eşleme kaybını ölçer,
  gerçek cihaz teslimi veya bu yeni rotaların runtime açılması değildir.

## Doğrulama ve açık kabul sınırları

- Tam `node --test tools/live_match_spectator_sql_test.mjs`: **67/67** (63 mevcut
  foundation/C1/Faz 1–3 + dört yeni). Son tam koşu **67/67**, odaklı
  `--test-name-pattern=0116` koşusu **4/4** geçti. Public read/ACL, undo, yayın iptali, çocuk rızası/ret/
  adulthood, private declined kişi/mazeret ve gerçekten tescilli özel rapor,
  final set skoru/resmi düzeltme/eski başlangıç zamanı kapsanır.
- 116 migration parse, SSS **42/42**, push **41** kayıp yok; **573 Dart syntax**
  ve **21/21** scoped mobil token kaynağı temiz. `git diff --check` temiz.
- İki yeni Dart dosyasında 12 senaryo (6 data/provider, 6 UI/route), navigation
  dosyasında bir yeni senaryo ve mevcut feature sync testi güncellemesi hazır.
- Data/app Flutter test çağrıları, analyze ve Melos format çalıştırılmaya
  çalışıldı; bu ortamda flutter/dart/melos bulunmadığı için **çalışmadı**.
  Syntax kontrolü typecheck/build/gerçek widget testinin yerini tutmaz.
- PGlite tek bağlantılı fixture kullanır; gerçek PostgREST JSON set-return biçimi,
  iki oturumlu yarış, canlı cihaz/ticker/pil, görüntü/taşma ve yük testi yapılmadı.
  0113–0115 birlikte uygulanmış üretim şemasında ek UAT gereklidir.
- `_referee_state` journal yeniden oynatır; uzun olay geçmişi ve 200 maçlık
  listede sorgu maliyeti ölçülmelidir. Server pagination ve ayrı public snapshot
  optimizasyonu bu teslimde yoktur. Voleybol chip'i program/sonuçları gösterebilir;
  0112 canlı yazıcısı halen yalnız futbol/basketbol/tenistir. Bireysel time/rank
  derece detayı bu scoreboard'da sunulmaz; sayısal skor uydurulmaz.
- Writer işi yalnız stage eder; kullanıcı tarafından başlangıçta stage edilen
  görev planı ve pano geçmişi korunur. Canlı SQL/yayın/commit/push yoktur.
