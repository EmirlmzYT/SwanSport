# Federasyon temeli — Faz A doğrulama

2026-10-09, yerel çalışma. Canlı SQL, push, deploy ve commit yapılmadı.
Kullanıcının kilitli görevinde yalnız Faz A uygulanır. B–E kodu yok; plan `.planning/federation-foundation/ROADMAP.md`.
0077–0093 zaten bulunduğu için yeni migration'lar 0094–0096; eski dosyalar değiştirilmedi.

## Değişiklikler ve gerekçeleri

| Dosya | Gerekçe |
|---|---|
| `supabase/migrations/0094_federation_foundation.sql` | Federasyon/ofis/atama, faaliyet yılı, branşlı tescil/lisans, sonuç/kadro revizyonu, transfer/itiraz, veli yayın tercihi. Mevcut organizasyon/maç/başarılar genişletilir. |
| `supabase/migrations/0095_federation_write_boundaries.sql` | Eski RPC ve doğrudan yazıları da kapsayan resmi kaynak koruması; eski keşif/paylaşım yollarından resmi kayıt sızıntısı engeli; yeni belge/takım/süpervizör kuralları. |
| `supabase/migrations/0096_federation_rpcs.sql` | Atama kontrollü ve atomik audit'li çevrimiçi resmi işlemler; özel dedup, veli tercihi ve allowlist kart. |
| `packages/swansport_data/lib/src/access.dart` | Eski getter korunurken branşlı kademe ve federasyon görevi hesabı eklenir. Önceki veli/saha değişiklikleri korunur. |
| `packages/swansport_data/lib/src/verification_service.dart` | Belge branşı ve bitiş tarihi taşınır; yeni başvuruda gerçek süre istenir, eski null süre geçerliliği korunur. |
| `packages/swansport_data/lib/src/federation_records.dart` | Ortak veri katmanında atama modeli/provider'ı, dar sonuç kartı ve çevrimiçi sonuç RPC çağrısı. |
| `packages/swansport_data/lib/swansport_data.dart` | Yeni veri modülünün dışa aktarımı; mevcut export'lar korunur. |
| `packages/swansport_data/test/federation_records_test.dart` | Branş/kademe/görev/süre/il, Türkiye tarih sınırı, null çocuk adı, RPC sürümü ve fixture testi. |
| `tools/federation_foundation_sql_test.mjs` | Gerçek eski/yeni SQL üzerinde izole PostgreSQL davranış ve rol testleri. |
| `.planning/federation-foundation/ROADMAP.md` | B–E yalnız plan; canlıya geçiş ve mevcut sistem geçiş kapıları. |
| `AGENTS.md`, `.ai-team/TEAM_BOARD.md`, bu rapor | Yeni kalıcı sözleşmeler, test kanıtı, sınırlar ve Writer devri. |

## Sunucu sözleşmesi

