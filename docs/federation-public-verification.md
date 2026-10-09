# Federasyon Faz B — yerel doğrulama

2026-10-09. Başlangıç: `6d85a758958d99defe1cbd100e7ccbd24ca6736e`.
Kapsam yalnız yayın anahtarı ve hesapsız RPC okumalarıdır. Yeni tablo, ekran,
konsol, Dart ürün API'si, sosyal/pazaryeri/ödeme veya club_id değişikliği yok.

## Değişiklikler

- `0097_federation_public_reads.sql`: mevcut tablolar üzerinde dört security
  definer RPC. Önceki 0094–0096 değişmedi. Dosya kendi transaction'ında,
  `lock_timeout=15s` ile uygulanmalıdır; canlıya uygulanmadı.
- `federation_publish_program(p_org uuid,p_public boolean)`: yalnız resmi program,
  aktif program_publisher görevi, doğru branş/il; `_federation_require` kullanır.
  Organizasyon satırı kilitlenir, tercih ve yayın zamanı güncellenir, önceki/yeni
  tercihyle `program_publication` audit satırı aynı işlemde yazılır. Mevcut
  federation_guard yetki/audit kontrolü de çalışır. Admin bypass yok. NULL tercih
  reddedilir. Yalnız authenticated çağırabilir.
- `federation_create_program` aynen kaldı: `is_public=false`. Migration hiçbir
  mevcut programı yayımlamaz. Geri çekme üç genel okumayı da kapatır.
- `public_sport_programs()`: id, name, sport_code, city_code, season_label,
  starts_on, ends_on. Yalnız official=true/is_public=true.
- `public_program_fixture(p_org uuid)`: id, starts_at, location, home_name,
  away_name, status. Taraf adları federation_guard tarafından tescilli kulüp
  yasal adı olarak doğrulanmış participant.name'dir; takım/sporcu adına dönüş
  yapılmaz. Kulüp silinse de bu yasal ad korunur.
- `public_program_result(p_match uuid)`: `protocol jsonb` sütunlu 0 veya 1 satır.
  Gizli/resmi olmayan/bulunamayan/sonuçsuz/bozuk protokollü maçta 0 satır.
  Son yayımlanmış result revision okunur. score: type/home/away; sets:
  type/sets[{home,away}]; time/rank: type/entries[{name,value,placement}].
  JSON alan alan yeniden kurulur; ham protokol dışarı verilmez. Tam kadro yok.
- Üç genel RPC'de PUBLIC/anon/authenticated execute temizlenir, yalnız anon ve
  authenticated'a execute verilir. Yeni tablo SELECT grant'i yok, SELECT * yok.
- Resmi kaynaklar, özel sporcu/sağlık/aidat/antrenman kaynakları ve eski
  athlete_public görünümü için PUBLIC/anon SELECT kaldırılır. Mevcut
  authenticated grant ve RLS politikaları değiştirilmez. Diğer ürünlerin
  kasıtlı genel kaynakları (ör. SSS) bu değişikliğin kapsamına alınmaz.
- `tools/federation_foundation_sql_test.mjs`: yalnız mevcut fixture yardımcılarını
  export eder; 16 Faz A senaryosunun davranışı değiştirilmez.
- `tools/federation_public_sql_test.mjs`: ortak fixture üzerine 0097 ve 11 yeni
  davranış testi; import edilen 16 Faz A testiyle toplam 27 senaryo.

## İsim ve gizlilik sözleşmesi

Hiçbir sonuç girdisi athlete_id/profile_id/lisans/TCKN/fotoğraf veya kadro
UUID'si taşımaz. Sonuç protokolündeki sporcular dışında kimse dönmez.

0098 sonrasında 18 yaş altı veya doğum tarihi bilinmeyen sporcu için
canlı veli bağlantısındaki allowed=true gerekir; bir velinin açık ret tercihi
izinleri geçersiz kılar. İzin geri alma veya veli/izin silme bir sonraki okumada
etkilidir. İzin yoksa name tam olarak `sporcu` olur. Reşit sporcunun aynı branşta
kayıtlı olması gerekir; geçmiş sonuç için lisansın bugün süresinin dolması veya
yayımlayanın görevinin bitmesi okumayı kapatmaz. Silinmiş/kayıtsız sporcu için
isim snapshot'ı kullanılmaz, `sporcu` döner. Yaş tarihi Türkiye takvimindendir.

