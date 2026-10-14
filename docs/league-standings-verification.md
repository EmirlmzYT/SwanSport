# Canlı Puan Durumu & Lig Tablosu — yerel doğrulama

2026-10-14. 0117 SQL, ortak veri katmanı ve mobil/konsol entegrasyonu yerelde
hazırdır. Canlı SQL, sürüm, deploy, commit veya push yapılmadı.

## Kapsam ve güvenlik

- `public_league_standings(uuid,boolean)` salt okunur tablosu yalnız
  `official AND is_public`, `kind IN ('league','tournament')` ve
  futbol/basketbol/voleybol/tenis programlarını kabul eder. Kapalı, bilinmeyen,
  amatör veya cup programı aynı boş sonucu verir. Planın `OR NOT official`
  ifadesi kullanılmadı: özel amatör kayıtları ve serbest katılımcı isimlerini
  anon'a açmak güvenli değildir. Amatörlerin genel tablo desteği bu teslimde yok.
- Yeni liste `public_standings_leagues()` ve maç bağlamı
  `match_public_standings_context(uuid)` aynı yayın kapısını kullanır. Detay
  ekranı organizasyonu başlık/isim veya 48 saatlik liste üzerinden tahmin etmez.
  Dönen participant/club/federation UUID'leri takım/program anahtarlarıdır;
  athlete/profile/kadro UUID'si, sağlık, özel rapor/mazeret ve mali veri yoktur.
- Kaynak RLS/ACL, audit ve yazma RPC'leri değişmedi. Üç public RPC PUBLIC'ten
  revoke, anon/authenticated'a grant edilir; private yardımcı açılmaz.
- Konsol modül girişini merkezi SwanAccess kontrol eder; panel server scope
  listesiyle federasyon + branş + il eşleşmesini süzer. İl temsilcisi kendi
  kapsamında kalır; başkan kendi federasyonunun tüm illerini görür. Bu zaten
  yayımlanmış public verinin konsol filtresidir, özel verinin güvenlik kapısı
  değildir. Yeni private lig okuma veya MHK yetkisi açılmaz.

## Hesap sözleşmesi

- Tüm sezon hesaplanır; 0116 liste limiti/son 48 saat sınırı tabloyu kesmez.
  Kabul edilmiş katılımcılar maçsızken sıfır istatistik + boş form ile yer alır.
- Tamamlanmış maçlarda 0116 private header projeksiyonu güncel
  `org_matches.result_version` / resmi sonuç protokolünü kullanır. Düzeltme
  eski revizyonu ikinci kez saymaz. Eksik/bozuk veya time/rank protokolü
  oynanmış 0–0 beraberlik olarak uydurulmaz; sayısal takım tablosuna katılmaz.
- Varsayılan puan 3/1/0; gerçek `organizations.win_points/draw_points/loss_points`
  değerleri esas alınır. Basketbola sessiz 2/1 kuralı yazılmaz; farklı lig
  mevcut ayarını korur. Set bazlı bonus (ör. voleybolda 3–2–1–0), ikili averaj,
  puan cezası, grup ayrımı, eleme veya şampiyon tescili bu motorun kapsamı değil.
- Canlı mod scheduled + iki kilitli esame + etkili 0112 olay koşulunu kullanır;
  başlamamış maçın puanı eklenmez. Undo-aware mevcut motor yeniden kullanılır,
  ikinci journal/skor kaynağı kurulmaz. Final olduysa resmi sonuç üstün gelir.
  Tenis/set protokolünde atılan/yenen değer **kazanılan setlerdir**, oyun toplamı
  değil. AV ilgili skor/set farkıdır. Başlamış fakat henüz eşit olan canlı maç,
  sanal beraberlik puanıyla gösterilebilir; kesin sonuç değildir.
- Sıra: puan, averaj, atılan sayı azalan; katılımcı adı ve UUID artan. UUID
  tam eşitlikte kararlı son bağdır; özel federasyon eşitlik kuralı değildir.
  Son 5 maç fikstür tarihine göre seçilir, eskiden yeniye W/D/L (UI G/B/M).
  Sonradan tescil/düzeltme kronolojiyi en yeni maç gibi yeniden sıralamaz.

## Veri ve UI