- Resmi yazı için `result_publisher`, `program_publisher`, `license_registrar` veya `club_registrar` ataması, doğru branş/il ve geçerli başlangıç/bitiş aranır. `is_platform_admin` bu kontrolü atlamaz.
- Kurum/ofis kurma ve atama/iptal, platformun idari bootstrap işlemleridir; sonuç/lisans/tescil yazma yetkisi sayılmaz. Bunlar da audit üretir.
- Federasyon duyuru kanalı/staff görevi resmi kurum/atama değildir. Yeni federasyonlar sports 1–1 ilişkisi taşır; kategori için ayrı kurum üretilmez.
- Eski `is_org_owner` resmi organizasyonda false. Eski sonuç/fikstür RPC'si resmi kayda yazamaz. Doğrudan yazılar da tetikleyici kontrolünden geçer.
- Yeni tablolar RLS açık, authenticated/anon/PUBLIC doğrudan yazma ve okuma kapalı. Yalnız kişinin kendi atamaları için dar okuma vardır.
- Resmi kayıtlar eski organizasyon/maç/katılımcı tablolarının genel okumalarından, fikstür/puan durumu/listelerinden ve sosyal organizasyon kartından çıkarılır. Yeni kart yalnız atanmış sonuç görevlisine açıktır.
- Resmi sonuç protokolü score/sets/time/rank için açık JSON anahtar/tür/değer allowlist'idir. İsim/sağlık vb. key eklenemez; zaman/sıralama sporcuları resmi kadroda olmalıdır. Branşın gerçek yarış kategori/protokol motoru D planında ayrıca kapıdır.
- Sonuç değişince yeni revizyon gerekir; beklenen sürüm uyuşmazsa yazılmaz. Revizyon o andaki kadro revizyonuna bağlanır. Sonradan yayımlanan kadro eskisini silmez.
- Başarı kaynağı `federation_result`, sonuç revizyonu ve maç referansını taşır. Elle insert policy'si bu kaynağı üretemez. `verified=true` kulüp gelişimini resmi yapmaz.
- Yeni resmi tablolar kulüp CASCADE zincirine girmez. Resmi organizasyonun owner/club referansı kişisel hesaba bağlanmaz; yazar referansları silinince null olur. Derecenin athlete_id anahtarı ve kadro UUID listeleri kişisel isim snapshot'ı olmadan korunur.
- Athletes.club_id NOT NULL ve profile_id nullable kalır. Kulüp silinince eski athlete satırı silinse bile resmi kayıtların kalıcı UUID anahtarı korunur. Arşiv lisansı yeniden bağlamak ulusal kayıt yetkisiyle aynı sporcu anahtarını geri kullanır.
- Lisans bitişi aynı `athletes.license_expires_on` kolonuna birincil branş için yazılır; `eligibility_gate` değiştirilmez. Resmi kadroda branş lisansının kendi süresi ayrıca kontrol edilir; başka branşın bitişi taşınmaz. Sağlık engeli her zaman uygulanır.
- Dedup lisans/TCKN eşleşmesinde mevcut ID'yi döndürür; çelişkili eski birden fazla kayıt sessiz birleştirilmez. Yeni duplicate yazıları ve legacy kimlik yazıları ortak kilitle korunur. Kimlik araması kulüp/anon için açık oracle değildir.
- Kimlik kilidi statement seviyesinde satır kilidinden önce alınır. Bu MVP'de globaldir; yüksek hacim ve iki gerçek oturum yarışı ayrıca ölçülmelidir.
- Transfer mevcut branş kaydını değiştirir, eski maç/kadro/lisans denetim geçmişi silinmez. Birincil kulüp projeksiyonu güncellenirken eski takım bağlantıları temizlenir; çok branşlı ekran projeksiyonu E'dedir.
- Yeni 1. kademe üyeliğinde aynı branşta geçerli >=2 belge taşıyan aktif antrenör supervisor gerekir. Eski üyelikler topluca doğrulanıp kırılmaz.
- Çocuk adı doğum tarihi VE/VEYA veli bağıyla korunur; doğum tarihi bilinmiyorsa kapalı kabul edilir. İzin her okumada güncel guardian bağlantısından değerlendirilir, iptal edilmiş tercihin isim snapshot'ı tutulmaz. Başka velinin açık reddi de yayını kapatır.
- Resmi offline kuyruk, events kopyası, yeni ekran, yeni özellik bayrağı veya anon grant eklenmedi.

## Entegrasyon sınırı — yayın kapısı

Yeni belge başvurusu `expiresOn` olmadan istemcide ve SQL'de reddedilir. Mevcut başvuru ekranları bu alanı henüz toplamaz: ekran değişikliği bu oturumda yasaktır. Bu backend temeli, yeni belge süresi girişini içeren C/D geçişi tamamlanmadan mevcut kullanıcı akışına tek başına canlı uygulanmamalıdır. Eski onaylı `expires_on IS NULL` belgeler geçerli kalır; eski başvurunun normal inceleme akışı silinmez.

