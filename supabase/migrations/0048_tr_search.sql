-- 0048 — Türkçe arama normalizasyonu (veritabanı tarafı)
--
-- Uygulama tarafında `trFold`/`trContains` (swansport_core) var ve on iki
-- dosya ona geçirildi. Ama istemci yalnızca **çekilmiş** listeyi süzebiliyor;
-- sorgu veritabanında yapılıyorsa oradaki karşılığı da olmalı. Pazaryeri
-- araması binlerce ilan arasından süzecek, istemcide filtrelemek mümkün değil.
--
-- SORUN: `lower()` Türkçe harfleri olduğu gibi bırakıyor.
--
--   lower('Işıklar')                    -> 'ışıklar'
--   lower('Işıklar') like '%isiklar%'   -> false
--
-- Kullanıcı "isiklar" yazıyor, "Işıklar Kort" bulunmuyor.
--
-- `unaccent` eklentisi bu işi görmüyor: Türkçe'de `ı` ile `i` ayrı harfler,
-- aksan değil. Eşleme elle yazılıyor.

-- ---------------------------------------------------------------------------
-- Arama için metni sadeleştirir.
--
-- `translate` ÖNCE, `lower` SONRA: bazı yerelleştirmelerde `lower('İ')`
-- birleşik noktalı bir dizi üretiyor ve sonrasında hiçbir eşleme tutmuyor.
-- Büyük Türkçe harfleri kendimiz karşılığına çevirip geri kalanı `lower`'a
-- bırakınca bu tuzağa hiç girilmiyor.
--
-- IMMUTABLE olmak zorunda: indeks ifadelerinde kullanılacak. `translate` ve
-- `lower` ikisi de immutable, o yüzden sorun yok.
-- ---------------------------------------------------------------------------
create or replace function public.tr_fold(p_text text)
returns text
language sql
immutable
strict
parallel safe
as $fn$
  select lower(translate(p_text,
    'ıİşŞğĞüÜöÖçÇâÂîÎûÛ',
    'iisSgGuUoOcCaaiiuu'));
$fn$;

comment on function public.tr_fold(text) is
  'Aramada karşılaştırmak için Türkçe metni sadeleştirir. '
  'swansport_core/text/tr_text.dart içindeki trFold ile aynı davranış — '
  'ikisi ayrışırsa istemci ve sunucu farklı sonuç verir.';

-- ---------------------------------------------------------------------------
-- `x` içinde `y` geçiyor mu — Türkçe duyarsız.
--
-- Boş arama her şeyi eşler; çağıran tarafta ayrıca kontrol gerekmesin.
-- ---------------------------------------------------------------------------
create or replace function public.tr_contains(p_haystack text, p_needle text)
returns boolean
language sql
immutable
parallel safe
as $fn$
  select coalesce(p_needle, '') = ''
      or public.tr_fold(coalesce(p_haystack, ''))
         like '%' || public.tr_fold(p_needle) || '%';
$fn$;

-- ---------------------------------------------------------------------------
-- Mevcut arama yapılan alanlarda indeks
--
-- `pg_trgm` olmadan `like '%...%'` indeks kullanamıyor. Eklenti Supabase'de
-- mevcut; onunla `gin` indeksi ortadaki eşleşmeleri de hızlandırıyor.
--
-- Şimdilik yalnızca ilan başlığı: pazaryeri araması buradan geçecek ve
-- listelerin en büyüğü o olacak. Diğer tablolar küçük; indeks eklemek
-- yazma maliyeti getirir, kazancı getirmez.
-- ---------------------------------------------------------------------------
create extension if not exists pg_trgm;

create index if not exists idx_listings_title_trfold
  on public.listings using gin (public.tr_fold(title) gin_trgm_ops);

revoke execute on function public.tr_fold(text) from public;
grant execute on function public.tr_fold(text) to anon, authenticated;
revoke execute on function public.tr_contains(text, text) from public;
grant execute on function public.tr_contains(text, text) to anon, authenticated;