- Immutable saf modeller, exact RPC parametreli servis ve açık tipli
  Riverpod sağlayıcıları. Canlı tablo 10s, resmi tablo/list/maç bağlamı 30s
  polling; timer istek bittikten sonra kurulur, dispose/geç cevap korunur.
  Fixture veya kapalı bayrak backend çağırmaz. Raw Realtime aboneliği yoktur.
- Mobil `LeagueStandingsView`: yatay kaydırmalı dokuz sütun, armada hata
  fallback'i, G/B/M form rozetleri, maç takımı vurgusu, resmi/canlı switch,
  loading/error/empty. Hub dört hap sekmesine, detay üç hap sekmesine geçer;
  mevcut SwanPillTabs çok/uzun etiket için kullanılır. Beş alt sekme değişmez.
- Lig/context yenilemesi seçili canlı modu korur; boş/null/error yanıt eski
  tabloyu sürekli tutmaz. Lig seçici UUID ile çalışır ve liste değişince geçerli
  seçime döner. Yayın kaldırma sonraki poll + ağ süresinde görülür, anlık garanti yok.
- Konsol gerçek dosyası `features/federation/provincial_leagues_screen.dart`
  (planın provincial/presentation yolu depoda yoktur); mevcut fikstür korunur.
  İkinci sekme ConsoleTable/StatusPill/ConsoleDensity/Theme kullanır; 900px ve
  aktif rol koruması doğrudan panelde de vardır. Tam sıralanmış RPC sonucu
  konsolda yerel sayfalara bölünür, yalnız görünen sayfa yeniden sıralanmaz.
- `league_standings` admins başlar: SQL/Dart/SSS/sync-test ve gerçek UI/provider
  kapıları vardır. Mobil giriş ayrıca mevcut `live_match_hub` kapısına tabidir;
  mobil yayın için iki bayrak birlikte açılmalıdır. Bayrak API güvenliği değildir.
  Yeni rota/push türü veya kConsoleModules kaydı eklenmez.

## Kanıtlar ve kabul sınırları

- `node --test tools/league_standings_sql_test.mjs`: **73/73** (67 mevcut +
  altı 0117). Public/auth ACL, publication withdrawal, unknown/private/amateur,
  replay, varsayılan/özel puan, averaj/gol/ad sırası, son beş, güncel resmi
  revizyon, tüm sezon, canlı/undo/set ve unsupported protokol kapsanır.
- `python tools/check_migrations.py`: **117 parse, 0 sorun**.
  `python tools/check_faq.py`: **43/43**. Push validator: **41, kayıp yok**.
  Scoped token checker: **22/22**; tüm Dart syntax: **580, 0 hata**.
  `git diff --check` / staged diff check temiz.
- Üç yeni Dart test dosyasında **15 senaryo** (6 data/provider, 6 mobil,
  3 konsol); mevcut feature sync testi güncellendi. Testler DTO/HTTP,
  subscription polling/slow request/error/dispose, dar/yüksek ölçekli tablo,
  canlı toggle/refresh/withdrawal, hub/detail ve il/federasyon/900px kapısını hedefler.
- Data/app Flutter testleri, tüm console testleri, analyze ve Melos format
  denendi; **Flutter/Dart/Melos SDK bulunmadığı için çalışmadı**. Syntax testi
  typecheck/widget/build/format/gerçek render değildir; bunlar yayın öncesi açık.
- PGlite izole tek bağlantı fixture'ıdır. 0113–0115 birlikte uygulanmış tam
  üretim şeması, PostgREST dönüşü, iki oturum, gerçek cihaz/taşma/erişilebilirlik,
  pil ve hacim performansı ayrıca UAT ister. Raw fixture tarih/snapshot seedleri
  test hazırlığıdır; yeni istemci yazma yetkisi değildir.
- `_public_match_header` mevcut journal'ı yeniden oynatır; tüm sezon ve uzun
  olay geçmişinde maliyet ölçülmedi. Liste/sıralama cache, server pagination,
  materialized snapshot ve tam foreground-only polling yoktur. 0112 canlı
  yazıcı halen futbol/basketbol/tenistir; voleybol resmi program/sonuçları
  gösterilebilir ancak voleybol hakem motoru bu görevle eklenmedi.
- Önceki 0116 stage ve kullanıcının iki planı/pano geçmişi korunur. Yalnız
  görev değişiklikleri stage edilir; canlı yayın ve Git commit/push yapılmaz.