Bu faz genel bekleme odasını veya tüm eski sportif RLS/RPC'leri dönüştürmez. Yeni resmi kayıt yüzeyi daraltılmıştır; aşağıdaki eski sistem riskleri ayrıca kayıtlıdır. Bunların kapandığı iddia edilmez.

## Privacy-reviewer kapsamı — ayrı risk değerlendirmesi

Bu bölüm `.agents/agents/privacy-reviewer/agent.md` kontrol listesiyle yapılan yerel incelemedir; bağımsız alt ajan incelemesi yapıldığı iddia edilmez.

| Önem / durum | Aktör, veri, erişim yolu ve kanıt | Koruma / gerekli doğrulama |
|---|---|---|
| Kapatıldı: yüksek, resmi kaydın dolaylı kimlik sızıntısı | Eski org_fixture/org_standings ve org_matches genel okumaları resmi roster/result UUID'lerine erişim verebilirdi. UUID'nin eski athlete_public ile birleştirilmesi çocuk adına ulaşmayı sağlayabilirdi. | Resmi kayıt eski genel yollardan çıkarıldı; atanmış kart, güncel veli tercihi ve sabit alan listesi kullanılır. SQL'de tablo/fikstür/puan/list/share yolları ve anon yürütme kapalı test edilir. |
| Kapatıldı: yüksek, resmi yazma yetki aşımı | Platform/kulüp yöneticisi, yanlış branş/il/görev, bitmiş/gelecek/iptal atama. | SQL gövdesi + eski yazı tetikleyicisi + audit, yönetici bypass yok; rol ve süre testleri başarılı. |
| Kapatıldı: yüksek, geçmişin silinmesi | Kulüp/hesap silme veya eski fixture temizleme işlemi resmi sonucu/dereceyi silebilirdi. | Referanslar ve silme tetikleyicileri değiştirildi, gerçek FK zinciriyle deletion testi yapıldı; resmi sonuç ve derece korunur, yazar null olur. |
| Devam eden eski sistem riski: yüksek | 0011 `athlete_public` görünümü owner yetkisiyle çalışıyor, authenticated'a SELECT veriliyor; eski sportif ad/ölçü alanlarını genel okuma imkânı var. Yeni resmi karttan bağımsızdır. | Faz A bunu daha geniş bir guest yolu yapmaz; fakat eski görünümün tüm privacy sorunu çözülmüş değildir. B/C ön kapısında gerçek authenticated/muhasebeci/anon view erişimi ve profil vitrin sözleşmesi birlikte düzeltilmeli. |
| Devam eden eski sistem riski: yüksek | 0002 `is_club_staff` ve birçok sportif RLS/definer okuması kulüp-geneli; atanmış takım sınırı her eski yolda uygulanmıyor. | Yeni resmi kart sportif iç veri döndürmez ve appointment zorunludur. C aşamasında takım ataması, RLS ve definer RPC'ler birlikte daraltılır; yalnız UI gizleme yapılmaz. |
| Devam eden lifecycle riski: yüksek | Athletes.profile_id hesap silinince SET NULL; bu, tüm kişisel/sağlık/belge/Storage içeriğinin silindiğinin kanıtı değildir. 0064 health_restrictions.created_by FK'sı bazı sağlık görevlisi hesaplarının silinmesini engelleyebilir. | Bu faz yeni resmi yazar FK'lerini silinmeye dayanıklı yapar. Tüm eski özel veri lifecycle temizliği ve Storage nesneleri C planında, gerçek backend üzerinde ayrıca test edilmelidir. |
| Devam eden kimlik-güveni riski: orta | Veli tercihi mevcut guardians bağlantısına güvenir; bu faz doğrulanmış TCKN/bekleme odası kurmaz. | Yetkisiz kişinin tercih değiştirmesi reddedilir; mevcut ilişkinin gerçek kimlik/davet doğrulaması C ön koşuludur. Kamu okuması bu fazda açılmaz. |
| Doğrulama sınırı: orta | PGlite tek bağlantılı yerel PostgreSQL fixture'ıdır. Revoke/write, kimlik kilidi, roster/result yarışları gerçek iki oturumla sınanmadı. | Canlı kapı: ayrı PostgreSQL oturumları, PostgREST imza/parametre testi, Supabase varsayılan grant ve Storage temizliği. |

