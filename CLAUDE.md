# SwanSport

Flutter/Dart + Supabase. Melos workspace. **Dart projesi — TypeScript değil.**

```
apps/swansport_app        mobil + web uygulaması
apps/swansport_console    masaüstü yönetim konsolu (web)
packages/swansport_data   Supabase veri katmanı — İKİ UYGULAMANIN ORTAK KAYNAĞI
supabase/migrations       şema, numaralı ve idempotent
```

Sorgular ve provider'lar `swansport_data`'da; widget'tan doğrudan Supabase
çağrılmaz. Yetki hesabı tek yerde: `SwanAccess` (`packages/swansport_data/lib/src/access.dart`).

## Araç seçimi

| İş | Araç |
|---|---|
| Tanım, referans, hover | **dart** MCP → `lsp` (Dart analiz sunucusu, birinci parti) |
| Statik analiz, test, pub | **dart** MCP (`analyze_files`, `pub`, `pub_dev_search`) |
| Framework/kütüphane dokümanı | **context7** (`resolve-library-id` → `query-docs`) |
| GitHub issue/PR | **`gh` CLI** (Bash ile) |
| Tarayıcı doğrulaması | **playwright** — yalnızca gerçekten gerekince |
| SQL, YAML, JS gibi LSP dışı dosyalar | `Grep` |
| Geniş kod tabanı taraması | **Explore** subagent'ı |

Dart kodunda **önce `lsp`, sonra `Grep`, en son `Read`**. Bir sembolün nerede
tanımlandığını `lsp` iki satırda söylerken, dosyayı okumak binlerce token
harcıyor.

> Serena kurulu ama `.mcp.json`'da devre dışı — bu makinede sunucusu ayağa
> kalkmıyor. Arama yaparken onu bekleme, listede yok.

## Kurallar

- **Önce sembolü bul, sonra dosya oku.** Tüm projeyi tarama; `serena` ile
  ilgili sembole git.
- **Aynı dosyayı tekrar okuma.** Bir kez okunan içerik context'te duruyor.
- **Büyük dosyanın tamamını okuma.** `offset`/`limit` ile yalnızca gereken
  aralığı al.
- **Önce mevcut implementasyonu ara.** Bu depoda çoğu şeyin bir karşılığı
  zaten var; ikinci bir kopya yazmak geçmişte üç kez sessiz çakışma üretti
  (`InjuryRow`, `injuriesProvider`, `attendanceSummaryProvider`).
- **İstenmeyen refactor ve özellik ekleme.** Kapsam neyse o.
- **Uzun terminal çıktısını context'e dökme.** `| tail -20`, `grep -c` gibi
  süzgeçlerle yalnızca gereken özeti al.
- **Araştırmayı Explore subagent'ına ver**, ana context'i koru.

## Effort önerisi

Kullanıcı effort'u kendi ayarlıyor; sen değiştiremezsin. Ama **her işe
başlamadan önce tek satırla** hangi seviyenin yeteceğini söyle — yukarı da
aşağı da. "Buna max gerekmez, medium yeter" demek, "max kullan" demek kadar
değerli; gereksiz yüksek effort para ve zaman yakar.

Biçim — **tek satır, en başta, gerekçesi yarım cümle**:

`Effort: medium — desen belli, mevcut ekranın kopyası.`

| Seviye | Ne zaman |
|---|---|
| **max** | Sıfırdan modül/mimari, veritabanı şeması, RLS ve yetki, çok dosyaya dokunan taşıma, "hata vermiyor ama garip davranıyor" |
| **high** | Mevcut sistemde bug avı, iki uygulamayı birden ilgilendiren değişiklik, yarış/çakışma durumları, dış servis entegrasyonu |
| **medium** | Deseni belli özellik ekleme, yeni ekran, test yazma, mevcut servise metot ekleme |
| **low** | Lint, yeniden adlandırma, dosya taşıma, "bu nerede tanımlı", commit, belge güncelleme |

Kararsızsan yukarıyı seç ve sebebini söyle: yanlış yolda bir saat gitmek,
yüksek effort'tan pahalıdır.

Seviyeyi söyledikten sonra **kullanıcının cevabını bekleme**, işe başla.
Uyarı bilgi vermek için, izin almak için değil.

```bash
flutter analyze packages/swansport_data apps/swansport_console apps/swansport_app
```

Derleme çıkış kodunu ayrı satırda oku, `| tail` ile boru hattına sokma.

**Testlerin hepsi geçer** — başarısız test normal değildir, kırıldıysa
düzelt. Sayılar: `swansport_data` 84, `swansport_console` 40,
`swansport_app` 139.

*(Eskiden burada "bilinen 69 başarısız var" yazıyordu; o kök neden
`cfc985c` ile giderildi — ortak Supabase ve bellek içi `shared_preferences`
kurulumu eklendi. Not güncellenmediği için bir süre yanlış bilgi taşıdı.)*

## AGENTS.md güncel tutulur

`AGENTS.md` bu projeyi ilk kez gören bir ajanın okuduğu dosya (Codex onu
kendiliğinden okuyor). İş bitirdikten sonra, **rapor vermeden önce** şunlardan
biri olduysa dosyayı güncelle:

| Olan | Güncellenecek bölüm |
|---|---|
| Yeni modül, tablo, migration, paket | Yapı · Durum |
| Yeni tuzak bulundu (sessiz hata, platform kuralı) | Bilinen tuzaklar |
| Bir şey çalışır/bozuk hale geldi | Durum → Çalışan / Yarım |
| Test sayısı değişti | Çalıştırma ve doğrulama |
| Commit atıldı ya da yeni iş commit'lenmedi | Commit durumu |
| Yeni sır/anahtar tanımlandı | Sırlar |

Küçük düzeltmeler (lint, yeniden adlandırma, metin değişikliği) için
güncelleme gerekmez.

**Neden:** bu dosyanın değeri kodu okuyarak bulunamayacak bilgiyi taşımasında.
Eskidiği anda tam tersine dönüyor — yanlış bilgi, hiç bilgi olmamasından kötü.

## Tuzaklar

- `flutter` alt çizgiyle başlayan dosyaları (`web/_redirects`) `build/web`'e
  kopyalamaz — dağıtımda elle kopyalanır.
- Cloudflare, hedefi `/index.html` olan 200 rewrite kurallarını sessizce yok
  sayar. Konsol yönlendirmesi `functions/konsol/[[path]].js` içinde.
- Git Bash `--base-href=/konsol/` değerini Windows yoluna çevirir;
  `MSYS_NO_PATHCONV=1` gerekir.
- Postgres'te `position` ve `current` ayrılmış sözcük; `RETURNS TABLE` içinde
  kullanılamaz.
- Fonksiyon izni kaldırırken `public` rolünü unutma — yalnızca `anon` ve
  `authenticated`'dan almak yetmez, izin `PUBLIC`'ten miras alınır.