Sağlık, aidat, belge, antrenman, özel not, doğum tarihi ve kimlik alanları genel
çıktıya girmez. Mevcut authenticated athlete_public gizlilik kapsamının yeniden
tasarlanması, doğrulanmış veli kimliği ve hesap silme özel veri temizliği Faz C
konularıdır; bu çalışmada çözülmüş sayılmaz.

## Çalıştırılan doğrulamalar

```text
node --test tools/federation_public_sql_test.mjs
27 test / 27 geçti / 0 başarısız (16 Faz A + 11 Faz B)

flutter test packages/swansport_data/test/access_test.dart packages/swansport_data/test/federation_records_test.dart
20 test / 20 geçti

flutter analyze packages/swansport_data apps/swansport_console apps/swansport_app
0 hata / 5 önceki uyarı / 2641 info; çıkış 1 (2646 bildirim)

python tools/check_migrations.py supabase/migrations/0097_federation_public_reads.sql
OK / 0 sorun

node --check tools/federation_public_sql_test.mjs
çıkış 0

git diff --check
çıkış 0
```

Beş uyarı Faz A'dakilerle aynı: role_context_switcher ve marketplace_screen
unused_import; console marketplace_admin_screen unused count; data
marketplace_service strict_raw_type; social_and_lifecycle_test inference_failure.
Bu oturumda Dart ürün kaynağı değişmedi. Genel analiz temiz denmedi.

Testler: gerçek 0001/0002/0004/0011/0027, eligibility_gate gövdesi ve
0094–0097 migration SQL'ini yerel PGlite PostgreSQL WASM içinde çalıştırır.
Supabase'in varsayılan izinlerini taklit eden anon/authenticated rolleri ve
PUBLIC grant tuzağı vardır. İlgisiz events/social yardımcıları ile sağlık,
fatura/ödeme/antrenman/belge tablolarının azaltılmış stand-in yapıları kullanılır;
27 test bütün üretim migration zincirinin kurulumu iddiası değildir.

Kanıt logları (Git'e dahil olmayan yerel dosyalar):
`build/federation-phase-b/sql-final.log`, `dart-tests.log`, `analyze.log`.
Graph migration/tools alt ağaçlarını kapsamıyor; ilgili kaynaklar doğrudan
okundu ve SQL runtime testi yapıldı. Canlı Supabase/PostgREST, tarayıcı UAT ve
iki gerçek PostgreSQL oturumunda yarış testi yapılmadı. Push/deploy/canlı SQL
bu oturumun açık yasağı nedeniyle yapılmadı.

Bu çalışma yerel Git commit olarak kaydedilir; push bu oturumda yapılmaz.


## 0098 — reşit ad kuralı düzeltmesi (2026-10-09)

0097 GitHub'daki haliyle değişmeden bırakıldı. 0098_public_result_adult_name.sql
public_program_result(uuid) fonksiyonunu aynı imza ve grant'lerle drop/create
eder. PUBLIC/anon/authenticated execute önce kaldırılır; yalnız anon ve
authenticated'a verilir. Tek gövde farkı: mevcut guardians satırı, reşit kişiyi
izin kontrolüne sokmaz. Türkiye takviminde 18 yaşını dolduran, sonuç kadrosunda
ve aynı branşta kayıtlı sporcunun adı veli izni/ret tercihinden bağımsızdır.
Çocuk veya doğum tarihi boş kişide canlı izin/ret kuralı aynen korunur.

Tek yeni senaryo: 25 yaş, branş kaydı ve veli ilişkisi var, izin yokken ad;
aynı velinin allowed=false tercihinden sonra da ad; tam 18. yaş gününde de ad.
time/rank çıktı allowlist'i ve UUID gizliliği ayrıca kontrol edilir.
Fixture artık 0097 ardından 0098 uygular; yeniden uygulama ve grant testleri de
son fonksiyon sürümünü kontrol eder. Skor/set/fikstür/yayın anahtarı değişmedi.

`node --test tools/federation_public_sql_test.mjs`: **28/28 geçti**, çıkış 0.
Önceki çocuk, bilinmeyen doğum, izin silme ve ret baskınlığı senaryoları dahil.
`python tools/check_migrations.py supabase/migrations/0098_public_result_adult_name.sql`:
OK, 0 sorun. `git diff --check`: çıkış 0. 0098 gövdesi eski fonksiyonla
karşılaştırıldı: yalnız belirtilen koşul kaldırıldı, imza/çıktı/grant aynı.
Log: `build/federation-phase-b/sql-0098.log`.
Dart ürün kodu değişmedi; bu düzeltmede Flutter analyze çalıştırılmadı.
Yerel commit dışında push/deploy/canlı SQL yapılmadı.