Muhasebeci için yeni sportif okuma yetkisi, isimli mali satır veya acc_* değişikliği yok. Sağlık kısıtını kaldırma RPC'si/yetkili sağlık görevlisi şartı değiştirilmedi. Yeni kartta teşhis, sağlık durumu, aidat, muhasebe, belge yolu, TCKN, doğum tarihi, konum ve profil kimliği yok. Sosyal/paylaşım değişikliği yalnız resmi organizasyonun eski karttan dışlanmasıdır; diğer sosyal dallar kaynaktaki kontrollerini korur.

## Test kanıtı

- Tam veri paketi: **336/336**, uygulama: **290/290**, konsol: **46/46**; toplam **672 Flutter testi** başarılı.
- Son erişim/federasyon dar koşu: **20/20** başarılı; yeni dosyanın yedi testi bu toplamın içindedir.
- Gerçek SQL davranış koşusu: **16/16** başarılı. Legacy boş branş/süpervizör ve süresiz belge, tek tek transaction/reapply, yanlış branş/il/duty/süre, admin/club bypass, JSON allowlist, frozen roster/result, child consent, deletion, dedup/archive restore, transfer, disputes ve eski kulüp maçı kapsanır.
- İstenen tam `flutter analyze --no-pub packages/swansport_data apps/swansport_console apps/swansport_app` çalıştı: **0 hata, 5 kapsam dışı mevcut uyarı**, ayrıca stil/info bulguları. Çıkış **1**; bütün workspace temiz diye rapor edilmez.
- Tam analizde görülen yeni inference uyarıları ve yeni trailing comma bulguları düzeltildi. Son değişen beş Dart dosyasının analizi **0 bulgu**, çıkış **0** (`analyze-changed.log`). Sonraki tek export sıralaması düzeltmesi de bu koşuda doğrulandı.
- Migration parse **96/96**, SSS **39/39**, bildirim rotası **39** ve `git diff --check` başarılı.
- Tam analizde kalan beş uyarı: role_context_switcher ve marketplace_screen unused_import; marketplace_admin_screen unused_element; marketplace_service strict_raw_type; social_and_lifecycle_test inference_failure_on_collection_literal. Bu dosyalar görev kapsamında değiştirilmedi.
- Başlangıç dosya SHA-256 listesine göre kayıp dosya yok. Önceden değişmiş kaynaklarda yalnız access.dart, barrel ve koordinasyon/bilgi dosyalarına amaçlı ekleme yapıldı; önceki veli/saha ve diğer kullanıcı/AGY değişiklikleri korunur. Board'un eski kontrol karakterleri de korunur.
- Yeni çalışma commit edilmedi; karışık çalışma ağacında eski değişiklikleri tek commit'e almak yerine görev diff'i incelemeye açık bırakıldı. Kullanıcı commit zorunluluğu vermedi.

Ham loglar `build/federation-phase-a/` altındadır; kişisel gerçek veri kullanılmadı.
Fixture actual 0001/0002/0004/0011/0027 SQL'ini, gerçek 0064 eligibility_gate gövdesini ve yeni migration'ları yürütür; ilgisiz event/post/listing altyapısı dar fixture, üretim backend simülasyonu değildir.
Graph indeksi 2026-10-07'de kaldığı ve migrations dışlandığı için coverage kontrolünden sonra ilgili kaynak SQL/Dart doğrudan okunmuştur.
